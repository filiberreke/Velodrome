# Velodrome Bridge v0.15 — lokaal UDP-protocol v1

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


## Transport en envelope

Eén UTF-8 JSON-object per datagram van 1..1024 bytes, geen BOM. IPv4 bestemming
`127.0.0.1:51725`. Gebruik één gebonden Godot-socket met vrije bronpoort en ontvang
antwoorden op dezelfde socket. Gebruik 51723/51724/51725 niet als bronpoort.
Alleen afzender-IP exact 127.0.0.1 wordt aanvaard; er is geen LAN-bindoptie.
Geen NaN/Infinity, dubbele sleutels, array-envelope of onbekende velden.

| Verplicht veld | Vereiste |
| --- | --- |
| `type` | string `command` |
| `v` | integer `1`, geen boolean |
| `id` | unieke string 1..64 ASCII letters/cijfers/`_.:-` |
| `command` | één van onderstaande zes opdrachten |

Gebruik een willekeurig sessievoorvoegsel plus teller als id. Veldvolgorde is vrij.

## Nieuw in v0.15: set_grade

```json
{"type":"command","v":1,"id":"session-grade-1","command":"set_grade","grade_pct":5.25,"ramp_pct_per_s":2.0}
```

Verplicht `grade_pct`: eindig JSON-getal -20..20, maximaal twee decimalen, geen boolean/string/null.
Optioneel `ramp_pct_per_s`: 0.1..100 procentpunt/s voor de weghelling vóór versnellingsfactor;
standaard 2.0, daarna blijft de eerdere keuze gelden. De versnellingsfactor heeft een eigen
ramp (standaard 0.5/s). Helling is alleen geldig als de gewenste modus SIM is; anders
`wrong_mode`. Geen Simulation-feature (0x2ACC target bit 13): `simulation_unsupported`.
Ongeldige helling/ramp: `invalid_grade`. Er is geen stille clamping of afronding van de aanvraag.

`set_grade` activeert SIM-backend `simulation` en dus echte FTMS-opcode 0x11, na Reset
en nieuwe controleaanvraag. De oude 0x04-regeling is dan uit. `set_mode SIM` zet de
backend terug naar `resistance` en maakt de opgeslagen helling 0. `set_mode ERG` wist
eveneens de hellingkeuze. Nieuwe set_grade vóór voltooiing kan de vorige vervangen.

Ook 0% houdt de simulatie, rol-/luchtweerstand, huidige versnelling en UDP-lease actief.
Een nieuw positief ERG-doel klaarzetten tijdens hellingregeling verandert die regeling
niet. `set_target_power 0` heeft altijd voorrang als vrijgave: RELEASED na Reset.

Stuur iedere seconde heartbeat met een nieuw id, ook op vlakke weg. De lease is aan
dezelfde bronpoort gekoppeld en stopt na vijf seconden stilte. Status/retries en
Ride-knoppen verlengen de lease niet. Drie seconden zonder trainerdata/powerfeedback
wist doelen/lease en pauzeert de regeling ook; de bridge blijft zoeken en
herverbinden. Een nieuwe opdracht na herstel heeft geen bridgeherstart nodig.
Bij consolewijziging verdwijnt UDP-eigendom zoals bij ERG.

Extra velden in elke state (oudere clients mogen onbekende responsevelden negeren):

| Veld | Betekenis |
| --- | --- |
| waiting_for_feedback | Tijdelijke onderbreking: wachten op verse trainerdata en power; geen nieuwe belasting toegestaan. |
| reconnect_ready | Oude doelen gewist na uitval; nieuwe wedstrijd mag de vrijgegeven sessie expliciet activeren. |
| simulation_supported | Trainer adverteert Indoor Bike Simulation Parameters. |
| sim_backend / desired_sim_backend | Bevestigde / aangevraagde SIM-regeling: resistance of simulation. Alleen relevant in SIM. |
| grade_pct | Door Godot gevraagde weghelling; nooit stil aangepast. |
| grade_ramp_pct_per_s | Huidige hellingsramp vóór versnellingsfactor. |
| gear_factor | Gewenste virtuele snelheids-/overbrengingsfactor van de gekozen versnelling. |
| effective_grade_pct | Eindhelling die het wegmodel voor de gekozen versnelling berekent; kan afwijken van grade_pct. |
| confirmed_simulation | Laatst FTMS-bevestigde grade_pct/wind_mps/crr/cw, of null buiten actieve simulatie. |

`applied_revision` wordt pas bijgewerkt als weghelling en versnellingsfactor het
gevraagde eindpunt bereiken. Een Ride-versnellingswijziging in simulatie verhoogt ook revision.
Een parameterbevestiging bewijst geen fysieke prestatie; vergelijk met power_w in
telemetrie. Helling/versnelling beïnvloeden samen de trainerparameters: zie
[SIMULATION.md](SIMULATION.md). Geen afleiding van een KICKR-maximum uit 0x2AD5:
die characteristic is geen betrouwbaar bereik voor deze specifieke 0x11-wegmodus.
Fysieke trainergrenzen kunnen lager zijn; een weigering stopt via de bestaande FTMS-foutafhandeling.

## Bestaande opdrachten

```json
{"type":"command","v":1,"id":"session-01","command":"status"}
{"type":"command","v":1,"id":"session-02","command":"set_target_power","watts":1300,"ramp_w_per_s":1500}
{"type":"command","v":1,"id":"session-03","command":"set_mode","mode":"ERG"}
{"type":"command","v":1,"id":"session-04","command":"heartbeat"}
{"type":"command","v":1,"id":"session-05","command":"set_target_power","watts":0}
{"type":"command","v":1,"id":"session-06","command":"set_mode","mode":"SIM"}
{"type":"command","v":1,"id":"session-07","command":"stop"}
```

- `set_mode`: verplicht `mode`, exact `SIM` of `ERG`. ERG valideert het opgeslagen
  doel opnieuw; positief ERG vereist verse trainer-powerfeedback.
- `set_target_power`: verplicht `watts`, **JSON-integer 0..1300**, geen boolean,
  float, string of null. Optioneel `ramp_w_per_s`: eindig getal 1..10000, geen boolean.
  Zonder rampveld blijft de eerdere snelheid gelden, aanvankelijk 300 W/s of CLI-keuze.
  Positieve doelen moeten passen bij trainerbereik en `min+n*increment`.
  Positief in SIM wordt klaargezet; expliciet `set_mode ERG` activeert de belasting.
  Positief na RELEASED hervat ERG, omdat de gewenste modus ERG gebleven is.
  0 vraagt altijd vrijgave via Reset, ook vanuit SIM, zonder ramp of Set Target Power 0.
  Daarna `mode=RELEASED`, `confirmed_target_w=null`, geen automatische terugkeer naar SIM.
- `heartbeat`: geen extra velden; alleen geldig voor huidige UDP ERG-eigenaar.
- `status`: geen extra velden; verse status, geen leaseverlenging.
- `stop`: geen extra velden; terminale stop, Reset geprobeerd, herstart vereist.
  Ook beschikbaar vóór ready, bij een fout of vanaf een andere lokale bronpoort.

## Antwoorden en bevestigingen

Het ACK-voorbeeld hieronder toont de basisvelden; v0.15 voegt de hierboven beschreven simulatievelden toe.

```json
{"type":"ack","v":1,"id":"session-02","ok":true,"result":"accepted","state":{"started":true,"disabled":false,"mode":"SIM","desired_mode":"SIM","target_w":1300,"confirmed_target_w":null,"ramp_w_per_s":1500.0,"revision":1,"applied_revision":0,"release_confirmed":false,"power_supported":true,"power_range":{"min_w":0,"max_w":1800,"increment_w":1},"range_state":"known","last_error":null,"udp_owned":false,"lease_remaining_s":0.0}}
```

Het bereik is hier een voorbeeld, geen KICKR CORE-claim. `result=accepted` betekent
gewenste toestand lokaal geaccepteerd; er is geen BLE-I/O in de UDP-handler.
`status` krijgt `result=snapshot`. Nieuwere verzoeken kunnen een nog niet uitgevoerde
toestand vervangen. Lees met telkens een nieuw status-id:

| Stateveld | Betekenis |
| --- | --- |
| `started`, `disabled` | FTMS-start voltooid; sturing terminaal geblokkeerd. |
| `mode`, `desired_mode` | Bevestigde regelmodus versus aanvraag. SIM vóór started=true is alleen de startinstelling. |
| `target_w`, `confirmed_target_w` | Gevraagd einddoel versus laatst FTMS-bevestigde rampwaarde. Fysieke power komt via telemetrie. |
| `revision`, `applied_revision` | Nieuwste sturingsrevision versus laatst bereikte toestand. Heartbeat/status wijzigen revision niet. |
| `release_confirmed` | Reset door FTMS bevestigd; geen garantie op mechanische nulweerstand. |
| `power_supported` | Target Power-feature gemeld. |
| `power_range` | Object met min_w/max_w/increment_w, of null. |
| `range_state` | unknown vóór uitlezen; known; unavailable bij ontbrekende 0x2AD8; invalid bij onleesbaar/ongeldig. |
| `last_error` | Stopreden/fout, anders null. |
| `udp_owned`, `lease_remaining_s` | Aanwezige ERG-lease en resterende seconden; geen authenticatie. |
| `ramp_w_per_s` | Huidige geconfigureerde overgangssnelheid. |

Controleer voor bevestiging óók doel, modus en disabled=false. Een nieuwere revision
kan een oudere opdracht vervangen; applied_revision >= een oud id bewijst dus niet
dat die oude opdracht is uitgevoerd. In SIM betekent toegepast dat SIM actief is,
niet dat een klaargezet ERG-doel al actief is. Bij 0 W controleer RELEASED plus release_confirmed.

Foutstructuur (het echte `state` bevat dezelfde volledige status als ACK):

```json
{"type":"error","v":1,"id":"session-08","ok":false,"code":"unsupported_power","message":"1300 W niet ondersteund: min=50, max=1000, stap=5 W; doel niet aangepast","state":{}}
```

Bij ongeldig JSON/envelope/schema is `id=null`; bij een schema-geldige opdracht het ontvangen id.

| Foutcode | Betekenis |
| --- | --- |
| invalid_packet / invalid_json | Omvang, JSON of UTF-8 ongeldig. |
| invalid_id / invalid_envelope / invalid_fields | ID, type/versie of veldenset ongeldig. |
| unknown_command / invalid_mode | Onbekende opdracht of andere modus dan SIM/ERG. |
| invalid_power / invalid_ramp | Type of globaal bereik ongeldig. |
| unsupported_power | Buiten trainerbereik of niet op min+n*increment; doel niet aangepast. |
| erg_unsupported | Geen Target Power-feature. |
| range_unavailable | Aanwezige 0x2AD8 onleesbaar/ongeldig; positieve ERG geblokkeerd. |
| not_active | Nog niet ready, lease verlopen, STOP of terminale fout; zo nodig herstarten. |
| control_busy / no_lease | Andere UDP-eigenaar of heartbeat zonder eigen lease. |
| id_conflict | Zelfde bronpoort/id met andere inhoud. |
| server_busy | Deduplicatiecache vol; nieuw id na wachttijd gebruiken. |

Bij ontbrekende 0x2AD8 blijft 1..1300 aanvragen mogelijk; de trainer beslist alsnog.
Een latere FTMS-weigering of timeout wijzigt een eerdere ACK niet. Lees verse status:
`disabled=true`, `last_error=ftms_error: ...`, inclusief opcode/resultaat bij weigering.
Geen aparte pushresponse na ACK. De bridge probeert cleanup-Reset en hervat niet automatisch.

## Deduplicatie, volgorde en lease

Deduplicatie per `(bron-IP, bronpoort, id)` gedurende 60 s, maximaal 2048 records.
Schema-geldige antwoorden, inclusief semantische fouten, worden byte-identiek herhaald.
Een retry voert niets opnieuw uit en verlengt geen lease. Na 60 s kan een id opnieuw
worden uitgevoerd: hergebruik IDs daarom nooit tijdens een sessie. Schemafouten
worden niet gecachet. Bij volle cache blijft stop bruikbaar; stop is zelf idempotent.

UDP garandeert geen aflevering/volgorde. Houd maximaal één wijzigingsopdracht onderweg;
heartbeat/status mogen daarnaast lopen. Retry identieke inhoud/id bijvoorbeeld na
0.3/0.6/1.2 s. Iedere heartbeat krijgt een nieuw id. Gebruik na onzekere aflevering
verse status voordat een volgende wijziging wordt gestuurd. Vertraagde pakketten
met een nieuw id kunnen een nieuwere toestand vervangen. Gebruik na herstart een nieuw sessievoorvoegsel.

Positieve UDP-ERG en UDP-hellingregeling (ook 0%) binden de lease aan de bronpoort. Iedere nieuwe geldige ERG-/simulatie-
besturingsopdracht van die eigenaar of heartbeat verlengt tot vijf seconden.
Stuur iedere seconde heartbeat. Alleen een positief doel klaarzetten in SIM neemt
geen lease. Andere UDP-clients mogen tijdens een lease alleen status/stop; console
kan expliciet overnemen. Na console-overname geeft heartbeat no_lease: claim dan
niet automatisch opnieuw ERG. Expliciet set_mode SIM en 0 W verwijderen de lease; set_grade 0 houdt de lease actief.

## Veiligheid en fysieke betekenis

De trainer-loop draait normaal circa iedere 100 ms. ERG en hellingregeling stoppen bij leaseverlies,
meer dan drie seconden zonder FTMS-data of powerfeedback, BLE-verlies of FTMS-fout.
BLE-verlies en ontbrekende data/power zijn nu tijdelijke onderbrekingen: doelen
en lease worden gewist, de bridge blijft zoeken en vraagt na herstel alleen
vrijgave aan. waiting_for_feedback blijft true totdat verse data én power binnen
zijn. reconnect_ready laat een expliciete nieuwe wedstrijd/opdracht toe zonder
procesherstart. Zie [RECOVERY.md](RECOVERY.md). Een geldige 0-W-vrijgave mag ook
tijdens deze offline wachtfase worden klaargezet; andere sturing krijgt not_active.
udp_timeout, console_stop, udp_stop en ftms_error blijven terminaal voor sturing.
Geen automatische herbelasting na onderbreking of terminale stop/fout.
Status blijft beschikbaar. Een FTMS-write/indication kan maximaal vijf seconden
duren en vrijgave vertragen; cleanup-Reset kan daarna nog maximaal vijf seconden
kosten. Nieuwere stop-/modusverzoeken worden na een lopende transactie opgepakt;
er volgen dan geen verdere oude rampstappen. Console/UDP doen nooit parallelle BLE-writes.

0 W gebruikt de bestaande FTMS Reset-functie, niet Target Power 0. Een niet bevestigde
Reset is een fout. Reset is geen gegarandeerde mechanische nulweerstand/noodstop;
bij BLE- of procesverlies kan software geen vrijgave afdwingen.

Ramping is tijdgestuurd, instelbaar 1..10000 W/s. Eerste stap: kleinste positieve
geldige trainerdoel (1 W bij onbekend bereik); daarna trainerincrementen met
fractionele accumulatie. Hoog minimum kan een eerste sprong vereisen. Maximaal
0.35 s rampbudget per tick voorkomt een inhaalsprong na BLE-stagnatie. Dit is een
softwarematige bovengrens, geen garantie op fysieke responstijd of haalbaar vermogen.

Ingresslimiet: globaal 50 datagrammen/s, burst 100. Overschrijding en niet-lokale
bronnen worden stil genegeerd, zonder ACK/leaseverlenging. Loopback is bronbeperking,
geen authenticatie tegen lokale processen.

## Bestaande berichten

Telemetrie op 127.0.0.1:51723 en interne HR op 51724 veranderen niet. Geen ERG-
statusvelden toegevoegd aan telemetrie: gebruik status op 51725. gear blijft 1..12
in actieve SIM, anders null; Ride-knopberichten blijven behouden.


