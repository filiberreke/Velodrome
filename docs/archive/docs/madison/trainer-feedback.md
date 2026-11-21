# Madison-trainerfeedback

Geïmplementeerd op `feature/madison-trainer-feedback`. Alleen de geïsoleerde
Madison-training gebruikt de nieuwe feedback. De baan wordt niet veranderd.

## Onderzoek van de bestaande keten

- `madison_exchange.gd`: tijdens GRAB/SLING werkt al compliant handcontact:
  `dv = clamp((vg-vr)/2, ±contact_acceleration*dt)`, met gelijke en tegengestelde
  snelheidswijzigingen. Dit dissipeert bij gelijke massa kinetische energie.
  Visuele convergentie, IK en de animaties voegen geen eigen snelheidsimpuls toe.
- Bij RELEASE verandert `apply_release()` beide snelheden met dezelfde `delta`,
  begrensd door de snelheid van de gever. De maximale basisimpuls is 3 m/s en
  18% van de geversnelheid; precisie, slingerfase en Easy/Advanced schalen deze.
  Dit zijn bestaande spelparameters, geen trainerweerstandspercentages.
- Momentum blijft voor twee gelijke massa's behouden. Energie hoeft niet behouden
  te blijven: bij massa m is de verandering van de paarenergie
  `m*delta*(vr-vg) + m*delta²`. Na vrijwel gelijkmaken door handcontact kan de
  loslaatimpuls dus netto kinetische energie toevoegen (actief slingerwerk).
  Er wordt hiervoor geen energiereserve of extra gemeten wattage afgetrokken.
- Madison gebruikt vervolgens `DernySession.next_speed()`: systeemmassa 80 kg,
  luchtdichtheid 1.20, CdA .334, Crr .004 en efficiëntie .975. Luchtkracht is
  `.5*rho*CdA*v²`; aandrijfkracht is `.975*power/max(v,2.5)`. De werkelijke nieuwe
  virtuele snelheid wordt de volgende fysicastap gebruikt. Zonder voldoende
  vermogen vertraagt de ontvanger. `_banked_speed()` voegt bestaande, begrensde
  zwaartekrachteffecten van de werkelijke route toe.
- `derny_environment.gd` berekent de echte routehelling uit hoogte/horizontale
  afstand en filtert deze met tijdconstante .125 s. De nieuwe aflossingshelling
  wordt pas bij de traineruitvoer opgeteld, buiten deze berekeningen.
- `ftp_training.gd:drive_trainer()` bewaakt telemetrie, pauze en herstel.
  `trainer_control.gd` beheert SIM-eigendom, één lopende wijzigingsopdracht,
  ACK/retries, maximaal 5 wijzigingen/s en een heartbeat/status per seconde.
- Godot verstuurt JSON over UDP localhost:51725. `bridge/udp_commands.py` en
  `combined_mode.py` valideren/beheren opdrachten en lease. `simulation.py` maakt
  FTMS Indoor Bike Simulation Parameters, opcode **0x11**, met gesigneerde
  helling in eenheden van .01%. Dit is geen ERG- of weerstandsniveauopdracht.
- De bridge accepteert **−20..+20%**, ramp **.1..100 procentpunt/s**.
  Positieve en negatieve hellingen volgen dezelfde wiskunde en ramp. Bij
  versnellingfactor k gebruikt de bridge `sin(theta_effective)=k*sin(theta)`,
  Crr aangepast met k/cos en Cw met k³. De effectieve trainerhelling kan daardoor
  buiten ±20% vallen. Dit is de bestaande protocolgrens, geen gegarandeerde
  hardwarecapaciteit. Firmware kan een aanvraag begrenzen of weigeren.
- De SIM-writer draait in de trainerloop ongeveer elke .1 s plus FTMS-transactietijd.
  Het rampbudget is maximaal .35 s per tick. Bij 100 procentpunt/s kan de
  doelhelling in enkele ticks bereikt worden. De fysieke respons en totale
  BLE-/mechanische vertraging zijn nog niet gemeten. Een UDP-ACK betekent alleen
  acceptatie; `confirmed_simulation` en `applied_revision` tonen FTMS-bevestiging.
- De bridge krijgt **geen Godot-snelheid**. Hij geeft wegparameters aan de trainer,
  die zijn eigen vliegwielsnelheid gebruikt. De normale belasting wordt na een
  puls hersteld volgens deze bestaande SIM-keten. Exacte fysieke belasting bij
  de nieuwe Godot-snelheid is hiermee **niet geïmplementeerd/gekalibreerd**.
  De spelvertraging bij onvoldoende vermogen is wel aanwezig en getest.

## Ontwerp en implementatie

`apply_release()` geeft nu één gebeurtenis terug met gever, ontvanger, werkelijke
snelheidswijziging, intensiteit en snelheden vóór/na. Bestaande aanroepers mogen de
retourwaarde negeren. De productiehandler van het bestaande `released`-signaal
past de spelimpuls precies eenmaal toe en geeft dezelfde gebeurtenis aan
`madison_trainer_feedback.gd`. De RELEASE-animatie en de trainerpuls starten dus
vanuit dezelfde faseovergang, inclusief automatisch, handmatig en bereikgestuurd
loslaten. Er is geen voorspellende weerstand vóór een geslaagde worp. Handcontact
krijgt geen tweede feedbackpuls.

De koppeling gebruikt **impuls**, omdat de werkelijke delta-v bekend is en FTMS
geen directe impuls/energieopdracht biedt. Met J=m*delta-v en
`A = duur - (opbouw+afbouw)/2` wordt de piekversnelling `intensiteit*delta-v/A`.
De equivalente helling is `100*tan(asin(a/9.81))`, met protocolbegrenzing.
Een smoothstep-krachtprofiel bouwt op, houdt kort aan en bouwt af; de gever krijgt
positieve helling (remkracht), de ontvanger negatieve helling (ontlasting).
Zonder begrenzing is de geïntegreerde kracht gedeeld door massa exact delta-v.
Hardware, sampling en bridgegearing maken dit een representatie van de impuls,
geen gemeten overdracht van precies dezelfde joules naar het vliegwiel.

De module raakt snelheden, gemeten vermogen, routehelling en energiereserves niet
aan. Werkelijk extra geleverd pedaalvermogen blijft, zoals alle telemetrie,
regulier de bewegingsfysica voeden. Er is geen synthetisch extra vermogen.

Nieuwe gebeurtenissen vervangen de vorige puls; ze worden niet opgeteld.
De klok is monotone wandtijd: een pauze mag de weerstandspuls niet verlengen.
Bij ontbrekende bruikbare telemetrie, ontbrekend trainereigendom, annuleren of
stoppen wordt de puls gewist. Herstel speelt hem niet opnieuw af. Verlaten,
stoppen en voltooiing gebruiken de bestaande 0-W/FTMS Reset-vrijgave. Bij een
verlopen pulscommando zonder ACK stopt de client met herhalen en vraagt Reset;
de training stopt vervolgens wegens de trainerfout. Late ACKs herstarten de
sturing niet. Bij procesverlies blijft de bestaande bridgelease van 5 s de
terugval; een volledig vastgelopen proces kan geen kortere vrijgave garanderen.

## Configuratie

Op `scene.trainer_feedback` (codeconfiguratie, geen nieuwe instellingenpagina):

| Parameter | Voorlopige standaard | Betekenis |
| --- | ---: | --- |
| enabled | true | Feedback aan/uit |
| intensity | 1.0 | Schaal op de werkelijke impuls; geen weerstandspercentage |
| duration_s | 1.6 s | Totale pulsduur, minimaal .4 s |
| attack_s | .2 s | Smoothstep-opbouw, maximaal halve pulsduur |
| decay_s | 1.0 s | Smoothstep-afbouw, begrensd tot resterende duur |
| max_grade_pct | 20% | Limiet van de offset, maximaal protocolgrens |
| ramp_pct_per_s | 100 | Bridge-ramp tijdens puls en korte herstelperiode |
| mass_kg | 80 kg | Massa voor diagnostische joules/Ns; delta-v bepaalt de helling |
| debug_log | false | Gestructureerde logregels |

Dit zijn **voorlopige, niet op hardware gevalideerde instellingen**. Een typische
werkelijke delta-v van 1 m/s geeft circa 10.25% piekhelling. Een zeer krachtige
worp kan tegen de limiet lopen; dan worden zwakke/krachtige verschillen minder
onderscheidbaar. De som met de echte routehelling wordt eveneens tot ±20%
begrensd. Geen vaste 40%-weerstandsverandering wordt gebruikt.

Bij nul offset gaan de bestaande routehelling en luchtfactor door. Andere
trainingen gebruiken de oorspronkelijke 10 procentpunt/s; vrijgave herstelt ook
de standaardramp en wist de aflossingsdeadline.

## Debuggen

Start Godot met `MADISON_TRAINER_DEBUG=1` of zet `debug_log` op de module.

- `MADISON_FEEDBACK_START`: beide snelheden vóór/na, delta-v, intensiteit,
  impuls in Ns, speler-/paarenergieverschil in J, richting, duur, piek en clipping.
- `MADISON_FEEDBACK_LOAD`: snelheid, offset, gevraagde totale helling en laatst
  ontvangen FTMS-bevestigde `confirmed_simulation`.
- `MADISON_TRAINER_COMMAND`: werkelijke uitgaande UDP-opdracht met id/tijd,
  helling, ramp en eventuele aerofactor. Retries herhalen identieke bytes/id.
- `MADISON_FEEDBACK_END`: verstreken duur of tijdstip van voortijdig wissen.

De logs zijn diagnostiek; ze bewijzen geen gerealiseerde kracht aan de pedalen.

## Automatische tests

```sh
python3 -m unittest discover -s bridge/tests -v
godot --headless --path game --script res://tests/test_madison_trainer_feedback.gd
godot --headless --path game --script res://tests/test_madison_trainer_integration.gd
```

De moduletest integreert de krachtpuls en controleert normaal rijden, geven,
ontvangen, zwak/krachtig, clipping, herhalen, onderbreken, tijdsverloop, herstel,
virtuele vertraging en echte UDP-opdrachten/Reset/late ACK. De integratietest
gebruikt het echte spel, RELEASE- en annuleringssignalen, beide spelersrollen,
telemetriepauze, herstel, stop en de ongewijzigde Derny-uitvoer.
`bridge/tests/test_madison_feedback.py` doorloopt de productie-FTMS-writer met
positieve/negatieve pulsen, allebei de protocolgrenzen, herstel en Reset.

Zie `trainer-feedback-validation.md` voor uitgevoerde regressies en resultaten.

## Zwift Ride-hardwaretest

1. Start de bridge in SIM en start een echte Madison-training met verse
   telemetrie. Zet debuglogging aan. Noteer trainer/firmware en versnelling.
2. Vergelijk normaal rijden met een zwakke en krachtige gegeven worp: korte,
   duidelijke extra belasting vanaf het loslaten en een vloeiende terugkeer.
3. Ontvang beide soorten worpen: duidelijke ontlasting, snelheidsimpuls in het
   spel, daarna herstel. Houd bewust te weinig vermogen aan: de virtuele snelheid
   moet teruglopen. Controleer dat de trainer niet op lage weerstand blijft.
4. Herhaal in meerdere versnellingen en op verschillende cadansen. Meet de
   vertraging tussen RELEASE, uitgaand commando, FTMS-bevestiging en gevoel.
5. Wissel rollen en voer meerdere worpen uit. Breek handcontact af vóór RELEASE:
   geen puls. Stop/verlaten tijdens een puls: Reset en geen resterende piek.
6. Test een telemetrieonderbreking en herstel: geen oude puls. Controleer daarna
   ook Derny/vrij rijden op normale belasting.
7. Beoordeel clipping, minimale weerstand bergaf en maximale fysieke helling.
   Een passieve trainer kan niet motorisch trekken; als de ontlasting onvoldoende
   voelbaar is, kan SIM alleen dat niet oplossen. Verlaag bij oncomfortabele
   pieken eerst max_grade_pct/intensity. Stel definitieve waarden pas na deze
   metingen vast.
