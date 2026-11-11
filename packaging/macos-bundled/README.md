# Velodrome voor macOS: spel en bridge samen

## Starten

1. Download de bundel voor **arm64 (Apple Silicon)** of **x86_64 (Intel)**.
   Deze builds zijn gericht op macOS Monterey 12 en nieuwer. Gebruik bij
   voorkeur de laatste Monterey-update (minstens 12.3 voor probleemloos BLE-scannen).
2. Pak het artifact uit en pak daarna de meegeleverde distributie-ZIP uit.
   Bewaar de volledige uitgepakte map bij elkaar.
3. Dubbelklik **Start-Velodrome.command**. Dit opent één Terminalvenster voor
   de bridge en start het spel. Python en Homebrew zijn niet nodig.
4. Geef Bluetooth-toestemming aan VelodromeBridge of Terminal wanneer macOS
   daarom vraagt. Bij een eerdere weigering: Systeeminstellingen >
   Privacy en beveiliging > Bluetooth.
5. Zet eerst de linker Zwift Ride aan, daarna de rechter. Zet de KICKR aan.
   De bridge blijft zoeken en kan dus ook eerder gestart worden.
6. Voor Garmin-hartslag: sluit een ANT+-USB-stick aan en zet Broadcast Heart
   Rate aan. Sluit Garmin Express en andere apps die de stick gebruiken.

Sluiten van het spel stopt ook de bridge. De bridge probeert daarbij de
trainerregeling via FTMS Reset vrij te geven voordat Bluetooth sluit.
Bij onverwachte weerstand stop je met trappen. Een geforceerd procesverlies
of verbroken Bluetooth kan verhinderen dat de trainer de Reset ontvangt.

De bundel is ad-hoc ondertekend voor lokale uitvoering, niet met een
Apple Developer ID ondertekend of genotariseerd. macOS kan daarom bij de
eerste opening om toestemming vragen via Privacy en beveiliging > Open toch.
Verplaats de bestanden niet afzonderlijk uit de uitgepakte map.

## Functies

Dezelfde bridgecode als Windows verzorgt KICKR FTMS-metingen, SIM/ERG,
instelbare wattageovergangen, hellingsimulatie, 12 virtuele versnellingen,
Zwift Ride-knoppen, analoge stuurpaddles, herverbinden, heartbeat/lease en
Garmin ANT+-hartslag. Alle UDP-poorten en het protocol zijn gelijk:
51723 telemetrie, 51724 interne hartslag, 51725 traineropdrachten op localhost.

Windows behoudt zijn bestaande libusb0-backend. macOS gebruikt CoreBluetooth
voor BLE en meegeleverde libusb 1.0 voor ANT+; geen Windows-driver of DLL.
Een ANT+-fout laat trainer en Ride doorwerken zonder hartslag.
Bluetooth-adressen op macOS zijn lokale UUID's, geen Windows-MAC-adressen.
Automatische apparaatselectie blijft beschikbaar.

De SIM/ERG-console ondersteunt dezelfde opdrachten als Windows:
sim, erg, target 0..1300 [W/s], grade -20..20 [pct/s], status en stop.
Zie bridge/README.md, UDP_PROTOCOL.md en SIMULATION.md in de repository.

## Configuratie en diagnose

Persoonlijke spelconfiguratie blijft behouden. Alleen ontbrekende
voorbeeldbestanden worden aangemaakt onder:
~/Library/Application Support/Godot/app_userdata/Velodrome 250 - Sprint Beta/config

Bridgeconfiguratie zit in de app naast de bevroren modules: gear_config.json,
simulation_config.json en button_mapping.json. Het buildproces controleert
deze bestanden tegen de bronbestanden.

Bridge-log: ~/Library/Logs/Velodrome/bridge.log
Het Terminalvenster toont daarnaast BLE-, ANT+- en opstartmeldingen.
Start desgewenst vanuit Terminal:
./Start-Velodrome.command --no-ant

## Bouwen en controles

De workflow **macOS bundled game and bridge** bouwt met deployment target 12.0.
libusb wordt uit versie 1.0.29 gebouwd met ditzelfde minimum; Homebrew-binaries
van de nieuwere runner worden niet meegeleverd. PyObjC-bindings zijn vastgezet
op 10.3.2. Een aparte controle verifieert de echte minimumversie van ieder
Mach-O-bestand (alle architecturen) en elke app-plist, inclusief het spel.
Een component die nieuwer macOS vereist blokkeert publicatie.

De workflow bouwt afzonderlijk voor
Apple Silicon en Intel. Hij hergebruikt het nieuwste succesvolle beschikbare
artifact van **Build macOS game** op main. game-build.json legt de gebruikte
spelcommit en build vast. De bestaande zelfstandige gamebuild blijft beschikbaar.

Automatisch: gedeelde bridgetests op Windows en beide Mac-architecturen,
launcher/configuratietests, laden van CoreBluetooth en libusb zonder
apparaten, controle van bevroren JSON-configuratie vanuit een andere werkmap,
app-signatuur, en headless spelstart met echte start/stop van de gebundelde
bridge in expliciete softwaretestmodus.

De build- en opstartcontroles draaien op macOS 15-runners. De minimumversiecontrole
is geen uitvoeringstest op Monterey zelf: die praktijktest blijft nodig.
Deze controles bewijzen geen fysieke Bluetooth- of ANT+-werking.
Nog te testen op een Mac: toestemmingsdialoog, KICKR-telemetrie en
SIM/ERG/helling, Ride-knoppen/sturen/schakelen, Garmin-hartslag,
verbindingsherstel en trainerreset bij sluiten.

Bronnen:
- https://bleak.readthedocs.io/en/latest/backends/macos.html
- https://pyinstaller.org/en/stable/feature-notes.html
