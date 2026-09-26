"""The Web build in real browsers (docs/specs/web.md §17.2).

    uv run --project tools/web python tools/web/web_check.py [--build build/web]
        [--debug-build <dir>] [--browsers chrome,msedge,firefox] [--checks a,b,…]
        [--out <dir>] [--smoke] [--expect <sim_run JSON or result.json>]

Serves the export on 127.0.0.1:8765 and `iframe_host.html` on localhost:8766
(another origin, as itch.io embeds a game), launches each browser headless with
a fresh temporary profile — Chrome and Edge are the machine's own, Firefox is
Playwright's — and drives the game with the mouse and keys through the iframe.
Screenshots go to `--out`. Prints one line per check and exits 1 when one fails.

`--smoke` runs only §17.2 item 13 (the CI web smoke job, §16.3): `index.html?smoke`
plays the reference run and its outcome, day and hash must equal `--expect`'s
(or, without it, `tools/sim_run.gd`'s seed-1 greedy run through $GODOT).

The coordinates below are the 1280 × 720 embed's (web.md §8.1: a 1920 × 1080
layout at ⅔); they are what the check clicks, measured on screenshots of build
0.6.0. A layout change that moves a button moves its number here.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import zipfile
from dataclasses import dataclass, field
from pathlib import Path

from playwright.sync_api import Browser, BrowserContext, Frame, Page, Playwright, sync_playwright

sys.path.insert(0, str(Path(__file__).resolve().parent))
import serve  # noqa: E402 - the sibling module

ROOT = Path(__file__).resolve().parents[2]
GAME_PORT = 8765
HOST_PORT = 8766
GAME_URL = f"http://127.0.0.1:{GAME_PORT}/index.html"
HOST_URL = f"http://localhost:{HOST_PORT}/iframe_host.html"
EMBED = (1280, 720)
# The host page's window: the embed plus some of the text around it, so the
# page can scroll.
HOST_VIEWPORT = {"width": 1400, "height": 900}
LOAD_TIMEOUT_MS = 180_000
# §17.2 item 5: a minute at 4×; every few seconds a card that holds the clock is
# answered with its focused (free) option and the speed set again.
RUN_SECONDS = 60
RUN_POLL_MS = 4000
SMOKE_TIMEOUT_MS = 600_000
FIRST_SCREEN = "first screen"
SMOKE_PREFIX = "smoke: "
BOARD_HOST = "raw.githubusercontent.com"
BOARD_CONFIG = ROOT / "data" / "benchmark.json"
CANARY = ROOT / "tests" / "fixtures" / "bench" / "determinism_entry.json"
# web.md §4.2: the hard limits and the target.
ZIP_TARGET_MB = 25.0
ZIP_HARD_MB = 30.0
EXTRACTED_TARGET_MB = 70.0
EXTRACTED_HARD_MB = 80.0
FILE_HARD_MB = 64.0
FILES_HARD = 50
MB = 1_000_000
# Where the game's files are in the page's IndexedDB. The engine's `user://` on
# the web is `/userfs/<custom_user_dir_name>` (measured in 4.7.2), and web.md
# §7.1 puts the game's files one folder further down; the engine keeps its own
# shader cache beside that folder.
USER_DIR = "/userfs/Doomsday"
GAME_DIR = USER_DIR + "/doomsday"
ENGINE_DIRS = (USER_DIR + "/shader_cache",)
AUTOSAVE = GAME_DIR + "/saves/autosave.json"
SETTINGS = GAME_DIR + "/settings.json"
PROFILE = GAME_DIR + "/profile.json"

# Where to click, in embed pixels (see the module's note).
BOOT_SKIP = (640, 360)
TITLE_NEW_RUN = (174, 323)
# With a run to continue the column is one row taller and *Continue* leads it.
TITLE_CONTINUE = (174, 297)
TITLE_STATISTICS = (174, 398)
TITLE_BENCHMARK = (174, 436)
TITLE_SETTINGS = (174, 473)
SETUP_BEGIN = (1238, 692)
INTRO_END = (634, 546)
ORIGIN_REGION = (180, 200)
ORIGIN_START = (160, 172)
TREE_NODE = (88, 170)
TREE_ACQUIRE = (1098, 492)
TREE_CLOSE = (1242, 40)
SETTINGS_LANGUAGE = (767, 72)
SETTINGS_TEXT_SIZE = (776, 221)
# With the settings scrolled to their end.
SETTINGS_SAVE_PROGRESS = (549, 506)
SETTINGS_LOAD_PROGRESS = (555, 543)
SETTINGS_ONLINE = (781, 642)
# The list's first row's *Runs* button, with the one-row fixture board, and the
# *Watch* of its one run.
BENCH_FIRST_ROW = (793, 177)
BENCH_WATCH = (791, 225)
# The speed buttons, top right: pause, 1×, 2×, 4×; a sample point inside each
# button's fill, clear of its icon.
SPEED_SAMPLES = [(1140, 20), (1175, 20), (1210, 20), (1244, 20)]
# Inside the pause menu's *Resume* button, the accent-filled primary.
MENU_RESUME = (600, 91)
LIT = 400
# The confirm over the settings, opened by *Load progress from a file*.
CONFIRM_YES = (779, 391)

# Console errors that are the browser's, not the game's.
IGNORED_ERRORS = ("favicon",)

# Records, in the game's frame, what reached the window after the engine's own
# listeners: whether each key, wheel and context menu was taken from the page.
JS_RECORD_DEFAULTS = """
() => {
	window.__prevented = [];
	for (const type of ['keydown', 'wheel', 'contextmenu']) {
		window.addEventListener(type, (e) => {
			window.__prevented.push([type, e.key || '', e.defaultPrevented]);
		});
	}
	return true;
}
"""
# The shell's status lines as they changed (web.md §5.2), for the progress check.
JS_WATCH_SHELL = """
document.addEventListener('DOMContentLoaded', () => {
	const line = document.getElementById('line');
	if (!line) { return; }
	window.__shellLines = [];
	new MutationObserver(() => window.__shellLines.push(line.textContent))
		.observe(line, {childList: true, characterData: true, subtree: true});
});
"""
# Every key of the engine's IndexedDB (`/userfs`, store FILE_DATA).
JS_IDB_KEYS = """
() => new Promise((resolve, reject) => {
	const open = indexedDB.open('/userfs');
	open.onerror = () => reject(String(open.error));
	open.onsuccess = () => {
		const db = open.result;
		if (!db.objectStoreNames.contains('FILE_DATA')) { resolve([]); return; }
		const query = db.transaction('FILE_DATA', 'readonly').objectStore('FILE_DATA').getAllKeys();
		query.onsuccess = () => resolve(query.result.map(String));
		query.onerror = () => reject(String(query.error));
	};
})
"""
JS_IDB_TEXT = """
(path) => new Promise((resolve, reject) => {
	const open = indexedDB.open('/userfs');
	open.onerror = () => reject(String(open.error));
	open.onsuccess = () => {
		const query = open.result.transaction('FILE_DATA', 'readonly').objectStore('FILE_DATA').get(path);
		query.onsuccess = () => {
			const entry = query.result;
			resolve(entry && entry.contents ? new TextDecoder().decode(entry.contents) : null);
		};
		query.onerror = () => reject(String(query.error));
	};
})
"""
# When the engine last wrote a file (IDBFS keeps each entry's modification time).
JS_IDB_STAMP = """
(path) => new Promise((resolve, reject) => {
	const open = indexedDB.open('/userfs');
	open.onerror = () => reject(String(open.error));
	open.onsuccess = () => {
		const query = open.result.transaction('FILE_DATA', 'readonly').objectStore('FILE_DATA').get(path);
		query.onsuccess = () => resolve(query.result ? Number(query.result.timestamp) : -1);
		query.onerror = () => reject(String(query.error));
	};
})
"""
# web.md §6.3 without a second tab: the page says it is hidden, then visible.
JS_VISIBILITY = """
(state) => {
	Object.defineProperty(document, 'visibilityState', {configurable: true, get: () => state});
	Object.defineProperty(document, 'hidden', {configurable: true, get: () => state === 'hidden'});
	document.dispatchEvent(new Event('visibilitychange'));
	return document.visibilityState;
}
"""
# A pixel of a screenshot, through a canvas in the host page (no image library).
JS_PIXEL = """
([data, points]) => new Promise((resolve) => {
	const image = new Image();
	image.onload = () => {
		const canvas = document.createElement('canvas');
		canvas.width = image.width;
		canvas.height = image.height;
		const context = canvas.getContext('2d');
		context.drawImage(image, 0, 0);
		resolve(points.map(([x, y]) => Array.from(context.getImageData(x, y, 1, 1).data.slice(0, 3))));
	};
	image.src = 'data:image/png;base64,' + data;
})
"""


@dataclass
class Result:
    browser: str
    check: str
    ok: bool
    detail: str = ""


@dataclass
class Session:
    """One browser context with the game in the host page's iframe."""

    name: str
    context: BrowserContext
    page: Page
    out: Path
    console: list[tuple[str, str]] = field(default_factory=list)
    requests: list[str] = field(default_factory=list)

    def frame(self) -> Frame:
        for frame in self.page.frames:
            if f":{GAME_PORT}/" in frame.url:
                return frame
        raise RuntimeError("the game's frame is not there")

    def origin(self) -> tuple[float, float]:
        box = self.page.locator("#game").bounding_box()
        if box is None:
            raise RuntimeError("the iframe has no box")
        return box["x"], box["y"]

    def click(self, point: tuple[int, int], button: str = "left") -> None:
        # Moved first and held a moment: the engine reads input once a frame, and
        # a press without a hover before it was sometimes lost.
        x, y = self.origin()
        self.page.mouse.move(x + point[0], y + point[1])
        self.page.wait_for_timeout(150)
        self.page.mouse.down(button=button)
        self.page.wait_for_timeout(80)
        self.page.mouse.up(button=button)

    def key(self, key: str, wait_ms: int = 400) -> None:
        self.page.keyboard.press(key)
        self.page.wait_for_timeout(wait_ms)

    def wait(self, ms: int) -> None:
        self.page.wait_for_timeout(ms)

    def shot(self, label: str) -> bytes:
        path = self.out / f"{self.name}_{label}.png"
        return self.page.screenshot(path=str(path))

    def lines(self, prefix: str) -> list[str]:
        return [text for _, text in self.console if text.startswith(prefix)]

    def errors(self) -> list[str]:
        return [text for kind, text in self.console
                if kind == "error" and not any(word in text for word in IGNORED_ERRORS)]

    def wait_for_line(self, prefix: str, count: int = 1, timeout_ms: int = LOAD_TIMEOUT_MS) -> bool:
        deadline = time.monotonic() + timeout_ms / 1000
        while time.monotonic() < deadline:
            if len(self.lines(prefix)) >= count:
                return True
            # The sync API delivers events only inside its own calls.
            self.page.wait_for_timeout(250)
        return False

    def pixels(self, png: bytes, points: list[tuple[int, int]]) -> list[list[int]]:
        x, y = self.origin()
        shifted = [[int(x + px), int(y + py)] for px, py in points]
        return self.page.evaluate(JS_PIXEL, [base64.b64encode(png).decode(), shifted])

    def speed_index(self) -> int:
        """Which speed button is lit: 0 paused, 1–3 the speeds."""
        colours = self.pixels(self.shot("speed"), SPEED_SAMPLES)
        brightness = [sum(colour) for colour in colours]
        return brightness.index(max(brightness))


# ----------------------------------------------------------------- browsers


def launch(playwright: Playwright, browser: str) -> Browser:
    if browser == "firefox":
        return playwright.firefox.launch(headless=True)
    return playwright.chromium.launch(channel=browser, headless=True)


def new_session(browser: Browser, name: str, out: Path, locale: str = "en-US",
                host: bool = True) -> Session:
    context = browser.new_context(viewport=HOST_VIEWPORT if host else
                                  {"width": EMBED[0], "height": EMBED[1]},
                                  locale=locale, accept_downloads=True)
    context.add_init_script(JS_WATCH_SHELL)
    page = context.new_page()
    session = Session(name, context, page, out)
    page.on("console", lambda message: session.console.append((message.type, message.text)))
    page.on("request", lambda request: session.requests.append(request.url))
    return session


def open_host(session: Session) -> bool:
    session.page.goto(HOST_URL)
    # The iframe in view, the page scrolled part of the way, so Space can
    # scroll it further.
    session.page.evaluate("window.scrollTo(0, 400)")
    return session.wait_for_line(FIRST_SCREEN)


def to_title(session: Session) -> None:
    """The first click skips the boot (and focuses the game, §9.1)."""
    session.click(BOOT_SKIP)
    session.wait(4000)


# ------------------------------------------------------------------- checks


def check_load(session: Session) -> Result:
    """§17.2 item 1."""
    if not open_host(session):
        return Result(session.name, "load", False, "no 'first screen' line")
    frame = session.frame()
    shell_lines = frame.evaluate("window.__shellLines || []")
    to_title(session)
    session.shot("title")
    finished = any("100" in line or "…" in line for line in shell_lines)
    errors = session.errors()
    ok = finished and not errors
    return Result(session.name, "load", ok,
                  f"shell lines {len(shell_lines)} (last {shell_lines[-1:]!r}); errors {errors[:3]}")


def check_phone(browser: Browser, out: Path) -> Result:
    """§17.2 item 2: a touch device with no fine pointer sees the notice first."""
    context = browser.new_context(viewport={"width": 800, "height": 600}, has_touch=True,
                                  is_mobile=True, locale="en-US")
    page = context.new_page()
    requested: list[str] = []
    page.on("request", lambda request: requested.append(request.url))
    page.goto(GAME_URL)
    page.wait_for_timeout(2000)
    shown = page.locator("#phone").is_visible()
    body = page.locator("#phone-body").inner_text() if shown else ""
    downloaded_before = [url for url in requested if url.endswith((".wasm", ".pck"))]
    page.screenshot(path=str(out / "phone_gate.png"))
    if shown:
        page.locator("#phone-start").click()
    page.wait_for_timeout(8000)
    downloaded_after = [url for url in requested if url.endswith((".wasm", ".pck"))]
    context.close()
    ok = shown and not downloaded_before and len(downloaded_after) == 2
    return Result("chrome", "phone", ok, f"notice {shown} ({body[:60]}…); before "
                  f"{len(downloaded_before)} downloads, after {len(downloaded_after)}")


def check_focus(session: Session) -> Result:
    """§17.2 item 3, before and after the first click. Run on a freshly loaded page."""
    page = session.page
    page.evaluate("window.scrollTo(0, 400); document.activeElement && document.activeElement.blur()")
    page.mouse.click(10, 10)  # the host page's own text, not the game
    before = page.evaluate("window.scrollY")
    session.key("Space", 600)
    scrolled = page.evaluate("window.scrollY") > before
    page.evaluate("window.scrollTo(0, 400)")
    to_title(session)
    # On the title Space would press the focused button; the arrows walk the
    # buttons instead — either way the page must not scroll. Space itself is
    # checked in the run, where it pauses (`play_a_run`).
    before = page.evaluate("window.scrollY")
    session.key("ArrowDown", 400)
    session.key("ArrowUp", 400)
    still = page.evaluate("window.scrollY") == before
    focused = page.evaluate("document.activeElement && document.activeElement.id") == "game"
    return Result(session.name, "focus", scrolled and still and focused,
                  f"space before the click scrolls the host: {scrolled}; after: the arrows "
                  f"leave the host still {still}, the iframe focused {focused}")


def check_keys(session: Session) -> Result:
    """§17.2 item 4 on the title: what the engine takes from the page."""
    frame = session.frame()
    frame.evaluate(JS_RECORD_DEFAULTS)
    page = session.page
    loads = len(session.lines(FIRST_SCREEN))
    before = page.evaluate("window.scrollY")
    session.key("F1", 1500)
    session.shot("help_f1")
    session.key("Escape", 800)
    session.key("Tab", 400)
    session.key("Tab", 400)
    session.shot("tab")
    x, y = session.origin()
    page.mouse.move(x + 900, y + 360)
    page.mouse.wheel(0, 300)
    session.wait(500)
    session.click((900, 360), button="right")
    session.wait(300)
    session.key("F5", 1500)
    records = frame.evaluate("window.__prevented")
    reloaded = len(session.lines(FIRST_SCREEN)) > loads
    host_still = page.evaluate("window.scrollY") == before
    taken = {(kind, key): prevented for kind, key, prevented in records}
    wanted = [("keydown", "F1"), ("keydown", "Tab"), ("keydown", "F5"), ("wheel", ""),
              ("contextmenu", "")]
    missing = [pair for pair in wanted if not taken.get(pair, False)]
    ok = not missing and not reloaded and host_still
    return Result(session.name, "keys", ok, f"not prevented: {missing}; F5 reloaded {reloaded}; "
                  f"host scrolled by the wheel {not host_still}")


def play_a_run(session: Session) -> Result:
    """§17.2 item 5 from the title: setup, origin, a purchase, 60 s at 4×."""
    session.click(TITLE_NEW_RUN)
    session.wait(3000)
    session.shot("setup")
    session.click(SETUP_BEGIN)
    session.wait(4000)
    session.click(INTRO_END)
    session.wait(1500)
    session.click(ORIGIN_REGION)
    session.wait(2000)
    session.click(ORIGIN_START)
    session.wait(1500)
    session.key("t", 2500)
    session.click(TREE_NODE)
    session.wait(1000)
    session.shot("tree")
    session.click(TREE_ACQUIRE)
    session.wait(1500)
    session.shot("acquired")
    session.key("Escape", 1000)
    session.key("3", 500)
    fast = session.speed_index()
    # §17.2 item 3's second half: Space is the game's pause, not the page's scroll.
    before = session.page.evaluate("window.scrollY")
    session.key("Space", 800)
    paused = session.speed_index()
    host_still = session.page.evaluate("window.scrollY") == before
    session.shot("run_paused")
    session.key("Space", 800)
    resumed = session.speed_index()
    answered = 0
    deadline = time.monotonic() + RUN_SECONDS
    while time.monotonic() < deadline:
        session.wait(RUN_POLL_MS)
        if session.speed_index() != 3:
            session.key("Enter", 600)
            session.key("3", 300)
            answered += 1
    session.shot("run_4x")
    save = session.frame().evaluate(JS_IDB_TEXT, AUTOSAVE)
    day = json.loads(save)["world"]["day"] if save else -1
    errors = session.errors()
    ok = fast == 3 and paused == 0 and resumed == 3 and host_still and not errors and day > 0
    return Result(session.name, "run", ok, f"speed lit {fast} at 4×, {paused} after Space, "
                  f"{resumed} after another; host still {host_still}; {answered} holds answered, "
                  f"autosave at day {day}; errors {errors[:3]}")


def check_hidden(session: Session) -> Result:
    """§17.2 item 10 on the live run: hidden → the menu and an autosave. The run is
    held first (Space) with no card open, so only the page's hiding can write."""
    frame = session.frame()
    if session.speed_index() != 3:
        session.key("Enter", 600)
        session.key("3", 300)
    session.key("Space", 800)
    session.wait(1500)
    before = frame.evaluate(JS_IDB_STAMP, AUTOSAVE)
    # A real second tab first; headless browsers may keep both visible.
    other = session.context.new_page()
    other.bring_to_front()
    session.page.wait_for_timeout(1500)
    real = frame.evaluate("document.visibilityState")
    session.page.bring_to_front()
    other.close()
    if real != "hidden":
        frame.evaluate(JS_VISIBILITY, "hidden")
        session.wait(1500)
        frame.evaluate(JS_VISIBILITY, "visible")
    session.wait(1500)
    after = frame.evaluate(JS_IDB_STAMP, AUTOSAVE)
    png = session.shot("hidden_menu")
    menu = sum(session.pixels(png, [MENU_RESUME])[0]) > LIT
    ok = after > before > 0 and menu
    return Result(session.name, "hidden", ok, f"second tab hid the page: {real == 'hidden'}; "
                  f"autosave rewritten {after > before}; the pause menu open {menu}")


def check_persist(session: Session) -> Result:
    """§17.2 item 6, the run's half: reload → Continue on the same day; the files
    in the game's folder."""
    frame = session.frame()
    keys_before = frame.evaluate(JS_IDB_KEYS)
    save = frame.evaluate(JS_IDB_TEXT, AUTOSAVE)
    day = json.loads(save)["world"]["day"] if save else -1
    session.page.reload()
    session.page.evaluate("window.scrollTo(0, 400)")
    loaded = session.wait_for_line(FIRST_SCREEN, count=2)
    frame = session.frame()
    to_title(session)
    session.shot("reload_title")
    keys = frame.evaluate(JS_IDB_KEYS)
    session.click(TITLE_CONTINUE)
    session.wait(5000)
    session.shot("continued")
    stray = [key for key in keys if key not in (USER_DIR, GAME_DIR)
             and not key.startswith(GAME_DIR + "/")
             and not key.startswith(ENGINE_DIRS)]
    ok = loaded and day > 0 and not stray and PROFILE in keys
    return Result(session.name, "persist", ok, f"autosave day {day} (the Continue shot shows "
                  f"it); files {len(keys)} (before {len(keys_before)}), outside {GAME_DIR}: {stray}")


def check_settings(browser: Browser, out: Path, name: str) -> Result:
    """§17.2 item 6, the settings' half: language and text size survive a reload,
    and the page's own loading screen follows the language (§5.1)."""
    session = new_session(browser, f"{name}_settings", out)
    if not open_host(session):
        return Result(name, "settings", False, "no 'first screen' line")
    to_title(session)
    session.click(TITLE_SETTINGS)
    session.wait(1500)
    session.click(SETTINGS_LANGUAGE)
    session.wait(800)
    session.click(SETTINGS_TEXT_SIZE)
    session.wait(1500)
    session.shot("settings_changed")
    before = json.loads(session.frame().evaluate(JS_IDB_TEXT, SETTINGS) or "{}")
    session.page.reload()
    session.page.evaluate("window.scrollTo(0, 400)")
    loaded = session.wait_for_line(FIRST_SCREEN, count=2)
    frame = session.frame()
    shell_lines = frame.evaluate("window.__shellLines || []")
    stored_locale = frame.evaluate("window.localStorage.getItem('doomsday_locale')")
    to_title(session)
    session.shot("settings_reloaded")
    after = json.loads(frame.evaluate(JS_IDB_TEXT, SETTINGS) or "{}")
    session.context.close()
    changed = before.get("locale") == "de" and float(before.get("text_scale", 1.0)) > 1.0
    kept = all(after.get(key) == before.get(key) for key in ("locale", "text_scale"))
    german_shell = any(line.startswith("Wird") for line in shell_lines)
    ok = loaded and changed and kept and stored_locale == "de" and german_shell
    return Result(name, "settings", ok, f"locale {after.get('locale')}, text "
                  f"{after.get('text_scale')} kept {kept}; the shell loaded in German "
                  f"{german_shell} (stored {stored_locale!r})")


def scroll_to_end(session: Session) -> None:
    """The title's settings scrolled to their last rows (the progress rows)."""
    x, y = session.origin()
    session.page.mouse.move(x + 640, y + 500)
    session.page.mouse.wheel(0, 2000)
    session.wait(1000)


def board_fixture() -> tuple[bytes, bytes, dict]:
    """A one-row board around the canary run (it plays on this content), and the run."""
    run = CANARY.read_bytes()
    entry = json.loads(run)
    seed = int(entry.get("seed", 1001))
    row = {
        "model": entry.get("model", "mock"), "backend": entry.get("backend", "mock:cheapest"),
        "params": entry.get("params", {}), "params_id": entry.get("params_id", ""),
        "prompt_version": entry.get("prompt_version", 1), "locale": entry.get("locale", "en"),
        "suite": entry.get("suite", "standard"), "content_hash": entry["content_hash"],
        "current": True, "complete": False, "runs": 1, "of": 10, "score": 1.0, "wins": 0,
        "win_rate": 0.0,
        "seeds": [{"seed": seed, "file": "runs/web_check.json",
                   "sha256": hashlib.sha256(run).hexdigest(),
                   "outcome": str(entry.get("outcome", "timeout")),
                   "days": int(entry.get("days", 0)), "score": float(entry.get("score", 0.0))}],
    }
    board = {"version": 1, "generated": "2026-09-26T12:00:00", "content_hash": entry["content_hash"],
             "rows": [row]}
    return json.dumps(board).encode(), run, board


def check_online(browser: Browser, out: Path, name: str) -> Result:
    """§17.2 item 7: the list fetches from the network, a run downloads and plays;
    with the setting off nothing is requested. The board's address answers with a
    one-row fixture (the real board has no rows yet)."""
    board_bytes, run_bytes, _ = board_fixture()
    config = json.loads(BOARD_CONFIG.read_text(encoding="utf-8"))["global"]
    session = new_session(browser, f"{name}_online", out)
    served: list[str] = []

    def answer(route) -> None:  # type: ignore[no-untyped-def]
        url = route.request.url
        served.append(url)
        body = board_bytes if url == config["leaderboard_url"] else run_bytes
        route.fulfill(status=200, body=body, headers={"Access-Control-Allow-Origin": "*",
                                                      "Content-Type": "text/plain"})

    session.context.route(f"https://{BOARD_HOST}/**", answer)
    if not open_host(session):
        return Result(name, "online", False, "no 'first screen' line")
    to_title(session)
    session.click(TITLE_BENCHMARK)
    session.wait(5000)
    session.shot("bench_list")
    fetched = any(config["leaderboard_url"] == url for url in served)
    session.click(BENCH_FIRST_ROW)
    session.wait(2500)
    session.shot("bench_row")
    session.click(BENCH_WATCH)
    session.wait(8000)
    session.shot("bench_watch")
    downloaded = any(url.endswith("runs/web_check.json") for url in served)
    playing = session.speed_index() != 0
    session.context.close()
    # The setting off: a fresh profile, the switch, the list — and no request.
    quiet = new_session(browser, f"{name}_offline", out)
    quiet.context.route(f"https://{BOARD_HOST}/**", answer)
    open_host(quiet)
    to_title(quiet)
    quiet.click(TITLE_SETTINGS)
    quiet.wait(1500)
    scroll_to_end(quiet)
    quiet.click(SETTINGS_ONLINE)
    quiet.wait(800)
    quiet.shot("online_off")
    quiet.key("Escape", 1500)
    count = len(served)
    quiet.click(TITLE_BENCHMARK)
    quiet.wait(4000)
    quiet.shot("bench_offline")
    none_made = len(served) == count and not any(BOARD_HOST in url for url in quiet.requests)
    quiet.context.close()
    ok = fetched and downloaded and playing and none_made
    return Result(name, "online", ok, f"board fetched {fetched}; the run downloaded on Watch "
                  f"{downloaded} and plays {playing}; with the setting off no request {none_made}")


def check_progress(browser: Browser, out: Path, name: str) -> Result:
    """§17.2 item 11: the progress file out and back in."""
    session = new_session(browser, f"{name}_progress", out)
    if not open_host(session):
        return Result(name, "progress", False, "no 'first screen' line")
    to_title(session)
    session.click(TITLE_SETTINGS)
    session.wait(1500)
    scroll_to_end(session)
    session.shot("settings_end")
    with session.page.expect_download(timeout=15_000) as waiting:
        session.click(SETTINGS_SAVE_PROGRESS)
    download = waiting.value
    temp = Path(tempfile.mkdtemp(prefix="doomsday_web_"))
    saved = temp / download.suggested_filename
    download.save_as(saved)
    profile = json.loads(saved.read_text(encoding="utf-8"))
    named = re.fullmatch(r"doomsday-progress-\d{4}-\d{2}-\d{2}\.json", download.suggested_filename)
    doctored = dict(profile)
    doctored["runs_completed"] = int(profile.get("runs_completed", 0)) + 1
    doctored_path = temp / "doctored.json"
    doctored_path.write_text(json.dumps(doctored), encoding="utf-8")
    with session.page.expect_file_chooser(timeout=15_000) as choosing:
        session.click(SETTINGS_LOAD_PROGRESS)
    choosing.value.set_files(str(doctored_path))
    session.wait(1500)
    session.shot("import_confirm")
    session.click(CONFIRM_YES)
    session.wait(1500)
    scroll_to_end(session)
    session.shot("imported")
    stored = json.loads(session.frame().evaluate(JS_IDB_TEXT, PROFILE)
                        or "{}")
    imported = int(stored.get("runs_completed", -1)) == doctored["runs_completed"]
    wrong = temp / "wrong.json"
    wrong.write_text(json.dumps({"hello": 1}), encoding="utf-8")
    with session.page.expect_file_chooser(timeout=15_000) as choosing:
        session.click(SETTINGS_LOAD_PROGRESS)
    choosing.value.set_files(str(wrong))
    session.wait(1500)
    scroll_to_end(session)
    session.shot("not_a_profile")
    session.key("Escape", 1500)
    session.click(TITLE_STATISTICS)
    session.wait(2000)
    session.shot("statistics")
    session.context.close()
    ok = bool(named) and "runs_completed" in profile and imported
    return Result(name, "progress", ok, f"download {download.suggested_filename} parses: "
                  f"{'runs_completed' in profile}; the doctored copy imported: {imported}")


def check_smoke(browser: Browser, name: str, expected: dict) -> Result:
    """§17.2 item 13 and §16.3."""
    context = browser.new_context(viewport={"width": EMBED[0], "height": EMBED[1]})
    page = context.new_page()
    lines: list[str] = []
    page.on("console", lambda message: lines.append(message.text))
    page.goto(GAME_URL + "?smoke")
    deadline = time.monotonic() + SMOKE_TIMEOUT_MS / 1000
    found = ""
    while time.monotonic() < deadline and not found:
        page.wait_for_timeout(1000)
        found = next((line for line in lines if line.startswith(SMOKE_PREFIX)), "")
    context.close()
    if not found:
        return Result(name, "smoke", False, "no smoke line in time")
    fields = dict(part.split("=", 1) for part in found[len(SMOKE_PREFIX):].split()[1:])
    want = {"outcome": str(expected.get("outcome")), "day": str(expected.get("days",
            expected.get("day"))), "hash": str(expected.get("hash"))}
    ok = found.startswith(SMOKE_PREFIX + "ok") and all(fields.get(k) == v for k, v in want.items())
    return Result(name, "smoke", ok, f"{found} — expected {want}")


def check_debug(browser: Browser, out: Path, name: str) -> Result:
    """§17.2 items 8 (the unlock) and 12 (the crash screen), on a debug export."""
    session = new_session(browser, f"{name}_debug", out)
    if not open_host(session):
        return Result(name, "debug", False, "no 'first screen' line")
    frame = session.frame()
    frame.evaluate("window.doomsdayDebugAudioUnlocked()")
    session.wait(500)
    to_title(session)
    frame.evaluate("window.doomsdayDebugAudioUnlocked()")
    session.wait(500)
    answers = session.lines("audio unlocked: ")
    # From a timer, as a crash in the engine's own frame would come: uncaught.
    frame.evaluate("setTimeout(() => window.doomsdayDebugCrash(), 0)")
    session.wait(2500)
    shown = frame.locator("#crash").is_visible()
    if shown:
        frame.locator("#crash details summary").click()
    log = frame.locator("#crash-log").inner_text() if shown else ""
    session.shot("crash")
    reload_label = frame.locator("#crash-reload").inner_text() if shown else ""
    session.context.close()
    unlock_ok = answers[:2] == ["audio unlocked: false", "audio unlocked: true"]
    ok = unlock_ok and shown and bool(reload_label)
    return Result(name, "debug", ok, f"unlock answers {answers[:2]}; crash overlay {shown}, "
                  f"{len(log.splitlines())} detail lines, button {reload_label!r}")


def check_size(build: Path) -> Result:
    """§17.2 item 14 against §4.2."""
    files = sorted(path for path in build.iterdir() if path.is_file())
    extracted = sum(path.stat().st_size for path in files)
    largest = max(files, key=lambda path: path.stat().st_size)
    with tempfile.TemporaryDirectory() as temp:
        archive = Path(temp) / "web.zip"
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zipped:
            for path in files:
                zipped.write(path, path.name)
        zipped_mb = archive.stat().st_size / MB
    extracted_mb = extracted / MB
    largest_mb = largest.stat().st_size / MB
    ok = (zipped_mb <= ZIP_HARD_MB and extracted_mb <= EXTRACTED_HARD_MB
          and largest_mb <= FILE_HARD_MB and len(files) <= FILES_HARD)
    notes = []
    if zipped_mb > ZIP_TARGET_MB:
        notes.append(f"over the {ZIP_TARGET_MB} MB target")
    if extracted_mb > EXTRACTED_TARGET_MB:
        notes.append(f"extracted over the {EXTRACTED_TARGET_MB} MB target")
    return Result("-", "size", ok, f"zip {zipped_mb:.2f} MB, extracted {extracted_mb:.2f} MB, "
                  f"largest {largest.name} {largest_mb:.2f} MB, {len(files)} files "
                  f"{'; '.join(notes)}".rstrip())


# ---------------------------------------------------------------------- run


def reference_run() -> dict:
    godot = os.environ.get("GODOT", "godot")
    output = subprocess.run([godot, "--headless", "--path", str(ROOT), "-s", "tools/sim_run.gd",
                             "--", "--seed=1", "--policy=greedy"], capture_output=True, text=True,
                            check=True).stdout
    line = [text for text in output.splitlines() if text.startswith("{")][-1]
    return json.loads(line)


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--build", type=Path, default=ROOT / "build" / "web")
    parser.add_argument("--debug-build", type=Path, default=None)
    parser.add_argument("--browsers", default="chrome,msedge,firefox")
    parser.add_argument("--checks", default="size,load,phone,focus,keys,run,hidden,persist,"
                        "settings,online,progress,smoke,debug")
    parser.add_argument("--out", type=Path, default=Path(tempfile.gettempdir()) / "doomsday_web")
    parser.add_argument("--smoke", action="store_true", help="only the smoke (CI)")
    parser.add_argument("--expect", type=Path, default=None)
    args = parser.parse_args()
    checks = ["smoke"] if args.smoke else args.checks.split(",")
    browsers = ["chromium"] if args.smoke and args.browsers == parser.get_default("browsers") \
        else args.browsers.split(",")
    out: Path = args.out
    out.mkdir(parents=True, exist_ok=True)
    build: Path = args.build.resolve()
    if not (build / "index.html").is_file():
        print(f"web_check: no index.html in {build}")
        return 1
    results: list[Result] = []
    if "size" in checks:
        results.append(check_size(build))
    expected: dict = {}
    if "smoke" in checks:
        expected = json.loads(args.expect.read_text()) if args.expect else reference_run()
    game_server = serve.start(build, GAME_PORT)
    host_server = serve.start(Path(__file__).resolve().parent, HOST_PORT)
    try:
        with sync_playwright() as playwright:
            for name in browsers:
                browser = launch(playwright, name) if name != "chromium" else \
                    playwright.chromium.launch(headless=True)
                print(f"web_check: {name} {browser.version}")
                if any(check in checks for check in ("load", "focus", "keys", "run", "hidden",
                                                     "persist")):
                    session = new_session(browser, name, out)
                    results.append(check_load(session))
                    if "focus" in checks:
                        session.page.reload()
                        session.wait_for_line(FIRST_SCREEN, count=2)
                        results.append(check_focus(session))
                    else:
                        pass
                    if "keys" in checks:
                        results.append(check_keys(session))
                    if "run" in checks:
                        results.append(play_a_run(session))
                        if "hidden" in checks:
                            results.append(check_hidden(session))
                        if "persist" in checks:
                            results.append(check_persist(session))
                    session.context.close()
                if "phone" in checks and name == "chrome":
                    results.append(check_phone(browser, out))
                if "settings" in checks:
                    results.append(check_settings(browser, out, name))
                if "online" in checks:
                    results.append(check_online(browser, out, name))
                if "progress" in checks:
                    results.append(check_progress(browser, out, name))
                if "smoke" in checks:
                    results.append(check_smoke(browser, name, expected))
                browser.close()
            if "debug" in checks and args.debug_build is not None:
                game_server.shutdown()
                game_server = serve.start(args.debug_build.resolve(), GAME_PORT)
                browser = launch(playwright, "chrome")
                results.append(check_debug(browser, out, "chrome"))
                browser.close()
    finally:
        game_server.shutdown()
        host_server.shutdown()
    failed = 0
    for result in results:
        failed += 0 if result.ok else 1
        print(f"{'PASS' if result.ok else 'FAIL'} {result.browser:8} {result.check:9} {result.detail}")
    print(f"web_check: {len(results) - failed} passed, {failed} failed; screenshots in {out}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
