# Menu's in ivoor, blauw en hout

De voor het logo gekozen stijl is vertaald naar native Godot-bediening: warme
ivoorkleurige panelen, donkerblauwe tekst, blauwe acties, lichte selectievelden
en een bescheiden houtkleurig accent. Het originele woordlogo is meegeleverd;
de spelbeelden gebruiken de bestaande 3D-renners en nationale tenues.

## Schermen

- Spelkeuze: vijf kolommen en twee rijen. Bovenaan Scratch, Achtervolging,
  Ploegenachtervolging, Puntenkoers en Afvalling. Onderaan Ploegkoers, Keirin,
  Tijdrit, Temporace en Records.
- Wedstrijdinstellingen voor Scratch, Puntenkoers en Afvalling.
- Afstands- en ploegkeuze, tegenstanderkeuze, rennerpaspoorten, overzicht en
  profielrecords van de AI-renners, en kaarten van opgeslagen prestaties.
- Persoonlijke top 10 met knoppen voor discipline en afstand; de ploegomvang
  verschijnt alleen bij ploegenachtervolging. Alle tien rijen passen tegelijk.
- Instellingen voor speler/uiterlijk, beeld en Strava.
- Uitslagpagina's, inclusief de tabellen van Puntenkoers en Ploegenachtervolging.

`menu_theme.gd` levert de gedeelde kleuren, lettertypen en bedieningsstijlen.
Het gebruikt systeembeschikbare Arial/Liberation Sans/DejaVu Sans en de normale
Godot-fontfallback; er is geen Windows-lettertype gekopieerd of vereist.
De interface blijft op de bestaande logische 1920×1080-weergave schalen.

## Gedrag

Tijdrit en Temporace zijn bewust nog niet speelbaar. Hun tegels tonen
**Binnenkort** en openen een informatiescherm met uitgeschakelde startknop,
net als de bestaande toekomstige disciplines Ploegkoers en Keirin.
Zowel de knop als de bestaande wedstrijdstartcontrole blokkeren een start.
Er zijn geen wedstrijdregels voor deze disciplines toegevoegd.

Klik op een discipline voor de instellingen, Escape/bridge-B gaat terug en
F10 opent de algemene instellingen. Achtervolging behoudt de twee stappen
voor afstand en tegenstander. Scratch, Puntenkoers en Afvalling openen nu
na de instellingen een bewerkbare startlijst vóór de bestaande intro/startcontrole.
Zie `README_menu_v2.md` voor de uitgebreidere testversie.
De visuele volgorde van de tegels staat los van de bestaande configuratie-indexen,
zodat de racekeuze en opgeslagen instellingen hetzelfde blijven werken.

Recordgegevens blijven echt en lokaal opgeslagen; de mockupgegevens zijn geen
onderdeel van het spel. Alleen het afzonderlijke capturescript maakt expliciete
voorbeeldrecords aan in een eigen testbestand.

## Controleren

Voer eerst een normale assetimport uit in Godot 4.7.2. De bronbestanden van
Blender zijn al in deze repository aanwezig; bij een volledig schone import
moet Godot een geldig Blender-programmapad hebben, zoals voorheen.

Belangrijke controles, uit te voeren vanuit de map `game`:

```powershell
Godot.exe --headless --path . --script res://tests/test_menu_theme.gd
Godot.exe --headless --path . --script res://tests/test_menu.gd
Godot.exe --headless --path . --script res://tests/test_elimination_menu_fix.gd
Godot.exe --headless --path . --script res://tests/test_pursuit_flow.gd
Godot.exe --headless --path . --script res://tests/test_records.gd
Godot.exe --headless --path . --script res://tests/test_rider_profiles.gd
Godot.exe --headless --path . --script res://tests/test_player_appearance.gd
Godot.exe --headless --path . --script res://tests/test_team_pursuit.gd
Godot.exe --headless --path . --script res://tests/test_points_race.gd
Godot.exe --headless --path . --script res://tests/test_broadcast_intro.gd
```

De nieuwe schermtest controleert tien tegels zonder overlap bij 720p, 900p,
1080p en 1440p, niet-startbare toekomstige disciplines, recordfilters en tien
zichtbare recordrijen. De bestaande tests controleren ook de echte muisstart
van Afvalling met 4/12/16 deelnemers en het doorgeven van tegenstanders.

`tests/capture_menu_theme.gd` maakt met de echte renderer zestien beelden in
`verification/menu_theme/`: spelkeuze, instellingen, toekomstige disciplines,
afstand/tegenstander, lege en gevulde records, de drie algemene instellingentabs
en een uitslag. Gebruik een aparte testomgeving: het script wisselt tijdelijk
van menu en maakt voorbeeldrecords in `user://menu_theme_capture_records.json`.

De controles gebruiken geïsoleerde gebruikersconfiguratie. Een fysieke trainer,
Bluetooth en een echte Strava-upload vallen buiten deze wijziging en zijn
niet met hardware of een extern account getest.

Uitgevoerd op 1 november 2026 met Godot 4.7.2: alle tien bovenstaande controles
geslaagd, plus een script-/assetimportcontrole en zestien gerenderde schermen.
De omgeving meldt een bestaande systeemcertificaatwaarschuwing; de headless
renderer meldt bij het opruimen van sommige 3D-portretten ook een lege materiaalreferentie.
De interactieve rendercontrole bevat geen script- of materiaalfouten.
