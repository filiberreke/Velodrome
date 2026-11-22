# Video browser proof-of-concept

Standalone experimental scene for Vélodrome. No 3D stadium, no ERG control, no changes to the normal start scene. Piste remains the default for all workouts.

## Run

1. Install a compatible **Godot WRY** release from https://github.com/doceazedo/godot_wry/releases into `game/addons/`. Native binaries are deliberately **not committed** to this branch.
2. Open `game/project.godot` with the project's Godot version (currently 4.7).
3. Open `res://video_poc/video_poc.tscn` and run the **current scene** (F6), not the main game (F5).
4. Paste an HTTPS URL (YouTube, Sporza, HBO Max, etc.) and click Open. Login/DRM/video compatibility is **not guaranteed**.

## Platform checks

- Windows: WebView2, test playback/audio, login, window resizing, native focus.
- macOS: WebKit, Intel and Apple Silicon, test video codecs and signing.
- Linux: WebKitGTK dependencies, X11 only for this extension; Wayland remains unresolved.
- All: confirm the webview stays **between** the address bar and the HUD, including resizing, fullscreen and DPI scaling.
- All: compare CPU/GPU/RAM against normal ERG piste mode; confirm playback, cookies, live streams, and DRM failures without circumvention.

WRY is a native overlay drawn above Godot. The HUD is positioned **outside** the WebView rectangle so it remains visible. This POC does not yet integrate the trainer, store URLs, measure performance or bundle native libraries. It is an integration scaffold, **not a validated working video player**.

WRY API: https://godot-wry.doce.sh/reference/webview.html
License: WRY Godot extension MIT; upstream https://github.com/doceazedo/godot_wry
