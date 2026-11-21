# Combined Windows release (game + bridge)

## Start the bundled version

1. Download the **Velodrome-Bundled-Windows-x64** artifact from GitHub Actions.
2. Extract the entire ZIP to a writable folder.
3. Double-click **Velodrome.exe** in the extracted folder.

**The bundled ZIP contains no `Start-Velodrome.cmd`.** It is deliberately excluded because it is only for the standalone Windows demo. In this bundled version, `Velodrome.exe` is the only start point: it initializes the configuration, starts the bridge, launches the game and stops the bridge when the game closes.

Keep all extracted files and folders together, including `VelodromeGame.exe`, its matching `VelodromeGame.pck`, the `bridge/` folder and configuration templates. Do not start `VelodromeGame.exe` directly.

## Build in GitHub Actions

1. Ensure the existing **Windows demo build** workflow has a successful run with an available artifact.
2. Open **Windows bundled game and bridge** under Actions and choose **Run workflow**. **No run ID is needed**: the workflow automatically selects the latest successful demo run with an available `Velodrome-Demo-Windows-x64` artifact.
3. Download the resulting `Velodrome-Bundled-Windows-x64` artifact.

The existing `.github/workflows/windows-demo.yml` is unchanged. The bundled workflow reuses its exported game and adds a Python bridge and launcher.

## Bridge runtime files

PyInstaller 6 stores the bridge's supporting files in `bridge/_internal/`.
The workflow includes every JSON file from the source `bridge/` directory using
`--add-data` with destination `.`. This places `gear_config.json`,
`simulation_config.json` and `button_mapping.json` beside the frozen modules,
where their `Path(__file__).with_name(...)` loaders expect them. Keep these
files in `_internal`; copies beside `VelodromeBridge.exe` are not used.

Before upload, the workflow checks that all three required configurations exist,
compares every bundled JSON file with its source, and runs
`bridge/VelodromeBridge.exe --check-config` from an unrelated working directory.
This loads the real gear, road simulation and button mapping configurations
without starting Bluetooth, ANT+, UDP listeners or the game.

The game still requires `VelodromeGame.exe`, `VelodromeGame.pck`,
`Initialize-Config.ps1` and the `defaults/` configuration templates. Python
dependencies are collected by PyInstaller; the legacy ANT+ `libusb0.dll` and
matching driver are machine prerequisites, not repository assets. Hardware
operation is not covered by the configuration check.

**Testing status:** The bundled release has not yet been verified on Windows hardware. If the launcher does not start the game, report the contents of the extracted folder and any error message. FTMS resistance should be released before closing; terminating the bridge is not guaranteed to send an FTMS Reset. PyInstaller's ANT+ backend may require further adjustments.
