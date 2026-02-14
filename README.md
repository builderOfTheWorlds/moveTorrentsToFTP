# moveTorrentsToFTP

Watches a local directory for `.torrent` files and automatically uploads them to a remote FTP server. Designed to run as a Windows service using NSSM.

## Prerequisites

- Windows 10/11
- Python 3.10+
- Network access to the FTP server

## Quick Deploy

1. Clone the repo:
   ```
   git clone <repo-url>
   cd moveTorrentsToFTP
   ```

2. Run the installer as Administrator:
   ```powershell
   powershell -ExecutionPolicy Bypass -File installer.ps1
   ```

3. The installer will:
   - Create a Python virtual environment
   - Install dependencies
   - Prompt you for FTP credentials and watch directory
   - Register and start a Windows service

## Manual Setup

If you prefer not to use the installer:

```powershell
python -m venv .venv
.venv\Scripts\pip install -r requirements.txt
copy .env.example .env
# Edit .env with your settings
.venv\Scripts\python main.py
```

## Configuration

All settings are stored in a `.env` file in the project root:

| Variable       | Description                          | Default                        |
|----------------|--------------------------------------|--------------------------------|
| `FTP_USERNAME` | FTP server username                  | *(required)*                   |
| `FTP_PASSWORD` | FTP server password                  | *(required)*                   |
| `FTP_LOCALIP`  | FTP server IP address                | *(required)*                   |
| `FTP_DEST_DIR` | Remote directory to upload into      | `/opt/qbittorrent/loadDir/`    |
| `WATCH_DIR`    | Local directory to watch for torrents| `C:/Users/<you>/Downloads`     |

## Service Management

The service is managed via NSSM (bundled in `utilities/`):

```powershell
# Start
nssm start moveTorrentsToFTP

# Stop
nssm stop moveTorrentsToFTP

# Restart
nssm restart moveTorrentsToFTP

# Remove
nssm remove moveTorrentsToFTP confirm
```

## How It Works

1. A file system observer watches `WATCH_DIR` for new `.torrent` files
2. New files are queued for processing
3. A worker thread waits for the file to finish writing, then uploads it via FTP
4. Successfully transferred files are renamed with a `.done` suffix
5. Failed transfers are retried up to 5 times

## Logs

- `file_transfer.log` — application log (created in the project directory)
- `service_stdout.log` / `service_stderr.log` — service output (when running via NSSM)
