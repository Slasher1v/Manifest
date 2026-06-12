"""
Manifest — desktop window.

Runs the Flask app in a background thread and shows its UI in a native window
(WebKit on macOS, WebView2 on Windows) via pywebview — so Manifest opens like a
real app instead of a browser tab. Falls back is handled by the launcher: if
pywebview isn't available it runs app.py in browser mode instead.
"""

import os
import threading
import time
import urllib.request

import webview

from app import app  # the Flask instance defined in app.py

PORT = int(os.environ.get("MANIFEST_PORT", "8000"))
URL = f"http://127.0.0.1:{PORT}"


def _run_flask():
    # use_reloader=False is essential — the reloader forks and breaks in a thread.
    app.run(host="127.0.0.1", port=PORT, debug=False, threaded=True, use_reloader=False)


def _wait_for_server(timeout=25):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            urllib.request.urlopen(URL, timeout=1)
            return True
        except Exception:
            time.sleep(0.3)
    return False


def _set_app_name(name="Manifest"):
    # Make the macOS menu bar / Dock say "Manifest" instead of "Python".
    try:
        from Foundation import NSBundle
        bundle = NSBundle.mainBundle()
        info = bundle.localizedInfoDictionary() or bundle.infoDictionary()
        if info is not None:
            info["CFBundleName"] = name
    except Exception:
        pass


def main():
    threading.Thread(target=_run_flask, daemon=True).start()
    _wait_for_server()
    _set_app_name("Manifest")
    webview.create_window(
        "Manifest",
        URL,
        width=1180,
        height=820,
        min_size=(920, 640),
    )
    webview.start()  # blocks on the main thread until the window is closed


if __name__ == "__main__":
    main()
