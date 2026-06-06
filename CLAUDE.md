# Manifest — Master Brain 🧠

> Read this file at the start of **every** session before doing anything else.

Manifest is a personal, self-hosted video downloader. One shared core (Python +
Flask backend + a single-page UI) is wrapped per platform. This file is the
source of truth for how the project is organized and how work gets done.

## Project structure & roles

You operate as one of **three specialist roles**, decided by which folder the
work touches:

| Role | Folder | Owns |
|------|--------|------|
| 🎨 **Design** | `/DESIGN` | The shared UI/UX **and** the cross-platform backend (`app.py`, `templates/`, `requirements.txt`). **Source of truth.** |
| 🍎 **Mac** | `/MAC` | macOS wrapper: `Install Manifest.command`, `Manifest.command`, `app/setup.sh` (uses Homebrew + `uv`). |
| 🪟 **Windows** | `/WINDOWS` | Windows wrapper: `Install Manifest.bat`, `Manifest.bat`, `app/setup.ps1` (uses winget + `uv`). |

**Golden rule for shared code:** edit UI/backend **only in `/DESIGN`**, then run
the **Design Changes** workflow to propagate into `/MAC/app` and `/WINDOWS/app`.
Never hand-edit the copies inside the platform folders.

The backend (`app.py`) is already cross-platform (it locates `deno`/`ffmpeg` via
`PATH`), so the *same* code runs on both; only the install/launch wrappers differ.

## Development Workflow Rules

* You have three specialist roles: **Mac**, **Windows**, and **Design**.
* **ALWAYS** make code changes for a feature inside a Git **branch** (our
  sandbox), e.g. `feature/<short-name>`. Do **not** commit to `main` until the
  user explicitly asks you to deploy.
* Keep the three roles consistent: a feature usually means a Design change that
  is then synced to both platform wrappers.

## Custom Commands

Execute these workflows instantly when the user requests them by name.

### 1. Publish Mac Release
1. Merge the current branch into `main`.
2. Run the Mac build steps (package `/MAC` into a distributable `Manifest.zip`).
3. `git push` to `main` to trigger the GitHub Actions deployment.

### 2. Publish Windows Release
1. Merge the current branch into `main`.
2. Run the Windows build steps (package `/WINDOWS` into a distributable `Manifest-Windows.zip`).
3. `git push` to `main` to trigger the GitHub Actions deployment.

### 3. Design Changes
1. Take the updated files from `/DESIGN` (`app.py`, `requirements.txt`, `templates/`).
2. Copy/refine them into both `/MAC/app` and `/WINDOWS/app`.
3. Ensure the UI looks and behaves consistently on both platforms.

## Notes / not-yet-built

* GitHub Actions deployment workflows and the per-platform "build steps" are
  referenced above but **not yet implemented** — set them up before relying on
  the Publish commands, or perform the package/push manually for now.
* Repo: https://github.com/Slasher1v/Manifest (default branch `main`).
