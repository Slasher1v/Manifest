# Manifest — Master Brain 🧠

> Read this file at the start of **every** session before doing anything else.

Manifest is a personal, self-hosted video downloader. One shared core (Python +
Flask backend + a single-page UI) is wrapped per platform. This file is the
source of truth for how the project is organized and how work gets done.

## Layout

The top level is kept clean so users can install easily:

```
Mac/         🍎 the ready-to-use macOS app (what users download/run)
Windows/     🪟 the ready-to-use Windows app
README.md    download landing page (links to the GitHub Release assets)
dev/         everything else (not for end users) ↓
  ├── DESIGN/    shared source of truth: app.py, requirements.txt, templates/
  ├── sandbox/   private macOS TEST build (port 8001, never shipped)
  └── docs/      context / notes
CLAUDE.md    this file
.github/     release automation
```

## Roles

Operate as one of three specialist roles by which folder you touch:

| Role | Folder | Owns |
|------|--------|------|
| 🎨 **Design** | `dev/DESIGN` | Shared UI/UX **and** cross-platform backend. **Source of truth.** |
| 🍎 **Mac** | `Mac/` (+ `dev/sandbox`) | macOS wrapper: `Install Manifest.command`, `Manifest.command`, `.engine/setup.sh` (Homebrew + uv). |
| 🪟 **Windows** | `Windows/` | Windows wrapper: `Install Manifest.bat`, `Manifest.bat`, `.engine/{setup,install,launch}.ps1` (winget + uv). |

> **Hidden engine:** in the shipped `Mac/` and `Windows/` folders the app machinery
> lives in a hidden **`.engine/`** folder so end users only see the click-files +
> README. (The dev `dev/sandbox` keeps a normal visible `app/` for convenience.)

### Mac: release vs sandbox
* **`Mac/`** = the official, user-facing app (port **8000**). Its launcher
  auto-updates (git pull on `main` for clones + a "new version" notice for ZIP users).
  Packaged into GitHub Releases.
* **`dev/sandbox/`** = private test build (port **8001**, via `MANIFEST_PORT`), never
  packaged, no auto-update. Do Mac testing here.
* **Promotion (only when the user says so):** copy tested files from `dev/sandbox/`
  into `Mac/`, then publish.

**Golden rule for shared code:** edit UI/backend **only in `dev/DESIGN`**, then run
the **Design Changes** workflow to propagate into the platform `app/` folders.
Never hand-edit the copies inside the platform folders. The backend (`app.py`) is
cross-platform (locates `deno`/`ffmpeg` via `PATH`); only the wrappers differ.

## Development Workflow Rules

* Three roles: **Mac**, **Windows**, **Design**.
* **ALWAYS** make feature changes on a Git **branch** (the sandbox). Do **not**
  commit to `main` until the user explicitly says to deploy.

## Custom Commands

### 1. Publish Mac Release / 2. Publish Windows Release
Releases are automated (both platforms packaged together):
1. Merge the feature branch into `main` and push.
2. `git tag vX.Y && git push origin vX.Y`.
3. The **Package & Release** Action (`.github/workflows/release.yml`) packages
   `Mac/` → `Manifest-macOS.zip` and `Windows/` → `Manifest-Windows.zip` and
   attaches both to the Release. (Also runnable manually via *workflow_dispatch*.)
> First promote `dev/sandbox` → `Mac/` (with the user's approval) so released code is tested code.

### 3. Design Changes
1. Take updated files from `dev/DESIGN` (`app.py`, `requirements.txt`, `templates/`).
2. Copy/refine into `dev/sandbox/app`, `Mac/.engine`, and `Windows/.engine`. (Test in sandbox first.)
3. Ensure the UI looks/behaves consistently on both platforms.

## Notes
* Auto-release runs on pushing a `v*` tag. Repo: https://github.com/Slasher1v/Manifest (default `main`).
