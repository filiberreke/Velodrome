# Combined Windows release (game + bridge)

## Start the bundled version

1. Download the **Velodrome-Bundled-Windows-x64** artifact from GitHub Actions.
2. Extract the entire ZIP to a writable folder.
3. Double-click **Velodrome.exe** in the extracted folder.

**Do not use `Start-Velodrome.cmd` for the bundled version.** That script belongs to the standalone Windows demo, where `Velodrome.exe` is the game itself. In the bundled version, `Velodrome.exe` is the launcher: it initializes the configuration, starts the bridge, launches the game and stops the bridge when the game closes.

Keep all extracted files and folders together, including the bridge, game executable, Godot PCK and configuration templates.

## Build in GitHub Actions

1. Ensure the existing **Windows demo build** workflow has a successful run with an available artifact.
2. Open **Windows bundled game and bridge** under Actions and choose **Run workflow**. **No run ID is needed**: the workflow automatically selects the latest successful demo run with an available `Velodrome-Demo-Windows-x64` artifact.
3. Download the resulting `Velodrome-Bundled-Windows-x64` artifact.

The existing `.github/workflows/windows-demo.yml` is unchanged. The bundled workflow reuses its exported game and adds a Python bridge and launcher.

**Testing status:** The bundled release has not yet been verified on Windows hardware. If the launcher does not start the game, report the contents of the extracted folder and any error message. FTMS resistance should be released before closing; terminating the bridge is not guaranteed to send an FTMS Reset. PyInstaller's ANT+ backend may require further adjustments.
