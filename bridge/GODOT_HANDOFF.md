# Technische overdracht voor Godot — Bridge v0.15

## Spelkoppeling: optionele luchtweerstandsfactor

`set_grade` accepteert daarnaast optioneel `aero_scale`: eindig JSON-getal 0..1,
geen boolean/string/null. Weglaten betekent 1 (volledige ingestelde luchtweerstand),
ook als een eerdere aanvraag een lagere factor had. Ongeldig: `invalid_grade`,
zonder gedeeltelijke wijziging. Schema, lease, deduplicatie en modusregels blijven gelijk.

```json
{"type":"command","v":1,"id":"race-21","command":"set_grade","grade_pct":3.25,"ramp_pct_per_s":10,"aero_scale":0.31}
```

Status adverteert `aero_scale_supported=true` en toont de gewenste `aero_scale`.
De actuele FTMS-bevestigde coëfficiënt staat in `confirmed_simulation.cw`.
`Cw_effective = Cw_config * aero_scale * gear_factor^3`; Crr en helling worden
niet met de aerofactor vermenigvuldigd. De factor heeft een vaste ramp van 2/s,
met hetzelfde maximale tickbudget van 0,35 s. `applied_revision` wacht ook tot
de aerofactor bereikt is. 0 betekent geen aerodynamische belasting, geen vrijgave.
De windsnelheid in de FTMS-bytes blijft 0; de coëfficiënt modelleert beschutting.

Het spel gebruikt `1 - _draft_drag_reduction(0)` en controleert de capability
voordat het nieuwe veld wordt verzonden. De eerdere v0.15 blijft daardoor met
helling alleen bruikbaar. Zie [spelkoppeling](../game/README_trainer_control.md)
voor routehelling, lifecycle en tests. Hardwarewerking blijft te bevestigen.


Behoud telemetrie op 127.0.0.1:51723 (incl. gear 1..12 in actieve SIM, anders null).
Interne HR blijft op 51724. Eén gebonden `PacketPeerUDP` met vrije lokale bronpoort
op 127.0.0.1 stuurt UTF-8 JSON naar 127.0.0.1:51725 en ontvangt antwoorden op dezelfde socket.

Envelope: type=command, integer v=1, uniek string-id (1..64 ASCII letters/cijfers/_.:-).
Maximaal 1024 bytes, geen onbekende velden/NaN/Infinity/dubbele sleutels.

```json
{"type":"command","v":1,"id":"g1-1","command":"set_mode","mode":"SIM"}
{"type":"command","v":1,"id":"g1-2","command":"set_grade","grade_pct":5.25,"ramp_pct_per_s":2}
{"type":"command","v":1,"id":"g1-3","command":"heartbeat"}
{"type":"command","v":1,"id":"g1-4","command":"status"}
```

`set_grade` activeert echte FTMS Indoor Bike Simulation (0x11). grade_pct is een
eindig JSON-getal -20..20 met maximaal twee decimalen, geen boolean/string/null.
Optionele ramp_pct_per_s: 0.1..100 procentpunt/s vóór versnellingsfactor; standaard 2.
De trainer moet Simulation ondersteunen, anders simulation_unsupported. Alleen
toegestaan binnen SIM; in ERG volgt wrong_mode. Geen stille wijziging van de spelhelling.

Ride-versnellingen 1..12 blijven actief. In hellingregeling gebruikt de bridge een
benaderingsmodel van virtuele overbrenging: wegkrachten maal k en aerodynamische
belasting maal k³, factoren uit simulation_config.json. Versnelling 4 is neutraal.
Daarom kan de effectieve trainerhelling afwijken van de spelhelling, en groter zijn
dan 20%. Dit is geen native Wahoo/Zwift-schakelprotocol. Het spel moet dezelfde
betekenis van virtuele versnelling/snelheid hanteren voor een consistent fysiek model;
de bridge wijzigt Godot-snelheid niet. Zie SIMULATION.md voor de formules/aannames.

`set_grade 0` betekent vlakke weg met rol-/luchtweerstand en actieve versnelling.
Expliciet `set_mode SIM` verlaat de hellingregeling en herstelt de oude vaste
weerstandstabel. Stuur daarna opnieuw set_grade om hellingsimulatie te activeren.
Stuur SIM niet ieder frame: het is een bewuste modus-/backendkeuze.

Bestaande ERG-opdrachten blijven beschikbaar:

```json
{"type":"command","v":1,"id":"g1-5","command":"set_target_power","watts":1300,"ramp_w_per_s":1500}
{"type":"command","v":1,"id":"g1-6","command":"set_mode","mode":"ERG"}
{"type":"command","v":1,"id":"g1-7","command":"set_target_power","watts":0}
{"type":"command","v":1,"id":"g1-8","command":"stop"}
```

Positief doel in SIM wordt klaargezet, expliciet ERG activeert. watts is JSON-integer
0..1300, gecontroleerd tegen gemeld trainerbereik/increment. Ontbreekt 0x2AD8 dan
beslist de trainer alsnog; onleesbaar/ongeldig bereik blokkeert positieve ERG.
0 W betekent altijd vrijgave via FTMS Reset, ook uit hellingregeling: RELEASED.
0% helling betekent dat juist niet. Stop is terminaal tot bridgeherstart.

Antwoord: type=ack|error, v=1, hetzelfde id, ok en state. ACK result=accepted betekent
aanvraag geaccepteerd, geen hardwarebevestiging. Status result=snapshot geeft verse
toestand: disabled/last_error, mode/desired_mode, sim_backend/desired_sim_backend,
grade_pct, effective_grade_pct, gear_factor, confirmed_simulation (grade_pct/wind_mps/crr/cw),
target_w/confirmed_target_w, revision/applied_revision, release_confirmed en trainerfeatures.
Bevestig gewenste modus/backend/doel én applied_revision; een nieuwere aanvraag kan
een eerdere vervangen. Fysieke power blijft power_w in telemetrie. FTMS-weigering na
ACK verschijnt in verse status als disabled=true, last_error=ftms_error: ...; geen pushfout.

Positieve UDP-ERG én UDP-hellingregeling (ook 0%) vereisen elke seconde heartbeat
met NIEUW id. Vijf seconden stilte stopt de sturing en probeert Reset; herstart nodig.
Ook data/powerverlies >3 s, BLE-verlies en FTMS-fouten stoppen. Status, retries en
Ride-knoppen verlengen de lease niet. Console kan overnemen: claim na no_lease niet
automatisch opnieuw. Een FTMS-transactie kan vrijgave maximaal 5 s vertragen, waarna
cleanup-Reset zelf nog maximaal 5 s kan kosten. Vrijgave is geen gegarandeerde noodstop.

Deduplicatie per bronpoort/id gedurende 60 s; retry identieke inhoud/id op dezelfde
socket. IDs nooit hergebruiken. Maximaal één wijzigingsopdracht onderweg; status/
heartbeat mogen daarnaast. Vraag verse status bij onzekere aflevering. Verstuur
alleen bij verandering een hellingsopdracht, bijvoorbeeld maximaal 5 keer/s; heartbeat
blijft nodig als helling gelijk blijft. Aanbevolen geen automatische herbelasting na fout.

Nieuwe fouten: wrong_mode, simulation_unsupported, invalid_grade. Bestaande fouten:
invalid_power, unsupported_power, invalid_ramp, erg_unsupported, range_unavailable,
not_active, control_busy, no_lease, id_conflict en formaatfouten. Volledig: UDP_PROTOCOL.md.
v0.15 is softwarematig getest; trainerrespons en rijgevoel wachten op de usertest.

