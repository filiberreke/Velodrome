# Combined Windows release (additional workflow)

The existing `.github/workflows/windows-demo.yml` remains **unchanged**. It already handles Godot 4.7.2, Blender source isolation, asset import, export, config templates, and Windows smoke tests.

1. Run the existing **Windows demo build** workflow successfully.
2. Note that workflow run's numeric GitHub Actions run ID.
3. Run **Windows bundled game and bridge** from Actions on this branch, supplying `demo_run_id`.
4. Download the `Velodrome-Bundled-Windows-x64` artifact.

The new workflow consumes the **validated** `Velodrome-Demo-Windows-x64` artifact; it never rebuilds or changes the standalone game. It renames the game EXE inside its own temporary release folder to `VelodromeGame.exe`, retaining the original `Velodrome.pck`, configuration templates and initialization script. It then packages the Python bridge and a top-level `Velodrome.exe` launcher.

Users start one `Velodrome.exe` but must retain the entire extracted folder. The launcher initializes config using the existing script, starts the bridge, runs the game, and terminates the bridge when the game exits. Godot and bridge remain separate processes communicating via existing UDP ports.

**Not yet hardware-tested.** Force-terminating a bridge is not a guaranteed FTMS Reset; release active resistance before closing. PyInstaller's ANT+ backend may need adjustments after a Windows hardware test. The source demo run and bundled workflow should use compatible commits; no automatic provenance check is implemented.
