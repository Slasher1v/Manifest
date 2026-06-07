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
| 🍎 **Mac** | `/MAC` | macOS wrapper, split into `release/` (official) and `sandbox/` (test). |
| 🪟 **Windows** | `/WINDOWS` | Windows wrapper: `Install Manifest.bat`, `Manifest.bat`, `app/setup.ps1` (uses winget + `uv`). |

### Mac: release vs sandbox

* **`MAC/release/`** = the official, user-facing app. This is what gets packaged
  into GitHub Releases and what users download / auto-update. Runs on port **8000**.
  Its launcher auto-updates (git pull on `main` + a "new version" notice).
* **`MAC/sandbox/`** = our private test build. Runs on port **8001** (so it can run
  next to the release), does **not** auto-update, and is **never** packaged into a
  release. Do all Mac testing here.
* **Promotion (only when the user says so):** copy the tested files from
  `MAC/sandbox/` into `MAC/release/`, then publish. Never push changes straight to
  `release/` without the user's go-ahead.

**Golden rule for shared code:** edit UI/backend **only in `/DESIGN`**, then run
the **Design Changes** workflow to propagate into the platform `app/` folders.
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

### 1. Publish Mac Release  /  2. Publish Windows Release
Releases are automated. To publish (both platforms are packaged together):
1. Merge the current feature branch into `main` and `git push` origin `main`.
2. Bump the version by creating + pushing a tag, e.g. `git tag v1.1 && git push origin v1.1`.
3. The **Package & Release** GitHub Action (`.github/workflows/release.yml`) then
   packages `/MAC/release` → `Manifest-macOS.zip` and `/WINDOWS` →
   `Manifest-Windows.zip` and attaches both to the GitHub Release for that tag.
   (It can also be run manually from the Actions tab via *workflow_dispatch*.)

> Reminder: a Mac release should first be **promoted** from `MAC/sandbox` →
> `MAC/release` (with the user's approval) so the packaged code is the tested code.

### 3. Design Changes
1. Take the updated files from `/DESIGN` (`app.py`, `requirements.txt`, `templates/`).
2. Copy/refine them into the platform `app/` folders: `MAC/sandbox/app`,
   `MAC/release/app`, and `WINDOWS/app`. (Test in `MAC/sandbox` first.)
3. Ensure the UI looks and behaves consistently on both platforms.

## Notes

* Auto-release runs on pushing a `v*` tag (see workflow above). It activates once
  this branch is merged to `main`.
* Repo: https://github.com/Slasher1v/Manifest (default branch `main`).
