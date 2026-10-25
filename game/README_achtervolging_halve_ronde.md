# Achtervolging: tussentijden elke halve ronde

Installatie: pak deze ZIP uit in je bestaande projectmap (waar project.godot staat) en vervang de bestanden. Vereist de vorige achtervolgings-HUD-patch. Alleen gewijzigde bestanden en deze README zitten in de ZIP.

De HUD meet nu elke 125 meter, zowel aan de eigen startlijn als aan de lijn aan de overkant. Naast iedere naam staat de tijd over het betreffende 125-metersegment. Zodra de eerste renner een nieuw meetpunt passeert, verschijnt diens segmenttijd meteen. Het andere tijdvak en het verschil blijven leeg totdat de andere renner hetzelfde meetpunt bereikt. Er worden nooit verschillende segmenten vergeleken. Als de snelste renner alweer een volgend meetpunt passeert, schuift het display door naar dat nieuwe meetpunt.

Wit/rood blijft de wedstrijdleider/tweede aangeven op basis van opgetelde tijden aan het meest recente gemeenschappelijke meetpunt. Tijdens het wachten blijft die laatst vastgestelde kleurverdeling behouden. Bij gelijke opgetelde tijden of vóór de eerste vergelijking zijn beide kanten neutraal. Rondenummer, totale tijd rechts en volledige rondetijden in de uitslag blijven ongewijzigd.

De 125-meterdoorkomst wordt binnen de simulatiestap geïnterpoleerd. Tegen een opgeslagen rit worden de tijden uit diens afstand/tijdgegevens afgeleid; bestaande opgeslagen ritten blijven bruikbaar.

Getest met Godot 4.7.2 headless: scriptcontrole, uitgebreide HUD-test, volledige achtervolgingstests tegen AI en opgeslagen rit over 1 en 4 km, en hoofdscene laden. Alles geslaagd. Tests controleren direct verschijnen van de eerste tijd, leeg tegenstandervak en verschil tijdens wachten, aanvulling na tweede doorkomst, kleuren, alle 125-meterdoorkomsten, exacte opgeslagen-rit-interpolatie en eindtijden.

Niet getest: visuele leesbaarheid tijdens het spelen, GPU-weergave en een fysieke trainer. De omgeving meldt een fout bij het lezen van de certificatenopslag; geen scriptfouten in deze controles. Netwerkfunctionaliteit is niet getest.

Zelf controleren:
1. Start achtervolging tegen AI: na de eerste 125 m verschijnt één segmenttijd; het andere vak blijft leeg.
2. Na de tweede doorkomst verschijnt de tweede segmenttijd en hun verschil.
3. Na nog eens 125 m herhaalt dit zich: vorige tijden worden niet met de nieuwe vergeleken.
4. Herhaal met een opgeslagen rit en over 4 km; de normale rondetijden in de uitslag blijven per 250 m.
