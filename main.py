import os
import logging
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import ftplib
import urllib.parse

# Configure logging
logging.basicConfig(filename='file_transfer.log', level=logging.DEBUG,
                    format='%(asctime)s - %(levelname)s - %(message)s')


class MyHandler(FileSystemEventHandler):
    def on_created(self, event):
        if not event.is_directory:
            # New file is created, check if it has ".torrent" extension
            filename = event.src_path
            if filename.endswith('.torrent'):
                # Call function to move file to FTP
                success = move_to_ftp(filename)
                if success:
                    logging.info(f"File transferred successfully: {filename}")
                    print(f"File transferred successfully: {filename}")
                else:
                    logging.error(f"File transfer failed: {filename}")
                    print(f"File transfer failed with error code: {filename}")
            else:
                logging.warning(f"Ignoring file with non-torrent extension: {filename}")


def move_to_ftp(filename):
    ftp_password = os.getenv('FTP_PASSWORD')
    ftp_username = os.getenv('FTP_USERNAME')
    ftp_localip = os.getenv('FTP_LOCALIP')

    if ftp_password and ftp_username and ftp_localip:
        try:
            ftp = ftplib.FTP(ftp_localip, ftp_username, ftp_password)

            # Encode the filename before transfer
            encoded_filename = urllib.parse.quote(os.path.basename(filename))

            with open(filename, 'rb') as file:
                # Change the destination directory to "/opt/qbittorrent/loadDir"
                dest_dir = "/opt/qbittorrent/loadDir/"
                ftp.storbinary('STOR ' + dest_dir + encoded_filename, file)

            # Rename the file by appending ".done" after successful transfer
            os.rename(filename, filename + ".done")

            ftp.quit()
            return True
        except Exception as e:
            logging.error(f"Error transferring file: {filename} - {e}")
            print(f"Error transferring file: {filename} - {e}")
            return False
    else:
        logging.error("FTP credentials not found in environment variables.")
        print("FTP credentials not found in environment variables.")
        return False


if __name__ == "__main__":
    event_handler = MyHandler()
    observer = Observer()
    observer.schedule(event_handler, path='C:/Users/matt/Downloads', recursive=True)
    observer.start()

    try:
        while True:
            pass
    except KeyboardInterrupt:
        observer.stop()

    observer.join()