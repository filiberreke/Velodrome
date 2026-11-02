# Geneutraliseerde start — controle 2 november 2026

Basis: `642feef` (main). Getest met Godot 4.7.2.

- Nieuwe starttest geslaagd op 10 en 60 stappen per seconde voor scratch,
  puntenkoers en afvalling met zestien deelnemers.
- Dezelfde test controleert de werkelijke aftelovergang, stuurbediening,
  uitgeschakelde boost, stilstand, onvoldoende startsnelheid, traineruitval,
  doorlopende demo- en traineropnames en de bestaande staande tijdritstarts.
- Bestaande controles geslaagd: analoge bediening, trainerweerstand, HUD,
  puntenkoers, afvallingsregels, gedeelde verkeerslogica, achtervolging,
  ploegenachtervolging, Strava-metadata en het stadionscherm.
- De oprijronde en het vliegende startsein zijn met de echte renderer vastgelegd
  en visueel gecontroleerd. De melding past in beeld; de klok staat vóór het sein
  op nul en de rondeteller toont NEUTRAAL.

Drie bestaande tests falen identiek met de oorspronkelijke `main.gd` uit de
basiscommit en met de wijziging:

- `test_bridge_protocol.gd`: twee controles verwachten nog twee rijlijnen per
  analoge druk, terwijl de huidige bediening één rijlijn per druk gebruikt.
- `test_menu.gd`: zeven controles gebruiken verouderde aannames over de tijdrit
  en de daaropvolgende menustatus.
- `test_heart_rate_export.gd`: een upload-testdubbel verwacht twee argumenten voor
  `begin_export`, terwijl de huidige aanroep meer argumenten meegeeft; de
  daaropvolgende controle leest daardoor een lege export.

Deze bestaande tests zijn niet aangepast in deze branch. Hun fouten staan los
van de nieuwe startfase. De eigen traineropnametest controleert tijd en afstand
over het vliegende startsein. Er is geen fysieke trainerhardwaretest uitgevoerd.
