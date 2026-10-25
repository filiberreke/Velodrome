# Blijvend zoeken en herstel na onderbreking

KICKR en linker Zwift Ride mogen bij opstarten ontbreken. De UDP-commandopoort
en telemetrie starten vóór de BLE-zoeklussen. Beide apparaten worden onafhankelijk
gezocht; een ontbrekende Ride houdt de trainer niet tegen en omgekeerd. De
linker-masterdetectie en bestaande RideOn-handshake blijven behouden. Scans worden
gedeeld en achter elkaar uitgevoerd, zodat er geen concurrerende scanners zijn.

Een BLE-scan duurt 8 seconden. Als een apparaat ontbreekt, Bluetooth tijdelijk
uitstaat of verbinden mislukt, volgt 5 seconden wachten en een volgende poging,
zonder maximumaantal. Een BLE-verbindingspoging heeft een timeout van 18 seconden.
De totale hersteltijd kan dus langer zijn dan 5 seconden. Na de eerste selectie
blijft het BLE-adres vast: de bridge springt niet naar een andere trainer of Ride.
Een niet eenduidig herkende linker Ride blijft wachten.

Bij een verbroken KICKR-link of meer dan 3 seconden zonder nieuwe FTMS-data of
vermogen wordt de oude sturing gewist. Een vastgelopen, nog open BLE-link wordt
gesloten en opnieuw gezocht. De laatst ontvangen meetwaarden worden niet als
actuele data hergebruikt. Na herverbinding worden notifications en FTMS-controle
opnieuw opgebouwd; de trainer krijgt alleen Reset/vrijgave totdat een nieuwe
expliciete opdracht volgt. De vorige ERG-target, helling en UDP-lease keren niet
automatisch terug. De gekozen Ride-versnelling blijft behouden.

In status:

- `started=false`: FTMS nog niet klaar of Bluetoothverbinding weg.
- `waiting_for_feedback=true`: tijdelijk wachten op verse data én power; nieuwe
  belasting wordt geweigerd met `not_active`. Status en 0-W-vrijgave blijven bruikbaar.
- `reconnect_ready=true`: doelen zijn gewist na uitval. Na verse data en bevestigde
  vrijgave (`mode=RELEASED`, `release_confirmed=true`) mag een nieuwe wedstrijd
  expliciet `set_mode SIM` en vervolgens `set_grade` sturen.
- `disabled=true`: expliciete STOP, verlopen UDP-lease of FTMS-protocolfout;
  sturing blijft geblokkeerd, maar de verbindings-/meetlus blijft werken.

Het bijgewerkte spel gebruikt de herstelstatus bij een nieuwe start. Voor
herstel van metingen hoeft niets opnieuw gestart te worden. Voor nieuwe
weerstandssturing na een verbinding-/datastoring volstaat een nieuwe wedstrijd
of een nieuw consolecommando zodra de verbinding klaar is. Als de huidige
wedstrijd met de bestaande korte telemetrie-overbrugging doorloopt, blijft
weerstandssturing tot die nieuwe start vrijgegeven.

Een UDP-heartbeattimeout blijft een blokkering van sturing, evenals een expliciet
STOP-commando of echte FTMS-weigering/protocolfout. Bluetooth wordt ook dan opnieuw
verbonden voor metingen; deze wijziging maakt die blokkeringen niet automatisch
ongedaan. Bezette UDP-poorten, ontbrekende Python-dependencies of ongeldige
configuratie blijven zichtbare opstartfouten en worden niet als een zoekprobleem
behandeld. Ctrl+C/sluiten beëindigt de bridge.

Softwarecontrole: 55 Python-tests, inclusief ontbrekende apparaten bij opstarten,
herhaalde scanfouten, gedeelde scans, vast BLE-adres, annuleren, uitval en herstel
van de werkelijke trainer-loop met gesimuleerde BLE-client, stilgevallen link,
vrijgave zonder oude targets en behoud van expliciete STOP. Godot-parser en
UDP-clienttests controleren ook starten op de herstelde bridge. Fysieke
herverbinding en rijgevoel moeten nog op de KICKR en Ride worden getest.
