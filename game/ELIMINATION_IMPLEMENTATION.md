# Afvalling: implementatieplan voor Godot

Status: work in progress. Deze featurebranch wijzigt geen bestaande spelmodus.
De nieuwe `elimination_race_rules.gd` is een eerste, nog niet in main.gd geïntegreerde jury-module.

## Regels en meetpunt

- Gebruik de **achterste rand van de achterband** als meetpunt, niet het bestaande FRONT_WHEEL_TIP_M.
- Voed `sample(rear_positions, start_time_s, dt)` iedere simulatietick met absolute, doorlopende posities van alle deelnemers.
- De eerste eliminatielijn ligt na 500 m raceafstand (na de afzonderlijke geneutraliseerde start). Daarna iedere 500 m.
- Registreer een interpolatietijd voor IEDER nog actief achterwiel. Stel de afvaller pas vast nadat ieder actief achterwiel de lijn heeft gepasseerd.
- De module retourneert `photo_review` bij quasi gelijke tijden. Dit moet op UI-/wedstrijdniveau afgehandeld worden.
- Met twee renners schakelt de wedstrijd naar eindsprint en is er geen eliminatie meer.

## Aandachtspunt bij laps

Een gedubbelde renner kan geen normale 500 m-passage afwachten indien de jury hem eerder uit koers neemt. Voeg voor de volledige UCI-regels een aparte regeling voor dubbelen/opgaven toe, en zorg dat een enorm geloste renner een fase niet eindeloos ophoudt.

## Beeld

- Bestaand: `main.gd` beschikt over `finish_photo_viewport`, `finish_photo_camera` en `_grab_finish_photo()`.
- Niet zomaar de bestaande foto gebruiken: die is op de winnaar en voorwiel gericht. De eliminatiefoto kijkt uitdrukkelijk vanaf **vóór de meetlijn, aan de aanrijzijde** in de richting van de naderende renners, zodat het achterwiel zichtbaar is wanneer het de lijn overschrijdt. Dus niet de bestaande camerapositie +3.4 m na de lijn hergebruiken: kies een positie met negatieve afstand t.o.v. de meetlijn en richt op het achterwielcontactvlak. Verifieer de cameraoriëntatie visueel in Godot (positie 'voor de meet' bedoelt aanrijzijde).
- Maak bij iedere passage een freeze-frame met alle laatste achterwielen, gefotografeerd vanaf de aanrijzijde van de meetlijn, met finishlijn als verticale referentie en een eventuele fotofinish-overlay. De juridisch beslissende tijd blijft uit de geïnterpoleerde achterwielpassage komen.
- Koppel een tijdelijke Texture2D-presentatie aan `infinity_scoreboard.gd` / `infinity_screen.gd`. Herstel daarna de normale scoreboardtexture. De foto is dus een race-uitzending, niet het scorebord permanent vervangen.
- Houd de visuele snapshot gescheiden van het tijdsoordeel, dat uit de interpolatie volgt.

## Afgevallen renner

- Na definitieve jurybeslissing: markeer als niet meer deelnemend aan de race-AI/drafting/klassering.
- Laat de renner verder uitbollen in zijn eigen animatiestatus. Gebruik niet blindelings het bestaande `finish_times`-veld: dat is ontworpen voor normale finishers.
- Plan pas aan de overkant een veilige uitrit naar de grijze strook. Langzaam uitwijken met ruimtecontrole en vervolgens stoppen aan de infield-box.
- `rennersboxen/six_boxes.gd` heeft zes LANDENboxen, geen individuele box voor elk van 16 renners: match op toegewezen land en bepaal een vrije stoppositie, ook als meerdere renners hetzelfde land hebben.

## HUD

- Centraal tijdelijke aankondiging `AFGEVALLEN — NAAM` gedurende bijvoorbeeld 3 s, niet over kritische vermogensmeters.
- Wanneer speler afvalt: stop wedstrijdinput en open zijn uitslag, terwijl de race voor AI kan doorgaan indien gewenst.

## Validatie

- 16 deelnemers: 14 eliminaties + eindsprint, zonder dubbele eliminatie.
- Exacte achterwielvolgorde, ook wanneer wielpassages in dezelfde fysicatick plaatsvinden.
- Twee renners bijna gelijk: fotofinish/juryreview.
- Geen nog actieve renner krijgt de uitbol-animatie.
- Afgeregelde renners blokkeren de wedstrijd niet.
- Fototextuur verschijnt en verdwijnt op het bestaande scherm.
- Stoppositie bij de juiste landenbox en zonder overlap met andere uitvallers.
- Regressiontests: scratch, puntenkoers en pursuit onveranderd.
