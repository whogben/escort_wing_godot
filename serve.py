#!/usr/bin/env python3
"""Local dev server for the committed web build in docs/.

Plain ``python3 -m http.server -d docs`` is enough for most testing. Use this
script when the export has Progressive Web App enabled with "Ensure cross origin
isolation headers" — it sends the COOP/COEP headers Safari and Godot expect.
"""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import os
import sys


class GodotWebHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, directory=os.path.join(os.path.dirname(__file__), "docs"), **kwargs)

    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        super().end_headers()


def main() -> None:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    server = ThreadingHTTPServer(("127.0.0.1", port), GodotWebHandler)
    print(f"Serving on http://127.0.0.1:{port}/ (COOP/COEP enabled)")
    print("Open http://127.0.0.1:{}/".format(port))
    server.serve_forever()


if __name__ == "__main__":
    main()
