"""Serves a folder on this machine only (docs/specs/web.md §13.2, §17.2).

    uv run --project tools/web python tools/web/serve.py [--dir build/web] [--port 8765]

Python's own file server, bound to 127.0.0.1 (never another interface), with
the MIME types a Godot web export needs and no caching headers of its own, so a
browser caches as it would on a plain static host. `web_check.py` and
`web_perf.py` start it in a thread through `start()`.
"""

from __future__ import annotations

import argparse
import functools
import http.server
import threading
from pathlib import Path

HOST = "127.0.0.1"
DEFAULT_PORT = 8765
ROOT = Path(__file__).resolve().parents[2]

# The types the export's files are served with; `.wasm` must be application/wasm
# for streaming compilation, `.pck` is opaque bytes.
MIME_TYPES = {
    ".wasm": "application/wasm",
    ".pck": "application/octet-stream",
    ".js": "text/javascript",
    ".html": "text/html",
    ".json": "application/json",
    ".png": "image/png",
}


class _Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, **MIME_TYPES}

    def log_message(self, format: str, *args: object) -> None:  # noqa: A002 - the base's name
        pass


class _Server(http.server.ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def start(directory: Path, port: int, host: str = HOST) -> _Server:
    """Serves `directory` on `host:port` in a background thread; `shutdown()` stops it."""
    handler = functools.partial(_Handler, directory=str(directory))
    server = _Server((host, port), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dir", type=Path, default=ROOT / "build" / "web")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    args = parser.parse_args()
    directory: Path = args.dir.resolve()
    if not (directory / "index.html").is_file():
        print(f"serve: no index.html in {directory} — export the Web preset first")
        return 1
    handler = functools.partial(_Handler, directory=str(directory))
    with _Server((HOST, args.port), handler) as server:
        print(f"serve: http://{HOST}:{args.port}/ ({directory}) — Ctrl+C stops")
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
