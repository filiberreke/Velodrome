# Virtuele bridge voor Godot (zonder hardware)

Start de echte Python-bridge niet tegelijk met deze testtool. De tool opent UDP 51725 en verzendt naar Godot op 127.0.0.1:51723. Er worden geen BLE- of ANT+-verbindingen gemaakt en geen trainercommando's naar fysieke hardware verstuurd.

## Controller-tab testen zonder hardware (featurebranch)

1. Start `python bridge/tools/virtual_bridge_ui.py` uit deze branch en start Godot uit dezelfde branch.
2. Open **F10 -> Instellingen -> Controller** in Godot.
3. Druk met de muis op een van de 16 fysieke Ride-knoppen in de virtuele bridge, **houd ingedrukt** en controleer de opgelichte rij. Bij muis loslaten dooft de rij.
4. Test ook **Y**, **Z** en de powerknoppen: deze zijn zichtbaar, ook als er geen spelactie aan gekoppeld is.
5. Test beide analoge paddles: de bestaande gecombineerde stuurwaarde wordt in Godot weergegeven (-100 tot +100).
6. Vink **Zwift Ride verbonden** uit terwijl een knop ingedrukt is: de virtuele bridge stuurt loslaten en een verbindingsmelding. Vink weer aan voor een nieuwe sessie.

De virtuele bridge verstuurt nu net als de echte bridge een aanvullend `controller_button`-bericht voor indrukken/loslaten (met `source_button`, `mapped_action`, `pressed`) plus `controller_connection` bij verbinding en verbreking. Bestaande `button`-berichten met `source_button` blijven werken.

**Opgelet:** met de Controller-tab open blokkeert Godot de reguliere spelacties. In de simulator blijft het wijzigen van een gesimuleerde versnelling via de bestaande schakelknoppen mogelijk, maar er wordt nooit echte trainerhardware aangestuurd. De speciale knoptest mag niet tegelijk met de echte bridge op dezelfde poorten draaien.

De bediening wordt voor deze fase getest; knopmapping aanpassen en de televisie-intro zijn nog geen onderdeel van deze branch.

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
2. Verhoog vermogen en snelheid zodra de race gestart is. Gebruik de afzonderlijke linker en rechter paddle-schuifregelaars voor sturen. Links negatief en rechts positief is naar buiten sturen; de andere richting simuleert remdruk en stuurt niet. Schakel lichter/zwaarder en controleer de versnellingsindicator. De menu-knoppen sturen niet tijdens de race.
3. Voltooi of herstart de wedstrijd. Zet vermogen en snelheid opnieuw op nul, start opnieuw en test alles opnieuw. Herhaal een derde keer.
4. Bij de ploegenachtervolging vraagt de rechter paddle vanaf +25 een kopwissel aan zodra je op kop rijdt en de ploeg beweegt. Laat hem weer los voor een volgende wissel. Lichter/zwaarder schakelen verandert alleen de versnelling. Uitsturen, uitzakken en achteraan aansluiten verlopen automatisch; links kiest hier geen vrije rijlijn. Het toetsenbord behoudt de bestaande stuurfunctie. Controleer in de log de `set_grade`-commando's en hun `aero_scale`, en in ERG de `set_mode`- en `set_target_power`-commando's. De tool simuleert antwoorden, niet de werkelijke fysieke weerstand.
5. Zet tijdens een race 'Simuleer verlies' minstens twee seconden aan. Godot geeft zijn trainerregeling na de telemetrietime-out vrij. Zet de optie weer uit: dezelfde race hervat zijn eigen SIM-regeling via een nieuwe statuscontrole; de versnelling verschijnt opnieuw. Test daarna schakelen en links/rechts sturen. Bij ongeldige trainerdata of een commandofout/overname door een andere besturing is er geen automatische heractivering.

## Paddlebediening en menu's

Er zijn twee schuifregelaars (-100..100), een loslaatknop per paddle en 'Beide
loslaten'. De weergegeven stuurwaarde is de gecombineerde uitslag. Links -40
of rechts +40 kiest twee banen; -85/+85 kan vijf banen opschuiven. De oversteek
blijft vloeiend. Vasthouden blijft bij dezelfde keuze; harder duwen voegt extra
bereik toe. Laat de uitslag terugkomen tot maximaal 15 voor een nieuwe beweging.
Gelijke, tegengestelde stuurdruk heft elkaar op. Remdruk stuurt niet en remt
het spel momenteel niet.

'Menu links/rechts/omhoog/omlaag' verplaatsen de focus. A kiest, B gaat terug.
Deze knoppen veranderen tijdens de race geen rijlijn. Schakelpaddles bedienen
de menu's niet. Gebruik na een update de nieuwe bridge én Godot-code.

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

Bij de echte bridge blijft de oorspronkelijke knop beschikbaar in het extra UDP-veld `source_button`, bijvoorbeeld `{"type":"button","button":"RIGHT","source_button":"SHIFT_UP_RIGHT"}`. Godot gebruikt dit om schakelen buiten de menu's te houden. Sturen gebruikt nu een apart `{"type":"steering","value":25}`-bericht uit de analoge paddles. De integratietest controleert dat schakelen op kop de versnelling wijzigt zonder uit te sturen, en dat daarna de rechter paddle wel een wissel start. Zie ook `game/tests/test_analog_steering.gd` en `game/tests/test_bridge_navigation.gd` voor de drukniveaus, vloeiende verplaatsing en menubediening.

