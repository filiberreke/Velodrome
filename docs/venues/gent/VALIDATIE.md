# Validatie Godot-uitwerking Gent

26 november 2026, Godot 4.7.2 stable. Code en beelden horen bij `feature/multiple-venues`.

| Controle | Resultaat |
|---|---|
| `test_gent_design.gd` | Geslaagd: nominale zesrondenbaan, gesloten lus, 7 m oppervlakbreedte, 52° banking, productiecoördinaten op Vélodrome, twaalf lage open rennerboxen tegenover de finish; jury, bel en uitkragende rondenteller aan de echte finish; twee perszones, centrale medische post en mixed zone; hergebruik van beide zijden van de Vélodrome-backdrop; camera met finish links; wit logo op rode piste-/boardingpanelen; vertaalde zones; publieksdekking in normale en eenvoudige uitvoering |
| `test_venue_configuration.gd` | Opnieuw geslaagd na de fotocorrectie: beide locatieprofielen en de standaardconfiguratie |
| `test_official_ready.gd` | Geslaagd: bestaande official behoudt zijn vier clips, props en resetgedrag na extractie naar gedeeld script |
| `test_finish_line_race.gd` | Geslaagd: echte Vélodrome-puntenkoers met start, sprints, official en finish |
| `test_graphics_settings.gd` | Geslaagd: bestaande Vélodrome-arena in beide grafische instellingen |
| `test_commentary_box.gd` | Geslaagd: bestaande box en beide onafhankelijke presentatoren |
| `test_localization.gd` | Opnieuw geslaagd na de fotocorrectie: catalogus en bestaande NL/EN-wissel |
| `test_gent_navigation.gd`, met echte OpenGL-renderer | Geslaagd: vertaald hoofdmenupunt, openen Gent, terug naar Vélodrome |
| `capture_gent.gd` / visuele controle | Vier echte Godot-frames op 1600 × 900; bekeken en bijgesteld |
| `git diff --check` | Geslaagd |

De navigatietest is ook met de echte renderer uitgevoerd: de headless dummy-renderer logt bij het vrijgeven van sommige rennermaterialen waarschuwingen/fouten die niet optreden bij de OpenGL-uitvoering. De opgenomen beelden en de gerenderde navigatietest gebruiken OpenGL Compatibility op Mesa llvmpipe. Dit is geen prestatiemeting voor een laptop-GPU.

De bestaande algemene test `test_menu_cleanup.gd` heeft twee mislukte assertions: terugnavigeren vanuit een historisch trainingsresultaat en een hardgecodeerde verwachting over de Strava-instructietekst. Exact die twee fouten zijn ook op de ongewijzigde `v0.4`-basis gereproduceerd. Deze niet aan Gent gerelateerde gedragingen zijn in deze wijziging niet aangepast.

De actuele scène is een inrichting-/ontwerpweergave met demonstratierenners. De locatie is niet als wedstrijdlocatie geregistreerd; wedstrijdregels, records, omnium en training vragen nog de locatiebewuste migratie uit [de takenlijst](../taken.md).

Na de fotocorrectie zijn vier nieuwe Godot-renders gemaakt en bekeken. De dekkingstest controleert dat toegankelijke publieksvloer overal binnen 2,1 m van een bezoeker ligt en dat alle werkzones vrij blijven van bezoekers. Bij standaarddichtheid: 1.388 publiekspersonen; eenvoudig: 604. Medewerkers en tribunes staan daar los van.

De geometrie- en inrichtingstest is na deze correctie opnieuw uitgevoerd, inclusief cameraoriëntatie, de gedeelde backdrop en de branding. Ook de configuratie- en lokalisatietests zijn opnieuw uitgevoerd. De overige regressietests in de tabel zijn uitgevoerd bij de oorspronkelijke Gent-integratie. De CSV is opnieuw opgebouwd voor de renders; de drie behouden paneelbenamingen zijn in Nederlands en Engels gecontroleerd.

## Sponsor- en tekstcorrectie

Na de bannerwijziging zijn de Gent-inrichtingstest en lokalisatietest opnieuw uitgevoerd. Extra controles: alle twintig pistevakken bevatten een bestaand sponsorbeeld of de nieuwe rode Vélodrome-PNG, de kleurverdeling bevat zes families, rode banners delen exact de boardingkleur, de nieuwe PNG is ten minste 2048 px breed en heeft mipmaps, en de zwevende technische/mixed-zonebenamingen ontbreken. Vier echte Godot-renders zijn vernieuwd om scherpte, roodovergang en plaatsing visueel te beoordelen.

Een aparte gerenderde kleurcontrole met identieke vlakken en gelijke belichting meet voor de rode bannerachtergrond en de basisboarding een maximaal kanaalverschil van **0/255** op de vergeleken kleurmonsters. De definitieve overzichts- en detailbeelden zijn daarna opnieuw opgenomen; de ongewenste zwarte opvulranden ontbreken.

De middenpleinreclame is daarna naar de rode/oranje vloer verplaatst. De opnieuw geslaagde inrichtingstest controleert dat alle vertices van die opdruk op vloerhoogte liggen, de achtergrondkleur gelijk is aan de binnenstrook en de oude reclamevlakken in de omheining ontbreken. De vier screenshots tonen deze definitieve plaatsing.

De vloerlogo’s zijn vervolgens 180° gedraaid, zodat ze vanaf de buitenzijde leesbaar zijn. De Gent-inrichtingstest is opnieuw geslaagd. Standpunt 3 kijkt nu loodrecht op de rij rennerboxen vanaf de buitenste tribune, over de piste heen. De capturer maakt daarnaast een dichter frontaal detailbeeld vanaf dezelfde zijde (`05-rennersboxen-frontaal-detail.jpg`); beide zijn echte Godot-renders.
