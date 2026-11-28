# Duwen bij de afvalling

## Implementatie

Een verse stuurbeweging naar buiten kan één duw starten als een naastliggende renner de uitwijking blokkeert. De bewegingsplanner reserveert de baan van alle betrokken renners voordat iemand beweegt. Een geblokkeerde buitenste renner kan de duw doorgeven. Als de volledige keten onvoldoende ruimte heeft, vervalt de actie. De verplaatsing gebruikt dezelfde vaste fysicaticks als de afvalling. Een menselijke stuurpoging krijgt voorrang bij gelijktijdige aanvragen.

De initiator verliest 50 W aandrijfvermogen gedurende vijf gesimuleerde seconden, tot minimaal 0 W. Dezelfde timer begrenst de volgende actieve duw. AI-renners putten hun W′-reserve uit op basis van het geleverde vermogen. De teller voor geleverd vermogen, het vermogen in de HUD en activiteitsgegevens gebruiken hun bestaande bron. Het HUD toont gedurende de duwinspanning een extra regel in het Nederlands of Engels.

| Parameter | Waarde |
| --- | ---: |
| Afstand tussen rijlijnen | 0,60 m |
| Longitudinale volgafstand | 2,00 m |
| Minimale nieuwe invoegafstand | 2,05 m |
| Zijdelingse veiligheidsafstand | 0,55 m |
| Verplaatsing per passieve renner | 0,30 m naar buiten |
| Glijsnelheid | maximaal 1,15 m/s |
| Volledige glijbeweging | circa 0,26 s |
| Blokkering van onmiddellijk insturen na passieve duw | 1,2 s |
| Straf en actieve cooldown voor initiator | 50 W gedurende 5 s |
| AI-vertraging bij blokkering | 3 s |
| Max. afstand tot voorliggende renner voor AI-duw | 4,5 m |
| Min. door verkeer afgekapt vermogen voor AI-duw | 35 W |
| AI-urgentie | Bedreigde positie binnen 115 m van de volgende afvallingslijn |
| Minimale W′-reserve voor AI-duw | 250 J |
| Geldigheid toeslag in de bridge | maximaal 5.000 ms |
| Minimumsnelheid in berekening trainerhelling | 4,0 m/s bij geldige positieve trainersnelheid |
| Maximumtoeslag en opbouw | 1,50 procentpunt en 5 procentpunt/s |
| Fietsmassa boven op het ingestelde rennersgewicht | 8 kg |

De AI controleert normale uitwijking vóór een duw. Tijdens de finale met twee renners gebruikt zij het gewone passeergedrag. Insturen blijft onder de bestaande veiligheidsregels vallen. Een passieve renner kan opnieuw naar buiten sturen zodra de glijbeweging rond is. De rem op terugsturen is onafhankelijk van de actieve vermogensstraf.

De gameplaywijzigingen staan in `game/elimination_push.gd`, `game/elimination_motion.gd`, `game/elimination_ai.gd` en `game/main.gd`. De toepassing volgt wedstrijdmodus 2, ook wanneer de omniumcontroller deze activeert. De baan gebruikt de bestaande rijlijncoördinaten en bewegingsparameters. De vertalingen staan in `game/translations/translations.csv`. De trainerintegratie staat in `game/trainer_control.gd` en de bridgebestanden `combined_mode.py`, `simulation.py` en `udp_commands.py`. Het wireformaat staat in `bridge/UDP_PROTOCOL.md`.

## Schouderanimaties

De animatielaag speelt bij een geslaagde duw boven op de gewone trapbeweging, zittend en staand. De initiator en iedere renner die de duw doorgeeft spelen de geefclip naar rechts. Andere geraakte renners spelen de ontvangclip voor contact van links. Bij een vertakking speelt iedere deelnemer één clip. Een ontvangclip kan een lopende geefclip niet onderbreken.

De clips starten tegelijk met de reservering. De fysica bepaalt nog steeds wanneer de fietsen uitwijken. De animatie duurt standaard twee seconden en pauzeert samen met de wedstrijd. De meegeleverde GLB en Blender-generator staan onder `game/assets/riders/contact/` en `game/assets/source_blender/contact/`.

De 52 animatiecontroles en 136 afvallingscontroles slaagden in Godot. De animatietest controleert beide rennermodellen, het stuurcontact en de clipprioriteit. De afvallingstest controleert onder meer de rollen in een vertakkende cascade. Twee herhaalde afvallingen met acht renners en seed 17 gaven exact dezelfde wedstrijd- en duwresultaten als de oorspronkelijke featuremeting.

## Methode

De nulmeting vertrekt van `3ac063782edb69820d0b2adaeb69263befee9ad8`. De eerste wedstrijd liep op die commit voordat de wedstrijdlogica werd gewijzigd. De vergelijkende reeks gebruikt vervolgens dezelfde vaste seeds en deelnemersvormen op beide revisies. Iedere rij in de ruwe gegevens vermeldt haar broncommit.

Godot 4.7.2 draait de normale wedstrijdlogica zonder rendering, export of netwerksturing, met 60 vaste fysicaticks per seconde en presentatieframes van 100 ms. Alle tegenstanders gebruiken de native AI. In `autonomous` stuurt een afzonderlijke computerregel het vermogen van renner 0 zonder uitwijkcommando. In `steering` geeft een deterministisch spelersscript zowel vermogen als gewone stuurcommando’s. Dit is geen menselijke rijderstest. De bochten, de jury en de afvallingsvolgorde komen uit de game.

De monitor telt een blokkering als een renner een lateraal doel heeft, minstens circa 4,5 cm afwijkt van dat doel en minder dan een kwart van de normale glijsnelheid beweegt. Renners die op hun oorspronkelijke doel blijven tellen daarbij niet mee. De meting omvat geen overwogen AI-uitwijkingen die de planner al voor targetselectie verwerpt. Een succesvolle uitwijking in deze tabel beëindigt een blokkering met laterale beweging. Het betekent niet noodzakelijk dat een volledige rijlijn vrij is. De duur van onafgesloten situaties wordt in de compacte fixture afzonderlijk zichtbaar gemaakt. P95 gebruikt de nearest-rank-methode.

Een overlap is een actief paar onder zowel 0,55 m zijwaarts als 2,00 m longitudinaal, met 0,00001 m numerieke tolerantie. De veiligheidskolommen tellen observaties per fysicatik. De rekentijd is wall-clock-tijd van parallel uitgevoerde runs. De waarden zijn gevoelig voor gelijktijdige systeembelasting. Er is geen betrouwbare grafische FPS-meting.

## Gericht scenario met acht renners

| Actie | Vrije uitwijklijn basis | Vrije uitwijklijn met duwen | Eindrijlijn basis / duwen | Aandrijfverlies |
| --- | --- | --- | --- | ---: |
| Gelijkmatig 320 W | Binnen 12,1 s geen | Binnen 12,1 s geen | 1,18 / 1,18 m | 0 J |
| Tijdelijk versnellen naar 650 W | Binnen 12,1 s geen | Binnen 12,1 s geen | 1,18 / 1,18 m | 0 J |
| Tijdelijk terugnemen naar 80 W | Binnen 12,1 s geen | Binnen 12,1 s geen | 1,18 / 1,18 m | 0 J |
| Één keer naar buiten sturen | Binnen 12,1 s geen | Binnen 12,1 s geen | 1,23 / 1,53 m | 250 J |
| Twee keer naar buiten sturen | Binnen 12,1 s geen | Na 6,7 s | 1,23 / 2,38 m | 500 J |

De rijlijnen in deze fixture liggen vast bij de start en de tegenstanders behouden hun doelen tijdens de 12,1 s. De longitudinale voortbeweging en het vermogen van tegenstanders lopen via de native wedstrijdcode. De twee geslaagde duwen begonnen na 0,5 en 5,8 s en verschoven respectievelijk twee en vier andere renners. De speler eindigde ongeveer 39 m verder achterop dan in de basisvariant. In deze fixture leverde de uitwijking dus ruimte op met een duidelijke tactische kost. De fixture is afzonderlijk van de volledige wedstrijden opgenomen.

## Volledige afvallingen

`feature-release.jsonl` bevat de metingen op de definitieve wedstrijdlogica van `01432639f36209a526270cbc8baaa421a78bf9bb`. De vergelijking gebruikt uitsluitend gematchte combinaties uit dit bestand en `baseline.jsonl`. De extra basiswedstrijden en de eerdere featuremetingen blijven beschikbaar als controledata. De gewenste 90 per versie zijn binnen de beschikbare rekentijd niet voltooid. De exacte verdeling van de gematchte wedstrijden staat in de tabel.

24 basiswedstrijden en 14 featurewedstrijden voltooid. 14 gematchte paren in de tabellen.

### Blokkeringen en uitwijken

| Renners | Besturing 0 | Versie | Races | Events | Gem. s | Mediaan s | P95 s | Max. s | >5 s | >10 s | >30 s | >60 s | Speler afgevallen tijdens blok | Uitwijken/ronde | Spelerblokken | Speler bevrijd gem. s | Speler bevrijd % |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 8 | autonomous | basis | 2 | 1 | 0.65 | 0.65 | 0.65 | 0.65 | 0 | 0 | 0 | 0 | 0 | 0.04 | 0 | — | — |
| 8 | autonomous | duwen | 2 | 0 | — | — | — | — | 0 | 0 | 0 | 0 | 0 | 0.00 | 0 | — | — |
| 8 | steering | basis | 2 | 2 | 5.45 | 5.45 | 8.20 | 8.20 | 1 | 0 | 0 | 0 | 0 | 0.07 | 2 | 5.45 | 100.0 |
| 8 | steering | duwen | 2 | 5 | 3.36 | 0.88 | 8.20 | 8.20 | 2 | 0 | 0 | 0 | 0 | 0.18 | 3 | 5.26 | 100.0 |
| 16 | autonomous | basis | 3 | 3 | 0.12 | 0.02 | 0.33 | 0.33 | 0 | 0 | 0 | 0 | 0 | 0.03 | 0 | — | — |
| 16 | autonomous | duwen | 3 | 35 | 0.20 | 0.03 | 1.58 | 1.95 | 0 | 0 | 0 | 0 | 0 | 0.38 | 0 | — | — |
| 16 | steering | basis | 3 | 18 | 11.86 | 1.57 | 72.57 | 72.57 | 8 | 6 | 2 | 1 | 0 | 0.20 | 8 | 21.77 | 100.0 |
| 16 | steering | duwen | 3 | 13 | 0.68 | 0.07 | 4.68 | 4.68 | 0 | 0 | 0 | 0 | 0 | 0.13 | 1 | 4.68 | 100.0 |
| 24 | autonomous | basis | 2 | 12 | 0.14 | 0.08 | 0.50 | 0.50 | 0 | 0 | 0 | 0 | 0 | 0.13 | 0 | — | — |
| 24 | autonomous | duwen | 2 | 37 | 0.19 | 0.07 | 0.92 | 0.95 | 0 | 0 | 0 | 0 | 0 | 0.40 | 0 | — | — |
| 24 | steering | basis | 2 | 6 | 0.87 | 0.38 | 2.95 | 2.95 | 0 | 0 | 0 | 0 | 0 | 0.07 | 1 | 2.95 | 100.0 |
| 24 | steering | duwen | 2 | 3 | 0.02 | 0.02 | 0.03 | 0.03 | 0 | 0 | 0 | 0 | 0 | 0.02 | 0 | — | — |

### Duwen en cascades

| Renners | Besturing 0 | Pogingen | Geslaagd | Geweigerd | AI | Speler | Speler passief | Binnen 115 m | AI buiten venster | Cascades | Gem. lengte | Max. lengte | Passieven × aantal | Rand | Conflict | Duwen/race | Duwen/renner |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 8 | autonomous | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | — | 0 | — | 0 | 0 | 0.00 | 0.00 |
| 8 | steering | 1 | 1 | 0 | 1 | 0 | 0 | 1 | 0 | 0 | — | 0 | 1×1 | 0 | 0 | 0.50 | 0.06 |
| 16 | autonomous | 25 | 24 | 1 | 24 | 0 | 0 | 24 | 0 | 16 | 3.88 | 8 | 1×8, 2×4, 3×3, 4×5, 5×2, 7×1, 8×1 | 0 | 0 | 8.00 | 0.50 |
| 16 | steering | 12 | 6 | 6 | 4 | 2 | 0 | 6 | 0 | 4 | 4.25 | 6 | 1×2, 2×1, 4×1, 5×1, 6×1 | 0 | 0 | 2.00 | 0.12 |
| 24 | autonomous | 21 | 21 | 0 | 21 | 0 | 0 | 21 | 0 | 17 | 4.00 | 10 | 1×4, 2×6, 3×4, 4×3, 5×1, 8×1, 9×1, 10×1 | 0 | 0 | 10.50 | 0.44 |
| 24 | steering | 2 | 2 | 0 | 2 | 0 | 0 | 2 | 0 | 2 | 3.00 | 4 | 2×1, 4×1 | 0 | 0 | 1.00 | 0.04 |

### Energie, baanposities en rekentijd

| Renners | Besturing 0 | Versie | Duur s | km/u | Geleverd W | Aandrijving W | Duwkost J totaal | AI W′ bij finish J | Rekentijd s | Overlappende paren × ticks | Buitenrand × ticks |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 8 | autonomous | basis | 351.7 | 36.79 | 248.09 | 248.09 | 0.0 | 8440.1 | 39.6 | 0 | 0 |
| 8 | autonomous | duwen | 355.0 | 36.58 | 249.17 | 249.17 | 0.0 | 7641.2 | 14.2 | 0 | 0 |
| 8 | steering | basis | 336.4 | 39.24 | 289.18 | 289.18 | 0.0 | 5218.5 | 33.7 | 0 | 0 |
| 8 | steering | duwen | 335.6 | 38.97 | 288.93 | 288.88 | 179.4 | 4917.1 | 9.8 | 0 | 0 |
| 16 | autonomous | basis | 798.5 | 35.15 | 200.98 | 200.98 | 0.0 | 8228.4 | 92.0 | 0 | 0 |
| 16 | autonomous | duwen | 800.6 | 35.10 | 201.75 | 201.48 | 5713.3 | 8128.0 | 54.9 | 0 | 0 |
| 16 | steering | basis | 763.6 | 37.74 | 238.07 | 238.07 | 0.0 | 5479.0 | 71.5 | 0 | 0 |
| 16 | steering | duwen | 756.9 | 38.05 | 245.07 | 244.99 | 1489.2 | 4478.0 | 42.9 | 0 | 0 |
| 24 | autonomous | basis | 1234.8 | 35.06 | 192.27 | 192.27 | 0.0 | 6688.4 | 201.2 | 0 | 0 |
| 24 | autonomous | duwen | 1243.5 | 34.66 | 192.40 | 192.26 | 4753.0 | 5578.5 | 146.4 | 0 | 0 |
| 24 | steering | basis | 1200.3 | 36.80 | 215.55 | 215.55 | 0.0 | 5248.3 | 355.7 | 0 | 0 |
| 24 | steering | duwen | 1186.5 | 37.21 | 224.41 | 224.40 | 338.0 | 3761.9 | 91.4 | 0 | 0 |

Identieke afvallingsvolgorde in 0 van 14 paren. De volgorde per wedstrijd staat in de JSONL-bestanden.


`Duwkost J` is het verschil tussen geleverd vermogen en aandrijfvermogen, geïntegreerd over de actieve ticks. 250 J is het theoretische verlies bij vol vermogen en de gehele straftijd. Een renner die eerder afvalt of minder dan 50 W levert komt lager uit. Deze waarde meet geen extra energie in een fysiek vliegwiel.

De 14 gematchte races tellen nul waargenomen overlaps en nul baanoverschrijdingen. De langste blokkering bij 16 renners met stuurcommando’s daalde van 72,57 s naar 4,68 s. De acht blokkeringen van meer dan vijf seconden in deze groep verdwenen. De langste gemeten blokkering bij 24 renners met stuurcommando’s daalde van 2,95 s naar 0,03 s. In de autonome groepen kwamen meer korte pogingen tot uitwijken voor. Bij acht renners bleef de langste gemeten blokkering gelijk, met meer afzonderlijke events in de featureversie. Van de 54 geslaagde duwen kwamen er 52 van AI-renners en twee van de gesimuleerde speler. De grootste keten verplaatste tien passieve renners. De AI gebruikte vooral in de grotere velden af en toe een duw. Alle gemeten succesvolle AI-duwen vielen binnen het gedefinieerde sprintvenster. De in deze races gemeten veranderingen in eindvolgorde tonen een tactische impact. De steekproef geeft nog geen robuuste voorspelling voor elke vermogenscurve of elk peloton.

## Tests en bijstellingen

De gerichte Godot-suite voert 125 controles uit. De gevallen omvatten onder meer een vrije buitenlijn, geblokkeerd insturen, één tot meerdere passieve renners, een geweigerde randcascade, gelijktijdige aanvragen, passief sturen zonder vermogensstraf, herstel na de cooldown, rondeovergang, verschillende frame-intervallen, headless-isolatie en opname van gemeten watts. Een test bouwt tijdens de duwinspanning een FIT/GPS-bestand uit gesimuleerde telemetrieberichten via het normale invoerpad. Wijziging van gemeten vermogen verandert het bestand. Toevoeging van synthetische helling- en hoogtevelden verandert de bytes niet.

De eerste twee meetrevisies leverden concrete veiligheidsgevallen op.

1. In de eerste 16-rennersrun met seed 17 en stuurcommando’s werden 47 overlappende ticks geteld. De speler wachtte op de laatste lijn op de jury. De longitudinale planner gebruikte nog een voorspelde vooruitgang voorbij die lijn. De planner gebruikt nu dezelfde afgeknotte vooruitgang als de wedstrijd. De volledige herhaling na die correctie telde nul overlappende ticks.
2. De daaropvolgende 24-rennersrun met seed 18 telde één overlappende tick tijdens een cascade. Een renner die aanvankelijk buiten de cascade stond, stuurde later in het nog benodigde deel van de corridor. De bestaande controle keek voor die stuuractie naar de eerstvolgende glijstap. De reservering bewaakt nu het hele resterende traject tegen nabije rijlijnwissels. De nieuwe test controleert dat de buitenstaander zijn vorige positie houdt terwijl de cascade doorgaat.

De parameters van 30 cm, 50 W en vijf seconden bleven in beide correcties gelijk. De AI-drempels zijn op de oorspronkelijke waarden gebleven. De bewegingscode hergebruikt de door de native planner berekende snelheid en slaat de laterale controle over bij vaste posities zonder reservering. In twee 8-rennersraces met seed 17 daalde de gemeten CPU-tijd inclusief start van 25,81 naar 18,04 s. Dit is een kleine CPU-steekproef van vóór de laatste corridorcorrectie. De wall-clock-waarden in de wedstrijdtabellen delen de machine met andere taken.

De volledige Python-bridgesuite met Godot-integratie draaide 126 tests. Er slaagden 122 en er faalden vier, zonder skips. Dezelfde vier tests faalden ook in de aparte basischeckout met de oorspronkelijke game en bridge. Het gaat om de virtuele apparaatselectie en drie varianten van het verlaten van het resultatenscherm via de controller. De drie nieuw toegevoegde bridgegevallen slaagden, inclusief de klokgestuurde FTMS-simulatie.

De Godot-regressies omvatten native afvalling, positionering, vermogensmodel, spelerslijnen, omnium, bridge, ERG, Strava-export en vertalingen. De oorspronkelijke omniumtest met 24 renners leverde met en zonder geometriecache exact dezelfde uitslag en W′ op na versnelde berekening. De vier native omniumgevallen deden volledige races voor acht en 24 renners. De bestaande uitrijrouteassertie, omniumtabelassertie, bridgeprotocol-parserfout, stuurtestfixture en ERG-helptekstassertie werden ook op de basiscommit vastgesteld. De virtuele apparaatselectie is met de bijbehorende Python-mockbridge geteld, omdat de losse Godot-scriptstart zonder dit hulpmiddel geen geldige opstelling is.

De pelotonregressie rondde alle 27 wedstrijdgevallen af zonder falende controles. De precieze uitkomsten en de uitgevoerde regressies staan in de TSV. De geometrische sporen van beide geconstateerde overlapgevallen zijn bij de resultaten bewaard.

Van de 33 Godot-scripts zijn er 28 geslaagd, 5 mislukt of beëindigd op de tijdlimiet, en 0 zonder volledige afloop in dit rapport.


## Smarttrainer en gemeten communicatie

De game gebruikt de snelheid uit de FTMS-telemetrie, in plaats van de virtuele snelheid in het peloton. Het geschatte totaalgewicht is het ingestelde rennersgewicht plus 8 kg fiets. De onbegrensde berekening is `100 × 50 / (massa × 9,81 × snelheid)`. Bij geldige positieve snelheden begrenst de game de noemer op minimaal 4 m/s en de uitkomst op 1,50 procentpunt. Bij stilstand, ontbrekende snelheid of ongeldig gewicht wordt de toeslag nul.

De bridge laat de bestaande berekening van weghelling, virtuele versnelling, rolweerstand, aerodynamica en drafting intact. De extra zwaartekrachtcomponent wordt daarna op de berekende FTMS-helling toegepast. Zo vermenigvuldigt een schakelactie de duwinspanning niet met de versnellingsfactor. De FTMS-schrijver rondt de uitkomst op 0,01 procentpunt af. De virtuele bewegingsfysica ontvangt alleen de vermogensaftrek. De laterale glijbeweging van de speler voegt geen kunstmatige bankingspiek toe aan het trainersignaal. De extra trainerwaarde komt niet in FIT-, GPS- of Strava-gegevens terecht.

In een lopende sessie kan de Godot-client op de begin- en eindflank buiten het normale interval van 200 ms een commando sturen. Bij een eerdere mutatie in afwachting van een antwoord wacht de client op de ACK. Tussentijdse wijzigingen worden gedempt met een drempel van 0,04 procentpunt. De bridge schrijft standaard per 100 ms plus eventuele BLE-transactietijd en slaat identieke FTMS-pakketten over. Iedere toeslag heeft een eigen monotone vervaltijd, naast de bestaande UDP-lease van vijf seconden en de controle op verse trainerfeedback. Pauze en stop gebruiken de bestaande FTMS-vrijgave. Bij hervatten kan alleen de resterende gesimuleerde duur opnieuw aangeboden worden.

| Totaalgewicht | Trainersnelheid | Toeslag | Eerste FTMS-write | Herstel | Duur verhoogde opdracht | Modelbereik na opbouw |
| --- | --- | --- | --- | --- | --- | --- |
| 85 kg | 30 km/u | 0,72 pp | 0,1 s | 5,1 s | 5,0 s | 50,01–50,72 W |
| 85 kg | 40 km/u | 0,54 pp | 0,1 s | 5,1 s | 5,0 s | 50,01–50,96 W |
| 85 kg | 45 km/u | 0,48 pp | 0,1 s | 5,1 s | 5,0 s | 50,01–51,07 W |
| 85 kg | 50 km/u | 0,43 pp | 0,1 s | 5,1 s | 5,0 s | 49,78–50,95 W |
| 98 kg | 33 km/u | 0,57 pp | 0,1 s | 5,1 s | 5,0 s | 50,21–51,11 W |

De tabel meet vanaf ontvangst van het UDP-commando door een mockbridge met een gesimuleerde schrijflus van 100 ms. De opstelling voert tijdens iedere puls één virtuele schakelactie en één wijziging van normale helling en aero uit. Dat levert 17 FTMS-writes per proef op, gemiddeld 3,4 per seconde. De wattages zijn theoretische afleidingen uit de werkelijk geserialiseerde FTMS-waarden. Het verzenden van een pakket naar de mock zegt niets over de reactietijd van de motor of het vliegwiel van een fysieke trainer.

| Configuratie | Pad |
| --- | --- |
| FTMS Indoor Bike Simulation | Extra helling via de bestaande opcode `0x11`. |
| Zwift Ride en virtuele versnellingen van de bridge | De bestaande knoppen en gearfactor blijven werken. De mock controleert schakelen tijdens de puls. |
| Fysieke versnellingen | Dezelfde FTMS-helling met de live gemeten trainersnelheid. Het verschil in daadwerkelijk vliegwielgedrag moet op hardware worden gemeten. |
| Oude bridges, FTMS zonder Indoor Bike Simulation of geen trainer | De game verwerkt de vermogensstraf. Voor de toeslag is expliciete bridgeondersteuning nodig. |
| Native virtueel schakelen of afzonderlijke OpenBikeControl/BikeControl-integratie | Deze branch bevat bridgegebaseerd schakelen voor Zwift Ride. De BikeControl-code wordt als bron voor Ride-pakketdecodering vermeld. Een afzonderlijke native schakelroute werd niet aangetroffen. |

Er was geen fysieke smarttrainer aangesloten. De praktijktest moet daarom bevestigen hoe snel de belasting voelbaar wordt tegenover het verstuurde commando, welk extra vermogen in verschillende fysieke en virtuele versnellingen nodig is, en hoe het toestel reageert op pauze, uitval en hervatten.

## Reproduceren

Gebruik Godot 4.7.2. Importeer de assets eerst met `godot --headless --path game --import`. Bij problemen met de Blender-import kan een wegwerpcheckout dezelfde aanpak volgen als `.github/workflows/erg-recovery.yml`, die de bronscènes in die tijdelijke checkout weglaat en de geëxporteerde GLB-assets gebruikt.

```sh
git worktree add --detach ../Velodrome-baseline 3ac063782edb69820d0b2adaeb69263befee9ad8
# Importeer ook de assets in de basischeckout.
python simulation/elimination_tests/run_pushing.py ../Velodrome-baseline /tmp/pushing-base.jsonl
python simulation/elimination_tests/run_pushing.py . /tmp/pushing-feature.jsonl
python simulation/elimination_tests/compare_pushing.py /tmp/pushing-base.jsonl /tmp/pushing-feature.jsonl
godot --headless --path game -s res://tests/test_elimination_pushing.gd
PYTHONPATH=bridge:bridge/tests python -m unittest test_elimination_push
```

De standaard runner vraagt 15 seeds × twee besturingen × drie veldgroottes. De optie `--counts` beperkt dit tot de opgegeven veldgroottes. `--seeds` en `--seed-start` bepalen het bereik. Gebruik dezelfde opties voor beide revisies. Eerder voltooide combinaties worden in een bestaand resultaatbestand overgeslagen. Kopieer voor de compacte fixture beide `measure_elimination_pushing*.gd`-scripts naar `game/tests` van de basischeckout en start in beide checkouts `res://tests/measure_elimination_pushing_scenarios.gd`.

## Conclusie

De speler kan in de gecontroleerde blokkering via twee afzonderlijke stuurcommando’s ruimte maken, met een merkbare kost in het aandrijfmodel. De volledige wedstrijden tonen winst tegen langdurige blokkeringen in een deel van de gemeten velden. De beperktere winst bij acht renners en het aantal herhalingen maken een algemene uitspraak over alle wedstrijdconfiguraties voorbarig.

De implementatie kan nu door een menselijke speler worden beoordeeld. De softwaremetingen ondersteunen de werking van de cascade en de tijdelijke FTMS-toeslag. De fysieke gewaarwording en herstelreactie moeten nog met de eigen smarttrainer worden vastgesteld.

- [Ruwe wedstrijd-, trainer- en testresultaten](../../simulation/elimination_tests/pushing-results/)
- [Runner voor volledige wedstrijden](../../simulation/elimination_tests/run_pushing.py)
- [Vergelijkingsscript](../../simulation/elimination_tests/compare_pushing.py)
- [Gerichte compacte-pelotonfixture](../../game/tests/measure_elimination_pushing_scenarios.gd)
