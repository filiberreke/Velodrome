# Wedstrijdcommissaris

Het spel gebruikt het door de gebruiker bijgewerkte `velodrome_official.glb` met 31 meshes en 21 botten, inclusief twee botten voor de schotflits en rook. Het aangeleverde GLB en Blenderbestand zijn ongewijzigd opgenomen.

## Model en bron

- Spelmodel: `game/assets/crowd/velodrome_official.glb`.
- Blenderbron: `game/assets/source_blender/official/velodrome_official.blend`.
- De bronmap is uitgesloten van automatische Godot-import.

Het haar heeft een expliciete donkerbruine basiskleur. De warme gezichtshuid en donkerbruine irissen gebruiken ingesloten texturen; de huid van armen en hals heeft een expliciete warme basiskleur. Godot extraheert de vier texturen naast het model. De oude huidskleuroverschrijving is verwijderd, zodat het spel de aangeleverde materialen gebruikt.

## Animaties

- `VO_StartReady`: herhaalt de opgeheven pistoolpose met een kleine ademhalingsbeweging, zonder schotflits of rook.
- `VO_StartFire`: afzonderlijke niet-herhalende schietanimatie met terugslag en geanimeerde flits/rook.
- `VO_LastLapBell`: herhalende belanimatie.
- `VO_FinishFlag`: herhalende finishvlaganimatie.

De spelcode gebruikt deze exacte namen en regelt welke accessoires zichtbaar zijn. Het GLB bevat alle accessoires; buiten de spelcode moet een viewer dezelfde zichtbaarheid instellen. De schotflits en rook worden daarnaast door de twee FX-botten geschaald.

De bestaande timing blijft behouden: ready op 60 m voor de start, schot op 5 m; voor staande starts ready in de laatste tel en schieten bij `RACING`. De bel begint 50 m voor de laatste-rondepassage en stopt na de laatste renner. De finishvlag krijgt voorrang vanaf 100 m voor de finish en stopt wanneer iedereen binnen is.

## Verificatie

Blenderbestand en GLB gecontroleerd op vier afzonderlijke Actions/clips en de 21-bottenrig. De GLB-accessors, indices, animatietijden en skinweights zijn geldig. Iris- en gezichtstexturen zijn aanwezig in het GLB. Haar en irissen zijn bruin; huid heeft de warme aangeleverde kleur.

Getest in Godot 4.7.2: import, materiaalweergave, ready zonder schoteffecten, schot met effecten, overgang ready naar schot, beltiming, finishprioriteit, stoppen na de laatste renner en reset voor de volgende wedstrijd. De volledige wedstrijd is niet interactief doorgespeeld.

Herhaal de gedragstest vanuit het Godot-project met `--headless --script res://tests/test_official_ready.gd`.
