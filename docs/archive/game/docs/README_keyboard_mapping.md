# Instelbare toetsenbordbediening

Basis: v0.2. Open de verbindingsinstellingen en kies **Toetsenbord en controller instellen**, of open **Instellingen > Toetsenbord**. Een Ride-controller is niet nodig. De toetsenbordbediening staat standaard aan en kan bij de verbindingsinstellingen worden uitgezet. De sneltoets voor Instellingen blijft beschikbaar.

Er zijn afzonderlijke profielen: Algemeen, Menu, Trainer aangesloten en Zonder trainer (simulator), plus Madison met trainer en Madison zonder trainer. Bij Madison blijft A standaard grijpen/loslaten en sturen de pijltjes links/rechts; ook deze toetsen zijn instelbaar. Tijdens het rijden wordt het passende profiel automatisch gekozen. Een tijdelijke storing van een eerder aangesloten trainer schakelt de sessie niet over naar gesimuleerd vermogen.

| Standaardtoets | Met trainer | Zonder trainer |
| --- | --- | --- |
| Omhoog / omlaag | Zwaarder / lichter schakelen in SIM | Vermogen +25 / -25 W |
| A / D | Links / rechts sturen | Links / rechts sturen |
| C / Q | Volgende / vorige camera | Volgende / vorige camera |
| B vasthouden | Achteruitkijken | Achteruitkijken |
| V | Rennerinformatie wisselen | Rennerinformatie wisselen |
| Escape | Pauze / training stoppen | Pauze / training stoppen |
| Links / rechts | Derny-tempo verlagen / verhogen | Derny-tempo verlagen / verhogen |
| Spatie | — | Simulatorsprint |

Alle acties, inclusief menu, Instellingen, opname bewaren en herstart, zijn opnieuw toe te wijzen. Klik op de toets naast de actie en druk een toets of combinatie met Ctrl/Shift/Alt in. De wijziging wordt direct bewaard. Dubbele toetsen binnen een profiel en conflicten met de algemene sneltoets worden geweigerd; dezelfde toets mag in verschillende profielen wel een andere functie hebben. Vrijmaken, annuleren en alle standaardtoetsen herstellen zijn beschikbaar.

Instellingen staan in `user://keyboard_mapping.json`, apart van de bestaande Ride-knopmapping. Ongeldige opgeslagen gegevens vallen terug op de standaardbediening zonder het bestand te overschrijven. Toetsenbordschakelen vereist de bijbehorende bridge-versie met het lokale `shift`-commando. Het gebruikt dezelfde virtuele versnellingen als de Ride-paddles; ERG, uitgeschakelde trainers en andere actieve eigenaren worden gerespecteerd. Er wordt geen verbinding met fysieke hardware getest door de automatische tests.

Validatie: `game/tests/test_keyboard_mapping.gd`, bestaande controller-/Ride-/trainingscontroles en `python -m unittest discover -s bridge/tests -q`.


## Focus in menu’s

Eén druk op een pijltjestoets verplaatst de focus één keer. Links/rechts volgt de zichtbare rij tegels, omhoog/omlaag volgt de kolom. Aan de rand springt de focus niet naar een andere rij. Tab en Shift+Tab volgen de zichtbare leesvolgorde, met de terugknop bovenaan. Verborgen of uitgeschakelde opties worden overgeslagen; de focus blijft binnen het actieve scherm of venster.

Bij numerieke velden en schuifregelaars ga je met omhoog/omlaag naar het vorige/volgende bedieningselement en pas je de waarde met links/rechts aan. Gewone tekstvelden blijven met het toetsenbord bewerkbaar. Trainingspagina’s beginnen bij de eerste trainingskeuze; na het afronden van een rit blijft het resultaat zichtbaar.

Regressietest met echte toetsdrukken: `godot --headless --path game --script res://tests/test_menu_navigation.gd`.
