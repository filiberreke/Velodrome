# Vélodrome in Godot

## Starten vanuit broncode

1. Open `game/project.godot` in Godot Standard. Het project gebruikt Godot 4.7 met GL Compatibility. De Windows-build gebruikt 4.7.2.
2. Laat Godot de assets importeren en druk op F5 om de hoofdscene te starten.
3. Speel met het toetsenbord of start de [bridge](../bridge/README.md) om een trainer, Zwift Ride of hartslagsensor te gebruiken.

De [spelershandleiding](https://velodrome.wielerpraat.be/nl/handleiding/) beschrijft de bediening. Zie [configuratie en opslag](config/CONFIGURATION.txt) voor rennerprofielen, Strava en lokale gegevens.

## Testen en exporteren

Voer de opdrachten uit vanuit de repositoryroot, met Godot op je PATH.

```sh
godot --headless --editor --path game --import
godot --headless --path game --script res://tests/test_neutral_start.gd
godot --headless --path game --script res://tests/test_exit_pause.gd
```

De Windows- en macOS-workflows bouwen de downloadpakketten. Volg bij lokale export de import- en exportstappen in de workflow voor je platform. Daar staan ook de engine- en templateversies.

- [Windows-demo](../.github/workflows/windows-demo.yml) en [Windows met bridge](../.github/workflows/windows-bundled.yml)
- [macOS-export](../.github/workflows/build-macos.yml) en [macOS met bridge](../.github/workflows/macos-bundled.yml)
