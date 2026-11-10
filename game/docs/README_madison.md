# Madison-aflossingstraining

In **Ploegkoers** kan je met twee renners de aflossing oefenen. Kies Easy of
Advanced en een sessie van **10 of 20 aflossingspogingen**. Dit is de aflossingstraining; ploegpunten,
ploegklassement en een volledig Madison-peloton zijn nog niet geïmplementeerd.

Advanced blijft grijs totdat een volledige Easy-sessie minstens 70% geslaagde
pogingen heeft: **7/10 of 14/20**. De vrijgave blijft bewaard in
`user://config/madison_progress.cfg`. Een geldige greep gevolgd door release met
positieve momentumoverdracht telt als geslaagd. Elke naderingskans telt eenmaal:
een gemist venster of verloren contact telt als mislukking; meerdere ongeldige
knopdrukken binnen dezelfde kans voegen geen extra pogingen toe. Stoppen of
herstarten begint een nieuwe reeks. Na 10/20 beoordeelde kansen en de laatste
scheidingsfase eindigt de sessie automatisch en toont het resultaat de score.

De ploegmaat draagt dezelfde uitrusting als de speler: standaardkleuren,
skinsuit/landentenue, helm, vizier en standaardopdrukken. Zijn eigen lichaamsbouw
en rijprofiel blijven behouden. Outfitwissels in de instellingen gelden meteen
voor beide renners en blijven ook bij een nieuwe start gelijk.

## Bediening

- Toetsenbord: **A** grijpen/vasthouden/loslaten; **← →** of D sturen.
- Gamepad: **A** gebruikt beide knopranden.
- Zwift Ride: fysieke **A** gebruikt de bestaande `controller_button`-berichten
  met `pressed: true/false`. In Madison is deze knop voor de aflossing gereserveerd.
  Sturen via de bestaande stuurbediening blijft beschikbaar.
- Easy: één druk grijpt, daarna automatisch slingeren en loslaten bij de piek.
  Maximum 70%, vermenigvuldigd met grijpprecisie.
- Advanced: druk om te grijpen, houd vast tot de gewenste slingeropbouw, laat los.
  Maximum 100%, vermenigvuldigd met grijpprecisie. Voorbij de piek neemt de
  beschikbare overdracht af. Na volledig overschrijden wordt met 0% losgelaten.
- Pauze breekt een lopende aflossing af. Een verdwenen Ride-knop, verbroken
  controllerverbinding of verlopen controllerheartbeat verwerkt een ontbrekende
  loslaatrand. Oude bridges met uitsluitend drukberichten ondersteunen geen
  betrouwbaar Advanced-loslaatmoment; gebruik daarvoor de bridge met knopranden.

De HUD staat centraal bovenaan onder de wattagebalk. Tijdens APPROACH schuift
de markering van links naar rechts op basis van de werkelijke onderlinge
positie. Grijpen bevriest de markering; daarna volgt de breedte het beschikbare
momentum. De ideale grijppositie ligt op 80% van de balk (naast elkaar).

## Ruimte en fysica

De actieve/snelle renner is de gever en rijdt binnen. De ontvanger rijdt op
3,58 m (blauwe lijn) of 2,98 m (één spelerslijn lager). Handbereik wordt in 3D
op de bestaande gebankte piste gemeten, maximaal 1,80 m. Beide modellen krijgen
tijdens naderen een geleidelijke laterale correctie, maximaal 0,20 m per model,
met 0,65 m/s. Grijpen vereist dat de visuele afstand circa 1,40 m heeft bereikt.
Geen spelpositie wordt daarvoor verplaatst. Na loslaten vloeien offsets terug.

Contact gebruikt begrensde, tegengestelde snelheidsimpulsen. De loslaatimpuls
wordt één keer toegepast: de ontvanger krijgt precies wat de gever verliest
(gelijke rennermassa aangenomen). De spelbalans gebruikt voorlopig een
begrensde impuls van maximaal 3 m/s; dit is een afstelbare spelparameter,
geen gevalideerd biomechanisch model. Sturen buiten bereik verbreekt contact.
De afgeremde AI kiest 4,78 m en gaat met de bestaande baanwisselsnelheid naar
buiten; voor het kruisen van de spelerslijn wacht hij op 2,2 m vrije ruimte.
De speler houdt zijn lijnkeuze en stuurcontrole. De rollen wisselen;
de AI kan in de volgende aflossing als snelle binnenrenner terugkeren.

## Controller en Blender-contract

`madison_exchange.gd` heeft precies vijf fasen, met `active` als aparte vlag:
APPROACH → GRAB → SLING → RELEASE → SEPARATE. Na een mislukte poging kan direct
naar SEPARATE worden gegaan. Er is geen extra animatie/idle-fase vereist.

Signalen:

- `phase_changed(phase, giver, receiver)`
- `released(giver, receiver, efficiency)`
- `missed(reason)`
- `animation_parameters(parameters)`

`parameters()` levert `active`, `phase`, `giver`, `receiver`, `approach_t`,
`phase_t`, `sling_t`, `precision`, `efficiency`, `hand_contact`, `contact_point`,
`visual_offsets`, `advanced`, `can_grab` en een HUD-bericht. `rider_visual.gd`
bewaart per model `madison_state`, voegt `role` en `hand` toe en stuurt het
signaal `madison_parameters_changed`. Gever gebruikt rechts, ontvanger links.

De Blender-levering is aangesloten via `madison_animation.gd` en de tijdelijke
`MadisonRiderRig`/`MadisonTwoBoneIK`-componenten uit `game/madison/`.
Alleen de twee deelnemers krijgen een AnimationTree met een filter op de twaalf
bovenlichaambotten. De bestaande trapcyclus blijft op dezelfde crankfase lopen.
De zes clips `madison_{giver,receiver}_{approach,sling,release}` komen uit
`assets/riders/madison/madison_anims.glb`; de oorspronkelijke rennermodellen
en hun animaties zijn niet gewijzigd. GRAB mengt de uitgestoken pose naar
handcontact; SEPARATE bouwt terug naar fietsen.

Eerst worden beide modellen op de werkelijke piste geplaatst, daarna worden
hun gedeelde wereldankers bijgewerkt, en pas dan beide trap-/bovenlichaamposes.
De adapter corrigeert een resterende visuele gap tot 1,00–1,40 m, met maximaal
4° extra modellean en begrensde veranderingssnelheid. Dit vangt ook het krappe
0,60 m-geval op. Gameplayposities en stuurkeuze blijven ongemoeid.

De pose-strip wordt opgezocht op `sling_t`, met de piek op **0,6** en afbouw tot
1,0. `efficiency` blijft daarvan gescheiden en volgt de HUD. Standaardtijden:
GRAB 0,15 s, volledige SLING-strip 2,0 s (Easy lost op 1,2 s los), RELEASE
1,15 s, SEPARATE 0,30 s. RELEASE bevriest de bereikte slingpose, mengt in
0,20–0,40 s naar de loslaatclip en zoekt die vervolgens in 0,75 s op.
APPROACH volgt de fysieke afstand, niet een vaste klok.
Tijden, bereik, piek en convergentiesnelheid zijn controllerparameters.

IK richt de echte grijphandankers op hetzelfde wereldcontactpunt. Bij twee
opeenvolgende frames boven 94% armstrekking volgt een gecontroleerde vroege
RELEASE met reden `reach`. Na afloop, herstart en verlaten van de race worden
trees, IK-modifiers en tijdelijke animatiebibliotheken verwijderd, offsets
hersteld en de oorspronkelijke modifierinstelling teruggezet.

De meegeleverde zelfstandige animatiedemo blijft beschikbaar als
`res://madison/madison_demo.tscn`. Zijn prototypecontroller heet nu
`MadisonDemoExchange` om verwarring met de speelbare controller te voorkomen.
Die demo heeft eigen automatische Easy-grepen en een eigen voorbeeldcurve.
De game behoudt uitdrukkelijk A om te grijpen, precisie, de 70%/100%-limieten,
de bestaande momentumcurve en de sessie-/vrijgaveregels. Animatie en HUD lezen
dezelfde `sling_t`, met dezelfde piek op 0,6; de animatieclip schrijft geen
gameplaysnelheden of score.

Beperkingen uit de levering blijven relevant: eenvoudige wanten zonder
vingergreep, kleine afwijking van de niet-grijpende hand bij lean, en validatie
op Windows/Godot 4.7.2. Zie `docs/madison/README.md` voor de oorspronkelijke
prototypeproeven; die vervangen de echte spelintegratietest niet.

## Validatie

Met Godot 4.7.2, na het importeren van de bestaande GLB/textuur-assets:

```text
Godot --headless --path game --script res://tests/test_madison.gd
Godot --headless --path game --script res://tests/test_madison_integration.gd
Godot --headless --path game --script res://tests/test_madison_progress.gd
Godot --headless --path game --script res://tests/test_madison_kit.gd
Godot --headless --path game --script res://tests/test_madison_game_animation.gd
Godot --headless --path game --script res://tests/test_menu.gd
Godot --headless --path game --script res://tests/test_hud.gd
Godot --headless --path game --script res://tests/test_bridge_protocol.gd
Godot --headless --path game --script res://tests/test_ride_mapping.gd
Godot --headless --path game --script res://tests/test_gameplay_headless.gd
```

De Madison-tests controleren beide rollen, Easy/Advanced, perfecte en minder
precieze grepen, vroege release, overhold, bereik, gemiste grepen, contactverlies,
geleidelijke offsets, momentumoverdracht, vijf fasen in de echte racefysica,
banking/rondeovergang en onafhankelijke gelijktijdige invoerbronnen. De bestaande
scratchsimulaties van 8 renners/10 ronden en 12 renners/50 ronden slagen ook.

De vijf meegeleverde testsets (`clips`, `contact`, `release`, `flow`,
`baseline`) slagen op de geïntegreerde code. Hun test-scenes worden expliciet
opgeruimd. De nieuwe `test_madison_game_animation.gd` gebruikt echte renners en
`main.gd`-plaatsing: maximaal 2,21 mm tussen beide handen in de beproefde
stilstaande rechte/bochtposes, en 2,14 mm tijdens de beproefde bewegende
aflossing. Dit zijn metingen van die scenario's, geen garantie voor elke
mogelijke stuurbeweging. De test controleert ook crankfase, gedeelde
`sling_t`, vroege release, de derde onaangetaste renner en opruimen.

`capture_madison.gd` maakt met rendering schermafbeeldingen van menu en HUD in
`verification/madison/`. Bij lokale tests zijn bestaande asset-UID-waarschuwingen
en een Windows-certificaatmelding waargenomen; de tests zelf slagen.
