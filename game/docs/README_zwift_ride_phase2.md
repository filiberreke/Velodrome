# Zwift Ride — fase 2

Werk bridge en game samen bij en herstart daarna ook de echte/virtuele bridge.
De standaard `button_mapping.json` bevat nu ook `"Z": "Z"`. De bijgewerkte bridge
voegt deze standaard tijdens het laden automatisch toe als Z in een ouder bestand
ontbreekt. Een expliciete lege of eigen toewijzing voor Z blijft behouden.

| Context | Bediening |
| --- | --- |
| Wedstrijd kiezen, configuratie, startlijst, rennerkiezer, records | Pijltjes navigeren, A bevestigt, B gaat terug. Z opent instellingen. |
| Intro | A slaat de intro over; B keert terug naar het hoofdmenu. |
| Staging, aftellen en rijden | Z pauzeert. A reset of herstart geen actieve wedstrijd. |
| Rijden, inclusief geneutraliseerde ronde en vliegende aanloop | B vasthouden kijkt achterom. Loslaten herstelt de gekozen camera. Omhoog/omlaag wisselt camera; Y wisselt naam/wattage/energie-weergave zoals V. |
| Pauzemenu | Omhoog/omlaag kiest Hervatten, Instellingen of Verlaten; A bevestigt. B/Z hervat of annuleert eerst de verlaatbevestiging. Verlaten vereist een tweede bewuste bevestiging. |
| Finish/uitslag | Pijltjes en A kiezen opnieuw rijden of hoofdmenu. B gaat naar het hoofdmenu; Z opent instellingen. Tijdens uitrijden vóór de uitslag kan B al terug. |
| Instellingen | Links/rechts op de bovenste tabknop wisselt tab; omhoog/omlaag doorloopt opties. Links/rechts wijzigt getallen, schuifbalken en keuzes; A bevestigt knoppen en wisselt keuzelijsten. B/Z sluit zonder bewaren. Gebruik Toepassen en bewaren om te bewaren. |
| Tekstveld | A opent een toetsenbord op het scherm; pijltjes kiezen letters, A typt. Kies Klaar om over te nemen, B/Z annuleert. |
| Controller-test | Alle spelacties zijn geblokkeerd. Z verlaat expliciet de test en keert terug naar de Speler-tab. SHIFT blijft de bestaande onafhankelijke bridge-schakeling gebruiken. |
| Hoofdmenu | B opent een bevestiging om Velodrome af te sluiten; A op Terug of B annuleert. |

Beide linker SHIFT-knoppen (`SHIFT_UP_LEFT`, `SHIFT_DOWN_LEFT`) schakelen lichter.
Beide rechter SHIFT-knoppen (`SHIFT_UP_RIGHT`, `SHIFT_DOWN_RIGHT`) schakelen zwaarder.
Deze knoppen navigeren nooit door menu's en sturen niet. De virtuele bridge gebruikt
dezelfde indeling; een vastgehouden knop telt één keer. Analoge paddles blijven de
afzonderlijke stuurbediening. DROP_LEFT/RIGHT (protocolnamen POWER_LEFT/RIGHT) blijven
gereserveerd voor arcade; aan/uit-knoppen hebben geen spelactie.

## Routing en herstel

De bovenste actieve context ontvangt de actie: test → teksttoetsenbord → instellingen
→ pauze → setup/intro/uitslag → race. Instellingen tijdens een wedstrijd pauzeert eerst;
sluiten laat de wedstrijd gepauzeerd. Toetsenbordbediening blijft beschikbaar, met
Escape voor terug/pauze en F10 voor instellingen.

De bridge verstuurt fysieke press/release-diagnostiek plus het bestaande gemapte
drukbericht. Alleen dat gemapte bericht voert een actie uit; dubbele berichten op
dezelfde fysieke druk worden onderdrukt. Een druk die in een andere context begon
kan geen actie in de nieuwe context uitvoeren. B loslaten wordt in elke context verwerkt.

Een verbindingsheartbeat (elke 0,5 s op de echte bridge, 0,1 s in de simulator) bevat de
vastgehouden knoppen. Daarmee herstelt het spel een verloren loslaatpakket; na 2 s
zonder controllerbericht stopt achteromkijken eveneens. Pauze, instellingen, finish,
reset en focusverlies wissen de achteromblik. Toetsenbord-B en Ride-B blijven onafhankelijk.
Analoge drukken tijdens menu's worden verbruikt, zodat vasthouden door de start geen
onverwachte stuuractie veroorzaakt.

## Tests

Godot 4.7.2:

```
Godot.exe --headless --path game --script res://tests/test_ride_phase2.gd
Godot.exe --headless --path game --script res://tests/test_controller_settings.gd
Godot.exe --headless --path game --script res://tests/test_exit_pause.gd
Godot.exe --headless --path game --script res://tests/test_result_navigation.gd
Godot.exe --headless --path game --script res://tests/test_bridge_navigation.gd
Godot.exe --headless --path game --script res://tests/test_analog_steering.gd
Godot.exe --headless --path game --script res://tests/test_bridge_protocol.gd
Godot.exe --headless --path game --script res://tests/test_ai_energy_display.gd
Godot.exe --headless --path game --script res://tests/test_rider_name_visibility.gd
```

Bridge: `python -m unittest discover -s bridge/tests -v`.
Stel `GODOT_BIN` in op de Godot-executable om ook de drie echte UDP-integratietests
mee te nemen, waaronder `test_ride_phase2_udp.gd`. `GODOT_PROJECT` kan naar een aparte
volledige testkopie van de game wijzen. De tests gebruiken tijdelijke UDP-poorten.
Gebruik voor geïsoleerde runs een apart APPDATA/LOCALAPPDATA-profiel.

De tests simuleren BLE-notificaties en controleren de echte UDP-route; fysieke
Zwift Ride/KICKR-bediening is nog niet getest. UDP heeft geen gegarandeerde levering:
de heartbeat herstelt vastgehouden B, maar een verloren druk kan opnieuw indrukken vereisen.
Externe Strava-aanmelding blijft een browserhandeling. De vaste teksttoetsenbordindeling
bevat A–Z/a–z, cijfers, spatie, punt, apostrof en koppelteken.
