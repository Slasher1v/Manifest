<h1 align="center">⬇ Manifest</h1>

<p align="center">
A personal video downloader that runs entirely on <b>your own computer</b>.<br>
Paste a link from YouTube, TikTok, Instagram, X, Reddit & ~1,800 more → pick a quality → download.<br>
No website, no account, no cost.
</p>

---

## ⬇ Download & Install

<table>
<tr>
<td align="center" width="50%">

### 🍎 macOS

**[⬇ Download for Mac](https://github.com/Slasher1v/Manifest/releases/latest/download/Manifest-macOS.zip)**

1. Unzip it
2. Right-click **Install Manifest.command** → **Open** (once)
3. Then double-click **Manifest.command**

</td>
<td align="center" width="50%">

### 🪟 Windows

**[⬇ Download for Windows](https://github.com/Slasher1v/Manifest/releases/latest/download/Manifest-Windows.zip)**

1. Unzip it
2. Double-click **Install Manifest.bat** (SmartScreen → *More info → Run anyway*)
3. Then double-click **Manifest.bat**

</td>
</tr>
</table>

The installer sets everything up automatically (a few minutes, first time only).
Then the app opens in your browser at **http://127.0.0.1:8000**. Each download
includes a **READ ME FIRST** with the full walkthrough.

> 🪟 **Windows + YouTube tip:** use **Firefox** (signed in to YouTube) or a
> `cookies.txt` file — recent Chrome encrypts cookies so they can't be read.
> Other sites work with no setup. (Details in the Windows READ ME.)

> For personal use. Please respect each site's Terms of Service and copyright.

---

## What's inside

It bundles, automatically and per-user (no admin): a self-contained Python (via
`uv`), **yt-dlp** (the engine), **ffmpeg** (merging), **Deno** (YouTube's nsig
solver), and the **bgutil** PO-token helper. yt-dlp auto-updates on launch, and
the app self-heals if anything goes missing.

## For developers

The two folders above are the shipped apps. Everything else lives in **`dev/`**:
`dev/DESIGN` is the shared source of truth (backend + UI), `dev/sandbox` is the
macOS test build. See **`CLAUDE.md`** for the full workflow, roles, and release
process. MIT licensed (see `LICENSE`); third-party tools keep their own licenses.
