# Uitvoeringstaken meerdere locaties

## Afgerond op deze branch

- [x] Branch `feature/multiple-venues` vanaf actuele `v0.4` maken.
- [x] Bestaande locatie als standaard **Vélodrome** definiëren.
- [x] Defaultconfiguratie in spel, pistegeometrie en arena aansluiten.
- [x] Onafhankelijke configuratiekopieën en schema-validatie toevoegen.
- [x] Geometrie-lookuptabel exact laten sluiten voor toekomstige korte baanlengtes.
- [x] Gent analyseren aan de hand van broncode en foto's van de editie 17–22 november 2026.
- [x] Nieuwe locatie **Gent** noemen; eigen sponsorvrije vormgeving beschrijven.
- [x] Bepalen welke objecten gedeeld zijn en welke niet automatisch meekomen.
- [x] Afweging Godot/Blender en overdraagbare bouwbrief uitschrijven.

De technische vervolgwerkzaamheden hieronder horen bij hetzelfde issue. Het ontwerp is goedgekeurd en de eerste Godot-ontwerpweergave is gebouwd; zie [Gent in Godot](gent/GODOT.md).

## 1. Piste en plaatsingspunten

- [ ] Eén actieve, gevalideerde venue-instantie vóór geometrie/raceregels initialiseren. Alleen wisselen buiten een actieve wedstrijd; arena en afhankelijke modules opnieuw opbouwen.
- [x] Definitieve Gent-lengteprecisie beslissen (**1000/6 m goedgekeurd**): bronwaarde 166,66 m versus een nominale 1000/6 m in de spelconfiguratie. Deze twee waarden niet door elkaar gebruiken.
- [ ] Radius, breedte, bochtovergangen, rechte-bankings en vlakke binnenruimte uit een proportionele blockout vastleggen. De bron bevestigt 52° in de bochten, geen volledig opgemeten baanprofiel.
- [ ] De 11 bestaande spelerbanen en de zes startbanen aan de effectieve breedte aanpassen; fiets, official en tv-box op ware grootte houden.
- [ ] Markeringen, meetlijn, achtervolgingsstart, tegengestelde start, neutrale vertrekplaats en aantal rondes uit hetzelfde profiel afleiden.
- [ ] `_at`, `_path_metric`, `_corner_lean`, `TRACK_EDGE`, `TRACK_OUTER_EDGE` en textuur-UV's op een smalle, steile baan controleren. Geen uniform geschaald bestaand stadion gebruiken.
- [ ] Binnen- en buitenboarding, official, tv-box, jury, finishcamera, resultatenpodium en toegang als benoemde plaatsingspunten uitwerken.

## 2. Wedstrijdregels en AI

| Systeem / bestanden | Te verwijderen aanname | Acceptatie |
|---|---|---|
| `main.gd`, `scratch_lap_rules.gd`, `peloton_state.gd`, `x_scratch_ai.gd` | 250 m in rondewinst, wrap-afstanden en peloton | Een fysieke passage telt één ronde; rondewinst beëindigt de race niet vroegtijdig |
| `points_race_rules.gd`, `points_intermediate_sprint.gd`, `points_ai.gd` | Vaste rondeafstand en sprintaanloop | Sprint alleen op de juiste meetpassage; interval expliciet in ronden of meters |
| `tempo_race_rules.gd`, `tempo_ai.gd` | 250 m als score-/raceklok | Startfase, punten en einde volgen hetzelfde pelotonreferentiepunt |
| `elimination_race_rules.gd`, `elimination_motion.gd`, omnium-afvalling | 500 m is impliciet twee ronden | Configureerbaar rondenaantal; interpolatie van achterwielpassages blijft behouden |
| `keirin_race.gd` | 750 m achter derny, 1500 m finish, delen door 250 | Expliciete disciplineafstand/-ronden; derny-uitrijroute past in Gent |
| `team_race.gd`, achtervolgings-/tijdritlogica | 125 m-splits, 4/16 ronden per 1/4 km | Vaste wedstrijdafstand blijft exact; splitafstand en startlijn zijn afzonderlijk gedefinieerd |
| `omnium/*` | Omgerekende afstanden en resultaten zonder locatie | Locatie bij omniumstart vastleggen; hervatten gebruikt dezelfde locatie |
| `race_signals.gd`, `infield_details.gd` | Belgrens 250 m en eventvoorbereiding | HUD en official kondigen dezelfde laatste ronde aan |

Afstanden in meters (fietsafmetingen, luchtweerstand, acceleratie, trainervermogen) niet met de baanlengte schalen. Tactische aanlopen per geval classificeren: een rondefractie, een echte afstand of een tijd. Het literal `250` kan ook een vermogenswaarde of animatieparameter zijn; geen algemene zoek-en-vervangactie.

Voorstel: punten- en afvallingsintervallen in **ronden** opslaan en daarnaast de berekende meters tonen. Een bestaand omnium bewaart zijn oorspronkelijke instellingen. Keirin en wedstrijdformats krijgen een eigen expliciete afstandsdefinitie; die hoort niet verstopt in de stadionkunst.

## 3. HUD, menu, camera en training

- [ ] `minimap.gd`, `race_hud.gd`, `infinity_scoreboard_model.gd`, `infinity_screen.gd`, previews en rondetijdgrafieken op actieve baanlengte aansluiten.
- [ ] Stadionkaarten toevoegen met naam, eigen afbeelding, baanlengte en sfeer; Gent pas aanbieden als compleet getest.
- [ ] Gekozen id persistent opslaan; bij ontbrekend id zichtbaar en veilig naar Vélodrome terugvallen. Bewaarde wedstrijden behouden hun vastgelegde id.
- [ ] NL/EN-vertalingen samen met UI-broncode toevoegen. `Gent` en `Vélodrome` blijven locatienamen.
- [ ] `broadcast_intro.gd` gebruikt nu vaste wereldcoördinaten en zoekt `EuroMaxCyclingCommentaryBox`. Eigen Gent-traject + terugval naar rennerscamera maken.
- [ ] POV, volg-, zij-, terugkijk-, finishfoto-, teamfoto- en podiumcamera controleren op dak, banken en boarding.
- [ ] `training_environment.gd`, `derny_environment.gd`, `madison_training_environment.gd`, `piste_exercise_environment.gd`: eigen inrichting kiezen. Hun medewerkers, objecten en trainingsroutes niet automatisch naar Gent kopiëren.
- [ ] ERG-workouts behouden tijd/vermogen; pisteoefeningen en aflossingszones volgen de gekozen geometrie.
- [ ] Trainings- en wedstrijdlicht, introshow en optie voor eenvoudige graphics per locatie aansluiten.

## 4. Hergebruik en Gent-inrichting

- [x] Official-controller uit `infield_details.gd` losmaken, inclusief vier animaties, props, fallback en reset bij volgende wedstrijd.
- [ ] `commentary_box.gd` losmaken van `TIERS[1]` en offset 27,83; een expliciet tv-box-plaatsingspunt gebruiken. Model en twee presentatoren behouden.
- [ ] Gent gebruikt een eigen infield-bouwer. Geen volledige `infield_details.gd`, `tour_spectator_details.gd`, `north_infield.gd`, kiosken of rennersboxen importeren om alleen de official te krijgen.
- [ ] Zitplaatsen en publiek in Gent opnieuw verdelen; generieke mensmeshes mogen later uit de gedeelde kit komen, bestaande supporterpersonages/plaatsingen/banners niet.
- [ ] Eigen zaalwand, vlak plafond, gele zitrijen, rode omranding en originele wandgrafiek bouwen. Geen kopieën van echte sponsors of fototexturen.
- [ ] Eigen podium/uitslagenopstelling bepalen; huidige podiumpositie en sponsorwand niet automatisch overnemen.

## 5. Registratie, herhalingen en export

- [ ] `performance_records.gd`, `time_trial_records.gd`, `pursuit_records.gd`, `training_history.gd`, `omnium_archive.gd`: `venue_id`, geometrieversie en benodigde lengtegegevens bewaren.
- [ ] Oude ritten zonder venue als Vélodrome behandelen; originele bestanden niet destructief herschrijven.
- [ ] Referentieritten filteren op compatibele locatie/geometrie. Bij verschillende pistes een expliciete keuze ontwikkelen; ze niet stilzwijgend als gelijkwaardige tegenstander behandelen.
- [ ] FIT/Strava-afstand in echte meters behouden; locatie als aanvullende metadata opnemen, geen echte GPS-locatie verzinnen.

## 6. Eindcontroles vóór Gent speelbaar wordt

- [ ] Geometrie: gesloten lus, continue raaklijn/helling, meetlijnlengte, baanbreedte, juiste race richting en consistente normals.
- [ ] Wedstrijden: scratch, puntenkoers, temporace, afvalling, keirin, tijdrit, achtervolging, ploegenachtervolging en volledig omnium op beide locaties.
- [ ] Lange simulatietijdstap kan geen sprint, bel, finish of afvalling overslaan; versneld uitrijden van AI blijft werken.
- [ ] Bestaande 250 m-simulaties en 1/4 km-tijden blijven gelijk na iedere infrastructuurmigratie.
- [ ] Official/TV: alle props, clips, twee onafhankelijke mondanimaties, kijkrichting en zichtlijnen controleren.
- [ ] Visuele controle in beide talen en alle camera's, normaal én eenvoudige graphics.
- [ ] Vergelijk FPS en frametimes met Vélodrome op hetzelfde apparaat, dezelfde renners, camera en lichtmodus. Godot headless geeft geen bruikbare GPU-FPS.
- [ ] Pas na deze controles Gent toevoegen aan de speelbare catalogus.
