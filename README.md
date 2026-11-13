# Velodrome

Een 3D-baanwielerspel op een piste van 250 meter, ontwikkeld met **Godot**, met AI-tegenstanders en een aparte **Python-bridge** voor indoorfietshardware. Je kunt ook zonder trainer spelen met toetsenbord en demovermogen.

> **Status:** actieve ontwikkeling / beta. De repository bevat speelbare disciplines, softwaretests en Windows-buildworkflows. Hardwarecompatibiliteit en rijgevoel zijn nog niet volledig op fysieke apparatuur gevalideerd.

## Spelvormen

De beschikbaarheid hieronder volgt de huidige wedstrijdkeuze in [game/race_menu.gd](game/race_menu.gd).

| Spelvorm | Huidige mogelijkheden |
| --- | --- |
| Scratch | Peloton met AI-tegenstanders, drafting en een eindklassement op ronden en finishvolgorde. |
| Puntenkoers | Sprintpunten elke 10 ronden, dubbele punten bij de finish en +20/−20 punten voor gewonnen/verloren ronden. |
| Afvalling | Iedere twee ronden valt de laatste renner met het achterwiel over de meet af. Keuze uit 4, 12 of 16 deelnemers. |
| Individuele achtervolging | 1 of 4 km; tegenoverliggende startlijnen, AI-tegenstander of een opgeslagen eigen rit. Geen drafting. |
| Ploegenachtervolging | 1 of 4 km; speler met 2 of 3 AI-ploegmaats, tegen een AI-ploeg of eerdere ploegprestatie. Automatische kopwissels, wattagedoelen en keuze tussen manuele weerstand en ERG in het wiel. |
| Tijdrit | Solo over 500 m of 1 km, met staande of vliegende start. Vergelijking met laatste rit, recent PR of all-time PR, apart per afstand en startwijze. |

Scratch, puntenkoers en afvalling beginnen met één geneutraliseerde ronde; de ingestelde wedstrijdafstand volgt daarna. De vliegende tijdrit heeft één aanloopronde.

**Ploegkoers (Madison) en keirin zijn zichtbaar als ‘Binnenkort’ en nog niet speelbaar.** Een configureerbaar Arcade-controllerprofiel is aanwezig voor toekomstige acties; dit is geen extra speelbare discipline.

Verder bevat het spel rennerpaspoorten en instelbare AI-profielen, spelersuiterlijk, camera's, wedstrijd-HUD, lokale records en opgeslagen achtervolgingsritten. Ritopname en CSV-, TCX- en FIT-export zijn aanwezig; Strava-koppeling is optioneel en vereist eigen accountconfiguratie. Echte Strava-upload en fysieke hartslag-/trainerwerking vallen buiten de beschreven hardwarevrije controles.

## Grafische standen

Via **F10 → Beeld → Eenvoudige graphics (na herstart)** kun je de lichte stand kiezen. Die gebruikt 400 eenvoudige middenpleinsupporters, zes eenvoudige tenten, eenvoudiger tribunepubliek en een intro van 2,5 seconden. De commentaarcabine en uitgebreide horeca- en media-inrichting vervallen; rennersboxen, officials, keldertrap, podium en live schermen blijven behouden. Standaard staat de optie uit. Beide standen gebruiken het compactere stadion met twee tribuneringen. Zie [grafische instellingen](game/docs/graphics_settings.md) voor details en controles.

## Projectstructuur

- [game/](game/) — het Godot-project: hoofdscene, GDScript, 3D-assets, interface, wedstrijdregels en AI.
- [game/config/](game/config/README.txt) — configuratievoorbeelden en uitleg over renners, Strava en lokale opslag.
- [game/docs/](game/docs/) en [game/verification/](game/verification/) — functiegerichte documentatie en verificatieverslagen; aanvullende wijzigingsnotities staan als `game/README_*.md`.
- [game/tests/](game/tests/) — Godot-tests.
- [bridge/](bridge/README.md) — Python-hardwarebridge v0.15, UDP-protocol, diagnose, tests en virtuele bridge.
- [packaging/](packaging/) — startbestanden, configuratiesjablonen en launcher voor de Windows-pakketten.
- [.github/workflows/](.github/workflows/) — onder meer Windows-demo, gebundelde Windows-build en hersteltests voor trainerbesturing.
- [simulation/](simulation/) — afzonderlijke Python-simulaties, analyses en testresultaten voor wedstrijdgedrag.
- [docs/](docs/README.md) — overzicht van geplande overkoepelende documentatie; de genoemde ontwerpdocumenten zijn daar nog niet uitgewerkt.

Sommige README's in submappen zijn historische patchinstructies. Gebruik voor een volledige checkout de installatie hieronder; voor actuele details zijn de betreffende code, configuratie en functiegerichte notities leidend.

## Installatie vanuit broncode

### Godot-game

De huidige [projectconfiguratie](game/project.godot) vermeldt Godot **4.7** met **GL Compatibility**; de [Windows-buildworkflow](.github/workflows/windows-demo.yml) gebruikt **4.7.2 stable**.

1. Clone de repository:
   ```powershell
   git clone https://github.com/filiberreke/Velodrome.git
   cd Velodrome
   ```
2. Open `game/project.godot` in Godot 4.7.2 en laat de assets importeren.
3. Start het project met **F5**. De hoofdscene is `game/main.tscn`.
4. Kies een spelvorm. Zonder ontvangen trainertelemetrie gebruikt het spel demovermogen; een bridge is daarvoor niet nodig.

Tijdens het rijden stuur je met **A/D** of **←/→**. Zonder trainer wijzig je het gevraagde vermogen met **↑/↓** of **+/−**, in stappen van 25 W. **C** wisselt camera en **Escape** opent tijdens de wedstrijd het pauzemenu. Het demovermogen gebruikt een energiemodel en is geen echte vermogensmeting.

### Hardwarebridge op Windows

De meegeleverde startprocedure gebruikt **Python 3.12**. De dependencies staan in [bridge/requirements.txt](bridge/requirements.txt): `bleak`, `openant` en `pyusb`.

1. Installeer Python 3.12 en sluit andere apps of bridges die dezelfde trainer, controller of ANT+-stick gebruiken.
2. Zet bij Zwift Ride eerst de linker controller aan, daarna de rechter. Activeer voor Garmin-hartslag de functie Broadcast Heart Rate.
3. Start `bridge/start_windows.bat`. Dit maakt een lokale `.venv` en installeert de dependencies; daarvoor is internet nodig.
4. Start het Godot-spel apart. De bridge blijft zoeken als de apparaten nog niet beschikbaar zijn.

Zonder ANT+-hartslag kun je starten met:

```powershell
.\bridge\start_windows.bat --no-ant
```

Zie de [bridgehandleiding](bridge/README.md) voor apparaatselectie, consolebediening en diagnose.

## Hardware en communicatie

De bridge implementeert de volgende koppelingen. Dit beschrijft de aanwezige ondersteuning in code, geen garantie voor ieder apparaat of iedere firmwareversie.

| Onderdeel | Implementatie en grenzen |
| --- | --- |
| Wahoo KICKR / KICKR CORE via Bluetooth FTMS | Vermogen, snelheid en cadans; SIM, ERG en FTMS-hellingsimulatie. Automatische trainerselectie zoekt standaard op `KICKR`. Beschikbaarheid van besturing hangt af van de geadverteerde FTMS-functies en het trainerbereik. Andere FTMS-trainers zijn niet als algemeen compatibel bevestigd. |
| Zwift Ride | BLE-verbinding via de linker mastercontroller; virtuele versnellingen, digitale knoppen en analoge stuurpaddles. Knoptoewijzing is configureerbaar via Instellingen → Controller. |
| Garmin ANT+-hartslag | ANT+-USB-stick met bestaande Dynastream/libusb0-koppeling op Windows; de startprocedure noemt Garmin vivoactive 5 met Broadcast Heart Rate. Hartslag wordt doorgegeven aan HUD en ritopname. |

De bridge heeft 12 virtuele versnellingen. Het spel kan routehelling en slipstream aan de trainer doorgeven; ploegenachtervolging kan ERG in het wiel gebruiken. Het virtuele versnellings-/weerstandsmodel is een benadering en gebruikt geen native Wahoo/Zwift-versnellingsprotocol. ERG-aanvragen zijn begrensd op 0–1300 W en worden getoetst aan de gemelde trainermogelijkheden; 0 W vraagt vrijgave via FTMS Reset.

Communicatie verloopt lokaal via UDP:

- `127.0.0.1:51723` — telemetrie en controllerberichten naar Godot.
- `127.0.0.1:51724` — interne ANT+-hartslagontvangst.
- `127.0.0.1:51725` — trainercommando's en status.

Start één spelinstantie en één echte of virtuele bridge tegelijk. De bridge bewaakt heartbeats en trainerfeedback en probeert na verbindingsverlies opnieuw te verbinden. Vrijgave via software garandeert geen mechanische nulweerstand bij proces- of verbindingsverlies; stop met trappen bij onverwachte weerstand.

Technische details: [UDP-protocol](bridge/UDP_PROTOCOL.md), [Godot-overdracht](bridge/GODOT_HANDOFF.md), [SIM-model](bridge/SIMULATION.md), [herstelprotocol](bridge/RECOVERY.md) en [trainerbesturing in het spel](game/README_trainer_control.md). Hardwarevrij testen kan met de [virtuele bridge](bridge/tools/README_virtual_bridge.md):

```powershell
python bridge/tools/virtual_bridge_ui.py
```

## Configuratie en opgeslagen gegevens

Voor een broncheckout kun je `game/config/riders_config.example.cfg` kopiëren naar `game/config/riders_config.cfg` om renners aan te passen. Zonder persoonlijk bestand gebruikt het spel het voorbeeld en vaste standaardidentiteiten. Behoud renner-ID's wanneer je namen wijzigt, zodat records gekoppeld blijven.

Strava is optioneel: kopieer `game/config/strava_config.example.cfg` naar `game/config/strava_config.cfg` en vul je eigen gegevens in. Persoonlijke configuraties horen niet in Git.

Bij een Windows-export staan bewerkbare configuraties in `config/` naast het spel. Gebruikersinstellingen en OAuth-tokens staan onder Godots `user://config/`; records en opgeslagen ritten hebben eigen mappen onder `user://`. Op Windows is de gebruikersmap:

```text
%APPDATA%\Godot\app_userdata\Velodrome 250 - Sprint Beta\
```

Zie [configuratie en opslag](game/config/README.txt) voor velden, migratie en recordindeling.

## Windows-builds

Er zijn twee buildworkflows aanwezig. Er zijn momenteel geen gepubliceerde [GitHub Releases](https://github.com/filiberreke/Velodrome/releases); downloadbare Actions-artifacts hangen af van geslaagde builds en hun bewaartermijn.

| Variant | Workflow / artifact | Starten na volledig uitpakken |
| --- | --- | --- |
| Demo zonder bridge | [Windows demo build](https://github.com/filiberreke/Velodrome/actions/workflows/windows-demo.yml) / `Velodrome-Demo-Windows-x64` | `Start-Velodrome.cmd`; maakt ontbrekende configuraties aan met 24 fictieve demorenners en lege Strava-gegevens. Een eigen bridge kan apart draaien. |
| Game met gebundelde bridge | [Windows bundled game and bridge](https://github.com/filiberreke/Velodrome/actions/workflows/windows-bundled.yml) / `Velodrome-Bundled-Windows-x64` | `Velodrome.exe`; initialiseert configuratie en start bridge en game. Gebruikt de laatste geslaagde demo-build met beschikbaar artifact. |

Houd alle uitgepakte bestanden samen. De gebundelde variant gebruikt geen `Start-Velodrome.cmd`; start daar ook niet rechtstreeks `VelodromeGame.exe`. De gebundelde distributie is volgens de packagingdocumentatie nog niet op Windows-hardware geverifieerd; de verpakte ANT+-backend kan verdere aanpassing vereisen.

Meer informatie: [demo en configuratiebehoud](packaging/windows-demo/README.txt) en [gebundelde launcher en build](packaging/windows-bundled/README.md).

## Ontwikkeling en verificatie

Er zijn hardwarevrije Python-tests, Godot-tests en functiegerichte verificatieverslagen aanwezig voor onder meer wedstrijdregels, startprocedures, records, controllerbediening, UDP, trainerherstel en export. Die controles vervangen geen fysieke trainer-/controllertest of volledige visuele acceptatietest. De validatiestatus verschilt per functie; zie onder meer [bridgevalidatie](bridge/VALIDATION.md), [tijdrit](game/docs/README_time_trial.md) en [controllerconfiguratie](game/docs/README_zwift_ride_phase3.md).

Voorbeelden vanuit de repositoryhoofdmap, met Godot op je PATH:

```powershell
py -3.12 -m unittest discover -s bridge/tests -v
godot --headless --editor --path game --import
godot --headless --path game --script res://tests/test_neutral_start.gd
godot --headless --path game --script res://tests/test_flying_time_trial.gd
```

Nog te bevestigen zijn onder meer de fysieke KICKR-respons en het rijgevoel, Ride-bediening op echte hardware, de gebundelde ANT+-werking en de volledige Strava-keten. De Windows-exportconfiguratie is geen bevestiging van ondersteuning voor andere besturingssystemen.

## Licentie

Dit project gebruikt de **GNU General Public License, versie 3 (GPLv3)**. De volledige gekozen licentietekst staat in [LICENSE](LICENSE).
