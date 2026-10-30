# Velodrome-tifo v2 — stadionleesbaarheid

Gebouwd op `main` commit `46eb765281409cf42e0bcb671b46ad8272cd06e1`.

De oude SVG bouwde het woordmerk op met twee losse live tekstobjecten en een
apart getekende o. Fontfallback en de handmatige plaatsing konden de letters
verschuiven. De slogan, illustratie en het grote beige vlak concurreerden met
het logo. De UV-richting spiegelde bovendien het doek vanuit het middenterrein;
de grote overspanning rekte het woordmerk uit. Het noordelijke scorebord stond
vlak vóór de tifo en sneed als een donkere streep door de letters.

## Ontwerp en integratie

- Donkerblauw `#10264b`, groot wit woordmerk, cyaan slagschaduw en de gouden
  piste-o van de echte boarding. Geen nationale kleuraccenten, slogan of extra
  illustraties. De lettervormen en onderlinge posities zijn overgenomen uit
  `assets/boarding/velodrome-boarding.png`; de lichte boarding bevestigt dezelfde
  logo-stijl. De bestaande fijne details zijn vereenvoudigd voor afstand.
- `assets/branding/velodrome_tifo.svg` bevat uitsluitend vaste vormen/paden,
  zonder tekst, fontreferenties of ingesloten rasterbeelden. Blender/Godot
  hoeven geen letters te zetten. `velodrome_tifo_v2.png` is rechtstreeks uit
  die SVG gebakken op **4096 × 1024**; Godot gebruikt uitsluitend deze PNG.
- Het doek beslaat s=10–46 m, binnen de eerste bocht, boven de eerste twee
  tribuneniveaus. De breedte past nu bij de textureverhouding. De UV-x-as is
  omgekeerd voor de leesrichting vanuit het middenterrein. Een extra 1,2 m
  vrije hoogte houdt doek en drukwerk boven publiek/balustrade.
- Het scorebord met zijn ondoorzichtige achterplaat staat nu aan de andere
  bocht (z=+71), zodat het de eerste-bochttifo niet meer afdekt.
- Lossless texture-import, geen verkleining of automatische VRAM-compressie,
  mipmaps aan en anisotrope trilineaire filtering met uitgeschakelde herhaling.
  Het matte, tweezijdige doek houdt via een unshaded materiaal zijn kleur in
  de schaduw; brede plooischakering varieert slechts 6%. Geen lichtgevende lamp.
- Rustige basisplooien van 3,5 cm en maximaal 2,5 cm extra beweging aan de rand
  tijdens de onthulling; het midden beweegt minder. Tijdens de laatste 24 m
  van ronde één trekt het doek van boven naar beneden weg, zakt het maximaal
  1,5 m en krijgt het meer beweging. Tijdens de onthulling blijft het materiaal
  in de ondoorzichtige depth-pipeline om sorteerfouten te vermijden.
- De intro toont rond 13 s het hele doek vanuit het middenterrein en richt
  van 11–16 s vloeiend naar de tifo. De overige route en startprocedure blijven
  aangesloten via de bestaande Hermite-interpolatie.

## Visuele controle

Werkelijke Godot 4.7.2 GL Compatibility-opnamen, 1920 × 1080, MSAA 4×:

| Opname | Bevinding |
| --- | --- |
| [Intro op 13 s](verification/tifo_v2/intro_13.jpg) | Volledig woordmerk binnen beeld, groot en direct herkenbaar. |
| [Brede stadioncamera](verification/tifo_v2/stadium.jpg) | Ook bij groter stadionoverzicht blijven alle letters herkenbaar. |
| [Eerste bocht](verification/tifo_v2/first_bend.jpg) | Correcte leesrichting, geen scorebord of balustrade door het logo. |
| [Verdwijnen](verification/tifo_v2/withdrawal.jpg) | Extra vervorming uitsluitend tijdens het terugtrekken. |

De accent-e, piste-o en de aansluiting op `me` blijven op hun vaste positie.
Er zijn geen afzonderlijk gezette letters meer die kunnen verschuiven.
Vanaf de latere lage, passerende intro-camera (16 s en verder) is het doek
schuiner of buiten beeld; het volledige leesmoment is bewust eerder voorzien.
De resultaten hierboven zijn visueel gecontroleerd op de opnamen, geen OCR-score.

## Opnieuw bouwen en controleren

Vanuit `game/`:

```text
python assets/source_blender/build_tifo_v2.py
godot --headless --path . --script res://tests/bake_tifo_v2.gd
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/test_tifo_v2.gd
godot --headless --path . --script res://tests/test_broadcast_intro.gd
godot --path . --rendering-method gl_compatibility --script res://tests/capture_tifo_v2.gd
```

Python-bron vereist Pillow en numpy. De PNG-bake gebruikt Godots SVG-renderer;
de runtime heeft deze Python-pakketten niet nodig.

Geslaagd: `TIFO_V2_BAKE_OK`, `TIFO_V2_TESTS_OK`, `BROADCAST_INTRO_OK` en
`TIFO_V2_CAPTURE_OK`. Tests controleren onder meer padbron, texturegrootte,
werkelijke mipmaps, UV-leesrichting, strakke onthulling, verdwijnen/herstart en
behoud van de bevroren race tijdens de intro. De bestaande introtest controleert
ook routecontinuïteit, disciplines, overslaan en de trainer-startpoort.

Logs staan in `verification/tifo_v2/`. De lokale sandbox meldt een onbeschikbare
Windows-certificaatstore en soms een bezette UDP-poort; die meldingen betreffen
de omgeving en hebben het renderen of de assertions niet verhinderd.
