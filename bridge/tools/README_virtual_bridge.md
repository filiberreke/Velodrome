# Virtuele bridge voor Godot (zonder hardware)

Start de echte Python-bridge niet tegelijk met deze testtool. De tool opent UDP 51725 en verzendt naar Godot op 127.0.0.1:51723. Er worden geen BLE- of ANT+-verbindingen gemaakt en geen trainercommando's naar fysieke hardware verstuurd.

## Starten op Windows

Installeer Python 3 met Tkinter (de standaardinstallatie van python.org bevat Tkinter). Open een terminal in de repository en voer uit:

```powershell
python bridge/tools/virtual_bridge_ui.py
```

Start vervolgens het Godot-project. Een andere volgorde mag ook, maar herstart Godot als poort 51723 reeds bezet is.

## Test van drie opeenvolgende races

1. Zet vermogen, snelheid en cadans op nul om de startvoorwaarden te halen. Laat 'KICKR telemetrie geldig' aangevinkt. Kies in Godot een wedstrijd en start de aftelling.
2. Verhoog vermogen en snelheid zodra de race gestart is. Klik links en rechts en controleer de rijlijn. Schakel lichter/zwaarder en controleer de versnellingsindicator.
3. Voltooi of herstart de wedstrijd. Zet vermogen en snelheid opnieuw op nul, start opnieuw en test alles opnieuw. Herhaal een derde keer.
4. Bij de ploegenachtervolging: controleer in de log de `set_grade`-commando's en hun `aero_scale`, en in ERG de `set_mode`- en `set_target_power`-commando's. De tool simuleert antwoorden, niet de werkelijke fysieke weerstand.
5. Zet desgewenst 'Simuleer verlies' aan om pakketverlies van telemetrie naar Godot te testen en zet het weer uit.

## Beperkingen

Dit is een diagnostische *mock* van de bridge, niet een echte koppeling met Zwift Ride of KICKR. De tool simuleert de poorten en commandostatus, maar test geen Bluetooth, FTMS-indicaties of fysieke weerstand. Hij verstuurt geen zelfstandige ACK voor knopberichten omdat het bestaande protocol die niet kent. De test vervangt de echte bridge tijdelijk; hij injecteert geen knoppen in een gelijktijdig draaiende echte bridge.

De standaardwaarden van vermogen, snelheid en cadans zijn 0 zodat de wedstrijd veilig door zijn startvoorwaarde kan gaan. Hartslag staat op 140 bpm voor HUD/exportcontrole.
