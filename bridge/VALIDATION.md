# Validatie v0.15 — 24 oktober 2026

Uitbreiding op de hier opgeleverde v0.14-broncode. Bewaard ZIP-manifest SHA-256
van v0.14: `a6844c505839fb146c0329b78b71b31fd8d306293bf338118edbb0edfc82ab16`. De oude ZIP hoeft niet meer in outputs aanwezig te zijn.

43 tests geslaagd op Windows / Python 3.12.4. Echte lokale UDP-
sockets, gesimuleerde BLE/FTMS-clients, geen fysieke trainer of USB-stick.
Alle Python-bronnen compileren, alle drie JSON-configuraties zijn leesbaar.

De v0.14-regressietests blijven slagen: 0..1300W-ERG, trainerbereik/increment,
instelbare ramp, 0W-Reset, deduplicatie/IDs/lease, console/UDP, timeouts, FTMS-
serialisatie en blokkering na fouten, hartslagverval en bestaande telemetrie.

Nieuw gecontroleerd: target-feature bit 13 (niet 14), exacte 0x11-bytevolgorde en
schaling, positieve/negatieve/vlakke helling, numerieke grensgevallen, geen stille
clamp, configuratievalidatie, neutrale versnelling en wiskundig wegkrachtmodel,
helling-/versnellingsramp, herstel naar oude SIM/ERG, geen 0x04-writes tijdens
simulatie, statusbevestiging, echte UDP-grade-uitwisseling, lease/feedbackverlies,
STOP tijdens moduswissel en doorlopende grade-updates tijdens initialisatie.
De bestaande integratietest voert nu ook set_grade uit via de echte trainer-loop
met een gesimuleerde BLE-client.

Byte-identiek behouden uit v0.14: ant_hr.py, ant_legacy_backend.py, ant_worker.py, button_mapping.json, button_mapping.py, ftms.py, gear_config.json, hr_bridge.py, requirements.txt, ride_ble.py, ride_protocol.py, selection.py, erg_protocol.py, resistance.py.
AST-identiek in bridge.py: Sender, discover_devices, ride_loop (inclusief
RideOn-handshake/subscriptievolgorde), shift_input, resistance_input en trainer_loop.
virtual_shift.py verandert alleen om de oude weerstandsniveau-melding in de
nieuwe simulatiebackend te onderdrukken; de oorspronkelijke knop-/niveaulogica blijft behouden.

Niet getest: echte KICKR Simulation-feature/firmwaregedrag, werkelijke helling-
of vermogenslimiet, fysiek rijgevoel van het versnellingsmodel, BLE/USB-disconnect,
Windows BAT/pip-installatie en abrupt procesverlies. Dependencies niet geïnstalleerd
tijdens deze controle. FTMS-bevestiging bewijst protocolacceptatie, geen fysieke prestatie.

## Eerste hardwaretest

1. Start de bridge in de oude SIM-regeling en controleer Ride-knoppen, gear-telemetrie en HR.
2. Lees status: simulation_supported moet true zijn voordat set_grade bruikbaar is.
3. Gebruik een bescheiden helling, bijvoorbeeld 1%, en de standaardramp. Stuur elke
   seconde heartbeat. Controleer sim_backend=simulation en confirmed_simulation.
4. Vergelijk neutrale versnelling 4 met lichter/zwaarder. Grade_pct blijft de
   spelhelling; effective_grade_pct/confirmed_simulation veranderen door het model.
5. Vraag 0% aan (vlak met rol-/luchtweerstand), daarna eventueel een bescheiden
   negatieve helling. Verwacht geen actieve motoraandrijving.
6. Controleer set_mode SIM (oude weerstandstabel), ERG, 0W-vrijgave en lease-timeout.

Bewaar v0.14 als terugvalversie. Het nieuwe wegmodel is niet gekalibreerd op jouw
fiets/trainer en verandert het schakelgevoel. Stop met trappen bij onverwachte
weerstand. Reset is geen gegarandeerde mechanische vrijgave of noodstop.
