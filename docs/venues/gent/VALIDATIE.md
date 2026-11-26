# Validatie Godot-uitwerking Gent

26 november 2026, Godot 4.7.2 stable. Code en beelden horen bij `feature/multiple-venues`.

| Controle | Resultaat |
|---|---|
| `test_gent_design.gd` | Geslaagd: nominale zesrondenbaan, gesloten lus, 7 m oppervlakbreedte, 52° banking, productiecoördinaten op Vélodrome, twaalf eigen cabines, eigen hal/publiek, gedeelde acteurs; publieksdekking op de volledige binnencontour in normale en eenvoudige uitvoering, doorgangen en materiaalzones vrij |
| `test_official_ready.gd` | Geslaagd: bestaande official behoudt zijn vier clips, props en resetgedrag na extractie naar gedeeld script |
| `test_finish_line_race.gd` | Geslaagd: echte Vélodrome-puntenkoers met start, sprints, official en finish |
| `test_graphics_settings.gd` | Geslaagd: bestaande Vélodrome-arena in beide grafische instellingen |
| `test_commentary_box.gd` | Geslaagd: bestaande box en beide onafhankelijke presentatoren |
| `test_localization.gd` | Geslaagd: catalogus en bestaande NL/EN-wissel |
| `test_gent_navigation.gd`, met echte OpenGL-renderer | Geslaagd: vertaald hoofdmenupunt, openen Gent, terug naar Vélodrome |
| `capture_gent.gd` / visuele controle | Vier echte Godot-frames op 1600 × 1000; bekeken en bijgesteld |
| `git diff --check` | Geslaagd |

De navigatietest is ook met de echte renderer uitgevoerd: de headless dummy-renderer logt bij het vrijgeven van sommige rennermaterialen waarschuwingen/fouten die niet optreden bij de OpenGL-uitvoering. De opgenomen beelden en de gerenderde navigatietest gebruiken OpenGL Compatibility op Mesa llvmpipe. Dit is geen prestatiemeting voor een laptop-GPU.

De bestaande algemene test `test_menu_cleanup.gd` heeft twee mislukte assertions: terugnavigeren vanuit een historisch trainingsresultaat en een hardgecodeerde verwachting over de Strava-instructietekst. Exact die twee fouten zijn ook op de ongewijzigde `v0.4`-basis gereproduceerd. Deze niet aan Gent gerelateerde gedragingen zijn in deze wijziging niet aangepast.

De actuele scène is een inrichting-/ontwerpweergave met demonstratierenners. De locatie is niet als wedstrijdlocatie geregistreerd; wedstrijdregels, records, omnium en training vragen nog de locatiebewuste migratie uit [de takenlijst](../taken.md).

Na de middenpleincorrectie zijn vier nieuwe Godot-renders gemaakt en bekeken. De dekkingstest controleert dat toegankelijke publieksvloer overal binnen 2,1 m van een bezoeker ligt, ook in beide uiteinden en de voormalige lege aankomsthoek. Bij de standaarddichtheid: 1.344 publiekspersonen, eenvoudig: 596. De telling betreft het middenpleinpubliek; medewerkers en tribunes staan daar los van.
