# Virtuele bridge voor Godot (zonder hardware)

Start de echte Python-bridge niet tegelijk met deze testtool. De tool opent UDP 51725 en verzendt naar Godot op 127.0.0.1:51723. Er worden geen BLE- of ANT+-verbindingen gemaakt en geen trainercommando's naar fysieke hardware verstuurd.

## Starten op Windows

Installeer Python 3 met Tkinter (de standaardinstallatie van python.org bevat Tkinter). Open een terminal in de repository en voer uit:

```powershell
python bridge/tools/virtual_bridge_ui.py
```

Start vervolgens het Godot-project. Een andere volgorde mag ook, maar herstart Godot als poort 51723 reeds bezet is.

Het menu toont `Bridge LIVE` zodra Godot geldige telemetrie ontvangt; de demo-instellingen verdwijnen dan. Zonder ontvangen telemetrie staat er expliciet `DEMO`. Als een andere spelinstantie UDP 51723 gebruikt, toont het menu de poortfout en kan de wedstrijd niet starten. Sluit de andere spelinstantie en herstart Godot. Een teller in de simulator bewijst alleen dat pakketten verzonden worden, niet welke spelinstantie ze ontvangt.

`RELEASED` betekent dat de trainerregeling is vrijgegeven; dan ontbreekt de versnelling in de telemetrie. Een expliciete nieuwe racestart mag deze bevestigde, onbezette toestand opnieuw in SIM activeren, ook als Godot ondertussen opnieuw is gestart. Je hoeft de simulator daarvoor niet te herstarten. Een actieve andere besturing of bestaande ERG-sessie wordt niet overgenomen. Een gesloten Godot-socket mag de simulatorlus niet stilleggen; tijdelijke UDP-connection-resetmeldingen worden opgevangen.

## Test van drie opeenvolgende races

1. Zet vermogen, snelheid en cadans op nul om de startvoorwaarden te halen. Laat 'KICKR telemetrie geldig' aangevinkt. Kies in Godot een wedstrijd en start de aftelling.
2. Verhoog vermogen en snelheid zodra de race gestart is. Klik links en rechts en controleer de rijlijn. Schakel lichter/zwaarder en controleer de versnellingsindicator.
3. Voltooi of herstart de wedstrijd. Zet vermogen en snelheid opnieuw op nul, start opnieuw en test alles opnieuw. Herhaal een derde keer.
4. Bij de ploegenachtervolging vraagt de aparte knop 'Stuur rechts' een kopwissel aan zodra je op kop rijdt en de ploeg beweegt. Lichter/zwaarder schakelen verandert alleen de versnelling en vraagt geen wissel aan. Uitsturen, uitzakken en achteraan aansluiten verlopen automatisch; links kiest hier geen vrije rijlijn. Dit werkt hetzelfde via bridge en toetsenbord. Controleer in de log de `set_grade`-commando's en hun `aero_scale`, en in ERG de `set_mode`- en `set_target_power`-commando's. De tool simuleert antwoorden, niet de werkelijke fysieke weerstand.
5. Zet tijdens een race 'Simuleer verlies' minstens twee seconden aan. Godot geeft zijn trainerregeling na de telemetrietime-out vrij. Zet de optie weer uit: dezelfde race hervat zijn eigen SIM-regeling via een nieuwe statuscontrole; de versnelling verschijnt opnieuw. Test daarna schakelen en links/rechts sturen. Bij ongeldige trainerdata of een commandofout/overname door een andere besturing is er geen automatische heractivering.

## Beperkingen

Dit is een diagnostische *mock* van de bridge, niet een echte koppeling met Zwift Ride of KICKR. De tool simuleert de poorten en commandostatus, maar test geen Bluetooth, FTMS-indicaties of fysieke weerstand. Hij verstuurt geen zelfstandige ACK voor knopberichten omdat het bestaande protocol die niet kent. De test vervangt de echte bridge tijdelijk; hij injecteert geen knoppen in een gelijktijdig draaiende echte bridge.

De standaardwaarden van vermogen, snelheid en cadans zijn 0 zodat de wedstrijd veilig door zijn startvoorwaarde kan gaan. Hartslag staat op 140 bpm voor HUD/exportcontrole.

## Automatische regressietests

Vanuit de repository:

```powershell
python -m unittest discover -s bridge/tests -p test_virtual_bridge_ui.py -v
```

De tests gebruiken echte UDP-sockets en Tcl-variabelen met nagebootste vensters; er is geen beeldscherm of hardware nodig. Voor de extra test met de echte Godot-code, importeer eerst het project en zet `GODOT_BIN`:

```powershell
$env:GODOT_BIN = 'C:\pad\naar\Godot.exe'
& $env:GODOT_BIN --headless --path game --editor --import
python -m unittest discover -s bridge/tests -p test_virtual_bridge_ui.py -v
```

Deze integratietest gebruikt vrije testpoorten en controleert detectie in het menu, aftelling, drie races, vrijgave bij UDP-verlies, automatisch herstel van de eigen SIM-sessie, versnelling/sturen na herstel en een bezette telemetriepoort. De fysieke weerstand en Bluetooth worden niet getest.

Een tweede integratietest start manuele ploegenachtervolging met een reeds `RELEASED` simulator en een nieuwe Godot-sessie. Hij controleert SIM-heractivatie, zichtbare versnellingen, schakelen/kopwissel en terugkeer van ERG naar manueel. `game/tests/test_bridge_steering.gd` controleert beide ploeggrootten, UDP-knopaliassen en de bestaande grenzen voor wisselen.

Bij de echte bridge blijft de oorspronkelijke knop beschikbaar in het extra UDP-veld `source_button`, bijvoorbeeld `{"type":"button","button":"RIGHT","source_button":"SHIFT_UP_RIGHT"}`. Godot gebruikt dit om schakelen in de ploegenachtervolging te onderscheiden van een echte stuurknop, ook met de bestaande knoppenmapping. Werk daarvoor zowel Godot als de Python-bridge bij; een oude echte bridge die alleen `RIGHT` verstuurt, heeft de knopherkomst al weggegooid. De integratietest controleert apart dat schakelen op kop de versnelling wijzigt zonder uit te sturen, en dat daarna 'Stuur rechts' wel een wissel start.

