# Kortere wedstrijdintro en lichtshow

De eerste wedstrijd van een spelsessie krijgt een intro van 26 seconden. Achtervolging en ploegenachtervolging krijgen 28 seconden, met een vast tegenstandershot en profielkaart van seconde 8 tot 10. Een nieuwe wedstrijd, reset of disciplinewissel binnen dezelfde sessie herhaalt de intro standaard niet. Een overgeslagen of afgebroken eerste intro telt ook als getoond. Opnieuw starten van de game begint een nieuwe sessie.

Onder Instellingen → Beeld staat **Intro bij elke wedstrijd tonen**, standaard uit. De bestaande knop Toepassen en bewaren bewaart deze keuze als `[presentation] always_show_intro` in `user://display_settings.cfg`. Aan herhaalt de intro bij elke wedstrijd; terug uitschakelen behoudt de sessiegeschiedenis.

De commentatoren blijven 2,2 seconden in beeld met alleen “Welkom bij Velodrome!”. De tweede zin en de tweede mondanimatie lopen door terwijl de camera al vertrekt. De bestaande intro bevat ondertitels en mondanimaties; deze wijziging voegt geen ingesproken audiobestanden toe.

De gewone route steekt eerst het middenterrein over en volgt de rugzijde van de piste langs de open rennersboxen. Beide routes maken vervolgens de volledige Tour d’Ambiance-bocht met een brede beeldhoek van 64 graden. Het hondje, het Wout-spandoek en de pizza-eters blijven onderdeel van de omgeving, zonder zooms of afzonderlijke stilstaande shots. Daarna passeert de camera de open westkant van de interviewtent, zodat beide interviews zichtbaar zijn. Ze rondt de tent aan de zuidkant en sluit direct aan op de echte chase-positie van de speler. De laatste beweging behoudt continuïteit van positie en snelheid en een uitsluitend dalende hoogte. Bij achtervolging vindt deze boog pas na het tweesecondenprofiel van de tegenstander plaats.

Zes bewegende schijnwerpers combineren echte SpotLight3D-verlichting met zichtbare bundelmeshes voor GL Compatibility. Bestaande verlichting wordt tijdelijk gedimd en keert voor het einde geleidelijk terug. Overslaan en annuleren herstellen de opgeslagen lichtsterktes en zichtbaarheid onmiddellijk.

De afzonderlijke `intro_opponent_card.gd` kan later verder worden vormgegeven. Ze toont de gekozen naam, beschikbare nationaliteit en één portret per tegenstander (ook bij ploegen van vier). Portretten zijn eenmalige renders van de bestaande rennerfiguren. AI-kaarten gebruiken de werkelijke pacer-CP, W′ en het berekende wedstrijdvermogen. Bij een opgeslagen rit staan naam, afstand en tijd in beeld; er worden geen AI-capaciteiten verzonnen. Zonder nationaliteitsmetadata staat er “Land onbekend”.

De kijkrichting interpoleert horizontale draaihoek en verticale kijkhoek afzonderlijk. Zo kan een doelpunt niet onder of door de camera schuiven. Bij brede draaien komt de blik dichter bij de horizon; de stadiontribunes blijven zichtbaar. De routepunten blijven behouden. Een test bewaakt dat de panoramische vlucht nooit meer dan 20 graden neerwaarts kijkt.

De podiumwand gebruikt een sponsormatrix van vier kolommen en zes rijen met afwisselend de bestaande witte en blauwe Velodrome-afbeeldingen. Beide zijden zijn leesbaar bedrukt, zonder de logo's te vervormen. De afzonderlijke `podium_sponsor_wall.gd` bouwt deze wand op het bestaande podium.

De race blijft bevroren tijdens de intro. Na afloop en bij overslaan blijft de bestaande stilstandscontrole met countdown actief.

## Verificatie

- `tests/test_broadcast_intro.gd`: gewone koers, individuele achtervolging, ploegen van drie en vier; sessiegeschiedenis; overslaan en annuleren; instelling toepassen, opslaan en herladen; kaarttijd en camerastilstand; continue cameraverbindingen; dalend einde; tentvrijloop; echte startpositie; bevroren race; trainercontrole; licht- en portretopruiming. Resultaat: `BROADCAST_INTRO_OK`.
- `tests/test_team_presentation.gd`: `TEAM_PRESENTATION_OK`.
- Godot 4.7.2 / OpenGL Compatibility op Intel Iris Xe: gerenderde controles van cabine, lichtshow, rennersboxen, Tour-bocht, open kant van de interviewtent, kaartjes, spelerspositie en instellingen; previews van scratch (26 seconden) en individuele achtervolging (28 seconden) op 24 fps.
- De bestaande `test_pursuit.gd` faalt op “Actual countdown launches both riders from a standing start”. Dezelfde fout is bevestigd met de oorspronkelijke GitHub-intro, vóór deze wijziging. Dit is geen geslaagde regressiecheck.
- De lokale runtime meldt een fout bij het lezen van de Windows-certificaatopslag. De uitgebreide introtest meldt daarnaast materiaalwaarschuwingen bij het direct vrijgeven van de testscene; de afzonderlijke beeldcaptures eindigen zonder script- of shaderfouten.

Captures opnieuw maken: `godot --path game --script res://tests/capture_broadcast_intro.gd -- pursuit quick settings`. Gebruik `turns podium video` voor scratch en `pursuit turns video` voor achtervolging. Frames verschijnen onder `verification/intro_tour_v4` op 24 fps. Gebruik `team four quick video` voor de vierpersoonsploeg.
