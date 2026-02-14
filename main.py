import os
import logging
import threading
import time
from pathlib import Path
from queue import Queue, Empty
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import ftplib
import urllib.parse
from dotenv import load_dotenv

# Load .env file from the same directory as this script
load_dotenv(Path(__file__).resolve().parent / ".env")

# Configure logging
log_path = Path(__file__).resolve().parent / "file_transfer.log"
logging.basicConfig(filename=str(log_path), level=logging.DEBUG,
                    format='%(asctime)s - %(levelname)s - %(message)s')

# Configuration
FILE_READY_DELAY = 1.0  # Seconds to wait before processing a file
MAX_RETRIES = 5  # Maximum retry attempts for failed transfers
RETRY_DELAY = 2.0  # Seconds between retries
WORKER_POLL_TIMEOUT = 1.0  # Seconds to wait when queue is empty

# Global queue for file processing
file_queue = Queue()
shutdown_event = threading.Event()


class FTPWorker(threading.Thread):
    """Worker thread that processes files from the queue sequentially."""

    def __init__(self):
        super().__init__(daemon=True)
        self.ftp = None

    def connect_ftp(self):
        """Establish FTP connection, reusing if possible."""
        ftp_password = os.getenv('FTP_PASSWORD')
        ftp_username = os.getenv('FTP_USERNAME')
        ftp_localip = os.getenv('FTP_LOCALIP')

        if not all([ftp_password, ftp_username, ftp_localip]):
            logging.error("FTP credentials not found in environment variables.")
            return False

        try:
            if self.ftp:
                # Check if connection is still alive
                self.ftp.voidcmd("NOOP")
            else:
                self.ftp = ftplib.FTP(ftp_localip, ftp_username, ftp_password)
                logging.info("FTP connection established.")
            return True
        except Exception:
            # Connection lost or not established, reconnect
            try:
                self.ftp = ftplib.FTP(ftp_localip, ftp_username, ftp_password)
                logging.info("FTP connection re-established.")
                return True
            except Exception as e:
                logging.error(f"Failed to connect to FTP: {e}")
                self.ftp = None
                return False

    def wait_for_file_ready(self, filename):
        """Wait for file to be fully written by checking if size stabilizes."""
        try:
            previous_size = -1
            for _ in range(10):  # Max 10 checks
                if not os.path.exists(filename):
                    return False
                current_size = os.path.getsize(filename)
                if current_size == previous_size and current_size > 0:
                    return True
                previous_size = current_size
                time.sleep(FILE_READY_DELAY)
            return os.path.exists(filename) and os.path.getsize(filename) > 0
        except Exception:
            return False

    def transfer_file(self, filename):
        """Transfer a single file to FTP with retry logic."""
        for attempt in range(1, MAX_RETRIES + 1):
            if shutdown_event.is_set():
                return False

            if not self.connect_ftp():
                time.sleep(RETRY_DELAY)
                continue

            try:
                encoded_filename = urllib.parse.quote(os.path.basename(filename))
                dest_dir = os.getenv('FTP_DEST_DIR', '/opt/qbittorrent/loadDir/')

                with open(filename, 'rb') as file:
                    self.ftp.storbinary('STOR ' + dest_dir + encoded_filename, file)

                os.rename(filename, filename + ".done")
                return True

            except Exception as e:
                logging.warning(f"Attempt {attempt}/{MAX_RETRIES} failed for {filename}: {e}")
                self.ftp = None  # Force reconnection on next attempt
                if attempt < MAX_RETRIES:
                    time.sleep(RETRY_DELAY)

        return False

    def run(self):
        """Main worker loop - process files from queue."""
        logging.info("FTP Worker thread started.")

        while not shutdown_event.is_set():
            try:
                filename = file_queue.get(timeout=WORKER_POLL_TIMEOUT)
            except Empty:
                continue

            logging.info(f"Processing file from queue: {filename}")

            # Wait for file to be ready
            if not self.wait_for_file_ready(filename):
                logging.error(f"File not ready or doesn't exist: {filename}")
                file_queue.task_done()
                continue

            # Transfer the file
            if self.transfer_file(filename):
                logging.info(f"File transferred successfully: {filename}")
                print(f"File transferred successfully: {filename}")
            else:
                logging.error(f"File transfer failed after {MAX_RETRIES} attempts: {filename}")
                print(f"File transfer failed: {filename}")

            file_queue.task_done()

        # Clean up FTP connection
        if self.ftp:
            try:
                self.ftp.quit()
            except Exception:
                pass
        logging.info("FTP Worker thread stopped.")


class MyHandler(FileSystemEventHandler):
    def on_created(self, event):
        if not event.is_directory:
            filename = event.src_path
            if filename.endswith('.torrent'):
                logging.info(f"Queuing file for transfer: {filename}")
                file_queue.put(filename)
            else:
                logging.warning(f"Ignoring file with non-torrent extension: {filename}")


if __name__ == "__main__":
    # Start the FTP worker thread
    worker = FTPWorker()
    worker.start()
    logging.info("FTP Worker started.")

    # Setup file system observer
    event_handler = MyHandler()
    observer = Observer()
    watch_dir = os.getenv('WATCH_DIR', 'C:/Users/matt/Downloads')
    observer.schedule(event_handler, path=watch_dir, recursive=True)
    observer.start()
    logging.info(f"File observer started, watching {watch_dir} for .torrent files.")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        logging.info("Shutdown requested...")
        print("Shutting down...")

        # Signal worker to stop
        shutdown_event.set()

        # Stop the observer
        observer.stop()

        # Wait for queue to be processed (with timeout)
        logging.info("Waiting for pending transfers to complete...")
        file_queue.join()

        # Wait for worker thread to finish
        worker.join(timeout=5.0)

    observer.join()
    logging.info("Shutdown complete.")