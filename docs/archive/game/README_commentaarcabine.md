# EuroMax Cycling commentaarcabine

Een commentaarcabine van de zender **EuroMax Cycling**, met twee commentatoren die frontaal in beeld kunnen komen voor een aankondiging. Het logo heeft dezelfde kleuren en stijl als het EuroMax Sport-voorbeeld: blauw, een gele sterrenboog en een rood blok, maar met "Cycling" in plaats van "Sport".

## Bestanden

| bestand | inhoud |
|---|---|
| `assets/commentary/euromax_commentary_booth.glb` | cabine (statisch, ~9k driehoeken) + aparte node `BoothGlass` |
| `assets/commentary/commentator_links.glb` | commentator met bril: skelet, 7 blend shapes, `idle` / `talk` |
| `assets/commentary/commentator_rechts.glb` | commentator met kuif en polo: zelfde rig |
| `assets/commentary/commentary_booth.tscn` | alles samen + key/fill-licht + `AnnouncementCamera` |
| `assets/commentary/commentator.gd` | knipperen, lipsync op audio of procedureel praten, idle/talk-wissel |
| `assets/commentary/commentary_booth.gd` | `announce("links"/"rechts"/"duo", stream)`, cameraposities, glas aan/uit |
| `assets/commentary/commentary_booth_rig.blend` | bewerkbare versie (cabine + beide rigs, acties als NLA-tracks) |
| `assets/commentary/textures/` | logo-paneel, polo/fietsjesprint, monitorbeeld |
| `assets/source_blender/crowd/build_commentary_booth.py` | genereert alles opnieuw |
| `assets/source_blender/crowd/face_sdf.py`, `hero_head.py` | semi-realistische hoofden (signed distance fields → mesh, alleen numpy) |
| `assets/source_blender/crowd/make_euromax_textures.py` | logo/textures opnieuw maken (Pillow + Inter ExtraBold Italic) |
| `tests/test_commentary_booth.gd` | importtest; verwacht `COMMENTARY_BOOTH_OK` |

Coördinaten: de oorsprong ligt in het midden van de cabinevloer, de voorkant (pistezijde) is **+Z**, en de cabine is 3,9 m breed. De presentatoren staan op (±0,52, 0,08, 0,22). De onderkant van de frontpanelen hangt 1,05 m onder de vloer, zodat je de cabine op een tribunerand kunt zetten.

## Gebruik in Godot

```gdscript
var booth = preload("res://assets/commentary/commentary_booth.tscn").instantiate()
add_child(booth)
booth.announce("rechts", preload("res://audio/aankondiging.ogg"))  # camera + lipsync
booth.announce("duo")                                              # zonder audio: 4 s procedureel praten
booth.glass_visible = false                                        # zuiverder frontaal shot
```

- **Blend shapes:** `open`, `wide`, `round`, `smile`, `blink_L`, `blink_R`, `brow_up`. De rechtse heeft een rustlach (`rest_smile = 0.85`, `rest_open = 0.16` in de scène).
- **Lipsync:** de mond volgt het piekvolume van `voice_bus`. Zet stemopnames op een eigen bus (bv. "Commentary") en vul die in op beide commentatoren.
- **Animaties:** Godot haalt de achtervoegsels `_loop` weg. De namen worden dus `idle` en `talk`, en het script vangt dat op.
- **Huid en haar:** de details (lippen, stoppels, hoofdhuid, lichte punten in het haar) zitten in vertexkleuren (`COLOR_0` × basiskleur). Het script zet `vertex_color_use_as_albedo` aan als de import dat niet doet.

## Opnieuw genereren

```
python assets/source_blender/crowd/make_euromax_textures.py assets/commentary/textures   # optioneel
blender --background --python assets/source_blender/crowd/build_commentary_booth.py
```

De hoofden worden als isosurface gemaakt en daarna gedecimeerd. Dat duurt ongeveer 1 tot 2 minuten per persoon. Gezichtskenmerken stel je in via `CHARS[...]["head"]["sdf"]` in `build_commentary_booth.py`:

- `W`, `face_w`, `face_len`, `cheeks`, `jaw_w`, `chin`
- `nose_len`, `nose_w`, `nose_tip`
- `lips`, `mouth_w`, `ears`

Kleuren staan in `CHARS[...]["colors"]`.

## Getest

- Gebouwd met Blender 5.2.3 (bpy).
- Godot 4.7.2: headless import en `test_commentary_booth.gd` geslaagd. Blend shapes, animaties, skelet, vertexkleur op de huid en een bewegende mond tijdens het praten zijn gecontroleerd.
- Captures gemaakt met de Compatibility-renderer onder een virtueel scherm (llvmpipe).

Niet getest: de Forward+-renderer, het effect op je eigen GPU en de plaatsing in `main.tscn`.

## Beperkingen

- De gezichten zijn **procedurele karikaturen** van de twee echte personen, geen scan. Voor een echte gelijkenis kun je een hoofd uit foto's maken (bv. KeenTools FaceBuilder) en dat op dezelfde rig zetten. De lichamen hebben nog de bouw van de publieksstijl.
- Zware hero-assets: links ~49k en rechts ~72k driehoeken (de kuif is ~24k). Gebruik ze alleen voor close-ups, of verlaag `skin_tris`/`hair_tris`.
- Het merklogo op de polo van de echte persoon is bewust weggelaten. De polo heeft enkel de crèmekleur en de groen/witte kraag en mouwboorden.
