# Vélodrome-bridge

De Python-bridge verbindt het spel met een smarttrainer via Bluetooth FTMS, de linker Zwift Ride-controller en hartslag via BLE of een ANT+-USB-stick. Voor SIM en ERG hangt de beschikbare trainerbesturing af van de functies die de trainer via FTMS meldt.

## Starten

De gebundelde Windows- en macOS-versies starten de bridge via hun eigen launcher. Bij een broncheckout start je de bridge en het spel apart. Gebruik één bridge per spelinstantie.

**Windows**. Installeer Python 3.12 en start vanuit de repositoryroot:

```powershell
.\bridge\start_windows.bat
```

De eerste start installeert de dependencies in een lokale virtuele omgeving. Voeg `--no-ant` toe als je geen ANT+-stick gebruikt. BLE-hartslag blijft beschikbaar. Voor een macOS-broncheckout zonder ANT+:

```sh
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install -r bridge/requirements.txt
python bridge/bridge.py --no-ant
```

## Apparaten en diagnose

Sluit andere apps die dezelfde hardware gebruiken. Zet je trainer aan en activeer bij Zwift Ride eerst de linker controller. Gebruik **Apparaten** in Vélodrome om de trainer, controller en hartslagbron te kiezen. Zonder opgeslagen keuze zoekt de bridge standaard op de trainernaam `KICKR`. De bridge blijft zoeken en probeert opnieuw te verbinden als een apparaat wegvalt.

Kijk bij verbindingsproblemen in het bridgevenster en `bridge.log`. In de macOS-bundel staat het log onder `~/Library/Logs/Velodrome/`. Gebruik `--help` voor de startopties. Stop met trappen bij onverwachte weerstand. Bij verbindings- of procesverlies kan de trainer een vrijgavecommando missen.

## Ontwikkelen en testen

```sh
python -m unittest discover -s bridge/tests -v
python bridge/tools/virtual_bridge_ui.py
```

De virtuele bridge is bedoeld voor testen zonder hardware. Zie het [UDP-protocol](UDP_PROTOCOL.md) voor berichten en poorten en de [archiefdocumentatie](../docs/archive/ARCHIEF.md) voor ontwerp- en validatieverslagen.
