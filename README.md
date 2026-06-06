# Manifest

A personal, self-hosted video downloader for macOS. Paste a link from YouTube,
TikTok, Instagram, X, Reddit, Vimeo and ~1,800 other sites → pick a quality →
it downloads to your computer. Runs entirely on your Mac — **no website, no
account, no cost, no cloud lag.**

> For personal use. Respect each site's Terms of Service and copyright — only
> download content you have the right to.

---

## Install (non-technical, double-click)

1. **Download:** go to **https://github.com/Slasher1v/Manifest** → green
   **Code** button → **Download ZIP** → unzip it.
   (Or clone: `git clone https://github.com/Slasher1v/Manifest.git`)
2. Double-click **`Install Manifest.command`**.
   - If macOS says *"unidentified developer"*, **right-click → Open** the first time.
   - It installs everything automatically (a few minutes, needs internet).
3. Double-click **`Manifest.command`** to start it. Your browser opens to the app.

That's it. See **`READ ME FIRST.txt`** for the friendly step-by-step.

### Updating later

If you cloned it: `git pull` then run **`Manifest.command`** again.
If you downloaded the ZIP: download it again and replace the folder. (The app
also auto-updates yt-dlp on each launch, so it keeps working as sites change.)

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

```bash
# from the app/ folder
./venv/bin/python app.py    # after setup.sh has run once
```

- `app/app.py` — Flask backend + yt-dlp glue
- `app/templates/index.html` — single-page UI
- `app/setup.sh` — idempotent environment setup (sourced by the launchers)
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
