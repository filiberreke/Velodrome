# Solo-tijdrit — experimentele branch

Gebaseerd op `feature/ivory-blue-menus`, zonder wijzigingen aan `main`.

- Wedstrijdkaart Tijdrit: 500 m (2 ronden) of 1000 m (4 ronden).
- De speler start vanuit stilstand op de bestaande achtervolgingslijn.
- Solo: 1 renner, geen AI-tegenstander, geen drafting en geen arcadeboost.
- Bestaande pursuit-fysica, ronde- en halve-ronderegistratie (125 m).
- Selecteer referentie: laatste rit (standaard), snelste rit laatste 60 dagen, all-time snelste rit, of geen.
- Bij iedere 125 m wordt de cumulatieve tussentijd vergeleken met dezelfde checkpoint van de gekozen referentie.
- Alle volledige tijdritten worden automatisch bewaard in `user://time_trial_history.json`, afzonderlijk per afstand. Geen top-10-trimming.
- Records toont top 10 plus all-time, recent en laatste prestatie.

## Nog te controleren
Dit is een implementatievoorstel in de GitHub-featurebranch; niet lokaal gecompileerd of headless gevalideerd. Controleer met Godot 4.7.2: menustart, solo-opstelling, 2/4 ronden, de 125 m-meldingen, automatische opslag, records en herstart. Controleer vooral dat de bestaande achtervolgings- en ploegenachtervolgingslogica niet geraakt is.

De tijdrit-resultaten zijn automatisch; eigen gespeelde ritten van andere disciplines blijven ongemoeid.
