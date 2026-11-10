# Madison-aflossingstraining

In **Ploegkoers** kan je met twee renners de aflossing oefenen. Kies Easy of
Advanced en het aantal oefenronden. Dit is de aflossingstraining; ploegpunten,
ploegklassement en een volledig Madison-peloton zijn nog niet geïmplementeerd.

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

De bestaande trapanimaties worden ongewijzigd aangestuurd. Er is geen preload
of verplicht bestand voor Madison-assets. Zodra `madison_anims.glb` beschikbaar
is, kan een bovenlichaamfilter de clips
`madison_{giver,receiver}_{approach,sling,release}` op deze parameters aansluiten.
GRAB gebruikt de uitgestoken contactpose; SEPARATE bouwt terug naar fietsen.

De pose-strip wordt opgezocht op `sling_t`, met de piek op **0,6** en afbouw tot
1,0. `efficiency` blijft daarvan gescheiden en volgt de HUD. Standaardtijden:
GRAB 0,15 s, volledige SLING-strip 2,0 s (Easy lost op 1,2 s los), RELEASE
0,30 s, SEPARATE 0,80 s. APPROACH volgt de fysieke afstand, niet een vaste klok.
Tijden, bereik, piek en convergentiesnelheid zijn controllerparameters.

**Wacht op Blender:** bovenlichaamclips, mengen met de trapcyclus, definitieve
handankers en IK die beide handen op hetzelfde wereldcontact houdt. Het huidige
`contact_point` is een voorlopig gedeeld anker op handhoogte. Nog geen zichtbare
handgreep of slingerpose: de bestaande renners blijven voorlopig doortrappen.

## Validatie

Met Godot 4.7.2, na het importeren van de bestaande GLB/textuur-assets:

```text
Godot --headless --path game --script res://tests/test_madison.gd
Godot --headless --path game --script res://tests/test_madison_integration.gd
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

`capture_madison.gd` maakt met rendering schermafbeeldingen van menu en HUD in
`verification/madison/`. Bij lokale tests zijn bestaande asset-UID-waarschuwingen
en een Windows-certificaatmelding waargenomen; de tests zelf slagen.
