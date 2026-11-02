# Vliegende tijdritstart — 2 november 2026

Gebouwd op main `f6103b4`, inclusief de eerdere geneutraliseerde groepsstart.
Getest met Godot 4.7.2 op Windows, met geïsoleerde testgegevens.

Elf testreeksen slagen:

- `test_flying_time_trial.gd`: 9247 controles, nul fouten.
- `test_neutral_start.gd`
- `test_solo_time_trial_hud.gd`
- `test_analog_steering.gd`
- `test_trainer_control.gd`
- `test_hud.gd`
- `test_strava_metadata.gd`
- `test_records.gd`
- `test_pursuit.gd`
- `test_team_pursuit.gd`
- `test_infinity_scoreboard.gd`

De nieuwe test rijdt volledige 500 en 1000 m-tijdritten op 10 en 60 tijdstappen per
seconde. Gecontroleerd: alle afstandsmeldingen, geen voortijdige wedstrijdtijd of
splits, behoud van positie en snelheid over GO, volledige wedstrijdafstand na de
aanloop, correcte finishpassage, doorlopende demo- en traineropnames, traineruitval
en hervatten, menukeuze, reset en gescheiden referenties/records per startwijze.
Oude records zonder startwijze worden als staande start behandeld.

De echte renderer heeft zeven beelden gemaakt: instellingen, 200/150/100/50 meter,
GO en het recordscherm. Tijdens de aanloop staan de aftelmeters uitsluitend in
het donkere meldingsvak; de grote letters verschijnen pas bij GO.
Instellingen, aftelmeters, GO en recordfilters zijn visueel
gecontroleerd op 1920 × 1080. `capture_flying_time_trial.gd` reproduceert de beelden.

Bestaande geïmporteerde assetcaches gebruikt. De omgeving meldt de bekende
certificaatopslagfout en model-UID-waarschuwingen met padfallback. Geen fysieke
trainerhardwaretest uitgevoerd.
