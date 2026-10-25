# Velodrome 250 — beta.16.15 Peloton & Game Modes (testversie)

Gebaseerd op de werkende beta.16.14.3 met boost-hond, mooie piste en Strava-upload.

- Scratch: 6–12 renners, standaard 8, 1–30 ronden.
- Zeven wedstrijdmodi in keuzemenu: Scratch, Puntenkoers, Afvalling, Keirin, Achtervolging, Arcade, Ploegkoers. Alleen Scratch actief.
- Drie AI-profielen (TT, sprinter, aanvaller) en per race vaste vormfactor 95–105%.
- Dynamische arrays voor de AI, rondetijden, draft, finish en ranglijst.
- Eerste pelotonlogica bouwt verder op bestaande inhaal- en slipstreamfuncties; géén volledige botsingsvermijding.
- Grafische prestatie met 12 gerigde renners nog te testen.
- Geen bridge of persoonlijke strava_config.cfg; project.godot direct in de zip-root.

WAARSCHUWING: Statische codecontrole, geen succesvolle Godot-runtime-test. Dit is een grotere refactor; maak een backup van de vorige build.

## Eigen rennersnamen en profielen
- Kopieer `riders_config.example.cfg` naar `riders_config.cfg` naast `project.godot`.
- Vul per nummer `rider_01` tot `rider_11` een `name` en `profile` in. Geldige profielen: `tijdrijder`, `sprinter`, `aanvaller`.
- De lijst wordt ingelezen bij het starten van elke race; je hoeft de game niet opnieuw te installeren.
- Het persoonlijke `riders_config.cfg` staat bewust **niet** in de ZIP en wordt dus niet overschreven bij updates.
- Voor 8 deelnemers gebruikt de game de eerste 7 AI-namen. De naam van de speler beheer je onder Instellingen.


## beta.16.15.1 - Personalized jerseys
- In riders_config.cfg you can set number, jersey_color, jersey_secondary, shorts_color, helmet_color, jersey_design.
- jersey_design: solid, stripes/vertical, hoops/horizontal, diagonal, two_tone. Procedural texture uses the GLB's existing UV layout.
- Two temporary Label3D race number placards on rider backs; positioning will need visual confirmation and eventual bone-following UV decal.
- Personal configuration files are excluded from the ZIP; use riders_config.example.cfg as a template.
