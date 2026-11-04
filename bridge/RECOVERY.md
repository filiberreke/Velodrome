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
- `disabled=true`: expliciete STOP; sturing blijft geblokkeerd. Een gewone
  heartbeat-timeout of FTMS-transactiefout schakelt niet meer permanent uit.

Het bijgewerkte spel gebruikt de herstelstatus bij een nieuwe start. Voor
herstel van metingen hoeft niets opnieuw gestart te worden. Voor nieuwe
weerstandssturing na een verbinding-/datastoring volstaat een nieuwe wedstrijd
of een nieuw consolecommando zodra de verbinding klaar is. Als de huidige
wedstrijd met de bestaande korte telemetrie-overbrugging doorloopt, blijft
weerstandssturing tot die nieuwe start vrijgegeven.

Een UDP-heartbeattimeout wist meteen het ERG-doel, de helling en de lease. De
trainer-loop voert vervolgens Reset uit. Na bevestigde vrijgave en verse data
kan de volgende expliciet gestarte wedstrijd opnieuw SIM/ERG aanvragen zonder de
bridge te herstarten. Een FTMS-transactiefout veroorzaakt eerst een best-effort
Reset en vervolgens een volledige trainerherverbinding; pas daarna mag een nieuwe
wedstrijd sturen. Een expliciete STOP blijft terminaal en wordt nooit via een
nieuwe wedstrijd omzeild. Bezette UDP-poorten, ontbrekende Python-dependencies of ongeldige
configuratie blijven zichtbare opstartfouten en worden niet als een zoekprobleem
behandeld. Ctrl+C/sluiten beëindigt de bridge.

Softwarecontrole: 55 Python-tests, inclusief ontbrekende apparaten bij opstarten,
herhaalde scanfouten, gedeelde scans, vast BLE-adres, annuleren, uitval en herstel
van de werkelijke trainer-loop met gesimuleerde BLE-client, stilgevallen link,
vrijgave zonder oude targets en behoud van expliciete STOP. Godot-parser en
UDP-clienttests controleren ook starten op de herstelde bridge. Fysieke
herverbinding en rijgevoel moeten nog op de KICKR en Ride worden getest.

## Herstel van ploegenachtervolging naar nieuwe wedstrijd

Bij elke overgang SIM -> ERG wordt het oude ERG-doel eerst gewist. De
modusaanvraag alleen legt dus geen wattage op en bezit nog geen lease.
Daarna moet het spel een nieuw positief `set_target_power` versturen.
Als dat uitblijft, blijft de trainer vrijgegeven; een oude 265 W kan niet
opnieuw geactiveerd worden. Na een time-out zijn verse data en een
bevestigde FTMS Reset vereist voordat een nieuwe wedstrijd de sturing
kan activeren. Een FTMS-protocolfout vereist bovendien een nieuwe BLE-
controller; de oorspronkelijke transactiestatus wordt niet hergebruikt.

Als een nieuwe wedstrijd begint terwijl de vorige lease nog actief is, leest
Godot via status of dezelfde UDP-bronpoort eigenaar is
(`udp_owned_by_requester=true`). Alleen dan vraagt het spel eerst
`set_target_power 0` aan. Na bevestigde Reset gaat de nieuwe wedstrijd
naar PROBE en kan ze verder starten. Een lease van een andere bron wordt
niet aangeraakt.
