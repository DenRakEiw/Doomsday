"""The browser performance runs (docs/specs/web.md §13.2).

    uv run --project tools/web python tools/web/web_perf.py [--build build/perf-web]
        [--release build/web] [--modes web_igpu,web_cpu,load] [--runs 3]
        [--port 8767] [--out <dir>] [--vsync] [--cpu-throttle 2.5]

Export first: `"Perf web (local)"` → `build/perf-web/index.html` (the bench) and
`"Web"` → `build/web/index.html` (the load times). Everything runs in
Playwright's own Chromium, headless (the new headless mode, which draws on the
machine's GPU), with a fresh profile per run:

- `web_igpu`: 1280 × 720 at device scale 1.5 (a 1920 × 1080 canvas) on the
  integrated GPU. Windows' per-application GPU preference is set to "power
  saving" for Playwright's `chrome.exe` only and removed again afterwards,
  whatever happens; the user's own browsers are never touched. A run whose
  adapter is not the integrated one does not count.
- `web_cpu`: 1280 × 720 at scale 1 on the default GPU, the DevTools protocol's
  CPU throttling at 2.5 (release.md §11.3's single-thread factor).
- `load`: the release export, network 50 Mbit/s down, 10 up, 20 ms; the clock
  runs from the navigation to the console's `first screen` line — cold in a
  fresh persistent profile, warm on a second navigation in the same one (the
  bytes that came over the network are printed beside each).

Each bench run waits for the bench's `perf:` summary line on the console; the
run with the median p95 frame counts. The page's WebAssembly memory (it only
grows, so its size at the end is the peak) is read beside the bench's own
static memory peak, which a release template does not count.

By default the browser's frame-rate limit is lifted (`--disable-gpu-vsync
--disable-frame-rate-limit`), so a frame's time is its work, not the wait for
the display; `--vsync` keeps the limit (every frame then takes at least 16.7 ms).

The server binds 127.0.0.1 on `--port` (default 8767, clear of `serve.py`'s and
`web_check.py`'s 8765/8766). Prints one line per run and a summary per mode;
writes `web_perf.json` and each bench run's console (`<mode>_<n>.log`) into
`--out`. Exit 0 when every run finished, 1 otherwise.
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
import tempfile
import time
import winreg
from dataclasses import dataclass, field
from pathlib import Path

from playwright.sync_api import Browser, ConsoleMessage, Page, Playwright, sync_playwright

sys.path.insert(0, str(Path(__file__).resolve().parent))
import serve  # noqa: E402 - the sibling module

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_PORT = 8767
MODES = ("web_igpu", "web_cpu", "load")
VIEWPORT = {"width": 1280, "height": 720}
IGPU_SCALE = 1.5
CPU_THROTTLE = 2.5
# web.md §13.1's load row.
NETWORK = {
    "offline": False,
    "latency": 20,
    "downloadThroughput": 50_000_000 / 8,
    "uploadThroughput": 10_000_000 / 8,
}
PERF_PREFIX = "perf: "
PERF_ADAPTER = "perf: adapter="
FIRST_SCREEN = "first screen"
# The bench's own watchdog is 900 s; the page gets a little more.
BENCH_TIMEOUT_S = 960
LOAD_TIMEOUT_S = 120
POLL_MS = 500
# Windows' per-application GPU preference (release.md §11.3).
GPU_KEY = r"Software\Microsoft\DirectX\UserGpuPreferences"
GPU_POWER_SAVING = "GpuPreference=1;"
# The integrated adapter's WebGL renderer string names its vendor; the RTX's
# says NVIDIA.
IGPU_MARKERS = ("AMD", "Radeon")
UNTHROTTLED_ARGS = ["--disable-gpu-vsync", "--disable-frame-rate-limit"]
BROWSER_ARGS = ["--mute-audio"]
MB = 1_048_576

# Keeps every WebAssembly memory the page instantiates, so its size can be read.
JS_KEEP_MEMORY = """
(() => {
	window.__wasmMemories = [];
	const keep = (result) => {
		try {
			const instance = result.instance || result;
			for (const name in instance.exports) {
				if (instance.exports[name] instanceof WebAssembly.Memory) {
					window.__wasmMemories.push(instance.exports[name]);
				}
			}
		} catch (e) { }
		return result;
	};
	const streaming = WebAssembly.instantiateStreaming;
	if (streaming) {
		WebAssembly.instantiateStreaming = function () { return streaming.apply(this, arguments).then(keep); };
	}
	const plain = WebAssembly.instantiate;
	WebAssembly.instantiate = function () { return plain.apply(this, arguments).then(keep); };
	const Memory = WebAssembly.Memory;
	WebAssembly.Memory = function (descriptor) {
		const memory = new Memory(descriptor);
		window.__wasmMemories.push(memory);
		return memory;
	};
	WebAssembly.Memory.prototype = Memory.prototype;
})();
"""
JS_MEMORY_BYTES = "() => Math.max(0, ...(window.__wasmMemories || []).map((m) => m.buffer.byteLength))"
JS_RENDERER = """
() => {
	const gl = document.createElement('canvas').getContext('webgl2');
	if (!gl) { return 'no webgl2'; }
	const info = gl.getExtension('WEBGL_debug_renderer_info');
	return info ? gl.getParameter(info.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER);
}
"""


@dataclass
class Console:
    """The page's console as it arrives, with the time of each line."""

    lines: list[tuple[float, str]] = field(default_factory=list)

    def on_message(self, message: ConsoleMessage) -> None:
        self.lines.append((time.monotonic(), message.text))

    def first(self, prefix: str, after: int = 0) -> tuple[float, str] | None:
        for stamp, text in self.lines[after:]:
            if text.startswith(prefix):
                return stamp, text
        return None


def launch(playwright: Playwright, vsync: bool) -> Browser:
    args = BROWSER_ARGS + ([] if vsync else UNTHROTTLED_ARGS)
    # `channel="chromium"` is the full build in the new headless mode: it draws
    # on the GPU (the headless shell only gets SwiftShader).
    return playwright.chromium.launch(channel="chromium", headless=True, args=args)


def wait_for(page: Page, console: Console, prefix: str, timeout_s: float, after: int = 0) -> tuple[float, str] | None:
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        found = console.first(prefix, after)
        if found is not None:
            return found
        page.wait_for_timeout(POLL_MS)
    return None


def summary_of(console: Console) -> dict | None:
    for _stamp, text in console.lines:
        if text.startswith(PERF_PREFIX + "{"):
            return json.loads(text[len(PERF_PREFIX):])
    return None


def bench_run(playwright: Playwright, mode: str, url: str, vsync: bool, log: Path,
              throttle: float) -> dict:
    """One bench run; the summary, or a dict with `error`. The page's console goes to `log`."""
    browser = launch(playwright, vsync)
    try:
        scale = IGPU_SCALE if mode == "web_igpu" else 1.0
        context = browser.new_context(viewport=VIEWPORT, device_scale_factor=scale)
        context.add_init_script(JS_KEEP_MEMORY)
        page = context.new_page()
        console = Console()
        page.on("console", console.on_message)
        renderer = page.evaluate(JS_RENDERER)
        if mode == "web_cpu" and throttle > 1.0:
            cdp = context.new_cdp_session(page)
            cdp.send("Emulation.setCPUThrottlingRate", {"rate": throttle})
        started = time.monotonic()
        page.goto(url, wait_until="commit")
        found = wait_for(page, console, PERF_PREFIX + "{", BENCH_TIMEOUT_S)
        lines = ["%.3f %s" % (stamp - started, text) for stamp, text in console.lines]
        log.write_text("\n".join(lines), encoding="utf-8")
        if found is None:
            return {"error": "no summary line", "renderer": renderer,
                    "last": [text for _s, text in console.lines[-5:]]}
        result = summary_of(console) or {}
        adapter = console.first(PERF_ADAPTER)
        result["adapter_line"] = adapter[1] if adapter else ""
        result["renderer"] = renderer
        result["wasm_memory_mb"] = float(page.evaluate(JS_MEMORY_BYTES)) / MB
        result["wall_s"] = time.monotonic() - started
        # The engine sees the browser's masked name ("WebKit WebGL"); the page's
        # own WebGL context reads the real adapter.
        if mode == "web_igpu" and not any(m in renderer for m in IGPU_MARKERS):
            result["error"] = "not the integrated GPU"
        return result
    finally:
        browser.close()


def load_run(playwright: Playwright, url: str) -> dict:
    """Cold then warm load of the release export under the throttled network.

    A persistent profile in a fresh temporary folder: a plain context is
    off the record, and its in-memory cache refuses an entry the size of the
    `.wasm`, so its "warm" load would download everything again.
    """
    with tempfile.TemporaryDirectory(prefix="doomsday_web_perf_") as profile:
        context = playwright.chromium.launch_persistent_context(
            profile, channel="chromium", headless=True, args=BROWSER_ARGS + UNTHROTTLED_ARGS,
            viewport=VIEWPORT)
        try:
            page = context.pages[0] if context.pages else context.new_page()
            console = Console()
            page.on("console", console.on_message)
            received: list[float] = [0.0]
            cdp = context.new_cdp_session(page)
            cdp.on("Network.loadingFinished",
                   lambda event: received.__setitem__(0, received[0] + float(event["encodedDataLength"])))
            cdp.send("Network.enable")
            cdp.send("Network.emulateNetworkConditions", NETWORK)
            out: dict = {}
            for name in ("cold", "warm"):
                seen = len(console.lines)
                received[0] = 0.0
                started = time.monotonic()
                page.goto(url, wait_until="commit")
                found = wait_for(page, console, FIRST_SCREEN, LOAD_TIMEOUT_S, after=seen)
                out[name + "_s"] = (found[0] - started) if found else None
                out[name + "_mb"] = received[0] / MB
            return out
        finally:
            context.close()


def median_run(runs: list[dict]) -> dict | None:
    counted = [run for run in runs if "error" not in run]
    if not counted:
        return None
    counted.sort(key=lambda run: float(run["frame_p95_ms"]))
    return counted[(len(counted) - 1) // 2]


def describe(run: dict) -> str:
    if "error" in run:
        return "FAILED: %s" % run["error"]
    return ("p50 %.2f p95 %.2f p99 %.2f max %.1f (with changes %.1f) | process p95 %.2f | "
            "tick-frame p99 %.2f | tick mean %.2f max %.2f | draw %d | static %.0f MB wasm %.0f MB | "
            "load %.0f ms | %s | %s" % (
                run["frame_p50_ms"], run["frame_p95_ms"], run["frame_p99_ms"], run["frame_max_ms"],
                run["frame_max_with_changes_ms"], run["process_p95_ms"], run["tick_frame_p99_ms"],
                run["tick_mean_ms"], run["tick_max_ms"], run["draw_calls_max"],
                run["static_memory_peak_mb"], run["wasm_memory_mb"], run["load_ms"], run["window"],
                run["renderer"]))


def seconds(value: float | None) -> str:
    return "no first screen" if value is None else "%.2f s" % value


def set_power_saving(exe: str) -> None:
    with winreg.CreateKeyEx(winreg.HKEY_CURRENT_USER, GPU_KEY, 0, winreg.KEY_SET_VALUE) as key:
        winreg.SetValueEx(key, exe, 0, winreg.REG_SZ, GPU_POWER_SAVING)


def clear_power_saving(exe: str) -> None:
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, GPU_KEY, 0, winreg.KEY_SET_VALUE) as key:
            winreg.DeleteValue(key, exe)
    except FileNotFoundError:
        pass


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--build", type=Path, default=ROOT / "build" / "perf-web")
    parser.add_argument("--release", type=Path, default=ROOT / "build" / "web")
    parser.add_argument("--modes", default=",".join(MODES))
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--out", type=Path, default=Path(tempfile.gettempdir()) / "doomsday_web_perf")
    parser.add_argument("--vsync", action="store_true")
    # Only to see what the throttling adds; §13.1 is judged at 2.5.
    parser.add_argument("--cpu-throttle", type=float, default=CPU_THROTTLE)
    args = parser.parse_args()
    modes = [m for m in args.modes.split(",") if m]
    for mode in modes:
        if mode not in MODES:
            print(f"web_perf: unknown mode {mode}")
            return 1
    needs = {"web_igpu": args.build, "web_cpu": args.build, "load": args.release}
    for mode in modes:
        if not (needs[mode] / "index.html").is_file():
            print(f"web_perf: no index.html in {needs[mode]} — export it first")
            return 1
    args.out.mkdir(parents=True, exist_ok=True)
    report: dict = {"vsync": args.vsync, "modes": {}}
    ok = True
    with sync_playwright() as playwright:
        exe = playwright.chromium.executable_path
        for mode in modes:
            directory = needs[mode].resolve()
            server = serve.start(directory, args.port)
            url = f"http://{serve.HOST}:{args.port}/index.html"
            runs: list[dict] = []
            try:
                if mode == "web_igpu":
                    set_power_saving(exe)
                for i in range(1, args.runs + 1):
                    run = load_run(playwright, url) if mode == "load" else \
                        bench_run(playwright, mode, url, args.vsync, args.out / f"{mode}_{i}.log",
                                  args.cpu_throttle)
                    runs.append(run)
                    if mode == "load":
                        print(f"{mode} {i}: cold {seconds(run['cold_s'])} ({run['cold_mb']:.1f} MB), "
                              f"warm {seconds(run['warm_s'])} ({run['warm_mb']:.1f} MB)", flush=True)
                    else:
                        ok = ok and "error" not in run
                        print(f"{mode} {i}: {describe(run)}", flush=True)
            finally:
                if mode == "web_igpu":
                    clear_power_saving(exe)
                server.shutdown()
                server.server_close()
            entry: dict = {"runs": runs}
            if mode == "load":
                colds = [r["cold_s"] for r in runs if r.get("cold_s") is not None]
                warms = [r["warm_s"] for r in runs if r.get("warm_s") is not None]
                ok = ok and len(colds) == len(runs) and len(warms) == len(runs)
                entry["cold_median_s"] = statistics.median(colds) if colds else None
                entry["warm_median_s"] = statistics.median(warms) if warms else None
                print(f"{mode}: cold median {entry['cold_median_s']} s, warm median {entry['warm_median_s']} s")
            else:
                entry["median"] = median_run(runs)
                print(f"{mode} median: {describe(entry['median']) if entry['median'] else 'none'}")
            report["modes"][mode] = entry
    (args.out / "web_perf.json").write_text(json.dumps(report, indent=1), encoding="utf-8")
    print(f"web_perf: {args.out / 'web_perf.json'}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
