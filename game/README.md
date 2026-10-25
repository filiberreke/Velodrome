# Velodrome 250 X — achtervolging

23 oktober 2026. **Dit is een patch met uitsluitend gewijzigde en nieuwe bestanden**
voor de versie met HUD v2. De bestaande assets, `project.godot` en hoofdscene blijven nodig.

## Installeren

1. Sluit de game en bewaar desgewenst een kopie van je huidige project.
2. Pak deze ZIP uit in de bestaande projectmap, naast `project.godot`.
3. Behoud de mapstructuur en vervang de gelijknamige bestanden.
4. Open het project in Godot 4.7.2, laat nieuwe scripts importeren en start met F5.

De ZIP bevat geen persoonlijke configuraties, ritten, assets of `.godot`-cache.
De eerder gebouwde menu's, HUD v2 en Scratch blijven beschikbaar.

## Wedstrijd kiezen

De kaart **Achtervolging** is nu speelbaar. Op de instellingenpagina kies je:

- **1 km:** vier ronden op de baan van 250 meter.
- **4 km:** zestien ronden.
- **AI-tegenstander** met zelf instelbare **CP**, standaard **250 W** (50–800 W).
- **Een vorige rit**, gekozen uit je opgeslagen achtervolgingen van dezelfde afstand.

Zonder opgeslagen rit op de geselecteerde afstand is de startknop bij ‘Een vorige rit’
uitgeschakeld; kies dan AI, rijd de afstand uit en sla je rit op. Demo-startvermogen
blijft instelbaar; met een echte trainer komt jouw vermogen uit de bestaande bridge.

## Start, baan en finish

- Beide renners starten uit stilstand, met de bestaande trainercontrole en aftelling.
- Jij start op de bestaande rode achtervolgingslijn halverwege het rechter rechte
  stuk, ongeveer 34,2 meter vóór de normale start/finish.
- De tegenstander start exact 125 meter verder, op de tegenoverliggende lijn.
- De afstandsteller van elke renner begint op nul. De fysieke halve baan wordt
  niet als voorsprong in de ranglijst of HUD geteld.
- Iedere renner finisht na zijn eigen vier of zestien ronden op zijn eigen startlijn.
  Rondetijden, finishcamera en foto gebruiken de bijbehorende zijde van de baan.
- De minimap toont beide lijnen en de werkelijke tegenoverliggende posities.

**Drafting is volledig uitgeschakeld voor beide renners.** Ook bij passeren of
vlak achter de tegenstander rijden ontstaat geen luchtweerstandsvoordeel.
De slipstreambalk is daarom in deze spelvorm verborgen.

**De tegenstander blijft de hele rit op de laagste rijlijn.** Dat geldt voor de AI
en ook voor de zichtbare tegenstander bij het afspelen van een opgeslagen rit.
Jij kunt de bestaande rijlijnbediening gebruiken; die extra route en banking blijven
je voortgang beïnvloeden. Arcade-boost is in achtervolging uitgeschakeld.

Deze trainingsvorm vergelijkt de eindtijden over de volledige gekozen afstand.
Een inhaalactie laat de rit doorlopen, zodat een voltooide poging kan worden bewaard.

## Constante AI

De CP bepaalt het volhoudvermogen. De AI berekent vooraf één constant vermogen
voor de volledige afstand, inclusief acceleratie vanuit stilstand en de bestaande
weerstand en baanhellingen. Er zijn geen demarrages, kopbeurten, willekeurige vorm,
wielzoekgedrag of eindsprint.

Het eenvoudige duurmodel gebruikt naast CP een eindige reserve van 20.000 J boven CP.
Een numerieke berekening met dezelfde snelheids- en baanfuncties zoekt het hoogste
constante vermogen binnen dat budget, met 2% marge voor integratiestappen. CP bepaalt
dus de basis; een kortere inspanning kan meer vermogen uit de reserve gebruiken.

Bij CP 250 W kwamen de uitgevoerde tests uit op circa **471,1 W over 1 km** en
**300,4 W over 4 km**. Het zijn game-instellingen, geen persoonlijke vermogensmeting.
De gekozen vermogens bleven tijdens beide volledige testritten constant.

## Een eigen rit bewaren en hergebruiken

1. Rijd jouw gekozen afstand volledig uit, tegen AI of tegen een opgeslagen rit.
2. Op het uitslagscherm staat een invulveld **‘Geef je rit een naam’**.
3. Vul een naam in en kies **‘Rit opslaan’**. Een melding bevestigt het bewaren.
4. Kies later Achtervolging, dezelfde afstand en **‘Een vorige rit’**.
5. Selecteer de bewaarde naam en start.

Opslaan is optioneel. Een lege naam of onvoltooide poging wordt niet bewaard.
Een geslaagde opslag deactiveert de knop voor deze poging, zodat dubbelklikken
geen dubbele rit maakt. Een opslagfout geeft een melding en laat opnieuw proberen toe.

De game bewaart tijd, wedstrijdafstand, vermogen en rijlijn ongeveer vijfmaal per
seconde, met een exact eindpunt op jouw geïnterpoleerde finishtijd. De vorige rit
wordt op zijn oorspronkelijke tijd-/afstandverloop afgespeeld, met dezelfde eindtijd,
ook als de nieuwe poging een andere framestap heeft. De zichtbare tegenstander rijdt
daarbij onderin; het eerder gereden tijdsverloop blijft ongewijzigd.

Ritten worden lokaal als JSON bewaard in **`user://pursuit_rides`**, onder Godots
gebruikersgegevens van deze game. Ze blijven beschikbaar na afsluiten en herstart.
Gebruikersnamen worden geen bestandsnamen; de bestanden krijgen een eigen ID.
Alleen complete, geldige ritten voor deze achtervolgingsversie en dezelfde afstand
worden aangeboden. Er is geen import van oude Scratch-, TCX- of FIT-bestanden toegevoegd.

## Gewijzigde en nieuwe code

- `main.gd`: spelkeuze, twee onafhankelijke renners, start-/finishcoördinaten,
  wedstrijdlus, camerakoppeling, ritregistratie en opslag op het uitslagscherm.
- `race_menu.gd`: achtervolging activeren en de nieuwe instellingen koppelen.
- `pursuit_options.gd`: afstand, AI/ritkeuze, CP en lijst met opgeslagen ritten.
- `pursuit_pacer.gd`: constant vermogensbudget en voorspelling van de ritduur.
- `pursuit_records.gd`: veilig bewaren, controleren, selecteren en afspelen van ritten.
- `race_hud.gd` en `minimap.gd`: draftingweergave verbergen en beide lijnen tonen.
- `tests/test_pursuit.gd`, `tests/test_pursuit_levels.gd`, `tests/test_menu.gd`:
  regressiecontroles.

## Uitgevoerde controles

Met Godot **4.7.2 stable**, headless:

- Schone import en GDScript-parsecontrole: geslaagd.
- Volledige 1 km- en 4 km-races tegen AI op CP 250 W: geslaagd. Beide renners
  finishen, alle rondetijden bestaan, AI-vermogen blijft constant en de reserve
  blijft begrensd. De tegenstander bleef in elke gecontroleerde stap onderin.
- CP-keuze beïnvloedt de AI-sterkte; de duurvoorspelling is daarnaast gecontroleerd
  op CP 50, 100, 250, 500 en 800 W, voor beide afstanden.
- Tegenoverliggende lijnen, eigen finishlijn, nul voortgang bij start en juiste
  fysieke minimapposities: geslaagd.
- Geen drafting in geometrie, HUD en snelheidsberekening, ook bij een kunstmatig
  aangeleverde draftwaarde van 100%: geslaagd.
- Daadwerkelijke startcontrole en aftelling starten beide renners uit stilstand.
- Werkelijk opslaan en opnieuw inlezen via een nieuwe opslaginstantie: geslaagd.
  Beide afstanden zijn opnieuw als tegenstander afgespeeld met een andere tijdstap;
  de finishtijden komen exact overeen met de bewaarde pogingen.
- Naam vereist, onvolledige rit geweigerd, foutieve samplevolgorde geweigerd,
  afstandsfiltering, selectie en beveiligde bestands-ID's: geslaagd.
- Menukeuze, opslagknop op het uitslagscherm, terugkeren naar Scratch en behoud van
  de afzonderlijke Scratch-instellingen: geslaagd.
- Bestaande HUD-, menu-, AI-, wielvolg-, sprinter-, scratch-ronde- en puntentests:
  geslaagd. De Scratch-wedstrijdlus met 8 deelnemers/10 ronden en
  12 deelnemers/50 ronden slaagt met dezelfde resultaten als vóór deze patch.
- De gewone hoofdscene is met assets headless geladen.

Logs, verschilpatch, bestandsmanifest en vier volledige achtervolgingsresultaten
staan in `pursuit_verification/`.

## Nog niet getest

**Geen visuele speeltest uitgevoerd.** Headless controles bevestigen berekende
posities en UI-grenzen, maar beoordelen het gerenderde camerabeeld, de finishfoto,
leesbaarheid of grafische prestaties niet. Echte trainer/Bluetooth, Strava en
TCX/FIT-export zijn niet getest. Godot meldt in deze omgeving een niet leesbare
systeemcertificaatstore en bij de scenetests een niet beschikbare UDP-poort;
de offline controles slagen.

## Zelf testen

Speel 1 km en 4 km, controleer de twee startlijnen en de lage lijn van de AI, rijd
eenmaal dicht langs de tegenstander en controleer dat drafting uit blijft. Bewaar
een poging met een naam, sluit de game, open opnieuw en kies die poging als
tegenstander. Controleer ook een nieuwe Scratch na terugkeer uit achtervolging.

Automatisch, vanuit de bestaande projectmap na installeren van de patch:

```powershell
$taskGodot = 'C:\Users\romboti\OneDrive - Cronos\Documenten\Priv\godot\Godot.exe'
& $taskGodot --headless --editor --path . --import
& $taskGodot --headless --path . --check-only --script res://main.gd
& $taskGodot --headless --path . --script res://tests/test_pursuit.gd --quit-after 2000
& $taskGodot --headless --path . --script res://tests/test_pursuit_levels.gd --quit-after 200
& $taskGodot --headless --path . --script res://tests/test_menu.gd --quit-after 200
& $taskGodot --headless --path . --script res://tests/test_hud.gd --quit-after 200
& $taskGodot --headless --path . --script res://tests/test_gameplay_headless.gd --quit-after 200
```

Pas het enginepad eventueel aan. Zoek naar `PURSUIT_OK`, `PURSUIT_LEVELS_OK`,
`MENU_FLOW_OK`, `RACE_HUD_OK` en `GAMEPLAY_HEADLESS_OK`. Controleer ook op scriptfouten.
Tests schrijven hun proefritten in een tijdelijke map onder `tests/tmp_pursuit_*`,
naast `tests/pursuit_results.json`, en verwachten een schoon project zonder
persoonlijke rennersconfiguratie. De proefritten worden niet in deze ZIP meegeleverd.
