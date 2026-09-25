"""Vendors the icon-set files data/icons.json names (docs/specs/icons.md §10.1).

    python tools/icons/vendor_icons.py [--check]

Downloads the two pinned archives into tools/icons/.cache/ (unless present),
refuses to go on when a hash differs, extracts exactly the files the map names
(stand-ins included), normalises them (§4: white, no background, no size) and
writes them under assets/icons/phosphor/ and assets/icons/game-icons/<author>/,
with the two licence files and an importer stub (§5.1) for every new file.
Vendored files the map no longer names are deleted.

--check downloads nothing: it exits non-zero when a mapped set file is missing
or not normalised. CI checks the same through tests/unit/test_icon_sources.gd.

Standard library only (Python 3.11 or newer).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import tarfile
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAP_PATH = ROOT / "data" / "icons.json"
ICONS = ROOT / "assets" / "icons"
CACHE = Path(__file__).resolve().parent / ".cache"

PHOSPHOR = "phosphor/"
GAME_ICONS = "game-icons/"

# §2: the pins. A human checks what changed upstream before either moves.
PHOSPHOR_URL = "https://registry.npmjs.org/@phosphor-icons/core/-/core-2.1.1.tgz"
PHOSPHOR_SHA256 = "313332be6190b724da24107addd781799b48bf76b13963f24501112ffe1baadd"
PHOSPHOR_ARCHIVE = CACHE / "core-2.1.1.tgz"
PHOSPHOR_LICENCE = ("package/LICENSE", ICONS / "phosphor" / "LICENSE.txt")

GAME_ICONS_COMMIT = "82d948812bfe3f269ef8f731dcdb07b08160edc4"
GAME_ICONS_URL = f"https://github.com/game-icons/icons/archive/{GAME_ICONS_COMMIT}.zip"
GAME_ICONS_SHA256 = "2b6f10a39898bd4dcb6b5590453821f7d88c5fff4f149de237b7ee183d579f01"
GAME_ICONS_ARCHIVE = CACHE / "game-icons-82d9488.zip"
GAME_ICONS_PREFIX = f"icons-{GAME_ICONS_COMMIT}/"
GAME_ICONS_LICENCE = (GAME_ICONS_PREFIX + "license.txt", ICONS / "game-icons" / "license.txt")

IMPORT_STUB = '[remap]\n\nimporter="svg"\n'
WHITE = "#FFFFFF"
VIEW_BOX = {PHOSPHOR: "0 0 256 256", GAME_ICONS: "0 0 512 512"}
# The black square every game-icons file starts with (§4).
BACKGROUND = '<path d="M0 0h512v512H0z"/>'
# §4: nothing that renders differently, or not at all, in Godot's SVG importer.
FORBIDDEN = re.compile(r"<(text|filter|mask|image|use|linearGradient|radialGradient)\b|stroke")


class VendorError(Exception):
    pass


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="verify, download nothing")
    args = parser.parse_args()
    wanted = mapped_set_paths()
    try:
        if args.check:
            return check(wanted)
        return vendor(wanted)
    except VendorError as error:
        print(f"vendor_icons: {error}", file=sys.stderr)
        return 1


def mapped_set_paths() -> list[str]:
    """Every phosphor/ and game-icons/ path the map names, stand-ins included."""
    data = json.loads(MAP_PATH.read_text(encoding="utf-8"))
    paths: set[str] = set()
    for key, section in data.items():
        if key.startswith("_") or not isinstance(section, dict):
            continue
        values = list(section.values())
        if key == "stand_ins":
            values += list(section.keys())
        for value in values:
            if isinstance(value, str) and value.startswith((PHOSPHOR, GAME_ICONS)):
                paths.add(value)
    return sorted(paths)


def vendor(wanted: list[str]) -> int:
    fetch(PHOSPHOR_URL, PHOSPHOR_ARCHIVE, PHOSPHOR_SHA256)
    fetch(GAME_ICONS_URL, GAME_ICONS_ARCHIVE, GAME_ICONS_SHA256)
    written = 0
    with tarfile.open(PHOSPHOR_ARCHIVE, "r:gz") as tar, zipfile.ZipFile(GAME_ICONS_ARCHIVE) as zf:
        for path in wanted:
            if path.startswith(PHOSPHOR):
                source = read_phosphor(tar, path)
            else:
                source = read_game_icon(zf, path)
            text = normalise(path, source)
            if write_if_changed(ICONS / path, text):
                written += 1
            stub(ICONS / path)
        copy_bytes(tar_member(tar, PHOSPHOR_LICENCE[0]), PHOSPHOR_LICENCE[1])
        copy_bytes(zf.read(GAME_ICONS_LICENCE[0]), GAME_ICONS_LICENCE[1])
    removed = remove_unmapped(wanted)
    authors = sorted({p.split("/")[1] for p in wanted if p.startswith(GAME_ICONS)})
    print(f"files written: {written} (of {len(wanted)} mapped set files)")
    print(f"files removed: {removed}")
    print(f"authors used: {', '.join(authors)}")
    return 0


def check(wanted: list[str]) -> int:
    problems: list[str] = []
    for path in wanted:
        file = ICONS / path
        if not file.exists():
            problems.append(f"{path}: missing")
            continue
        problems += [f"{path}: {p}" for p in normalisation_problems(path, file.read_text("utf-8"))]
        if not Path(str(file) + ".import").exists():
            problems.append(f"{path}: no .import")
    for _, licence in (PHOSPHOR_LICENCE, GAME_ICONS_LICENCE):
        if not licence.exists():
            problems.append(f"{licence.relative_to(ROOT).as_posix()}: missing")
    for problem in problems:
        print(problem, file=sys.stderr)
    print(f"{len(wanted)} mapped set files, {len(problems)} problems")
    return 1 if problems else 0


def fetch(url: str, target: Path, expected: str) -> None:
    if not target.exists():
        CACHE.mkdir(parents=True, exist_ok=True)
        print(f"downloading {url}")
        with urllib.request.urlopen(url) as response:
            target.write_bytes(response.read())
    actual = hashlib.sha256(target.read_bytes()).hexdigest()
    if actual != expected:
        raise VendorError(
            f"{target.name}: SHA-256 {actual}, expected {expected} — check upstream before "
            "moving the pin (docs/specs/icons.md §2)")


def tar_member(tar: tarfile.TarFile, name: str) -> bytes:
    member = tar.extractfile(name)
    if member is None:
        raise VendorError(f"{name}: not in the Phosphor archive")
    return member.read()


def read_phosphor(tar: tarfile.TarFile, path: str) -> str:
    name = path[len(PHOSPHOR):]
    weight = name.rsplit("-", 1)[-1].removesuffix(".svg")
    if weight not in ("bold", "fill"):
        raise VendorError(f"{path}: only the bold and fill weights are used (§2)")
    try:
        return tar_member(tar, f"package/assets/{weight}/{name}").decode("utf-8")
    except KeyError as error:
        raise VendorError(f"{path}: not in the Phosphor archive") from error


def read_game_icon(zf: zipfile.ZipFile, path: str) -> str:
    try:
        return zf.read(GAME_ICONS_PREFIX + path[len(GAME_ICONS):]).decode("utf-8")
    except KeyError as error:
        raise VendorError(f"{path}: not in the game-icons archive") from error


def normalise(path: str, source: str) -> str:
    """§4: white on nothing, the set's viewBox, no size."""
    text = source.strip()
    if path.startswith(PHOSPHOR):
        if text.count('fill="currentColor"') != 1:
            raise VendorError(f"{path}: expected one root fill=\"currentColor\"")
        text = text.replace('fill="currentColor"', f'fill="{WHITE}"')
    else:
        start = text.find(">") + 1
        if not text[start:].startswith(BACKGROUND):
            raise VendorError(f"{path}: the first element is not the background square")
        text = text[:start] + text[start + len(BACKGROUND):]
        text = text.replace('fill="#fff"', f'fill="{WHITE}"')
    root = re.match(r"<svg\b[^>]*>", text)
    if root is not None:
        bare = re.sub(r'\s(width|height)="[^"]*"', "", root.group(0))
        text = bare + text[root.end():]
    problems = normalisation_problems(path, text)
    if problems:
        raise VendorError(f"{path}: {'; '.join(problems)}")
    return text + "\n"


def normalisation_problems(path: str, text: str) -> list[str]:
    problems: list[str] = []
    folder = PHOSPHOR if path.startswith(PHOSPHOR) else GAME_ICONS
    root = re.match(r"\s*<svg\b[^>]*>", text)
    if root is None:
        return ["no <svg> root"]
    if f'viewBox="{VIEW_BOX[folder]}"' not in root.group(0):
        problems.append(f"viewBox is not {VIEW_BOX[folder]}")
    if re.search(r"\s(width|height)=", root.group(0)):
        problems.append("the root has a size")
    if BACKGROUND in text:
        problems.append("background square")
    if "currentColor" in text:
        problems.append("currentColor")
    for colour in re.findall(r'fill="([^"]*)"', text):
        if colour != WHITE:
            problems.append(f"fill {colour}")
    if FORBIDDEN.search(text):
        problems.append("text, filter, mask, image, use, gradient or stroke")
    if 'fill="' not in text:
        problems.append("no white fill")
    return problems


def write_if_changed(file: Path, text: str) -> bool:
    if file.exists() and file.read_text("utf-8") == text:
        return False
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text(text, encoding="utf-8", newline="\n")
    return True


def copy_bytes(data: bytes, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists() or target.read_bytes() != data:
        target.write_bytes(data)


def stub(file: Path) -> None:
    import_file = Path(str(file) + ".import")
    if not import_file.exists():
        import_file.write_text(IMPORT_STUB, encoding="utf-8", newline="\n")


def remove_unmapped(wanted: list[str]) -> int:
    keep = {(ICONS / p).resolve() for p in wanted}
    removed = 0
    for folder in (ICONS / "phosphor", ICONS / "game-icons"):
        if not folder.exists():
            continue
        for svg in sorted(folder.rglob("*.svg")):
            if svg.resolve() in keep:
                continue
            svg.unlink()
            Path(str(svg) + ".import").unlink(missing_ok=True)
            removed += 1
        for sub in sorted(folder.iterdir(), reverse=True):
            if sub.is_dir() and not any(sub.iterdir()):
                sub.rmdir()
    return removed


if __name__ == "__main__":
    sys.exit(main())
