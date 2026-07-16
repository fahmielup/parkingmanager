import os
import sys
import time
import socket
import subprocess
from pathlib import Path

BASE_DIR = Path(__file__).parent
APP_PATH = BASE_DIR / 'app.py'
LOCK_FILE = BASE_DIR / '.keep_alive.lock'
PYTHON_EXE = sys.executable
PORT = int(os.environ.get('PORT', '5001'))


def log(msg):
    now = time.strftime('%Y-%m-%d %H:%M:%S')
    print(f'[{now}] {msg}', flush=True)


def is_port_responsive(port):
    """Check if something is already listening on the port and responds."""
    try:
        with socket.create_connection(('127.0.0.1', port), timeout=3):
            return True
    except (OSError, socket.timeout):
        return False


def acquire_lock():
    """Ensure only one keep_alive instance runs."""
    if LOCK_FILE.exists():
        try:
            old_pid = int(LOCK_FILE.read_text().strip())
            try:
                os.kill(old_pid, 0)
                log(f'Another keep_alive is already running (PID {old_pid}). Exiting.')
                return False
            except OSError:
                log(f'Stale lock from PID {old_pid}. Taking over.')
        except (ValueError, FileNotFoundError):
            pass
    LOCK_FILE.write_text(str(os.getpid()))
    return True


def release_lock():
    try:
        LOCK_FILE.unlink()
    except FileNotFoundError:
        pass


def kill_existing_on_port(port):
    """Kill any process currently listening on the target port."""
    try:
        import psutil
        for conn in psutil.net_connections(kind='inet'):
            if conn.laddr.port == port and conn.pid:
                try:
                    p = psutil.Process(conn.pid)
                    log(f'Killing process {conn.pid} ({p.name()}) on port {port}')
                    p.terminate()
                    p.wait(timeout=5)
                except Exception:
                    try:
                        p.kill()
                    except Exception:
                        pass
    except ImportError:
        log('psutil not installed; skipping port cleanup')


def run_app():
    """Start the Flask application and return the process."""
    env = os.environ.copy()
    env['PORT'] = str(PORT)
    log(f'Starting {APP_PATH} on port {PORT}')
    return subprocess.Popen(
        [PYTHON_EXE, str(APP_PATH)],
        cwd=str(BASE_DIR),
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        creationflags=subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS
    )


def main():
    if not acquire_lock():
        sys.exit(0)
    log('Parking Manager keep-alive monitor started')
    try:
        while True:
            if is_port_responsive(PORT):
                log(f'Port {PORT} already responsive. Monitoring.')
                time.sleep(30)
                continue
            log(f'Port {PORT} not responsive. Starting server...')
            kill_existing_on_port(PORT)
            time.sleep(2)
            proc = run_app()
            log(f'Server started (PID {proc.pid}). Waiting for it to come up...')
            for _ in range(15):
                time.sleep(2)
                if is_port_responsive(PORT):
                    log('Server is responsive. Monitoring.')
                    break
            else:
                log('Server failed to become responsive. Retrying in 10 seconds...')
                time.sleep(10)
    except KeyboardInterrupt:
        log('Interrupted by user; shutting down')
    finally:
        release_lock()


if __name__ == '__main__':
    main()
