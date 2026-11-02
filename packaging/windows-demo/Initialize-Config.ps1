$ErrorActionPreference = 'Stop'
$demoDirectory = $PSScriptRoot
# Godot's default user:// location for the application name in game/project.godot.
$userConfigDirectory = Join-Path $env:APPDATA 'Godot/app_userdata/Velodrome 250 - Sprint Beta/config'
foreach ($name in @('riders_config.cfg', 'strava_config.cfg')) {
    $target = Join-Path $demoDirectory "config/$name"
    # Match config_paths.gd precedence: do not mask a personal or legacy config.
    $existing = @(
        $target
        (Join-Path $demoDirectory $name)
        (Join-Path $userConfigDirectory $name)
    )
    if (@($existing | Where-Object { Test-Path -LiteralPath $_ }).Count -gt 0) {
        continue
    }
    New-Item -ItemType Directory -Path (Join-Path $demoDirectory 'config') -Force | Out-Null
    # overwrite=false also protects a config created since the existence check.
    [System.IO.File]::Copy((Join-Path $demoDirectory "defaults/$name"), $target, $false)
    Write-Host "Voorbeeld aangemaakt: config/$name"
}
