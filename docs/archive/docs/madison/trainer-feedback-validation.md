# Validatie — 2026-11-12

Branch: `feature/madison-trainer-feedback`. Engine: Godot **4.6.3** (beschikbaar
in deze omgeving); het project vermeldt 4.7 en de README 4.7.2. Er is geen fysieke
trainer aangesloten. De nieuwe code is dus niet op 4.7.2 of op BLE-hardware getest.

## Resultaten

| Controle | Resultaat |
| --- | --- |
| Nieuwe Godot feedbackmodule + echte UDP-pakketten | geslaagd, exit 0 |
| Nieuwe Godot productie-integratie Madison | geslaagd, exit 0 |
| Bestaand `test_trainer_control.gd` | geslaagd, exit 0 |
| Bestaand `test_training_signal_pause.gd` | geslaagd, exit 0 |
| Bestaand `test_madison.gd` | geslaagd, exit 0 |
| Bestaand `test_madison_feedback.gd` | geslaagd, exit 0 |
| Bestaand `test_madison_v02_training.gd` | geslaagd, exit 0 |
| Bestaand `test_madison_flow.gd` | geslaagd, exit 0 |
| Bestaand `test_madison_contact.gd` | geslaagd, exit 0 |
| Bestaand `test_derny_training.gd` | geslaagd, exit 0 |
| Bestaand `test_derny_session.gd` | geslaagd, exit 0 |
| Bestaand `test_piste_exercises.gd` | geslaagd, exit 0 |
| Bestaand `test_free_training.gd` | geslaagd, exit 0 |
| Python bridge-unittest discovery, inclusief nieuwe FTMS-pulstest | 113 tests: 102 geslaagd, 11 overgeslagen |
| Aanvullend workout SIM/ERG/simulatorharnas | 1 test geslaagd (een van de 11 hierboven overgeslagen tests) |
| `git diff --check` | geslaagd |

De 11 overgeslagen tests vereisen `GODOT_BIN`; één daarvan is daarna afzonderlijk
met het volledige simulatorharnas uitgevoerd:

```sh
GODOT_BIN=/usr/local/bin/godot PYTHONPATH=bridge/tests python3 -m unittest \
  test_virtual_bridge_ui.VirtualBridgeTests.test_saved_workout_erg_free_and_ramp -v
```

`test_workout_virtual_bridge.gd` is aanvankelijk ten onrechte rechtstreeks zonder
zijn twee poortargumenten gestart: dat gaf een indexfout en timeout. De correcte
harnasaanroep hierboven levert simulator, poorten en telemetrie en slaagt.
De overige tien optionele Python/Godot-integratietests zijn niet uitgevoerd.

Voor de koude assetimport is de bestaande CI-procedure gevolgd: Blender-bronnen
tijdelijk geïsoleerd, PNG-importmetadata opnieuw aangemaakt. Alle bronbestanden en
bestaande importmetadata zijn daarna teruggezet; er worden geen assetwijzigingen
meegecommit. Lokale XDG-directories onder /tmp maakten Godot-data/cache schrijfbaar.
De netwerk-sandbox blokkeerde aanvankelijk lokale UDP-sockets; de geslaagde
netwerktests zijn met toegestane lokale sockets buiten die sandbox uitgevoerd.

## Dekking van de gevraagde scenario's

1. Normaal rijden: geen offset; bestaande routehelling/aero blijven behouden.
2. Geven: positieve sterke puls en effectief positief `set_grade`-commando.
3. Ontvangen: negatieve sterke puls en effectief negatief commando.
4. Zwak/krachtig: kleinere impuls geeft kleinere kracht; begrenzing wordt gemeld.
5. Herhaald: nieuwe puls vervangt vorige; geen optelling of oude puls bij herstel.
6. Onderbreking: productie-annuleringssignaal wist feedback.
7. Stop tijdens aflossing: gebeurtenis/deadline worden gewist, trainer krijgt Reset.
8. Herstel: normale helling en standaardramp; FTMS-writer herstelt wegparameters.
9. Geen dubbele versnelling: eenmalige productie-impuls, uitgangsberekening verandert
   geen snelheden; ongeclipte krachtpuls integreert tot dezelfde delta-v.
10. Regressies: bestaande Madison-mechanica/contact, trainerownership/retries,
    signaalpauzes, Derny, piste, vrij rijden en workout SIM/ERG gecontroleerd.

`trainer-feedback-debug.log` en `trainer-feedback-integration-debug.log` bevatten
gefilterde diagnostiek van de nieuwe tests, **gesimuleerd zonder hardware**.
De waarschuwing over een verlopen aflossingscommando is bewust opgewekt door de
test zonder ACK en controleert Reset en bescherming tegen een late ACK.
`confirmed_simulation=null` in de Godot-integratielog is verwacht: die test
registreert de productie-uitvoer met een spy; de Python-test controleert de
werkelijke FTMS-bytes via een fake FTMS-controller.

## Nog niet aangetoond

- Fysiek duidelijk voelbare feedback, BLE-/mechanische latency, firmwaregrenzen,
  comfort en bruikbaarheid van de voorlopige parameters op de Zwift Ride.
- Exacte trainerbelasting op basis van de Godot-snelheid na de worp. De bridge
  ontvangt die snelheid niet; normale SIM-belasting blijft vliegwielafhankelijk.
- Exacte gelijkheid van fysieke/virtuele energie: hardwaremassa en wegmodel zijn
  ongekalibreerd; de bestaande slinger is geen energiebehoudend passief model.
- Actief vooruit trekken door een trainer die geen motoraandrijving ondersteunt.
- Volledige speltestsuite, grafische validatie en een testrun op Godot 4.7.2.

De concrete hardwareprocedure en instelparameters staan in
[trainer-feedback.md](trainer-feedback.md).
