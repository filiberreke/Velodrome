# Uiterlijk van de speler

Open **Instellingen [F10] → Speler**. Kies onafhankelijk een truitje/wielerpak,
helm en vizier (**Donker** of **Doorzichtig**). Het wielerpak omvat torso,
mouwen, rug en broek. Het geanimeerde 3D-voorbeeld heeft een voor- en achterkant.

**Toepassen en bewaren** past het uiterlijk meteen op de bestaande speler toe,
zonder de wedstrijd of animatie opnieuw te starten. De keuze geldt ook na een
herstart en bij volgende wedstrijden, inclusief individuele en ploegachtervolging.
**Sluiten** of F10 verwerpt nog niet bewaarde wijzigingen aan het uiterlijk. Andere renners behouden
hun eigen configuratie en kleuren.

Er zijn elf landenpakken, een witte helm en vijf verschillende nationale
helmontwerpen. De overige landenontwerpen gebruiken dezelfde witte helm.
**Bestaande keuze** gebruikt de optionele `country_kit`, `skinsuit_png` en
`helmet_png` uit `[player]` in `riders_config.cfg`. **Standaardkleuren** herstelt
de oorspronkelijke kleuren. De bestaande configuratie blijft bij de eerste start
actief; de vizierkeuze toont dan de ingestelde waarde (standaard Donker).

De menukeuzes worden lokaal opgeslagen als `user://player_appearance.cfg`, apart
van `user://rider_profile.cfg` (naam/gewicht) en de beeldinstellingen. Het menu
schrijft nooit naar `riders_config.cfg`. Een bewaarde keuze heeft voor de speler
voorrang op de overeenkomstige configuratiewaarde. Verwijder alleen het lokale
`player_appearance.cfg` om alle oorspronkelijke instellingen opnieuw te volgen.
Persoonlijke configuraties en testresultaten horen niet in Git.

## Implementatie en controle

- `player_appearance.gd`: keuzeaanbod, opslag en samenvoegen met spelerconfig.
- `player_appearance_preview.gd`: apart 3D-voorbeeld; verwerking/rendering stopt
  zodra het menu sluit of een andere tab actief wordt.
- `display_settings.gd`: tabs Speler, Beeld en Strava; bewaren/annuleren.
- `main.gd`: voorkeuren laden, toepassen bij spawn op alleen pelotonindex 0,
  bestaande speler bijwerken via de bestaande materiaalsetters.

Geen nieuwe Blender-export nodig. Open `game/project.godot` in Godot 4.7.2 en
laat de bestaande GLB- en PNG-bestanden importeren. Bij export moeten de nationale
PNG-resources worden meegenomen (standaard: alle resources). Het keuzeaanbod
gebruikt resourcepaden en vereist geen los JSON-bestand in de export.

Reproduceerbare tests vanuit de repositoryroot, met `godot` op PATH:

```powershell
godot --headless --path game --editor --import --quit
godot --headless --path game --script res://tests/test_player_appearance.gd
godot --headless --path game --script res://tests/test_player_appearance_spawn.gd
godot --headless --path game --script res://tests/test_country_skins.gd
godot --headless --path game --script res://tests/test_national_kit_assets.gd
```

De eerste test gebruikt een testparent voor de instellingen en echte renners;
wijzigt geen persoonlijke beeld-, profiel- of trainerinstellingen. De tweede
compileert en test de daadwerkelijke spawn/apply-methoden uit `main.gd`, zonder
UDP-, Strava- of trainerstart. Beide gebruiken eigen tijdelijke voorkeursbestanden.
Met een grafische renderer maakt de instellingentest ook
`user://player_settings.png` en `user://player_settings_back.png`.

Gecontroleerd met Godot 4.7.2: beide nieuwe tests PASS, bestaande kledingtests
PASS, tien landen × twee rigs × vier animaties PASS. De instellingentest is ook
uitgevoerd met OpenGL op Intel Iris Xe; voor- en achterkant visueel gecontroleerd
op 1280×720 met de bestaande UI-referentie van 1920×1080. Volledige wedstrijd,
trainerkoppeling en release-export zijn niet opnieuw getest. De testomgeving
meldt een losstaande fout bij het lezen van de Windows-certificaatopslag.
