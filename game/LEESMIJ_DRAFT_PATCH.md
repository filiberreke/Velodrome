# Velodrome 250 X - draft HUD, CSV en snelheidsfactor (22 oktober 2026)

## Installatie
Maak eerst een back-up. Kopieer `main.gd` uit deze ZIP over het gelijknamige bestand in de **root van je bestaande Godot-project**. Houd alle overige bestanden van de werkende X-versie, waaronder `scratch_lap_rules.gd`, scènes, assets en de trainerbridge, zoals ze zijn. Deze ZIP is een scriptpatch, **geen zelfstandig Godot-project**. De andere drie bestanden zijn ter referentie/ongewijzigd uit de aangeleverde ZIP.

## Wijzigingen (alleen scratch)
- Basis drafting uit wielafstand/rijstrook is niet aangepast.
- De werkelijke maximale luchtweerstandsreductie blijft 69%, gelijk voor speler en AI.
- Nieuwe snelheidsfactor op de draftsterkte: 65% bij <=20 km/u, lineair tot 100% bij >=50 km/u. Dit betekent niet dat een renner automatisch 69% krijgt: afstand/zijligging/peloton bepalen nog steeds de basissterkte. Onder 16,2 km/u blijft de bestaande draftdetectie uitgeschakeld.
- Dezelfde gecorrigeerde draftsterkte wordt gebruikt voor de spelerfysica, AI-fysica en de AI-berekening van het benodigde vermogen.
- HUD en CSV-kolom `draft_pct` rapporteren de werkelijke luchtweerstandsreductie uit de gebruikte draftsterkte, niet langer de verouderde 48%-waarde.
- De andere koersmodi houden hun bestaande 48%-fysica en HUD/CSV-berekening.
- CP/W', sprint, finish, wielvolg-/tactiekregels en rondewinstregels zijn niet gewijzigd.

## Test
1. Start scratch met 5 ronden en rijd op een vaste snelheid een duidelijk wiel in met zo weinig mogelijk zijdelingse afwijking. Controleer of Slipstream zichtbaar oploopt.
2. Test op ongeveer 25 km/u en 45 km/u bij vergelijkbare afstand en zijligging: bij 45 km/u moet het gerapporteerde voordeel groter zijn.
3. Vergelijk bij gelijkmatige snelheden de HUD met de `draft_pct` uit een geëxporteerde CSV. Door de sampling en tijdstippen kan een kleine afwijking optreden.
4. Controleer een niet-scratch spelmodus: die blijft op de oude 48%-maximaalwaarde en oudere dynamiek.

Let op: dit is een **statisch gecontroleerde patch**, niet uitgevoerd in een Godot-runtime. Het is een bewuste nieuwe balansparameter en moet in-game worden gevalideerd.
