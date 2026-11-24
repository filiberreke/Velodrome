# Release v0.4: documentatie en releasechecks

Dit is een werkdocument voor de [milestone Release v0.4](https://github.com/filiberreke/Velodrome/milestone/4). **Huidig** beschrijft de geïnspecteerde bron op `v0.4` (`13c9523`), niet de inhoud van de publieke v0.3-downloads. De checklists zijn nog uit te voeren; ze zijn geen testrapport.

## Taal kiezen ([#37](https://github.com/filiberreke/Velodrome/issues/37))

**Voor spelers (v0.4-builds met deze wijziging):** open **Instellingen** (tijdens het rijden: **F10**), kies **English** of **Nederlands** bij het spelersprofiel en klik **Toepassen en bewaren** / **Apply and save**. De wijziging wordt meteen toegepast en blijft behouden na herstart. English is de projectstandaard en terugvaltaal. De taal van het spel staat los van de taalkeuze op de website.

**For players (v0.4 builds containing this change):** open **Settings** (**F10** while riding), select **English** or **Nederlands** next to the player profile and click **Apply and save**. The game switches language immediately and keeps your choice when you reopen it.

- De keuze staat onder `[interface]`, sleutel `language`, in `user://config/display_settings.cfg` ([instellingen](../game/display_settings.gd)). Wijzig vertalingen in de [CSV-catalogus](../game/translations/translations.csv): één unieke sleutel, een Engelse en Nederlandse waarde, met passende placeholders zoals `%d` en `%s`. [LocalizedText](../game/localized_text.gd) werkt samengestelde UI-tekst bij na een taalwissel.
- Draai vanuit de repositoryroot, bij voorkeur met een apart testprofiel:

  ```sh
  godot --headless --editor --path game --import
  godot --headless --path game --script res://tests/test_localization.gd
  ```

- Verwacht `LOCALIZATION_OK` en exitcode 0. De [test](../game/tests/test_localization.gd) controleert onder andere menu, puntenkoersmelding, wisselen tijdens een race en herstart. Controleer in de gebouwde game beide talen ook visueel op afgeknotte labels, onopgeloste vertaalsleutels en verkeerd ingevulde placeholders.

## Mijn ritten, wedstrijdhistoriek en records

### Mijn ritten ([#60](https://github.com/filiberreke/Velodrome/issues/60))

**Huidig:** op het hoofdmenu opent **Mijn ritten / My rides** een trainingsoverzicht. Het gebruikt [de bestaande trainingsopslag](../game/training_store.gd), die per sessie lokaal schrijft naar `user://training_sessions/`. De [issuecommentaren](https://github.com/filiberreke/Velodrome/issues/60) bevestigen dat wedstrijden nog ontbreken.

**Voorgestelde acceptatie:** een afgeronde training en een afgeronde wedstrijd verschijnen elk één keer in dezelfde lijst, nieuwste eerst, met herkenbaar type en resultaat. Controleer ook een lege lijst, herstart en de terugknop. Leg vast of voortijdig opgeslagen trainingen in de lijst blijven en hoe afgebroken wedstrijden worden getoond. Haal wedstrijdactiviteiten niet uit een Top 10: een finish buiten die Top 10 is nog steeds een activiteit.

### Wedstrijdprestaties ([#44](https://github.com/filiberreke/Velodrome/issues/44))

**Huidig:** **Records** toont persoonlijke tijden voor individuele achtervolging, ploegenachtervolging en tijdrit. [Achtervolgingsrecords](../game/performance_records.gd) houden de snelste tien per discipline, afstand en ploegomvang bij; de [tijdrit](../game/time_trial_records.gd) bewaart ritten apart en onderscheidt staande en vliegende start. De [AI-records](../game/config/CONFIGURATION.txt) zijn een andere gegevensbron. Geen van deze lijsten is een algemene historiek van de laatste tien wedstrijddeelnames per moeilijkheid.

**Voorgestelde acceptatie:** houd per wedstrijdvorm de **laatste tien deelnames** op datum bij, los van de **beste prestatie ooit per ingesteld percentage** waar een percentage van toepassing is. Leg vóór implementatie vast welke maatstaf per discipline telt (bijvoorbeeld tijd of klassering), hoe varianten gescheiden worden en hoe een ex aequo wordt behandeld. Test elf deelnames, minstens twee percentages, een herstart en een beste resultaat dat uit de lijst met de laatste tien valt maar als record bewaard blijft.

### Toetsenbord en smarttrainer ([#42](https://github.com/filiberreke/Velodrome/issues/42))

**Huidig:** het [achtervolgingsrecord](../game/performance_records.gd) wordt niet per invoerbron gegroepeerd. Historische resultaten zonder betrouwbare broninformatie kunnen niet achteraf veilig aan één bron worden toegewezen.

**Voorgestelde acceptatie:** bewaar bij een prestatie de bron van het **vermogen** (trainer of manueel/gesimuleerd), los van de bediening. Met het toetsenbord sturen terwijl de trainer vermogen levert, telt dus niet als manueel vermogen. Beslis expliciet wat er bij bronwissels of een verbroken verbinding gebeurt; label bestaande records zonder bewijs als onbekend. Test twee resultaten met dezelfde discipline en moeilijkheid maar verschillende bronnen. Bevestig vóór reset welke categorieën worden gewist; laat andere categorieën en de ritgeschiedenis ongemoeid.

## Renners en omnium: migratie voorbereiden ([#66](https://github.com/filiberreke/Velodrome/issues/66))

**Huidig op `v0.4`:** het spel heeft een preview en outfitkeuzes in Instellingen ([`player_appearance.gd`](../game/player_appearance.gd)); de nieuwe hoofdmenuflow en centrale catalogus uit het issue zijn daar niet mee gelijk te stellen. [De omniumloader](../game/omnium/omnium_catalog.gd) leest nog twee configuratiebestanden en verwacht elk 24 renners. [Configuratiepaden](../game/config_paths.gd) onderscheiden bestanden naast het spel van gegevens in `user://`.

- Maak vóór een migratietest een kopie van de bewerkbare `riders_config.cfg` en beide `omnium_*_24_riders_config.cfg`-bestanden, plus `user://config/rider_profile.cfg`, `user://config/player_appearance.cfg` en de volledige map `user://omnium/`. Werk op kopieën; deel persoonlijke configuratie of saves niet in Git.
- Controleer op dubbele renner-ID's en conflicten tussen bronbestanden. Bewaar expliciete outfit- en helmkeuzes en test ook een nationaal pak zonder bijhorende helm. Vergelijk een nieuw omnium met een al lopend omnium en het archief; een cataloguswijziging mag geen bestaande deelnemers of uitslagen vervangen.
- Leg vóór release vast welk speleruiterlijk een lopend omnium gebruikt en welke fallback geldt voor het ontbrekende vrouwelijke achtervolgingsmodel dat het issue noemt. Publiceer pas een spelershandleiding voor de nieuwe editor als de bediening, opslag en migratie getest zijn.

## Website en downloadcheck ([#63](https://github.com/filiberreke/Velodrome/issues/63))

**Huidig in Git:** de [website](../website/) bestaat uit statische NL- en EN-pagina's. De [Pages-workflow](../.github/workflows/website.yml) publiceert de map `website/` en draait automatisch bij een push naar `main`. De [NL-downloadpagina](../website/nl/downloads/index.html) en [EN-downloadpagina](../website/en/downloads/index.html) gebruiken de v0.3-release. Er is nog geen publieke v0.4-release gevonden.

- Laat de v0.3-links staan tot de tag én ZIP's voor v0.4 gepubliceerd zijn. Controleer dan in beide talen de release-API-URL, de directe downloadlinks, de bestandsnamen en de installatie-instructies. Test als uitgelogde bezoeker op Windows en macOS (Intel en Apple Silicon waar aangeboden); kijk ook of de directe links werken zonder JavaScript.
- Controleer de Pages-deployment op `main`, het ingestelde domein en HTTPS. Open in beide talen de handleiding en downloads vanuit het menu, controleer taalwissel op een subpagina en tabvolgorde op smalle schermen. Beschrijf alleen functies die de aangeboden download bevat; zet de taalkeuze uit #37 pas in de publieke handleiding wanneer ze in de download zit.

## Hardware en vermelding

### OpenBikeControl ([#70](https://github.com/filiberreke/Velodrome/issues/70))

De [bridge](../bridge/README.md) documenteert Bluetooth FTMS voor trainerbesturing en aparte ondersteuning voor de linker Zwift Ride-controller. Die ondersteuning is geen bewijs van OpenBikeControl-compatibiliteit. De [OpenBikeControl v1-specificatie](https://openbikecontrol.org/) beschrijft controllerinvoer via BLE of mDNS/TCP.

**Voorgestelde eerste stap:** kies één transport en documenteer welk toestel of welke simulator ermee getest wordt. Leg per ondersteunde knop de actie vast, inclusief indrukken en loslaten. Test schakelen, omhoog/omlaag, selecteren en terug; controleer dat een losgelaten knop niet blijft hangen na verbreken/herverbinden, dat een niet-gemapte knop niets doet en dat FTMS en Zwift Ride blijven werken. Maak pas daarna een compatibiliteitsclaim en vermeld daarbij het werkelijk geteste transport.

### Smart Trainer Apps ([#69](https://github.com/filiberreke/Velodrome/issues/69))

Concept voor het [aanmeldformulier](https://smarttrainerapps.com/submit/), **niet ingediend**:

- **Naam:** Vélodrome
- **Website:** https://velodrome.wielerpraat.be/
- **Beschrijving (EN):** “A 3D track cycling game. Race a virtual peloton on a 250 m velodrome with a compatible smart trainer, or play with simulated power and a keyboard.”
- **Type / platforms:** Game; Windows en macOS.
- **Broncode:** https://github.com/filiberreke/Velodrome
- **OpenBikeControl:** niet aanvinken zolang #70 niet geïmplementeerd en getest is. Controleer vóór indiening of de website en downloads publiek bereikbaar zijn en of er al een vermelding bestaat. Voeg desgewenst een echte gameplay-screenshot toe waarvoor publicatierechten vaststaan.
