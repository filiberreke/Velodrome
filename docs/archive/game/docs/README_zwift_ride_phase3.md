# Zwift Ride — configureerbare knoppen (issue #33)

Open **Instellingen → Controller**. Kies Menu, Wedstrijd of Arcade, kies een
actie en het drukgedrag, en klik **Knop wijzigen**. Laat een reeds ingedrukte knop
eerst los, druk de nieuwe fysieke knop in en klik **Bevestigen**. De wijziging is
direct actief en wordt automatisch opgeslagen. De tabel toont de fysieke knop
en de actie in het gekozen profiel. De testindicatoren werken ook voor vrije
knoppen. Tijdens deze veilige test voert een knop geen wedstrijdactie uit.

Een discrete actie werkt bij indrukken of bij loslaten. Achteruitkijken werkt
altijd zolang de toegewezen knop wordt vastgehouden. Loslaten, instellingen
openen, een andere instellingentab, verbindingsverlies, een ontbrekende knop
in de bridge-heartbeat of twee seconden zonder controllersignaal beëindigt de
Ride-achteruitblik. Een gelijktijdige B-toets op het toetsenbord blijft werken.

Eén fysieke knop kan binnen één context maar één actie hebben. Bij een conflict
blijft de vorige mapping actief en verschijnt een melding. Gebruik **Vrijmaken**
op de bestaande actie voordat je de knop aan een andere actie toewijst. Gebruik
**Herstel context** of **Herstel alles** om de standaardbediening terug te zetten.
**Annuleren**, tabwissel en verbindingsverlies annuleren een lopende knopkeuze.
Z verlaat de test; tijdens een knopkeuze kan Z zelf worden vastgelegd.

Menu omvat instellingen, pauze, intro, resultaten en de wedstrijdkeuze. Wedstrijd
heeft een eigen profiel. Arcade heeft een bewaarbaar profiel voor toekomstige
acties; deze acties hebben nog geen spelgedrag. DROP_LEFT en DROP_RIGHT zijn
standaard vrij. Hun interne fysieke identiteit blijft POWER_LEFT/POWER_RIGHT.
Y blijft standaard rennersinformatie schakelen, ↑/↓ wisselen camera en B houdt
de achteruitblik vast. Analoge stuurpaddles behouden hun bestaande functie.
SHIFT-knoppen blijven in de bridge schakelen: een expliciete extra toewijzing
voegt een spelactie toe, en schakelt de trainerfunctie niet uit.

Godot bewaart versie 1 in `user://ride_button_mapping.json` (Windows:
`%APPDATA%/Godot/app_userdata/Velodrome 250 - Sprint Beta/`). Opslaan gebruikt een
tijdelijk bestand en hernoemen; bij een fout blijft de vorige actieve mapping staan.
Ongeldige of onbekende versies vallen terug op defaults met een melding en
blijven op schijf bewaard tot de speler een wijziging opslaat.

Zonder gebruikersprofiel importeert Godot `bridge/button_mapping.json` naast de
executable of naast de projectmap. Ontbrekende Z wordt behouden; oude SHIFT →
LEFT/RIGHT-aliases blijven trainerbediening. Als de bridge elders draait, worden
zijn `mapped_action`-hints nog gebruikt zolang er geen gebruikersprofiel is.
Na opslaan bepaalt Godot de actie uitsluitend aan de hand van fysieke identiteit
en context. Ruwe druk/loslaat-events zijn leidend; een legacy `button`-kopie van
dezelfde druk wordt onderdrukt. Oudere bridges met alleen `button`-berichten
blijven bruikbaar voor drukacties; vasthouden/loslaten vereist ruwe events.

## Tests

Stel `GODOT_BIN` in op Godot 4.7 en voer uit:

```powershell
python tests/run_ride_mapping.py
```

De runner kopieert het spel naar een tijdelijke testmap, zonder Blender-bronnen
en CSV-resultaten die alleen voor editor-import bedoeld zijn. GLB-modellen en
andere runtime-assets blijven intact. Iedere Godot-suite heeft eigen instellingen.
De UDP-integraties gebruiken vrije poorten en de echte virtuele bridge zonder
Bluetooth of trainer. Ze testen onder andere capture van DROP_LEFT, bevestigen,
vrijgave-acties en achteruitblik met een andere fysieke knop. De volledige
Python-bridge-suite en Phase 2-regressies draaien eveneens. Fysieke hardware
blijft een afzonderlijke acceptatietest.
