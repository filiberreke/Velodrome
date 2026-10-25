# Helling en luchtweerstand naar de KICKR

Start de bijgewerkte Python-bridge uit `bridge/` en daarna het spel. Bij een echte
trainer en een gestarte wedstrijd neemt het spel de bestaande SIM-modus over via
localhost UDP 51725. De eerste status moet een actieve trainer met FTMS Indoor Bike
Simulation-ondersteuning melden. Demo stuurt geen trainercommando's. Een bestaande
ERG-sessie of andere UDP-eigenaar wordt behouden; kies zelf SIM in de bridge en
start een nieuwe wedstrijd om de spelkoppeling te gebruiken.

De helling volgt de hoogteverandering van de werkelijke spelersroute gedeeld door
de horizontaal afgelegde afstand. Daarmee tellen zowel de hoogteovergangen van de
bochten als het omhoog/omlaag sturen over de schuine piste mee, in alle spelvormen.
De 42 graden dwarsverkanting van een bocht is op zichzelf geen weghelling: op een
constante hoogte blijft de helling nul. De waarde wordt kort gefilterd (0,125 s),
begrensd op -20..20% voor het bridgeprotocol en afgerond op 0,01 procentpunt.
Het spel kiest een bridgehellingsramp van 10 procentpunt/s. De begrenzing en de
bestaande vereenvoudigde spelzwaartekracht betekenen dat trainer en spel geen
exact gekalibreerd fysiek model vormen.

De bestaande spelberekening van slipstream bepaalt `aero_scale = 1 - drag_reduction`.
De bridge schaalt hiermee alleen zijn luchtweerstandscoëfficiënt; zwaartekracht,
rolweerstand en virtuele versnellingen blijven behouden. Achter een wiel neemt de
belasting af, uit de slipstream neemt ze toe. Zonder slipstream, ook bij de
individuele achtervolging, is de factor 1. De bridge moet in status
`aero_scale_supported=true` melden; bij de eerdere v0.15 wordt alleen helling
verstuurd en blijft de luchtweerstand de ingestelde vaste waarde.

Er gaat maximaal één wijzigingsopdracht tegelijk uit, maximaal vijf per seconde
en alleen bij verandering. Eén gebonden loopbacksocket ontvangt ACK/fouten en
gebruikt unieke ids. Retries behouden inhoud/id/bronpoort. Nieuwe heartbeats lopen
iedere seconde en status wordt iedere seconde gecontroleerd. ACK betekent alleen
aanvraag geaccepteerd; `confirmed_simulation` en `applied_revision` in status tonen
de FTMS-bevestiging. Bij fout/console-overname wordt niet automatisch herladen.
Begin daarvoor expliciet een nieuwe wedstrijd. Bij een tijdelijke BLE-/datastoring
blijft de bridge zoeken en herstellen de metingen vanzelf. De nieuwe wedstrijd
kan de vrijgegeven herstelsessie overnemen zodra verse feedback en Reset bevestigd
zijn (`reconnect_ready=true`); een bridgeherstart is dan niet nodig. Fouten staan in de Godot-log als
`Trainerkoppeling: ...`.

Bij finish, terug naar menu, herstart of verlies van geldige trainertelemetrie
vraagt de client vrijgave met `set_target_power watts=0` (FTMS Reset), alleen van
de eigen sturing. Hij blijft antwoorden/retries verwerken zolang het spel draait.
Bij sluiten gaat een laatste vrijgavepoging uit; bij proces-/pakketverlies is de
bestaande vijfsecondenlease de terugval. De bridge bewaakt daarnaast trainerdata
en powerfeedback. `set_grade 0` is vlak rijden met weerstand en is geen vrijgave.

## Controle

- Python: `python -m unittest discover -s bridge/tests -v` — 55 tests, inclusief
  validatie, legacy-defaults, slipstreamramp, FTMS-bytes en lease/foutafhandeling.
- Godot: `--headless --path game --script res://tests/test_trainer_control.gd` —
  routehelling, echte UDP-loopback met gesimuleerde bridge, verloren ACK/retry,
  heartbeats, vrijgave, volgende start, console-overname, bestaande ERG,
  v0.15-compatibiliteit en begrensde retries. Gebruikt een vrije testpoort.
- Bestaande telemetrie- en gameplaytests blijven bruikbaar.

FTMS definieert wind- en rolweerstandscoëfficiënten binnen Indoor Bike Simulation
Parameters: [Bluetooth SIG FTMS-test suite, 0x11](https://files.bluetooth.com/wp-content/uploads/dlm_uploads/2024/10/FTMS.TS_.p6.pdf).
Hier wordt geen externe windrichting of weersimulatie toegevoegd: het gaat om
luchtweerstand en beschutting in het peloton. De fysieke KICKR-respons en het
rijgevoel zijn nog niet op hardware getest. Trainerfirmware en bridgeparameters
bepalen de absolute belasting; het bestaande virtuele versnellingsmodel is een
benadering en gebruikt geen native Wahoo/Zwift-versnellingsprotocol.

