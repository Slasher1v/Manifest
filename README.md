# Manifest

A personal, self-hosted video downloader. Paste a link from YouTube, TikTok,
Instagram, X, Reddit, Vimeo and ~1,800 other sites → pick a quality → it
downloads to your computer. Runs entirely on your machine — **no website, no
account, no cost, no cloud lag.**

> For personal use. Respect each site's Terms of Service and copyright — only
> download content you have the right to.

---

## Repository layout

| Folder | What it is |
|--------|-----------|
| **`DESIGN/`** | Shared source of truth — the UI (`templates/index.html`) and the cross-platform backend (`app.py`, `requirements.txt`). |
| **`MAC/`** | macOS wrapper: `Install Manifest.command`, `Manifest.command`, `app/setup.sh` (Homebrew + uv). ✅ released. |
| **`WINDOWS/`** | Windows wrapper: `Install Manifest.bat`, `Manifest.bat`, `app/setup.ps1` (winget + uv). 🚧 draft, untested. |
| `CLAUDE.md` | The "master brain": roles, workflow rules, and custom commands. |

Shared code is edited in `DESIGN/` and synced into the platform folders (see the
**Design Changes** workflow in `CLAUDE.md`).

## Install (non-technical, double-click)

Download the repo (**Code → Download ZIP**, or `git clone`), then:

- **macOS:** open the **`MAC`** folder → double-click **`Install Manifest.command`**
  (right-click → Open the first time) → then **`Manifest.command`**.
- **Windows:** open the **`WINDOWS`** folder → double-click **`Install Manifest.bat`**
  → then **`Manifest.bat`**. *(Draft — not yet tested on real Windows.)*

Each platform's **`READ ME FIRST.txt`** has the friendly step-by-step. The
installer is self-contained and idempotent; the launcher self-repairs and
auto-updates yt-dlp.

## What gets installed

The installer is self-contained and idempotent. It sets up:

- **[uv](https://github.com/astral-sh/uv)** → a self-contained Python (avoids
  relying on the Mac's system Python, which can be broken).
- **[yt-dlp](https://github.com/yt-dlp/yt-dlp)** → the download engine.
- **[ffmpeg](https://ffmpeg.org/)** → merges HD video+audio, makes MP3s.
- **[Deno](https://deno.com/)** → solves YouTube's "n-challenge" (nsig).
- **[bgutil PO-token provider](https://github.com/Brainicism/bgutil-ytdlp-pot-provider)**
  → mints the YouTube Proof-of-Origin token (fetched + built at install).

It also reads your **Chrome** cookies at runtime so logged-in / HD YouTube works
(make sure you're signed in to YouTube in Chrome).

## How it works

```
Browser page (index.html)  ──►  Flask app (app.py)  ──►  yt-dlp ──► ffmpeg
   paste link, pick quality        /info  /download           (download + merge)
                                    /progress  /file
```

For YouTube specifically, yt-dlp uses **Deno** to solve the nsig challenge, a
local **bgutil** server (port 4416) for the PO token, and your **Chrome cookies**
for the session. All local; nothing is uploaded.

## For developers

Edit shared code in **`DESIGN/`**, then sync to the platform folders (the
**Design Changes** workflow in `CLAUDE.md`). Make feature changes on a branch,
not `main`.

```bash
# run the Mac build directly, after MAC/app/setup.sh has run once
cd MAC/app && ./venv/bin/python app.py
```

- `DESIGN/app.py` — Flask backend + yt-dlp glue (cross-platform)
- `DESIGN/templates/index.html` — single-page UI
- `MAC/app/setup.sh` / `WINDOWS/app/setup.ps1` — per-platform environment setup
- Env vars: `MANIFEST_BROWSER` (cookie source, default `chrome`),
  `MANIFEST_DENO` (deno path), `MANIFEST_PROXY` (optional proxy)

## Troubleshooting

- **A missing-module or Python error?** Just run **Manifest.command** again — it
  repairs the environment automatically.
- **YouTube only gives low quality / nothing?** Make sure you're logged into
  YouTube in Chrome, then retry.
- **Slow download?** Usually your connection or a large HD file — try a lower
  quality.

## Credits

Built on the excellent work of yt-dlp, ffmpeg, Deno, uv, and the bgutil
PO-token provider. Manifest is just the glue + a friendly UI.

## License

MIT (see `LICENSE`). Third-party tools retain their own licenses.
