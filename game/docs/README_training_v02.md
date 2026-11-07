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
