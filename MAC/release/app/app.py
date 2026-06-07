"""
Manifest — local video downloader.

A small Flask app that wraps yt-dlp to fetch quality/format options for any
supported social-media link, then downloads the chosen one locally (merging
with ffmpeg). Runs entirely on your machine — no cloud, no queue, no lag.
"""

import os
import re
import shutil
import threading
import uuid
from pathlib import Path

from flask import (
    Flask,
    jsonify,
    render_template,
    request,
    send_file,
)
from yt_dlp import YoutubeDL
from yt_dlp.utils import DownloadError

BASE_DIR = Path(__file__).resolve().parent
DOWNLOAD_DIR = BASE_DIR / "downloads"
DOWNLOAD_DIR.mkdir(exist_ok=True)

# Which browser yt-dlp pulls cookies from, so it can use your logged-in session.
# Required to unlock YouTube HD format *listings* and age-gated/private content.
# (Note: cookies + a PO token are necessary but NOT sufficient if your network's
# path to YouTube's googlevideo CDN is itself blocked — that needs MANIFEST_PROXY.)
# Override with the env var:
#   MANIFEST_BROWSER=safari ./run.sh      (or chrome / firefox / brave / edge)
#   MANIFEST_BROWSER=none   ./run.sh      to disable cookies entirely
_b = os.environ.get("MANIFEST_BROWSER", "chrome").strip().lower()
COOKIES_FROM_BROWSER = None if _b in ("", "none", "off", "false", "disable") else _b

# Optional proxy for all yt-dlp traffic. Use this when your ISP/region blocks the
# YouTube media CDN (symptom: format list loads fine, but downloads 403). Accepts
# http/https/socks5, e.g.:
#   MANIFEST_PROXY=socks5://127.0.0.1:1080 ./run.sh
#   MANIFEST_PROXY=http://user:pass@host:port ./run.sh
PROXY = os.environ.get("MANIFEST_PROXY", "").strip() or None

# JavaScript runtime for YouTube's "n-challenge" (nsig) solver. Modern yt-dlp
# offloads this to an external runtime — Deno is the supported default. Without
# it YouTube returns only images / "Requested format is not available". We locate
# Deno and hand yt-dlp its explicit path so it works regardless of launch PATH.
_deno = (
    shutil.which("deno")
    or next((p for p in ("/opt/homebrew/bin/deno", "/usr/local/bin/deno") if os.path.exists(p)), None)
)
DENO_PATH = os.environ.get("MANIFEST_DENO", _deno) or None

app = Flask(__name__)

# In-memory registry of running/finished download jobs.
# job_id -> {status, progress, speed, eta, title, filepath, error}
JOBS = {}
JOBS_LOCK = threading.Lock()


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #
def _human_size(num):
    if not num:
        return None
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if abs(num) < 1024.0:
            return f"{num:3.1f} {unit}"
        num /= 1024.0
    return f"{num:.1f} PB"


def _base_ydl_opts():
    """Options shared by info-extraction and downloading."""
    opts = {
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,  # one video at a time keeps the UX predictable
    }
    if COOKIES_FROM_BROWSER:
        # (browser, profile, keyring, container) — only the browser is required.
        opts["cookiesfrombrowser"] = (COOKIES_FROM_BROWSER,)
    if PROXY:
        opts["proxy"] = PROXY
    if DENO_PATH:
        # Equivalent of CLI `--js-runtimes deno:<path>`.
        opts["js_runtimes"] = {"deno": {"path": DENO_PATH}}
    return opts


def extract_info(url):
    """Probe a URL and return a normalized dict of formats — no download."""
    opts = _base_ydl_opts()
    with YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=False)

    # Some extractors return a playlist even with noplaylist; take first entry.
    if info.get("_type") == "playlist" and info.get("entries"):
        info = info["entries"][0]

    formats = []
    seen = set()
    for f in info.get("formats", []):
        # Skip storyboards / images / formats with no real media.
        if f.get("vcodec") == "none" and f.get("acodec") == "none":
            continue
        if f.get("ext") in ("mhtml",):
            continue

        has_video = f.get("vcodec") not in (None, "none")
        has_audio = f.get("acodec") not in (None, "none")

        if has_video:
            height = f.get("height")
            label = f"{height}p" if height else (f.get("format_note") or "video")
            fps = f.get("fps")
            if fps and fps >= 50:
                label += f"{int(fps)}"
            kind = "video" if has_audio else "video-only"
        elif has_audio:
            abr = f.get("abr")
            label = f"audio {int(abr)}kbps" if abr else "audio"
            kind = "audio"
        else:
            continue

        filesize = f.get("filesize") or f.get("filesize_approx")
        key = (label, f.get("ext"), kind)
        if key in seen:
            continue
        seen.add(key)

        formats.append(
            {
                "format_id": f.get("format_id"),
                "label": label,
                "ext": f.get("ext"),
                "kind": kind,
                "height": f.get("height") or 0,
                "fps": f.get("fps") or 0,
                "abr": f.get("abr") or 0,
                "filesize": filesize,
                "filesize_h": _human_size(filesize),
                "vcodec": f.get("vcodec"),
                "acodec": f.get("acodec"),
            }
        )

    # Sort: video by height desc, then audio by bitrate desc, audio-only last.
    def sort_key(f):
        kind_rank = {"video": 0, "video-only": 1, "audio": 2}.get(f["kind"], 3)
        return (kind_rank, -f["height"], -f["abr"])

    formats.sort(key=sort_key)

    return {
        "id": info.get("id"),
        "title": info.get("title"),
        "uploader": info.get("uploader") or info.get("channel"),
        "thumbnail": info.get("thumbnail"),
        "duration": info.get("duration"),
        "duration_string": info.get("duration_string"),
        "webpage_url": info.get("webpage_url") or url,
        "extractor": info.get("extractor_key"),
        "formats": formats,
    }


def _progress_hook(job_id):
    def hook(d):
        with JOBS_LOCK:
            job = JOBS.get(job_id)
            if not job:
                return
            status = d.get("status")
            if status == "downloading":
                total = d.get("total_bytes") or d.get("total_bytes_estimate")
                downloaded = d.get("downloaded_bytes", 0)
                job["status"] = "downloading"
                job["progress"] = round(downloaded / total * 100, 1) if total else 0
                job["speed"] = _human_size(d.get("speed")) and (
                    _human_size(d.get("speed")) + "/s"
                )
                job["eta"] = d.get("eta")
            elif status == "finished":
                # File finished downloading; ffmpeg merge/convert may follow.
                job["status"] = "processing"
                job["progress"] = 100

    return hook


def _run_download(job_id, url, format_selector, audio_only):
    outtmpl = str(DOWNLOAD_DIR / f"{job_id}.%(ext)s")
    opts = _base_ydl_opts()
    opts.update(
        {
            "outtmpl": outtmpl,
            "format": format_selector,
            "progress_hooks": [_progress_hook(job_id)],
            "merge_output_format": "mp4",
        }
    )
    if audio_only:
        # Extract/convert the audio stream to mp3.
        opts["postprocessors"] = [
            {
                "key": "FFmpegExtractAudio",
                "preferredcodec": "mp3",
                "preferredquality": "0",
            }
        ]
        opts.pop("merge_output_format", None)

    try:
        with YoutubeDL(opts) as ydl:
            info = ydl.extract_info(url, download=True)
            if info.get("_type") == "playlist" and info.get("entries"):
                info = info["entries"][0]

        # Find the produced file (extension is decided by yt-dlp/ffmpeg).
        produced = sorted(
            DOWNLOAD_DIR.glob(f"{job_id}.*"),
            key=lambda p: p.stat().st_mtime,
            reverse=True,
        )
        if not produced:
            raise RuntimeError("Download finished but no output file was found.")

        filepath = produced[0]
        # Build a friendly download filename from the title.
        title = info.get("title") or "video"
        safe = re.sub(r'[\\/:*?"<>|]+', "_", title).strip() or "video"
        nice_name = f"{safe}{filepath.suffix}"

        with JOBS_LOCK:
            JOBS[job_id].update(
                {
                    "status": "done",
                    "progress": 100,
                    "filepath": str(filepath),
                    "filename": nice_name,
                    "title": title,
                }
            )
    except DownloadError as e:
        with JOBS_LOCK:
            JOBS[job_id].update({"status": "error", "error": str(e)})
    except Exception as e:  # noqa: BLE001 — surface anything to the UI
        with JOBS_LOCK:
            JOBS[job_id].update({"status": "error", "error": str(e)})


# --------------------------------------------------------------------------- #
# Routes
# --------------------------------------------------------------------------- #
@app.route("/")
def index():
    return render_template("index.html")


@app.route("/info", methods=["POST"])
def info():
    url = (request.json or {}).get("url", "").strip()
    if not url:
        return jsonify({"error": "Please paste a link."}), 400
    try:
        data = extract_info(url)
        return jsonify(data)
    except DownloadError as e:
        return jsonify({"error": f"Couldn't read that link: {e}"}), 400
    except Exception as e:  # noqa: BLE001
        return jsonify({"error": str(e)}), 500


@app.route("/download", methods=["POST"])
def download():
    body = request.json or {}
    url = (body.get("url") or "").strip()
    format_id = (body.get("format_id") or "").strip()
    kind = body.get("kind", "video")
    if not url or not format_id:
        return jsonify({"error": "Missing url or format."}), 400

    audio_only = kind == "audio"
    if audio_only:
        selector = format_id
    elif kind == "video-only":
        # Pair the chosen video-only stream with the best available audio.
        selector = f"{format_id}+bestaudio/{format_id}"
    else:
        # Progressive stream already has audio.
        selector = format_id

    job_id = uuid.uuid4().hex[:12]
    with JOBS_LOCK:
        JOBS[job_id] = {
            "status": "queued",
            "progress": 0,
            "speed": None,
            "eta": None,
            "error": None,
            "filepath": None,
        }

    t = threading.Thread(
        target=_run_download,
        args=(job_id, url, selector, audio_only),
        daemon=True,
    )
    t.start()
    return jsonify({"job_id": job_id})


@app.route("/progress/<job_id>")
def progress(job_id):
    with JOBS_LOCK:
        job = JOBS.get(job_id)
        if not job:
            return jsonify({"error": "Unknown job."}), 404
        # Don't leak filesystem path to the client.
        public = {k: v for k, v in job.items() if k != "filepath"}
    return jsonify(public)


@app.route("/file/<job_id>")
def file(job_id):
    with JOBS_LOCK:
        job = JOBS.get(job_id)
    if not job or job.get("status") != "done" or not job.get("filepath"):
        return jsonify({"error": "File not ready."}), 404
    return send_file(
        job["filepath"],
        as_attachment=True,
        download_name=job.get("filename", "download"),
    )


if __name__ == "__main__":
    # Port is configurable so the sandbox build can run alongside the release
    # build (e.g. release on 8000, sandbox on 8001).
    port = int(os.environ.get("MANIFEST_PORT", "8000"))
    print(f"\n  Manifest running →  http://127.0.0.1:{port}\n")
    app.run(host="127.0.0.1", port=port, debug=False, threaded=True)
