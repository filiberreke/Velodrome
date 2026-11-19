#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
godot=${GODOT_BIN:-godot}
output=${1:-"$repo_dir/website/assets/img/mode-previews"}
mkdir -p -- "$output"
output=$(cd -- "$output" && pwd)

project_dir=$(mktemp -d)
trap 'rm -rf -- "$project_dir"' EXIT
# Imports can rewrite Godot's tracked sidecars. Keep the import cache and edits temporary.
tar -C "$repo_dir/game" --exclude='./.godot' -cf - . | tar -C "$project_dir" -xf -
# The previews load the shipped GLBs. Skip the Blender authoring files during import.
printf '\n[filesystem]\n\nimport/blender/enabled=false\n' >> "$project_dir/project.godot"
"$godot" --headless --path "$project_dir" --import
# The virtual X11 display keeps the real OpenGL renderer available without a desktop.
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s '-screen 0 800x600x24' \
    "$godot" --path "$project_dir" --display-driver x11 \
    --rendering-method gl_compatibility --audio-driver Dummy --resolution 640x420 \
    --fixed-fps 60 --disable-render-loop --disable-vsync \
    --script res://tools/export_mode_previews.gd -- "$output"
