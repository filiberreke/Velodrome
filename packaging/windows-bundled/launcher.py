"""One-click launcher; uses the existing validated Windows demo layout."""
import subprocess
import sys
from pathlib import Path

def main():
    root = Path(sys.executable).resolve().parent
    bridge = root / "bridge" / "VelodromeBridge.exe"
    game = root / "VelodromeGame.exe"
    init = root / "Initialize-Config.ps1"
    for path in (bridge, game, init):
        if not path.is_file():
            raise SystemExit(f"Missing packaged file: {path}")
    result = subprocess.run(["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(init)], cwd=root)
    if result.returncode:
        raise SystemExit("Could not initialize game configuration")
    worker = subprocess.Popen([str(bridge)], cwd=bridge.parent)
    try:
        return subprocess.call([str(game)], cwd=root)
    finally:
        if worker.poll() is None:
            worker.terminate()
            try:
                worker.wait(timeout=8)
            except subprocess.TimeoutExpired:
                worker.kill()
                worker.wait()

if __name__ == "__main__":
    sys.exit(main())
