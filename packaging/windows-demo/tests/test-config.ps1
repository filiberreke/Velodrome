$ErrorActionPreference = 'Stop'
$source = Split-Path $PSScriptRoot
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('velodrome-demo-config-' + [guid]::NewGuid())
$originalAppData = $env:APPDATA
New-Item -ItemType Directory -Path $testRoot | Out-Null
function Assert($condition, $message) {
    if (-not $condition) { throw $message }
}
function New-Case($name) {
    $directory = Join-Path $testRoot "$name/demo [with spaces]"
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $source 'Initialize-Config.ps1') -Destination $directory
    Copy-Item -LiteralPath (Join-Path $source 'defaults') -Destination $directory -Recurse
    $env:APPDATA = Join-Path $testRoot "$name/appdata"
    return $directory
}
function Run-Initializer($directory) {
    & (Join-Path $directory 'Initialize-Config.ps1')
}
try {
    $demo = New-Case 'fresh'
    Run-Initializer $demo
    foreach ($name in @('riders_config.cfg', 'strava_config.cfg')) {
        Assert ((Get-FileHash -LiteralPath "$demo/config/$name").Hash -eq
                (Get-FileHash -LiteralPath "$demo/defaults/$name").Hash) "Wrong fresh config: $name"
    }
    # User edits and empty user files are both preserved on subsequent starts.
    [IO.File]::WriteAllText("$demo/config/riders_config.cfg", 'personal riders')
    [IO.File]::WriteAllText("$demo/config/strava_config.cfg", '')
    Run-Initializer $demo
    Assert ([IO.File]::ReadAllText("$demo/config/riders_config.cfg") -eq 'personal riders') 'Riders overwritten'
    Assert ((Get-Item -LiteralPath "$demo/config/strava_config.cfg").Length -eq 0) 'Empty config overwritten'

    $demo = New-Case 'legacy'
    [IO.File]::WriteAllText("$demo/riders_config.cfg", 'legacy riders')
    [IO.File]::WriteAllText("$demo/strava_config.cfg", 'legacy credentials')
    Run-Initializer $demo
    Assert (-not (Test-Path -LiteralPath "$demo/config")) 'Legacy config masked'
    Assert ([IO.File]::ReadAllText("$demo/riders_config.cfg") -eq 'legacy riders') 'Legacy riders changed'
    Assert ([IO.File]::ReadAllText("$demo/strava_config.cfg") -eq 'legacy credentials') 'Legacy Strava changed'

    $demo = New-Case 'user-data'
    $userConfig = Join-Path $env:APPDATA 'Godot/app_userdata/Velodrome 250 - Sprint Beta/config'
    New-Item -ItemType Directory -Path $userConfig -Force | Out-Null
    foreach ($name in @('riders_config.cfg', 'strava_config.cfg', 'strava_tokens.cfg')) {
        [IO.File]::WriteAllText("$userConfig/$name", "personal $name")
    }
    Run-Initializer $demo
    Assert (-not (Test-Path -LiteralPath "$demo/config")) 'User data config masked'
    foreach ($name in @('riders_config.cfg', 'strava_config.cfg', 'strava_tokens.cfg')) {
        Assert ([IO.File]::ReadAllText("$userConfig/$name") -eq "personal $name") "User data changed: $name"
    }

    $demo = New-Case 'mixed'
    [IO.File]::WriteAllText("$demo/riders_config.cfg", 'legacy riders')
    Run-Initializer $demo
    Assert (-not (Test-Path -LiteralPath "$demo/config/riders_config.cfg")) 'Legacy riders masked'
    Assert (Test-Path -LiteralPath "$demo/config/strava_config.cfg") 'Missing Strava not initialized'
    Write-Host 'PASS: fresh install, repeated start, empty config, legacy config, user data/tokens, mixed config, paths with spaces/brackets'
} finally {
    $env:APPDATA = $originalAppData
    # This unique temporary test directory is owned entirely by this test.
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolved.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path $resolved -Leaf) -like 'velodrome-demo-config-*') {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
