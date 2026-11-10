# Training en hoofdmenu v0.2

Branch `v0.2` is gestart vanaf stabiele `main`, commit
`c6b6ae4d4afe8acd1b96c1e12d0f32e232222be1`. Wedstrijden behoudt de bestaande
spelvormen, instellingen en wedstrijdengine. Training bevat de FTP Ramp Test.
Toernooien heeft voorlopig een eigen scherm met een melding dat dit later volgt.

## Trainingsverloop

- Start direct naast de eigen ploegtent aan de westelijke rechte lijn, ook als
  je al fietst. Geen intro, journalisten, stilstandcontrole, wedstrijdcountdown,
  start aan de finishlijn, tegenstanders of podium.
- Vijf minuten **vrij opwarmen**. De test verstuurt geen ERG-, SIM- of
  hellingscommando tijdens de opwarming. De bestaande bridge-SIM en de twaalf
  virtuele versnellingen blijven beschikbaar. De bridge moet dus zoals normaal
  in SIM staan; een andere actieve controllersessie wordt niet overgenomen.
- Het scherm toont gemeten vermogen, versnelling, een aftelklok tot de ramp en
  een vrijblijvend richtvermogen van ongeveer 80–120 W. Dit is geen persoonlijk
  voorgeschreven vermogen: rustig en comfortabel opwarmen staat voorop.
- Na 5 minuten vraagt de client via het bestaande protocol ERG en 100 W aan.
  De rampklok start pas wanneer `confirmed_target_w`, `revision` en
  `applied_revision` de toepassing van 100 W bevestigen. Een UDP-ACK op zichzelf
  volstaat niet. Vervolgens iedere 60 seconden +20 W, maximaal 1300 W.
- Alleen de speler rijdt rond op basis van de bestaande gemeten trainersnelheid.
  De tribunes en het binnenplein zijn leeg. Alleen één eigen ploegtent, een trainer
  aan de baan en een toekijkende mecanicien blijven zichtbaar. Tent en kleding
  gebruiken de bestaande spelerslandkleuren indien bekend, anders ploegblauw.
  De bestaande menubediening blijft beschikbaar; schakelpaddles bedienen tijdens
  training uitsluitend de bridge, ook bij een aangepaste knoppenmapping.
- Stop toont de reden, beste gemeten minuutvermogen en geschatte FTP. De rustige
  trainingsomgeving blijft staan bij het resultaat. Terug naar Training herstelt
  de menuomgeving; een volgende wedstrijd krijgt zijn bestaande aankleding terug.

## Vermogensberekening en gegevens

FTP = **0,75 × het hoogste voortschrijdende 60-secondenvermogen** tijdens de
ramp. Opwarmmetingen zijn uitgesloten. De berekening integreert het werkelijke
gemeten vermogen over tijd, waarbij een meting geldt tot de volgende verse
meting. Onregelmatige intervallen krijgen hun werkelijke duur als gewicht;
doelvermogen en aantal ontvangen UDP-pakketten bepalen het resultaat niet.
Ook een gedeeltelijke laatste stap telt mee. Extrema tussen twee metingen
worden meegenomen op venstergrenzen die 60 seconden na eerdere metingen liggen.
De meetgeschiedenis is begrensd tot het lopende venster. Zonder een volledige,
aaneengesloten minuut rampmetingen verschijnt geen FTP.

De bestaande commandosocket blijft localhost UDP **51725**, met `status`,
`set_mode`, `set_target_power`, `heartbeat`, IDs en bestaande retries/lease.
Telemetrie blijft localhost UDP **51723**. Er zijn twee optionele velden aan
de daadwerkelijk geïmplementeerde bridge-zender toegevoegd, zonder bestaande
velden of wedstrijdconsumenten te wijzigen:

- `power_sample_id`: loopt alleen op bij een FTMS-melding mét vermogen.
  Het bestaande `sample_id` blijft iedere FTMS-melding tellen.
- `power_age_s`: monotone ouderdom van de laatste echte vermogensmeting,
  of `null` als die ontbreekt.

De FTP-test vereist de bijgewerkte bridge. Een oude bridge blijft voor de
bestaande wedstrijden bruikbaar maar kan deze test niet starten. De test weigert
verouderd vermogen, ongeldige waarden en teruglopende meetnummers. Herhaalde
UDP-pakketten en meldingen met alleen cadans/snelheid vernieuwen geen meting.
De lokale meettijd wordt gecorrigeerd met `power_age_s`.

## Stoppen en uitval

- Ongeldig vermogen, meetuitval of een meetinterval langer dan **1,25 s** stopt
  de test. Er wordt geen gemeten vermogen bij verzonnen en geen automatische
  herstart gedaan na herstel. Cadans is optioneel en ontbrekende cadans is geen nul.
- Iedere nieuwe rampstap heeft 10 s gewenning. Daarna stopt de test na 10 s
  aaneengesloten onder 85% van het doel, of na 5 s met cadans onder 40 rpm én
  vermogen onder 90% van het doel. Herstel boven de grens wist die teller.
- Geen ERG-bevestiging binnen 8 s, geen bridgeantwoord gedurende 3 s in de ramp,
  een bridgefout of overname door een andere controller stopt de sessie.
- Stop, terug, sluiten en uitval gebruiken `set_target_power` met `watts=0`
  voor de eigen bediening: dit betekent FTMS Reset/vrijgave, geen actief 0-W-doel.
  Een late ACK op een oud positief doel kan een gestopte training niet heractiveren.
  De client blijft vrijgave-antwoorden, retries en status verwerken nadat het
  trainingsscherm verborgen is. Een geaccepteerde Reset is pas een bevestigde
  vrijgave zodra de bridge `release_confirmed=true` meldt.
- Een nieuwe poging vereist verse metingen en bevestigde vrijgave, of verse
  status die een vrije SIM-sessie bevestigt als geen ERG-belasting actief is.
  De client blijft na blokkering status vragen, maar hervat niet vanzelf. Bij proces-
  of pakketverlies blijft de bestaande bridgelease van 5 s de terugval, naast
  de bestaande bridgebewaking van trainer- en vermogensfeedback (3 s).

## Controles

Gebruik Godot 4.7.2 na de gewone assetimport, en Python voor de bridge:

```text
python -m unittest discover -s bridge/tests -v
Godot --headless --path game --script res://tests/test_ftp_ramp.gd
Godot --headless --path game --script res://tests/test_v02_menu.gd
Godot --headless --path game --script res://tests/test_training_environment.gd
Godot --headless --path game --script res://tests/test_trainer_control.gd
Godot --headless --path game --script res://tests/test_bridge_protocol.gd
Godot --headless --path game --script res://tests/test_menu.gd
Godot --headless --path game --script res://tests/test_ride_mapping_routing.gd
Godot --headless --path game --script res://tests/test_ride_pursuit_navigation.gd
```

De tests gebruiken vrije lokale poorten en gesimuleerde hardware. Nieuwe tests
dekken de tijdgewogen berekening, gedeeltelijke stappen, meetuitval, echte
power-versus-cadansmeldingen, ERG-ACK/bevestiging, veilige vrijgave, vrij
schakelen, menuovergangen en herstel van de wedstrijdaankleding. Twee bestaande
menutests zijn bijgewerkt voor het nieuwe hogere menu; de oude menutest behandelde
de inmiddels bestaande tijdrit nog ten onrechte als niet speelbaar.

## Resterende hardwaretests op Zwift Ride/KICKR

1. Start al fietsend bij de ploegtent; controleer lege tribunes, leeg binnenplein,
   twee begeleiders, camera, eigen uitrusting en afwezigheid van intro/startcontrole.
2. Warm 5 minuten vrij op, schakel links/rechts en controleer de aftelklok en het
   gemeten vermogen. Controleer de overgang naar 100 W en verdere stappen van 20 W.
3. Controleer de werkelijk gevoelde ERG-respons en de tijd tot hardwarebevestiging.
4. Rijd een echte test tot vermoeidheid; beoordeel de grenzen voor ondervermogen
   en lage cadans en vergelijk de beste minuut met een onafhankelijke opname.
5. Test Stop, Terug, venster sluiten, Bluetoothverlies, verdwijnen van alleen
   powerfeedback, bridge-uitval en procesverlies; verifieer fysiek dat belasting
   wordt vrijgegeven en bij herstel geen oud ERG-doel terugkomt.
6. Start daarna opnieuw een training en een bestaande wedstrijd. Controleer
   vrijgave, bediening door een andere app, herstel na een bridgeherstart en
   terugkeer van alle normale wedstrijddecors en publiek.

Dit is een FTP-schatting. Er zijn nog geen fysieke hardwaretests uitgevoerd.


## Hoofdmenu en workout-editor

Het hoofdmenu heeft vier tegels: bovenaan Wedstrijden en Toernooien, onderaan
ERG-training en Pistetraining. ERG-training heeft een workoutgrafiek als miniatuur.
Pistetraining bevat vaste sessies zonder ZWO-import of -export.
De tegels gebruiken het bestaande ivoren/blauwe menuthema en de bestaande baanbeelden.
Toernooien behoudt zijn pagina met de melding dat deze functie later wordt toegevoegd.

De workout-editor heeft links de bouwstenen, in het midden één klikbare grafiek
en rechts de eigenschappen van het geselecteerde blok. Links/Rechts verplaatst
het geselecteerde blok in de tijdlijn. Dupliceren maakt een onafhankelijke kopie;
Verwijderen werkt ook tot een lege workout. Korte blokken blijven aanklikbaar via
een minimale breedte en horizontaal scrollen. De intervallen tonen inspanning en herstel.
Bewerken van duur of vermogen behoudt de veldfocus en een nog niet bewaard tekstbericht.
De controllerknop B keert vanuit de editor terug naar Training.

ZWO-export gebruikt geldige Godot-getalopmaak; import leest XML-tekst zonder
foutmeldingen. Zoals in de bestaande trainingslezer worden geïmporteerde intervallen
uitgevouwen naar afzonderlijke inspannings- en herstelblokken.

Extra controle:

```text
Godot --headless --path game --script res://tests/test_workout_editor_ui.gd
```

Deze controle test echte muisklikken op de grafiek, selectie, bewerken met behoud
van focus, volgorde, dupliceren, verwijderen, ZWO-import/export en de schermindeling.
Met `-- --capture` zonder `--headless` worden ook schermafbeeldingen gemaakt.


## Dernytraining (Pistetraining)

- Instelbare startsnelheid van 10–60 km/u (standaard 30), gevolgd door één
  geholpen aanloopronde van 250 m.
  Je blijft in het wiel, onafhankelijk van het gemeten vermogen: niet inhalen
  of lossen tijdens deze aanloop. De meetgegevens zelf blijven ongewijzigd.
- Daarna de gekozen gemiddelde rondesnelheid; elke 60 seconden +1 km/u, zonder snelheidsplafond.
- De piloot geeft één duim omhoog bij het begin van het eerste tempoblok en kondigt
  de volgende stappen één keer aan, 1,5 seconde vóór de minuutgrens.
- Bij elke nieuwe stap verschijnt de snelheid drie seconden centraal in beeld,
  via dezelfde `race_popup.gd` als de wedstrijdmeldingen.
- Achteromkijken gebeurt ongeveer elke 16 s, bij meer dan 5 m afstand elke 5 s.
  Een snelheidssignaal heeft voorrang. De platte-handanimatie wordt niet gebruikt.
- Direct achter de derny maximaal 60% minder luchtweerstand (normaal maximaal 69%).
  De beschutting neemt af met afstand en zijwaartse afwijking; naast of vóór de
  derny is ze nul. In het wiel begrenst het spel de snelheid bij een volgafstand van circa 2,8 m.
  Bij te dicht volgen verschijnt een waarschuwing om minder vermogen te leveren.
  Bewust minimaal twee rijlijnen opzij sturen maakt inhalen mogelijk, met volledige
  luchtweerstand.
  Dit zijn instelbare spelwaarden, geen claim van een gemeten aerodynamisch model.
- Meer dan 15 m achterstand gedurende 5 s beëindigt het tempo-deel; opnieuw
  aansluiten wist de teller. Resultaat: hoogste voltooide minuut en volgtijd.
- Vermogen bepaalt de virtuele snelheid via een krachtenmodel, met de bestaande
  pistegeometrie en hoogte-effecten. Het tempo wordt niet aan de speler vastgeklikt.
- Een echte trainer gebruikt de bestaande SIM-client, inclusief routehelling en
  `aero_scale` waar ondersteund. Zonder die mogelijkheid blijft de virtuele wake
  werken, maar kan de trainer de lagere luchtweerstand niet voelbaar overnemen;
  het scherm meldt dit. Er wordt geen ERG-belasting gebruikt.
- Verse gevalideerde vermogensmetingen zijn vereist zodra een trainer bekend is.
  Meetuitval, een bedieningsfout of een ontbrekend bridgeantwoord stopt de sessie
  en geeft eigen trainerbediening vrij. Escape/Z stopt en opent het resultaat.
  B blijft de wedstrijdknop voor achteromkijken; de cameraknoppen gebruiken
  hetzelfde profiel en dezelfde camera-opstelling als wedstrijden. C wisselt
  de camera op het toetsenbord, V/Y wisselt de naamlabels.
- Zonder aangesloten trainer is een expliciet gemarkeerde PC-proefrit beschikbaar:
  met A/D sturen en omhoog/omlaag het proefvermogen aanpassen. Links/rechts
  roept HOW/ALLEZ voor een tempowijziging. Fysieke
  versnellingsknoppen blijven versnellingsknoppen en kunnen de training niet stoppen.

Het aangeleverde `derny_pilot.glb` staat in `game/assets/derny/`, met de vier
originele `DP_Derny*`-animaties. De `.blend` en de bouwscripts blijven de
bronbestanden van de gebruiker; de game heeft alleen het GLB-bestand nodig.

Controles in Godot 4.7.2:

```text
Godot --headless --path game --script res://tests/test_derny_session.gd
Godot --headless --path game --script res://tests/test_derny_training.gd
```

De eerste test controleert tempo, minuutgrenzen, gebaren, beschutting en lossen.
De tweede controleert het echte model, toetsenbord/controller, traineruitval,
terugkeer naar het menu en behoud van de bestaande wedstrijdomgeving. Met
`-- --capture` zonder `--headless` maakt hij beelden in `.test-user/derny-captures`.
De fysieke gevoelssterkte op een KICKR/Zwift Ride moet nog op hardware worden getoetst.


## HUD, grafiek, archief en Strava

Tijdens de dernytraining vervangt een afgeleide van de bestaande wedstrijd-HUD
het oude tekstkader. De vermogensbalk bovenaan wisselt van kleur met het geleverde vermogen,
zoals in de wedstrijd-HUD. Er staat geen richtvermogen of doelpijltje meer.
De werkelijke trainerhelling en de zwaartekracht in de rennersfysica blijven actief.
Snelheid, hartslag, cadans, versnelling en de horizontale slipstreambalk staan in
het bekende wedstrijdpaneel. Ontbrekende sensormetingen blijven zichtbaar als onbekend.

Onderaan toont een semitransparante grafiek de volledige tijdlijn van snelheid,
geleverd vermogen, hartslag en cadans. De vier kleuren hebben elk een expliciet
vermelde schaal en eenheid; de horizontale as is de verstreken trainingstijd.
Onbekende waarden worden niet als nul getekend.

Elke gestarte training krijgt een JSON-bestand in `user://training_sessions`, met
een begincheckpoint, een update ongeveer iedere tien seconden en een definitieve
opslag bij stoppen, lossen, meetuitval, teruggaan of normaal afsluiten. Een abrupte
procesuitval kan het laatste checkpoint herstellen; de laatste tien seconden
kunnen dan ontbreken. De bestanden bevatten de echte beschikbare sensormetingen,
virtuele snelheid/afstand, de automatisch geholpen aanlooptijd en het resultaat.
PC-proefritten zijn als simulatie gemarkeerd. Bij een schrijffout meldt het
resultaatscherm dat de opslag is mislukt.

Onder Pistetraining → Opgeslagen trainingen kun je eerdere sessies openen, de
grafiek bekijken en alsnog voor Strava kiezen. De knop Opslaan op Strava bouwt
een FIT-bestand uit precies die sessie en gebruikt de bestaande Strava-client en
koppeling. Er wordt niets automatisch geüpload. De activiteit is virtueel, zonder
verzonnen GPS-route; de beschrijving vermeldt de geholpen aanloop en simulatiedata
bij een PC-proefrit. Werkelijke sensormetingen worden niet door dernysnelheid of
richtvermogen vervangen.

De regressiecontrole `test_training_store.gd` dekt checkpoints, herladen,
FIT-opbouw, ontbrekende sensoren en de richtvermogensberekening. De uitgebreide
`test_derny_training.gd` controleert ook vast aansluiten bij 0 W, begrenzen bij
hoog vermogen, bewust inhalen, de wedstrijdcamera's, de HUD, meetreeksen,
automatisch bewaren en de Strava-overdracht via een testclient zonder netwerk.


## Vermogen, snelheid en rijlijn van de derny

De startsnelheid wordt vóór elke start gekozen. Aanloop, tempoblokken, centrale
de aftelklok, resultaten, trainingsarchief en Strava-beschrijving gebruiken die keuze.
Oudere opgeslagen trainingen zonder startsnelheidsveld blijven als 30 km/u zichtbaar.

De derny wordt niet op een vaste snelheid vastgezet. Hij krijgt per tempoblok
een vast aandrijfvermogen en gebruikt hetzelfde krachtenmodel en dezelfde
hellingsinvloed als de renner. Daardoor vertraagt hij bergop en versnelt hij
bergaf. Het vermogen wordt vooraf afgestemd op de gewenste gemiddelde snelheid
over een volledige ronde op de geplande rijlijn. Na een versnelling of een
rijlijnwissel is er een natuurlijke overgang naar dat nieuwe gemiddelde.
De HUD toont links een apart Derny-kader: de actuele snelheid midden in een
cirkel die gedurende de minuut volloopt, met resterende seconden. Centraal
verschijnt uitsluitend “Te dicht - snelheid begrensd” zolang die begrenzing actief is.
De geleverde watts van de speler worden altijd afzonderlijk opgenomen.

Vanaf de gekozen startsnelheid rijdt de derny op de laagste rijlijn (1,18 m).
Bij iedere extra 5 km/u schuift hij 0,60 m naar buiten, geleidelijk met 0,20 m/s,
tot maximaal het midden van de bestaande blauwe lijn (3,55 m). De renner volgt
die lijn automatisch. Handmatig sturen is een afwijking ten opzichte van die
rijlijn: twee stappen naar buiten blijven voldoende om bewust in te halen.
Het gevolgde terrein blijft zowel voor de speler als de trainer voelbaar.

`test_derny_motor.gd` meet met de echte pistegeometrie meerdere rondes: constant
aandrijfvermogen, vertragen/versnellen op hellingen, een gemiddelde rondesnelheid
binnen 0,3 km/u van het doel. De sessie- en UI-tests
controleren de startsnelheidskeuze, +1 km/u-stappen, 60%-limiet, automatische
rijlijnwissels en bewaren/herladen van de gekozen startsnelheid.


## Eigen workouts en profiel-FTP

De ERG-keuze bevat FTP-ramp test, Workout-editor en een aparte tegel per eigen
opgeslagen workout, met een miniatuurgrafiek uit de echte blokduur en FTP-fracties
(inclusief alle herhalingen). Een workouttegel opent een trainingsscherm met Start en
Bewerken. In de editor begint Nieuwe workout met een eigen identiteit; opslaan
van een geopende workout werkt alleen die workout bij. De dropdown bevat alleen
eigen workouts, nooit ingebouwde FTP-tests. De bibliotheek staat in
`user://workouts`, naast de bestaande ZWO-import/export.

FTP staat in `user://config/rider_profile.cfg`, samen met naam en gewicht.
Handmatig wijzigen kan via Instellingen → spelersprofiel → FTP (W).
Een FTP-test met een volledige gemeten rampminuut bewaart zijn uitkomst eenmaal
automatisch; een onvolledige test overschrijft de eerdere FTP niet. Het bereik
is 20–1000 W; een nieuw profiel begint op 200 W.

Elk eigen workoutscherm toont vóór Start een instelbare FTP. Het scherm leest
bij openen de actuele profielwaarde. Een afwijking geldt alleen voor die sessie.
Constante blokken, herstel en intervallen gebruiken hun FTP-fractie; opwarming
en afkoeling interpoleren tussen de opgegeven fracties. Een vrij blok geeft de
trainer vrij. Klok en ERG starten pas na bevestiging door de bridge; de overgang
van vrij rijden naar ERG wacht opnieuw op bevestiging. Voltooien, stoppen,
meetuitval en sluiten geven de eigen trainerbediening vrij.

`test_workout_library.gd` controleert meerdere workouts, bewerken/herladen,
FTP-opslag zonder verlies van profielvelden, testresultaten, sessie-overrides,
blokken en trainerbevestiging. `test_workout_virtual_bridge.gd` doorloopt via
echte lokale UDP-pakketten een workout met ERG, vrij rijden en opnieuw ERG.

## Tempo vragen tijdens dernytraining

Na de aanloop vraagt rechts/links +1/−1 km/u, zowel op de echte trainer als
in de simulator. Het kader toont + en − met de overeenkomstige pijl eronder. De virtuele bridge markeert zijn telemetrie met `virtual`.
De renner roept ALLEZ of HOW; de tekst beweegt van de renner naar de gangmaker
en vervaagt. Na een korte reactietijd bevestigt de gangmaker met respectievelijk
de duim of de vlakke hand. De minuutklok begint opnieuw bij die tempowijziging;
de automatische verhogingen blijven actief. Stuurpaddles en camera blijven
beschikbaar; op het toetsenbord sturen A/D en wisselt C de camera.


De FTP-ramptegel tekent het echte testprotocol: 300 seconden vrij opwarmen,
gevolgd door stappen van 60 seconden vanaf 100 W, met telkens 20 W erbij tot
de veiligheidslimiet van 1300 W. De test kan eerder stoppen wanneer de renner
niet meer kan. De miniatuur en de test gebruiken dezelfde protocolconstanten.

Bij een geopende eigen workout toont de editor **Workout verwijderen**. De knop
opent een bevestigingsvenster met de opgeslagen naam. Annuleren bewaart de
workout; bevestigen verwijdert alleen die workout en vernieuwt de tegels en
de keuzelijst. Daarna staat de editor klaar voor een nieuwe workout.


## Vliegende start — eerste speelbare versie

Onder Pistetraining start een poging op de bestaande rode achtervolgingslijn,
op de laagste rijlijn en steeds met 30 km/u virtuele rolsnelheid. Daarna rijdt
de speler één volledige voorbereidingsronde op werkelijk geleverd vermogen.
Links/rechts en de stuurpaddles kiezen vrij de rijlijn. De bestaande pistegeometrie,
extra afstand buitenom, hellingsweerstand en dalingshulp blijven actief; er is
geen slipstream. Het resultaat bij terugkomst op dezelfde lijn wordt binnen
de laatste fysicastap geïnterpoleerd, zodat snelheid en tijd niet afhangen van
een overschietend beeldframe.

Het doel is hoge passagesnelheid met laag piekvermogen. Er is geen richtvermogen
of vermogensplafond meer. Resultaat en HUD tonen het werkelijk gemiddelde en
maximale vermogen. De samenstelpagina en het resultaat tonen dezelfde bewaarde
top 10, gesorteerd op hoogste passagesnelheid, met datum, gemiddeld vermogen en
maximaal vermogen per poging. Alleen voltooide passages tellen mee. De tabel leest
alle opgeslagen trainingen; PC-proefritten zijn herkenbaar gemarkeerd. Een
onderbroken poging krijgt geen fictieve passagesnelheid. Na tien minuten stopt
een niet voltooide poging. Dit is een techniekoefening, geen automatische tijdritstart.

## Neem een ronde — eerste speelbare versie

Een eigen groep van acht renners rijdt met constant gekozen tempo (standaard
30 km/u, instelbaar 15–60). De speler begint drie meter achter de staart, met
dezelfde virtuele rolsnelheid. De groep rouleert compact in twee tot drie rijen,
binnen een lengte van 9 m en rijlijnen tussen 1,18 en 3,58 m. De koprijder wisselt
ongeveer elke zeven seconden; de volledige roulatie duurt 56 seconden. Kleine
onderlinge snelheids- en rijlijnwissels blijven begrensd binnen de groep. Het
groepscentrum houdt het ingestelde tempo, zonder aanvallen of ontsnappingen.
In het wiel is maximaal 50% vermindering van luchtweerstand beschikbaar, gebaseerd
op de werkelijke posities en rijlijnen van de renners. Spel en SIM-bridge gebruiken
dezelfde beschutting. De speler kan zoals in scratch door andere renners rijden;
er is geen wielafstands- of snelheidsbegrenzing achter het peloton.

Kop en staart krijgen dezelfde gekleurde lijnen en labels als scratch, met de
bestaande `peloton_markers.gd`. Lijnen en minimap volgen de actuele voorste en
achterste renner, terwijl de ononderbroken meetreferentie voor rondewinst met het
vaste groepstempo blijft bewegen. Een kopwissel geeft dus geen gratis afstand.

Voortgang is ononderbroken relatieve afstand tot de pelotonstaart, niet de
zichtbare positie modulo 250 m. Voorbij de kop rijden levert dus nog geen ronde
op. Pas na 250 m relatieve winst is de speler opnieuw bij de staart en is de
opdracht geslaagd. De tijdslimiet is vooraf instelbaar van 1 tot 30 minuten,
standaard 10. Een passage na de limiet telt niet meer. Het resultaat bewaart
tijd, pelotontempo, relatieve winst, gemiddeld vermogen en piekvermogen.

Beide vaste sessies gebruiken dezelfde trainingsomgeving, camera's, sensoren,
trainerbewaking, grafiek, checkpointopslag en bevestigde SIM-vrijgave als de
dernytraining. Bij meetuitval wordt gestopt en lokaal opgeslagen. De historie
opent per trainingssoort het juiste resultaat; de bestaande Strava-knop gebruikt
de bijbehorende titel en beschrijving en vermeldt de virtuele rolsnelheid en
PC-proefrit wanneer toepasselijk. Er is geen import/export van deze sessies.

`test_piste_exercises.gd` controleert de exacte passage, relatieve rondewinst,
hellingen en rijlijnen, vrij passeren van renners, opgeslagen resultaten, historie, Strava en
meetuitval. `test_piste_exercise_virtual_bridge.gd` controleert via echte lokale
UDP-pakketten beide starts, SIM-bediening, sturen en vrijgave.


`test_training_peloton.gd` controleert een volledige roulatie: acht wisselende
koprijders, constante beweging van het groepscentrum, compacte meerrijige vorm,
kleine vloeiende onderlinge verplaatsingen en geen rondewinst door kopwissels.
De integratiecontrole vergelijkt de lijn- en minimapgrenzen met de actuele
formatie en controleert dat hoog vermogen ook zonder rijlijnwissel kan passeren.


## Vrije training en piste-overzicht

Het piste-overzicht toont vier eigen tegels met spelbeelden: Vrije training,
Dernytraining, Vliegende start en Neem een ronde. De vrije training begint vanuit
stilstand aan de finishlijn, heeft geen tijdslimiet en stopt wanneer de speler dat
kiest. Tijd en werkelijk gereden afstand staan links, onder het standaardpaneel
met snelheid, hartslag, cadans en slipstream. Daaronder verschijnt een scrollbare
tabel met iedere voltooide rondetijd. Lijntijden worden binnen de fysicastap
geïnterpoleerd, ook als meerdere lijnen in één stap worden gepasseerd. De eerste
ronde bevat het optrekken; buitenom rijden kost ook werkelijk extra afstand.

Vier losse pacers beginnen verspreid op willekeurige plekken en rijlijnen.
Ze rijden elk op vaste fysieke snelheid, onafhankelijk van elkaar:

- **30km/u Pacer**: blauw.
- **35km/u Pacer**: groen.
- **40km/u Pacer**: oranje.
- **45km/u Pacer**: rood.

Hun eigen truien, naamlabels en minimapkleuren stemmen overeen. De speler kan
achter iedere pacer beschutting zoeken; naast of voor de renner valt die weg.
Er zijn geen botsings- of wielafstandsbegrenzingen. Tijd, afstand, meetgrafiek en
rondetijden worden lokaal bewaard, met de bestaande Strava-optie na stoppen.

`test_free_training.gd` controleert lapinterpolatie, onbeperkte duur, pacertempo's,
willekeurige startposities, werkelijke trui-materialen, slipstream, de HUD-tabel,
opslag/herladen, de vier overzichtstegels en beide vliegende-starttabellen.
