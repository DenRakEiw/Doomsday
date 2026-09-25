"""Renders the game's sound set from tools/audio/recipes.json (docs/specs/audio.md §9, §10).

    uv run --project tools/audio python tools/audio/synth.py [--only <id>] [--check]

`data/audio.json` says where each file goes (a recipe's id is the file's stem);
`recipes.json` says how it sounds. Every recipe is rendered in float64 at the
sheet's rate, post-processed, written (WAV 16-bit for cues, OGG Vorbis q0.5 for
loops), read back and measured. One line per file:

    id  peak dBFS  LUFS  length s  bytes  [seam dB]

`--check` renders in memory, compares every file byte for byte with the one on
disk and every measurement with the targets of audio.md §10.1, and exits 1 on
any miss. That is the tool's own test.

Determinism: all randomness comes from the recipe's seed. Channel 0's noise and
every `repeat` jitter are drawn from `default_rng(seed)`, channel 1's noise from
`default_rng(seed + 1)`, in voice order. libsndfile gives every Ogg stream a
random serial number, so the tool rewrites the serial of each page to a fixed
value (and the page checksum with it); with the pinned soundfile wheel (uv.lock)
the OGG files are then byte-identical run to run, like the WAVs.

Rendering notes (audio.md §9.2):
- Oscillators are additive and band-limited to 0.45 × rate, with the harmonic
  count fixed by the voice's highest frequency so a glide never switches a
  harmonic on mid-note.
- A release falls exponentially to -60 dB and is offset so it ends at exactly 0.
- A loop voice without `t`/`d` spans the loop: its phase is scaled so it runs a
  whole number of cycles (that is the "snap to a multiple of 1/length", and it
  also holds under `vib` and `detune`), its `trem`/`vib` rates are snapped, it
  has no envelope, and its filters are applied in the frequency domain over the
  whole loop, so the end runs into the start. A loop voice with `t`/`d` is
  rendered with its envelope and causal filters and wrapped around the end.
- The post filters (30 Hz high-pass, the recipe's lp/hp) are circular for loops
  and causal for cues.
- An ambience loop is rotated so the file starts on its quietest near-zero
  frame: the frame with the smallest |x| on both sides among the quietest 1 % of
  the loop (50 ms windows). Vorbis codes the file's two edges without each other,
  so the join carries a small step of codec error, and it is smallest where the
  signal is near zero (it was a click in `amb_emergent`, whose file started on
  its sub-bass swell). The music stems are not rotated: they start together and
  must stay in step.
- `--check` also fails a loop whose join is a larger step than any inside it.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import struct
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pyloudnorm
import soundfile
from scipy import signal

ROOT = Path(__file__).resolve().parents[2]
SHEET_PATH = ROOT / "data" / "audio.json"
RECIPES_PATH = ROOT / "tools" / "audio" / "recipes.json"
AUDIO_DIR = ROOT / "assets" / "audio"

POST_HIGHPASS_HZ = 30.0
CUE_FADE_S = 0.005
HARMONIC_LIMIT = 0.45  # × rate
RELEASE_FLOOR_DB = -60.0
LOOP_TAIL_S = 0.5  # filter ring kept after a t/d voice in a loop before wrapping
OGG_QUALITY = 0.5  # Vorbis quality (libsndfile's compression level is 1 - quality)
OGG_SERIAL = 0x444F4F4D  # "DOOM": the fixed stream serial number
OGG_BLOCK = 4096  # frames per write
QUIET_WINDOW_S = 0.05  # the window of an ambience loop's rotation search
QUIET_PERCENTILE = 1.0  # … among the quietest this many percent of windows

DEFAULTS = {"t": 0.0, "a": 0.005, "r": 0.005, "db": 0.0, "detune": 0.0, "pan": 0.0}

# audio.md §10.1: (group, cue ids or a prefix test, allowed recipe value range).
PEAK_CEILING_DB = -1.0
PEAK_TOLERANCE_DB = 0.5
LUFS_TOLERANCE = 1.0
CLICKS = {"ui_click", "ui_select", "boot_line", "ui_pause", "ui_speed", "ui_dissolve"}
BIG_FIVE = {"alert_discovered", "phase_open", "tf_appeared", "tf_acted"}
STEM_LUFS = {"mus_bed": -28.0, "mus_pulse": -30.0, "mus_chords": -28.0, "mus_edge": -32.0}


def target_range(recipe_id: str, kind: str) -> tuple[str, float, float]:
    """The §10.1 group a file belongs to and the range its recipe value must lie in."""
    if kind == "loop":
        if recipe_id in STEM_LUFS:
            value = STEM_LUFS[recipe_id]
            return ("music stem", value, value)
        if recipe_id == "amb_covert":
            return ("ambience", -34.0, -34.0)
        return ("ambience", -32.0, -32.0)
    if recipe_id in CLICKS:
        return ("click", -16.0, -12.0)
    if recipe_id in BIG_FIVE or recipe_id.startswith("end_"):
        return ("big five", -4.0, -3.0)
    if recipe_id.startswith("map_") or recipe_id == "tf_move":
        return ("map", -18.0, -16.0)
    if recipe_id.startswith("prep_"):
        return ("prep", -14.0, -14.0)
    if recipe_id.startswith("ui_") or recipe_id.startswith("boot_"):
        # D6.8 widened both by 1 dB (audio.md §10.1): ui_open/ui_close at -12, ev_expired at -11.
        return ("interface", -12.0, -6.0)
    return ("alert", -11.0, -5.0)


# ---------------------------------------------------------------- the data


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def sheet_files(sheet: dict) -> dict[str, str]:
    """Stem → the file's path under assets/audio/, from every part of the sheet."""
    files: list[str] = [cue["file"] for cue in sheet["cues"]]
    files += [layer["file"] for layer in sheet["ambience"]["layers"]]
    files += [stem["file"] for stem in sheet["music"]["stems"]]
    return {Path(file).stem: file for file in files}


def resolve_recipes(data: dict) -> dict[str, dict]:
    """Recipes by id, with `from` expanded (audio.md §9.2.1)."""
    by_id: dict[str, dict] = {recipe["id"]: recipe for recipe in data["recipes"]}
    resolved: dict[str, dict] = {}
    for recipe_id, recipe in by_id.items():
        if "from" in recipe:
            source = by_id[recipe["from"]]
            merged = dict(recipe)
            for key in ("channels", "length", "seed", "voices"):
                merged[key] = source[key]
            recipe = merged
        resolved[recipe_id] = recipe
    return resolved


# ---------------------------------------------------------------- filters


def butter_sos(kind: str, hz: float, rate: int) -> np.ndarray:
    return signal.butter(2, hz, btype=kind, fs=rate, output="sos")


def bandpass_sos(centre: float, q: float, rate: int) -> np.ndarray:
    """RBJ band-pass, constant 0 dB peak gain."""
    w0 = 2.0 * math.pi * centre / rate
    alpha = math.sin(w0) / (2.0 * q)
    b = np.array([alpha, 0.0, -alpha])
    a = np.array([1.0 + alpha, -2.0 * math.cos(w0), 1.0 - alpha])
    return signal.tf2sos(b / a[0], a / a[0])


def voice_filters(voice: dict, rate: int) -> list[np.ndarray]:
    filters: list[np.ndarray] = []
    if "hp" in voice:
        filters.append(butter_sos("highpass", float(voice["hp"]), rate))
    if "lp" in voice:
        filters.append(butter_sos("lowpass", float(voice["lp"]), rate))
    if "bp" in voice:
        filters.append(bandpass_sos(float(voice["bp"][0]), float(voice["bp"][1]), rate))
    return filters


def post_filters(post: dict, rate: int) -> list[np.ndarray]:
    filters = [butter_sos("highpass", POST_HIGHPASS_HZ, rate)]
    if "hp" in post:
        filters.append(butter_sos("highpass", float(post["hp"]), rate))
    if "lp" in post:
        filters.append(butter_sos("lowpass", float(post["lp"]), rate))
    return filters


def filter_causal(x: np.ndarray, filters: list[np.ndarray]) -> np.ndarray:
    for sos in filters:
        x = signal.sosfilt(sos, x, axis=0)
    return x


def filter_circular(x: np.ndarray, filters: list[np.ndarray], rate: int) -> np.ndarray:
    """FFT × each filter's magnitude response, inverse FFT: a seamless, zero-phase filter."""
    if not filters:
        return x
    n = x.shape[0]
    spectrum = np.fft.rfft(x, axis=0)
    freqs = np.fft.rfftfreq(n, 1.0 / rate)
    gain = np.ones(freqs.shape[0])
    for sos in filters:
        _, response = signal.sosfreqz(sos, worN=freqs, fs=rate)
        gain *= np.abs(response)
    if x.ndim == 2:
        gain = gain[:, None]
    return np.fft.irfft(spectrum * gain, n=n, axis=0)


# ---------------------------------------------------------------- oscillators


def harmonic_series(wave: str, count: int) -> list[tuple[int, float]]:
    """(harmonic, amplitude) pairs of a band-limited wave (Fourier series)."""
    if wave == "sine":
        return [(1, 1.0)]
    series: list[tuple[int, float]] = []
    for k in range(1, count + 1):
        if wave == "saw":
            series.append((k, (2.0 / math.pi) * (1.0 if k % 2 == 1 else -1.0) / k))
        elif wave == "square" and k % 2 == 1:
            series.append((k, (4.0 / math.pi) / k))
        elif wave == "triangle" and k % 2 == 1:
            sign = 1.0 if (k // 2) % 2 == 0 else -1.0
            series.append((k, (8.0 / math.pi**2) * sign / (k * k)))
    return series or [(1, 1.0)]


def additive(wave: str, phase: np.ndarray, top_hz: float, rate: int) -> np.ndarray:
    """Σ a_k sin(k φ) by the Chebyshev recurrence sin(kφ) = 2 cos φ sin((k-1)φ) - sin((k-2)φ)."""
    count = max(1, int(HARMONIC_LIMIT * rate / max(top_hz, 1e-9)))
    series = harmonic_series(wave, count)
    amplitudes = dict(series)
    top = series[-1][0]
    two_cos = 2.0 * np.cos(phase)
    previous = np.zeros_like(phase)
    current = np.sin(phase)
    out = amplitudes.get(1, 0.0) * current
    for k in range(2, top + 1):
        previous, current = current, two_cos * current - previous
        amplitude = amplitudes.get(k)
        if amplitude is not None:
            out += amplitude * current
    return out


def snap(value: float, length: float) -> float:
    """The nearest multiple of 1/length Hz (never 0 for a non-zero rate)."""
    steps = round(value * length)
    if steps == 0 and value != 0.0:
        steps = 1
    return steps / length


def frequency_curve(voice: dict, n: int, rate: int, cents: float, spanning: bool, length: float) -> np.ndarray:
    tau = np.arange(n) / rate
    f = voice["f"]
    if isinstance(f, list):
        f0, f1 = float(f[0]), float(f[1])
        if spanning:
            f0, f1 = snap(f0, length), snap(f1, length)
        duration = n / rate
        curve = f0 * (f1 / f0) ** (tau / duration)
    else:
        curve = np.full(n, float(f))
    if cents != 0.0:
        curve = curve * 2.0 ** (cents / 1200.0)
    if "vib" in voice:
        vib_rate, vib_cents = float(voice["vib"][0]), float(voice["vib"][1])
        if spanning:
            vib_rate = snap(vib_rate, length)
        curve = curve * 2.0 ** (vib_cents / 1200.0 * np.sin(2.0 * math.pi * vib_rate * tau))
    return curve


def oscillator(voice: dict, n: int, rate: int, cents: float, spanning: bool, length: float) -> np.ndarray:
    curve = frequency_curve(voice, n, rate, cents, spanning, length)
    cycles = np.concatenate(([0.0], np.cumsum(curve[:-1]))) / rate
    if spanning:
        # A whole number of cycles over the loop: the phase at the end is the phase at the start.
        total = float(np.sum(curve)) / rate
        whole = max(1.0, round(total))
        cycles *= whole / total
        curve = curve * (whole / total)
    phase = 2.0 * math.pi * np.mod(cycles, 1.0)
    return additive(voice["wave"], phase, float(np.max(curve)), rate)


def envelope(n: int, rate: int, attack: float, release: float) -> np.ndarray:
    tau = np.arange(n) / rate
    duration = n / rate
    env = np.ones(n)
    if attack > 0.0:
        env *= np.minimum(tau / attack, 1.0)
    if release > 0.0:
        floor = 10.0 ** (RELEASE_FLOOR_DB / 20.0)
        x = np.clip((tau - (duration - release)) / release, 0.0, 1.0)
        env *= (floor**x - floor) / (1.0 - floor)
    return env


def tremolo(voice: dict, n: int, rate: int, spanning: bool, length: float, offset: float = 0.0) -> np.ndarray:
    if "trem" not in voice:
        return np.ones(n)
    trem_rate, depth = float(voice["trem"][0]), float(voice["trem"][1])
    if spanning:
        trem_rate = snap(trem_rate, length)
    tau = offset + np.arange(n) / rate
    return 1.0 - depth * (0.5 - 0.5 * np.cos(2.0 * math.pi * trem_rate * tau))


def pan_gains(voice: dict, channels: int) -> list[float]:
    if channels == 1:
        return [1.0]
    angle = (float(voice.get("pan", 0.0)) + 1.0) * math.pi / 4.0
    return [math.cos(angle), math.sin(angle)]


def channel_cents(voice: dict, channel: int, channels: int) -> float:
    if channels == 1:
        return 0.0
    detune = float(voice.get("detune", 0.0))
    return -detune / 2.0 if channel == 0 else detune / 2.0


# ---------------------------------------------------------------- rendering


@dataclass
class Rendered:
    recipe_id: str
    kind: str
    audio: np.ndarray  # frames × channels, float64
    rate: int
    shortfall_db: float  # loops: how far the -1 dBFS ceiling kept it from its LUFS target


def render_voice_segment(voice: dict, n: int, rate: int, channels: int, rngs: list[np.random.Generator],
                         spanning: bool, length: float, offset: float) -> np.ndarray:
    """One placement of a voice: frames × channels, before filters and gain."""
    out = np.zeros((n, channels))
    if spanning:
        env = np.ones(n)
    else:
        env = envelope(n, rate, float(voice.get("a", DEFAULTS["a"])), float(voice.get("r", DEFAULTS["r"])))
    trem = tremolo(voice, n, rate, spanning, length, offset)
    for c in range(channels):
        if voice["wave"] == "noise":
            wave = rngs[c].uniform(-1.0, 1.0, n)
        else:
            wave = oscillator(voice, n, rate, channel_cents(voice, c, channels), spanning, length)
        out[:, c] = wave * env * trem
    return out


def quietest_frame(audio: np.ndarray, rate: int) -> int:
    """The loop's new first frame: near zero on both sides of the join, in a quiet stretch."""
    window = max(1, round(QUIET_WINDOW_S * rate))
    power = np.sum(audio**2, axis=1)
    wrapped = np.concatenate((power[-window:], power, power[:window]))
    running = np.convolve(wrapped, np.ones(window) / window, mode="same")[window:-window]
    quiet = running <= np.percentile(running, QUIET_PERCENTILE)
    edges = np.sum(np.abs(audio), axis=1) + np.sum(np.abs(np.roll(audio, 1, axis=0)), axis=1)
    return int(np.argmin(np.where(quiet, edges, np.inf)))


def render_recipe(recipe: dict, rate: int, rotate: bool = False) -> Rendered:
    kind = recipe["kind"]
    channels = int(recipe["channels"])
    length = float(recipe["length"])
    frames = round(length * rate)
    seed = int(recipe["seed"])
    rngs = [np.random.default_rng(seed + c) for c in range(channels)]
    is_loop = kind == "loop"
    mix = np.zeros((frames, channels))

    for voice in recipe["voices"]:
        gain = 10.0 ** (float(voice.get("db", DEFAULTS["db"])) / 20.0)
        pans = np.array(pan_gains(voice, channels))
        filters = voice_filters(voice, rate)
        spanning = is_loop and "t" not in voice and "d" not in voice and "repeat" not in voice
        if spanning:
            segment = render_voice_segment(voice, frames, rate, channels, rngs, True, length, 0.0)
            segment = filter_circular(segment, filters, rate)
            mix += segment * gain * pans
            continue

        start = float(voice.get("t", DEFAULTS["t"]))
        duration = float(voice["d"]) if "d" in voice else length - start
        starts = [start]
        if "repeat" in voice:
            every = float(voice["repeat"]["every"])
            jitter = float(voice["repeat"].get("jitter", 0.0))
            starts = []
            at = start
            while at < length - 1e-9:
                starts.append(at)
                at += every
            if jitter > 0.0:
                draws = rngs[0].uniform(-jitter, jitter, len(starts))
                starts = [s + float(j) for s, j in zip(starts, draws)]
        n = max(1, round(duration * rate))
        for placed in starts:
            segment = render_voice_segment(voice, n, rate, channels, rngs, False, length, 0.0)
            if is_loop:
                tail = np.zeros((n + round(LOOP_TAIL_S * rate), channels))
                tail[:n] = segment
                tail = filter_causal(tail, filters) * gain * pans
                begin = round(placed * rate) % frames
                index = (begin + np.arange(tail.shape[0])) % frames
                np.add.at(mix, index, tail)
            else:
                begin = round(placed * rate)
                if begin >= frames:
                    continue
                span = np.zeros((frames - begin, channels))
                keep = min(n, span.shape[0])
                span[:keep] = segment[:keep]
                mix[begin:] += filter_causal(span, filters) * gain * pans

    post = recipe["post"]
    filters = post_filters(post, rate)
    shortfall = 0.0
    if is_loop:
        mix = filter_circular(mix, filters, rate)
        if rotate:
            mix = np.roll(mix, -quietest_frame(mix, rate), axis=0)
        meter = pyloudnorm.Meter(rate)
        loudness = meter.integrated_loudness(mix)
        scale = 10.0 ** ((float(post["lufs"]) - loudness) / 20.0)
        peak = float(np.max(np.abs(mix))) * scale
        ceiling = 10.0 ** (PEAK_CEILING_DB / 20.0)
        if peak > ceiling:
            shortfall = 20.0 * math.log10(peak / ceiling)
            scale *= ceiling / peak
        mix *= scale
    else:
        mix = filter_causal(mix, filters)
        fade = min(frames, round(CUE_FADE_S * rate))
        mix[frames - fade:] *= np.linspace(1.0, 0.0, fade)[:, None]
        peak = float(np.max(np.abs(mix)))
        mix *= 10.0 ** (float(post["peak_db"]) / 20.0) / peak
    return Rendered(recipe["id"], kind, mix, rate, shortfall)


# ---------------------------------------------------------------- encoding


def ogg_crc(data: bytes) -> int:
    crc = 0
    for byte in data:
        crc ^= byte << 24
        for _ in range(8):
            crc = ((crc << 1) ^ 0x04C11DB7) if crc & 0x80000000 else (crc << 1)
            crc &= 0xFFFFFFFF
    return crc


_CRC_TABLE: list[int] = []


def ogg_crc_fast(data: bytes) -> int:
    if not _CRC_TABLE:
        for i in range(256):
            _CRC_TABLE.append(ogg_crc(bytes([i])))
    crc = 0
    for byte in data:
        crc = ((crc << 8) & 0xFFFFFFFF) ^ _CRC_TABLE[((crc >> 24) ^ byte) & 0xFF]
    return crc


def fix_ogg_serial(data: bytes) -> bytes:
    """Rewrites every page's stream serial to OGG_SERIAL and its checksum to match."""
    out = bytearray(data)
    at = 0
    while at < len(out):
        if out[at:at + 4] != b"OggS":
            raise ValueError(f"not an Ogg page at byte {at}")
        segments = out[at + 26]
        body = sum(out[at + 27:at + 27 + segments])
        size = 27 + segments + body
        struct.pack_into("<I", out, at + 14, OGG_SERIAL)
        struct.pack_into("<I", out, at + 22, 0)
        struct.pack_into("<I", out, at + 22, ogg_crc_fast(bytes(out[at:at + size])))
        at += size
    return bytes(out)


def encode(rendered: Rendered) -> bytes:
    buffer = io.BytesIO()
    if rendered.kind == "loop":
        # In blocks: libsndfile's Vorbis writer overflows the stack on one large write.
        with soundfile.SoundFile(buffer, "w", rendered.rate, rendered.audio.shape[1], format="OGG",
                                 subtype="VORBIS", compression_level=1.0 - OGG_QUALITY) as handle:
            for begin in range(0, rendered.audio.shape[0], OGG_BLOCK):
                handle.write(rendered.audio[begin:begin + OGG_BLOCK])
        return fix_ogg_serial(buffer.getvalue())
    pcm = np.clip(np.round(rendered.audio * 32767.0), -32768, 32767).astype(np.int16)
    soundfile.write(buffer, pcm, rendered.rate, format="WAV", subtype="PCM_16")
    return buffer.getvalue()


# ---------------------------------------------------------------- measuring


@dataclass
class Measured:
    peak_db: float
    lufs: float | None
    seconds: float
    frames: int
    channels: int
    rate: int
    seam_db: float | None  # loops: the step at the join, dBFS
    step_db: float | None  # loops: the largest step inside the loop, dBFS


def measure(data: bytes) -> Measured:
    audio, rate = soundfile.read(io.BytesIO(data), dtype="float64", always_2d=True)
    frames, channels = audio.shape
    peak = float(np.max(np.abs(audio)))
    peak_db = 20.0 * math.log10(peak) if peak > 0.0 else -math.inf
    lufs: float | None = None
    if frames / rate > 0.4:
        lufs = float(pyloudnorm.Meter(rate).integrated_loudness(audio))
    seam: float | None = None
    step: float | None = None
    if frames > 1:
        # The loop's join as the decoder plays it (last frame → first) against its largest
        # frame-to-frame step inside: a join above every step inside is a click.
        seam = to_db(float(np.max(np.abs(audio[0] - audio[-1]))))
        step = to_db(float(np.max(np.abs(np.diff(audio, axis=0)))))
    return Measured(peak_db, lufs, frames / rate, frames, channels, rate, seam, step)


def to_db(value: float) -> float:
    return 20.0 * math.log10(value) if value > 0.0 else -math.inf


# ---------------------------------------------------------------- checks


def check_file(recipe: dict, relative: str, rendered: Rendered, data: bytes, measured: Measured) -> list[str]:
    problems: list[str] = []
    recipe_id = recipe["id"]
    kind = recipe["kind"]
    expected_ext = ".ogg" if kind == "loop" else ".wav"
    if Path(relative).suffix != expected_ext:
        problems.append(f"{recipe_id}: a {kind} must be {expected_ext}, the sheet says {relative}")
    path = AUDIO_DIR / relative
    if not path.exists():
        problems.append(f"{recipe_id}: {relative} is missing")
    elif hashlib.sha256(path.read_bytes()).hexdigest() != hashlib.sha256(data).hexdigest():
        problems.append(f"{recipe_id}: {relative} differs from the render")
    if measured.rate != 44100:
        problems.append(f"{recipe_id}: {measured.rate} Hz")
    if measured.frames != round(float(recipe["length"]) * 44100):
        problems.append(f"{recipe_id}: {measured.frames} frames, the recipe says {recipe['length']} s")
    want_channels = 2 if kind == "loop" or recipe_id.startswith("end_") else 1
    if measured.channels != want_channels or int(recipe["channels"]) != want_channels:
        problems.append(f"{recipe_id}: {measured.channels} channels, want {want_channels}")
    if kind == "loop" and measured.seam_db is not None and measured.step_db is not None \
            and measured.seam_db > measured.step_db:
        problems.append(f"{recipe_id}: the join is a step of {measured.seam_db:.1f} dBFS, "
                        f"above any inside ({measured.step_db:.1f})")
    if measured.peak_db > PEAK_CEILING_DB:
        problems.append(f"{recipe_id}: peak {measured.peak_db:.2f} dBFS above {PEAK_CEILING_DB}")
    group, low, high = target_range(recipe_id, kind)
    post = recipe["post"]
    if kind == "loop":
        value = float(post["lufs"])
        if measured.lufs is None or abs(measured.lufs - value) > LUFS_TOLERANCE:
            problems.append(f"{recipe_id}: {measured.lufs} LUFS, the recipe says {value} ±{LUFS_TOLERANCE}")
        if rendered.shortfall_db > 0.0:
            problems.append(f"{recipe_id}: the ceiling held it {rendered.shortfall_db:.2f} dB short of {value} LUFS")
    else:
        value = float(post["peak_db"])
        if abs(measured.peak_db - value) > PEAK_TOLERANCE_DB:
            problems.append(f"{recipe_id}: peak {measured.peak_db:.2f} dBFS, the recipe says {value} ±{PEAK_TOLERANCE_DB}")
    if not low - 1e-9 <= value <= high + 1e-9:
        # §10.1: "the exact per-file value is the recipe's post" — the group range is the
        # intent, so a recipe outside it is reported, not failed.
        print(f"note  {recipe_id}: the recipe's {value} lies outside the {group} range {low}…{high}")
    return problems


def check_coverage(files: dict[str, str], recipes_data: dict) -> list[str]:
    problems: list[str] = []
    ids = [recipe["id"] for recipe in recipes_data["recipes"]]
    for recipe_id in sorted(set(ids)):
        if ids.count(recipe_id) > 1:
            problems.append(f"{recipe_id}: {ids.count(recipe_id)} recipes")
    for stem in sorted(files):
        if stem not in ids:
            problems.append(f"{stem}: in the sheet, no recipe")
    for recipe_id in sorted(set(ids)):
        if recipe_id not in files:
            problems.append(f"{recipe_id}: a recipe, not in the sheet")
    return problems


def check_stems(results: dict[str, Measured], sheet: dict) -> list[str]:
    stems = [Path(stem["file"]).stem for stem in sheet["music"]["stems"]]
    lengths = {stem: results[stem].frames for stem in stems if stem in results}
    if len(set(lengths.values())) > 1:
        return [f"the music stems differ in length: {lengths}"]
    return []


# ---------------------------------------------------------------- main


def format_line(recipe_id: str, measured: Measured, size: int) -> str:
    lufs = f"{measured.lufs:7.2f}" if measured.lufs is not None and math.isfinite(measured.lufs) else "      -"
    seam = ""
    if recipe_id.startswith(("amb_", "mus_")) and measured.seam_db is not None:
        seam = f"  join {measured.seam_db:6.1f} dBFS (largest step {measured.step_db:6.1f})"
    return f"{recipe_id:28s} {measured.peak_db:7.2f} dBFS {lufs} LUFS {measured.seconds:6.2f} s {size:8d} B{seam}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--only", help="render (or check) one recipe id")
    parser.add_argument("--check", action="store_true", help="render in memory and compare, write nothing")
    args = parser.parse_args()

    sheet = load_json(SHEET_PATH)
    recipes_data = load_json(RECIPES_PATH)
    rate = int(recipes_data["rate"])
    files = sheet_files(sheet)
    recipes = resolve_recipes(recipes_data)

    problems = check_coverage(files, recipes_data)
    ids = [recipe["id"] for recipe in recipes_data["recipes"] if recipe["id"] in files]
    if args.only:
        if args.only not in recipes or args.only not in files:
            print(f"unknown id {args.only}", file=sys.stderr)
            return 2
        ids = [args.only]

    results: dict[str, Measured] = {}
    stems = {Path(stem["file"]).stem for stem in sheet["music"]["stems"]}
    for recipe_id in ids:
        recipe = recipes[recipe_id]
        rotate = recipe["kind"] == "loop" and recipe_id not in stems
        rendered = render_recipe(recipe, rate, rotate)
        data = encode(rendered)
        measured = measure(data)
        results[recipe_id] = measured
        if args.check:
            problems += check_file(recipe, files[recipe_id], rendered, data, measured)
        else:
            path = AUDIO_DIR / files[recipe_id]
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            if rendered.shortfall_db > 0.0:
                problems.append(f"{recipe_id}: the ceiling held it {rendered.shortfall_db:.2f} dB short")
        print(format_line(recipe_id, measured, len(data)), flush=True)

    if not args.only:
        problems += check_stems(results, sheet)
        total = sum((AUDIO_DIR / files[recipe_id]).stat().st_size for recipe_id in ids
                    if (AUDIO_DIR / files[recipe_id]).exists())
        print(f"{len(ids)} files, {total / 1e6:.2f} MB on disk")
    for problem in problems:
        print(f"MISS  {problem}", file=sys.stderr)
    if args.check:
        print("check: " + ("ok" if not problems else f"{len(problems)} misses"))
    return 1 if problems and args.check else 0


if __name__ == "__main__":
    sys.exit(main())
