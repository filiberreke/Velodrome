# Zwift Ride controller-test (featurebranch)

De bestaande **Instellingen** (F10) hebben nu een tab **Controller**.
Deze tab toont de fysieke digitale Ride-knoppen, ingedrukt/losgelaten, en de gecombineerde analoge stuurwaarde (-100..100). Y, Z en DROP-knoppen worden zichtbaar ook zonder bestaande mapping. Vanaf fase 3 kun je hier ook acties per context opnieuw toewijzen en bewaren; zie [configureerbare knopmapping](docs/README_zwift_ride_phase3.md).

## Technisch
- De bridge blijft de bestaande `type=button`-berichten sturen voor compatibiliteit.
- Nieuw en onafhankelijk diagnosebericht: `{"type":"controller_button","source_button":"B","mapped_action":"B","pressed":true}` of `pressed:false`.
- Bij BLE-verbinding / -verlies: `{"type":"controller_connection","connected":true/false}`.
- De bestaande `type=steering`-berichten voeden de analoge indicatie.
- Tijdens de actieve Controller-tab blokkeert Godot spelacties en analoge sturing. Buiten de test routeert Godot ruwe druk/loslaat-events volgens het actieve profiel; legacy `type=button`-kopieën worden onderdrukt.
- Bij verbreken van de Ride-verbinding worden vastgehouden knopindicaties vrijgegeven.

## Grenzen
- Nog geen uitleg in de tv-intro.
- Het display ontvangt geen volledige per-paddle-waarde, alleen de bestaande samengevoegde stuurwaarde.
- Het Godot-menu kan de **fysieke versnellingsregeling in de Python-bridge** nog niet pauzeren; echte schakelpaddles kunnen tijdens de test de trainer-virtuele versnelling veranderen. Test daarom bij voorkeur zonder te trappen. Voor volledige isolatie moet de bridge een aparte testmodus ontvangen.
- Automatische Godot-runtime- en virtuele-bridge-tests staan in `tests/run_ride_mapping.py`. Fysieke hardwarevalidatie blijft afzonderlijk nodig.

## Uitvoering tests
`godot --headless --path game --script res://tests/test_controller_settings.gd`
en de bestaande navigatietest `res://tests/test_bridge_navigation.gd`.
