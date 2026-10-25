# Achtervolging HUD: lopend verschil en segmentgemiddelden

Installatie: pak uit in de bestaande projectmap waar project.godot staat en vervang bestanden. Vereist de vorige halve-ronde-HUD-patch. Alleen gewijzigde bestanden en deze README zijn opgenomen.

Wijzigingen:
- Het blauwe opschrift 'VERSCHIL' is verwijderd.
- Zodra de eerste renner een nieuw 125-meterpunt passeert, loopt het verschil vanaf die doorkomst op. Bij de tweede doorkomst stopt het op het exacte tijdsverschil aan hetzelfde meetpunt. Dat verschil blijft staan tot het volgende meetpunt.
- Plus betekent voorsprong voor jou; min betekent achterstand. Gelijkstand wordt 0.00 s, zonder negatief nul. Dit is nu het verschil op de totale verstreken tijd aan hetzelfde afstandspunt, zodat het oplopende verschil en het uiteindelijke verschil op elkaar aansluiten.
- Het tijdvak van de tweede renner blijft leeg tot diens doorkomst.
- Onder iedere segmenttijd staan kleiner de gemiddelde snelheid (km/u) en het tijdgewogen gemiddelde vermogen (W) over datzelfde 125-metersegment. Tijdens het wachten blijven ook die gegevens voor de tweede renner leeg.
- Wit/rood volgt de actuele leiding aan het getoonde meetpunt; de vaste naamposities en transparantie blijven behouden.
- Volledige rondetijden in de uitslag blijven per 250 meter. De nieuwe gemiddelden betreffen de 125 meter van de HUD, niet de hele rit.

Metingen:
Speler/AI-vermogen wordt per simulatiestap geïntegreerd, inclusief gedeeltelijke stappen bij een doorkomst en tijd die stilstaan wordt doorgebracht. Gemiddelde snelheid = 125 meter / segmentduur. Bij opgeslagen ritten wordt het opgenomen vermogen tussen de bewaarde meetpunten geïnterpoleerd en geïntegreerd. De nauwkeurigheid daarvan wordt begrensd door de opgeslagen metingen.

Getest met Godot 4.7.2 headless:
- Scriptcontrole en hoofdscene laden geslaagd.
- HUD-test geslaagd: oplopen met + en -, stoppen bij tweede doorkomst, teken en gelijkstand, gemiddelden, naamlimiet en scratch-weergave.
- Achtervolgingstests 1 en 4 km tegen AI en opgeslagen rit geslaagd, met alle 125-meterdoorkomsten, eindtijden en gemiddelden.
- Extra controles: wisselend vermogen, stilstand, meerdere doorkomsten binnen één stap en integratie van gedeeltelijke opgeslagen meetintervallen.

Niet getest: visuele speeltest/GPU-weergave en fysieke trainer. Godot meldt in deze omgeving dat de certificatenopslag niet gelezen kan worden; geen scriptfouten in de genoemde controles. Netwerkfunctionaliteit niet getest.

Zelf testen:
1. Start een achtervolging. Controleer dat 'Verschil' weg is en dat nog geen fictieve tijden verschijnen.
2. Passeer als eerste een lijn: jouw segmenttijd en gemiddelden verschijnen; centraal loopt + op en rechts blijft de segmentinformatie leeg.
3. Laat de tegenstander passeren: het verschil stopt, diens segmenttijd en gemiddelden verschijnen.
4. Laat de tegenstander als eerste de volgende lijn passeren: het verschil loopt negatief op. Het eigen segmentvak blijft leeg totdat jij passeert.
5. Herhaal met een opgeslagen rit en controleer dat diens wattagegemiddelde uit die rit komt.
