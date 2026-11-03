# Zwift Ride controller-test (featurebranch)

De bestaande **Instellingen** (F10) hebben nu een tab **Controller**.
Tijdens deze tab toont het spel de actuele fysieke digitale Ride-knop, ingedrukt/losgelaten, en de gecombineerde analoge stuurwaarde (-100..100). De labels zijn vooralsnog alleen-lezen. Y, Z en powerknoppen worden zichtbaar ook zonder bestaande mapping.

## Technisch
- De bridge blijft de bestaande `type=button`-berichten sturen voor compatibiliteit.
- Nieuw en onafhankelijk diagnosebericht: `{"type":"controller_button","source_button":"B","mapped_action":"B","pressed":true}` of `pressed:false`.
- Bij BLE-verbinding / -verlies: `{"type":"controller_connection","connected":true/false}`.
- De bestaande `type=steering`-berichten voeden de analoge indicatie.
- Tijdens de actieve Controller-tab blokkeert Godot `type=button`-spelacties en analoge sturing. De nieuwe diagnoseberichten zijn altijd non-activerend.
- Bij verbreken van de Ride-verbinding worden vastgehouden knopindicaties vrijgegeven.

## Grenzen van versie 1
- Geen knopmapping bewerken en nog geen uitleg in de tv-intro.
- Het display ontvangt geen volledige per-paddle-waarde, alleen de bestaande samengevoegde stuurwaarde.
- Het Godot-menu kan de **fysieke versnellingsregeling in de Python-bridge** nog niet pauzeren; echte schakelpaddles kunnen tijdens de test de trainer-virtuele versnelling veranderen. Test daarom bij voorkeur zonder te trappen. Voor volledige isolatie moet de bridge een aparte testmodus ontvangen.
- Geen fysiek hardware- of Godot-runtime-resultaat is in deze branch bevestigd. De test is toegevoegd als `game/tests/test_controller_settings.gd`.

## Uitvoering tests
`godot --headless --path game --script res://tests/test_controller_settings.gd`
en de bestaande navigatietest `res://tests/test_bridge_navigation.gd`.
