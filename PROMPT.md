# Original Prompt — Deploy-Ready Setup

> Date: 2026-02-14

## User Request

I need to update this project so I can push to git and deploy on another machine. We will need:
- A README file with instructions on how to deploy on a new machine
- An `installer.ps1` script that will do any installation steps necessary to deploy this

## Planning Decisions

During planning, the following choices were made:

- **Watch path**: Make configurable via `WATCH_DIR` env var (was hardcoded to `C:/Users/matt/Downloads`)
- **FTP destination**: Make configurable via `FTP_DEST_DIR` env var (was hardcoded to `/opt/qbittorrent/loadDir/`)
- **Windows service**: `installer.ps1` registers the script as a service using bundled NSSM
- **Gitignore**: Added `.gitignore` to exclude `.venv/`, `.idea/`, `*.log`, `.env`

## Files Created/Modified

| File              | Action   | Purpose                                         |
|-------------------|----------|-------------------------------------------------|
| `.gitignore`      | Created  | Exclude venv, IDE files, logs, secrets from git |
| `requirements.txt`| Created  | Pin Python dependencies                         |
| `.env.example`    | Created  | Template for environment configuration          |
| `main.py`         | Modified | Load `.env`, use configurable paths             |
| `installer.ps1`   | Created  | Automated deployment script                     |
| `README.md`       | Created  | Deployment and usage instructions               |
| `PROMPT.md`       | Created  | This file — records the original prompt         |
