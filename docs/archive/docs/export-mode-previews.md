# Wedstrijd- en trainingspreviews exporteren

Gebruik op Linux Godot 4.7.2 Standard, Xvfb, `xauth` en Mesa met GLX en llvmpipe. Voer dit uit vanaf de hoofdmap van de checkout.

```sh
bash tools/export-mode-previews.sh
```

Met `GODOT_BIN=/absoluut/pad/naar/godot` kies je een Godot-binary buiten `PATH`. Geef desgewenst een uitvoermap mee als eerste argument. Standaard komen de PNG’s in `website/assets/img/mode-previews/`.

Het script importeert een tijdelijke kopie van het Godot-project en rendert `mode_preview.gd` met OpenGL Compatibility op een virtueel X11-scherm. Godot gebruikt `--headless` voor de import. Xvfb houdt de 3D-renderer beschikbaar voor de export op een machine zonder grafische sessie.

De uitvoer bestaat uit twaalf PNG’s van 640 × 420. Toernooien en Neem een ronde gebruiken de Scratch-preview. Aflossingstraining gebruikt de Madison-preview, zoals in het spelmenu.

De websitegenerator leest de PNG’s rechtstreeks uit `website/assets/img/mode-previews/`. De koppelingen met de Nederlandse en Engelse tegels staan in `tools/website/content.py`. Draai na wijzigingen aan die koppelingen de generator met Python 3.10 of nieuwer en Pillow.

```sh
python tools/website/build.py --in-place
```

Gebruik `--output <map>` voor een aparte kopie van de site en een zelfstandig previewbestand.
