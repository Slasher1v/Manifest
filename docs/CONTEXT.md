# Manifest — Project Context / Status

> Quick orientation for any new session (e.g. on a different machine). Pair this
> with `CLAUDE.md` (the rules/roles) — together they carry continuity across
> computers, since chat history and local memory do NOT sync between machines.

## What Manifest is
A personal, self-hosted video downloader. Shared Python/Flask backend + single-page
UI, wrapped per platform. Repo: https://github.com/Slasher1v/Manifest

## Where things stand (2026-06)
- **Published:** `v1.0` on `main` — the **flat, macOS-only** layout (the original
  package). This is what the public Release currently contains.
- **This branch (`setup/multiplatform`, NOT yet merged to main):**
  - Restructured into `MAC/`, `WINDOWS/`, `DESIGN/` + `CLAUDE.md` master brain.
  - `DESIGN/` = source of truth (app.py, requirements.txt, templates/); synced into platform `app/` folders.
  - GitHub Actions release workflow (`.github/workflows/release.yml`): push a `v*`
    tag → auto-packages MAC + WINDOWS zips and attaches to the Release.

## Platform status
- **Mac 🍎 — PROVEN.** Downloads YouTube up to 4K. Stack: `uv`-provisioned
  self-contained Python + `deno` (nsig solver) + `bgutil` PO-token server on
  `:4416` + Chrome cookies. Wrapper = `MAC/Install Manifest.command` + `Manifest.command` + `app/setup.sh`.
- **Windows 🪟 — DRAFT, UNTESTED.** `WINDOWS/Install Manifest.bat` + `Manifest.bat`
  + `app/setup.ps1` (winget + uv). Authored on macOS; needs real-Windows testing.

## Key technical learnings (don't re-derive)
- YouTube needs ALL of: current `yt-dlp` (requires **Python ≥ 3.10**), **deno** for
  the nsig "n-challenge", a **PO token** (bgutil on :4416), and **browser cookies**.
  Missing any → 403 or "only images". It was NEVER an ISP/CDN block.
- `uv venv --python 3.13 --python-preference only-managed --seed` gives a
  self-contained Python, dodging broken system/Homebrew Python (a friend hit a
  libexpat/pyexpat symbol crash; uv fixed it).
- `app.py` is already cross-platform (pathlib + `shutil.which`); only wrappers differ.

## Suggested next steps
1. On the PC: test the Windows wrapper (`WINDOWS/`), fix what breaks.
2. (Optional) Add a `windows-latest` CI job that runs `setup.ps1` + smoke-tests,
   plus a `.gitattributes` for correct CRLF/LF line endings.
3. When a platform is finalized: merge the feature branch → `main`, then
   `git tag vX.Y && git push origin vX.Y` to auto-publish the Release.

## Workflow rules (from CLAUDE.md)
Always work on a feature **branch**; never commit to `main` until the user says
"deploy". Custom commands: Publish Mac Release, Publish Windows Release, Design Changes.
