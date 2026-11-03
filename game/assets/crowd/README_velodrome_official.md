# Wedstrijdcommissaris (startschot, bel, finishvlag)

De game-code voor de nieuwe wedstrijdofficial staat in `game/infield_details.gd`.

## Nog te plaatsen modellen

Plaats het aangeleverde `velodrome_official.glb` in:

`game/assets/crowd/velodrome_official.glb`

Optioneel kan het Blender-bronbestand in `game/assets/source_blender/velodrome_official.blend` worden geplaatst.

**Waarom apart?** De GitHub-connector kan tekstwijzigingen committen, maar heeft in deze sessie geen manier om de meegeleverde binaire bestanden te uploaden. Die bestanden zitten wel in het eerder aangeleverde integratie-ZIP-pakket.

Totdat het GLB aanwezig is, gebruikt de game automatisch `flag_official.glb` en het bestaande vlaggedrag. Dit voorkomt dat de game crasht door een ontbrekend asset.

## Animaties

- `VO_StartPistol`: bij overgang naar `RACING`
- `VO_LastLapBell`: eenmalig zodra de koploper de laatste ronde bereikt
- `VO_FinishFlag`: zodra een renner de finish passeert

De acties worden in Godot door de bestaande wedstrijddata aangestuurd; er zijn geen wijzigingen aan de bridge nodig.

## Controle

Open het Godot-project nadat het GLB gekopieerd is, laat Godot het model importeren en controleer de positie/orientatie bij de aankomstlijn. Test een start, de overgang naar de laatste ronde en het finishen van meerdere renners. Godot-runtimevalidatie is in deze sessie niet uitgevoerd.
