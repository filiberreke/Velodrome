# Standaard naar de binnenbaan

AI-renners in scratch en puntenkoers kiezen standaard de binnenste rijlijn zodra die én de volledige route ernaartoe vrij zijn. Dat geldt ook tijdens het optrekken: er is geen vaste wachttijd.

Een bruikbaar wiel volgen of zoeken, een aflossing, uitwijken, een aanval en sprintpositionering blijven geldige redenen voor een hogere lijn. Een oude rijlijnvergrendeling alleen houdt een vrije renner niet meer onnodig hoog. Als de binnenbaan of de afdaling bezet is, blijft de bestaande tactische keuze gelden; de nieuwe voorkeur duwt niemand alvast een tussenbaan in.

De routecontrole gebruikt de fysieke afstand rondom de piste, ook bij een rondeverschil of over de startlijn. Ze houdt rekening met snelheidsverschillen tijdens de afdaling en met reeds geplande routes van eerder verwerkte AI-renners. Een eigen eerdere standaardafdaling wordt afgebroken als de route ondertussen bezet raakt. De bestaande directe conflictcontrole blijft daarna actief. Dit is een defensieve AI-planner, geen garantie op volledige botsingsvrije wedstrijdsimulatie.

De speler houdt de bestaande rijlijnbediening. Achtervolging en ploegenachtervolging houden hun eigen rijlijnbesturing; de overige bestaande AI-modi kozen al standaard de binnenlijn. Er is geen nieuwe optie of instelling nodig in het spel. `prefer_inside_when_free=false` is uitsluitend een ontwikkelaarsoptie om de voorkeur uit te schakelen voor vergelijkingen.

Hoger rijden was al langer in de baanfysica: de werkelijke routeafstand volgt de geometrie en banking. Deze wijziging past CP, W′, drafting, de snelheidsberekening, de baangeometrie en de jury niet aan. De oorspronkelijke Python A/B-resultaten voor TUSSENSPRINT zijn niet opnieuw berekend en gelden niet als meting van deze latere rijlijnwijziging.

Zie [tests en uitgevoerde vergelijkingen](../verification/inside_lane/README.md).
