# Vrouwelijk rennersmodel — uiterlijk en configuratie

Bron: `velodrome_renster_v3.zip` (MANIFEST.md), gekoppeld aan issue #65.

> Status: documentatie van het aangeleverde model. De implementatie van automatische modelselectie op `category=women` en het toevoegen van de binaire assets moeten afzonderlijk worden gecontroleerd; dit document betekent niet dat de integratie al voltooid is.

## Per-renner configuratie

In `riders_config.cfg`, onder de sectie van de betreffende renner:

```ini
[rider_01]
category="women"
hair_style="ponytail"
hair_color="kastanjebruin"
```

`category="women"` moet bij de integratie het vrouwelijke model selecteren. `category="men"` en een ontbrekende categorie moeten het bestaande mannelijke model blijven gebruiken.

De oorspronkelijke ZIP-patch gebruikt nog `sex="female"` in plaats van `category="women"`. De patch moet daarom bij integratie worden aangepast. Tot die aanpassing is uitgevoerd, is bovenstaande configuratie nog niet gegarandeerd werkend.

## Kapsels

| Waarde | Betekenis |
| --- | --- |
| `low_bun` | Lage knot; standaardwaarde |
| `ponytail` | Paardenstaart |
| `short` | Kort haar |

In het GLB zijn de kapsels afzonderlijke meshes: `Hair_low_bun`, `Hair_ponytail` en `Hair_short`. Slechts één wordt getoond.

## Haarkleuren

De aangeleverde documentatie noemt: `blond`, `lichtbruin`, `kastanjebruin`, `donkerbruin`, `zwart`, `rood`, `grijs` en een eigen hexkleur zoals `"#7a5230"`. Controleer bij integratie de exacte sleutels in `HAIR_COLORS` van `rider_visual.gd`, omdat die de werkelijk geaccepteerde namen bepalen.

```ini
hair_style="low_bun"
hair_color="#7a5230"
```

Een lege haarstijlinstelling gebruikt `low_bun`; een lege haarkleur laat de standaardkleur van het GLB behouden.

## Tijdens het spel

De ZIP-patch voorziet `set_hair_style("short")` en `set_hair_color("#7a5230")` op `rider_visual.gd`. Die functies zijn pas beschikbaar nadat de patch is geïntegreerd.

## Lichaamsbouw en outfits

Het model behoudt de bestaande shape keys `ShoulderWidth`, `TorsoMass`, `HipWidth`, `ThighMass`, `CalfMass` en `ArmMass`. Voor vrouwelijke profielpresets worden schouder- en armwaarden met 0,7 geschaald, maar expliciete `shoulder_width`- en `arm_mass`-configuratiewaarden niet.

Het model deelt de UV-atlas met het mannelijke model. Nationale outfits en PNG-projecties moeten nog visueel op voor-, achter- en zijkant worden gecontroleerd.

## Bekende beperkingen

- Nog geen afzonderlijk vrouwelijk achtervolgingsmodel; de ZIP-patch valt in pursuit-modus terug op het bestaande model.
- Geen keuzemogelijkheid man/vrouw in de speler-uiterlijk-UI.
- De Blender/Cycles-renders zijn gecontroleerd; de weergave in de game zelf nog niet.
- Bronbestand: `game/assets/source_blender/velodrome_rider_female_rig.blend`; export: `game/assets/riders/velodrome_rider_female.glb`.
