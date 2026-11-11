# Aflossingstraining op v0.2

Deze feature is gebouwd op `v0.2`, uitgangscommit
`b2dac77`, als afzonderlijke **Pistetraining → Aflossingstraining**.
De bestaande hub, ERG-workouts, FTP-test, vrije training, dernytraining,
vliegende start, Neem een ronde, trainingshistoriek en wedstrijden blijven
behouden. De wedstrijdtegel **Ploegkoers** blijft onbeschikbaar; deze feature
voegt geen wedstrijdtactiek, ploegklassement of ploegpunten toe.

## Sessies en bediening

- Kies **10 of 20 aflossingspogingen**, Easy of Advanced.
- Easy: A grijpt, automatisch slingeren en loslaten, maximaal 70% momentum.
- Advanced: A grijpen, vasthouden en loslaten. Maximaal 100%, na de piek minder.
- Advanced blijft grijs tot een volledige Easy-sessie minstens 7/10 of 14/20
  geslaagde aflossingen heeft. Dit wordt bewaard in
  `user://config/madison_progress.cfg`. Een geldige release met positieve
  momentumoverdracht is geslaagd; gemiste kansen tellen eenmaal als mislukking.
- ←/→, D of de stuurpaddles kiezen de rijlijn. A is in deze training de greep,
  niet links sturen. C/cameraknoppen en B voor achteromkijken blijven beschikbaar.
- De slider staat onder de wattagebalk. Zijn positie bevriest bij grijpen;
  daarna volgt de breedte de beschikbare overdracht.

## Positionering, feedback en score

Gedurende de hele training markeert een gele strook op de gebankte piste de
aanbevolen rijlijn, ook tussen pogingen en tijdens de aflossing. Uitgaand (speler geeft) ligt die aan de binnenkant, inkomend (speler
ontvangt) bij de blauwe lijn. De ontvanger mag ook één lijn binnen de blauwe lijn
rijden. De zone bestaat alleen in deze training. Voor de toekomstige wedstrijdmodus
Ploegkoers is het de bedoeling deze hulp pas tijdens de laatste 50 m te tonen.
De speler houdt altijd stuurcontrole.

Het HUD toont uitgaand (snelle gever): **Volg de gele lijn. Rij maximaal
55 km/u**. Boven deze grens blokkeert de controller het grijpen en verbreekt hij
een reeds begonnen greep. `giver_max_kmh` maakt de grens instelbaar.

Inkomend (ontvanger): **Volg de gele lijn en rij minstens XX km/u**.
De controller berekent dit minimum uit de snelheid van de snelle gever min het
snelheidsverschil dat binnen het handbereik en de beschikbare contactversnelling
kan worden afgebouwd. Het minimum wordt naar boven afgerond op 0,1 km/u; exact
dezelfde waarde wordt getoond en bij de greep gecontroleerd. Snellere gever =
hoger minimum voor de ontvanger. De ontvanger moet wel trager blijven dan de
gever, zodat die kan bijsluiten. Er is geen afzonderlijke 50-km/u-limiet voor
de ontvanger. Meldingen en resultaattabel vermelden de gemeten snelheid en grens.

Bij verkeerde volgorde,
verkeerde ontvangerslijn, te kleine of te grote zijafstand verdwijnt de slider en
verschijnt **Aflossen niet mogelijk wegens slechte positionering**, met een
concrete reden. De groene timingzone is vanaf het begin van de zichtbare slider aanwezig,
zodat de speler de naderende marker op het doel kan timen. De melding A: grijpen
verschijnt zodra de controller de greep accepteert. De controller controleert ook of het snelheidsverschil
binnen handbereik kan worden afgebouwd; een onhoudbare greep wordt geweigerd.

Iedere afgeronde poging toont vijf seconden feedback met rol, scorepercentage
en resultaat/redengeving. De vaardigheidsscore is in beide modi op 100:
perfect Easy = 100/100 en maximaal 70% momentum, perfect Advanced = 100/100 en
maximaal 100% momentum. Een mislukking scoort 0. De rollen wisselen ook na een
mislukte poging, zodat beide rollen aan bod komen.

Nieuwe pogingen bewaren ook `player_role` (`giver` of `receiver`), zodat de
rol ondubbelzinnig blijft. Eerder bewaarde activiteiten met omgekeerde Nederlandse
benamingen worden bij het tonen gecorrigeerd.

De activiteit bewaart `exchanges`: per poging het volgnummer, `role`, `success`,
`reason`, `score` (0–100) en `momentum_percent`. Na afloop en bij heropenen via de
historiek staat er een scrollbare tabel met één rij per poging. Oude activiteiten
zonder deze velden blijven gewoon leesbaar.

## Eén kans per spelersronde

De eerste kans wordt bij de start klaargezet. Bij elke volgende gereden
spelersronde van 250 m verschijnt een nieuwe ploegmaat op circa 10 m
naderingsafstand: vóór de speler als ontvanger, achter de speler als gever.
De speler wordt daarvoor nooit verplaatst en behoudt stuurcontrole.

Na de aflossing/mislukte poging verdwijnt de AI na SEPARATE. Bij de volgende
spelersronde wordt het model op de nieuwe naderingspositie hergebruikt.
In-/uitfaden duurt 0,3 s en blokkeert de volgende ronde niet. De AI hoeft
zelf geen ronde te rijden en er is geen extra respawnwachttijd.
Een niet ingehaalde kans mag een volgende spelersronde niet blokkeren.
De spawn mag zichtbaar zijn; voorspelbaar gericht oefenen heeft hier voorrang.

## Aansluiting op de trainingsarchitectuur

`madison_training_environment.gd` hergebruikt de rustige v0.2-trainingsomgeving,
SIM-client, meetuitvalafhandeling, camera's, opname en lokale trainingsopslag.
Hij heeft twee eigen rennermodellen en eigen afstands-, snelheids- en
rijlijnarrays. `game.race_mode`, wedstrijdarrays, deelnemers en ronde-instellingen
worden niet veranderd. Er is geen wedstrijdintro, startcontrole, podium of
wedstrijd-HUD. Na stoppen/verlaten komt de gebruiker terug bij Pistetraining;
de bestaande trainingsomgeving herstelt het menu en de wedstrijdomgeving.

Beide renners volgen dezelfde spelersuitrusting, inclusief standaardpalet,
skinsuit, helm, vizier en opdrukken. De lichaamsbouw kan verschillen.
Een outfitwijziging wordt op beide modellen toegepast.
De activiteit wordt via de bestaande `training_store.gd` opgeslagen met score,
gekozen lengte en moeilijkheid; de historiek opent opnieuw de trainingspagina.

`madison_exchange.gd` bewaakt APPROACH, GRAB, SLING, RELEASE en SEPARATE.
`madison_animation.gd` stuurt alleen de twee deelnemers via de geleverde clips,
bovenlichaamfilter en hand-IK. Trapfase en gameplay-overdracht blijven onafhankelijk
van de animatiebibliotheek. De gever gebruikt rechts, de ontvanger links.
Bij dreigende overstrekking volgt gecontroleerd loslaten. Na afloop worden
AnimationTree, IK en tijdelijke libraries verwijderd en modeloffsets hersteld.

De zelfstandige Blender/Godot-demo blijft onder `game/madison/` beschikbaar.
Zijn `MadisonDemoExchange` is een afzonderlijke demonstratie, geen tweede
controller van de training. Zie `docs/madison/` voor rig en bronmetingen.
De eenvoudige wanten zonder vingeranimatie blijven een assetbeperking.

## Validatie

Gebruik Godot 4.7.2 na de normale import:

```text
python game/tests/run_v02_headless.py --godot PAD/NAAR/Godot.exe test_madison_feedback test_madison_v02_training test_madison_progress test_madison test_free_training test_derny_training test_piste_exercises test_training_environment test_v02_menu test_training_signal_pause test_ftp_ramp test_workout_library test_workout_editor_ui
```

De Madison-integratietest controleert plaatsing in de hub, vergrendeling,
score en resultaat, outfit, invoer, behoud van wedstrijdstaat, trainingshistoriek,
despawn/respawn per spelersronde en het ontbreken van teleportatie van de speler.
De bestaande vijf assettests (clips, contact, release, flow en baseline)
valideren de geleverde animaties en de oorspronkelijke trapanimaties.
Het bestaande testharnas benoemt Windows-certificaat- en dummy-rendererdiagnostiek
apart; die komen ook op de ongewijzigde v0.2-code voor.

`capture_madison_v02.gd` maakt beelden in `verification/madison_v02/`.
