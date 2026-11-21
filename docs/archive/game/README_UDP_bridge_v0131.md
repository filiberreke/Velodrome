# Velodrome 250 — Godot UDP Bridge v0.13.1

## Installatie en scope
Deze patch is gebaseerd op de laatste Records-versie. Pak uit in de projectmap waar project.godot staat en vervang main.gd. De nieuwe test staat in tests/test_bridge_protocol.gd. Alleen gewijzigde/nieuwe bestanden en deze README zijn opgenomen.
Uitsluitend de verwerking van het UDP-protocol is aangepast. Alle bestaande Godot-functies buiten de UDP-verwerking en de bijbehorende gear-normalisatie zijn gecontroleerd op gelijkheid met de basisversie. HUD-scripts, spelmodi, fysica, menu's en Python-bestanden zijn ongewijzigd. De eventuele bestaande weergave van de versnelling gebruikt nog dezelfde gegevenskoppeling; er zijn geen nieuwe HUD-velden of spelregels aan hartslag of versnelling gekoppeld.

## Ontvangen protocol
De bestaande PacketPeerUDP-ontvanger op 127.0.0.1:51723 blijft behouden. Telemetrie is UTF-8 JSON, ongeveer 10 Hz. Godot luistert niet op de interne ANT+-poort 51724. Er worden geen SIM-/ERG-commando's verstuurd en geen ERG-bediening toegevoegd: daarvoor is nog geen inkomend bridgeprotocol beschreven.

Nieuwe beschikbare Godot-waarden:
- trainer_selected_gear: int 1 t/m 12, of null als niet beschikbaar. Dit is de door de bridge gemelde gekozen versnelling, geen bevestiging dat de trainerweerstand al gewijzigd is.
- trainer_heart_rate_bpm: positief geheel getal, of null als niet beschikbaar. Ontvangst is onafhankelijk van de KICKR-vlag valid.
- trainer_gear: bestaande tekstuele gear-waarde blijft beschikbaar voor de al aanwezige koppeling, met — als niet beschikbaar. Een oude gear_label blijft als tekstuele fallback ondersteund wanneer er geen canoniek gear-veld is; een expliciete gear:null heeft altijd voorrang.

De nieuwe velden worden bij ieder telemetry-bericht bijgewerkt, ook bij hetzelfde sample_id en bij valid:false. Een ontbrekend veld of expliciete null wist een oudere waarde. Gear buiten 1–12, breuken, strings, booleans en niet-eindige getallen worden als niet beschikbaar behandeld. Getallen die JSON als integrale floats oplevert worden wel geaccepteerd.
Gear null in ERG-mode, bij STOP of vóór actieve FTMS-besturing wordt direct overgenomen. Godot leidt hier geen besturingsmodus of trainerbevestiging uit af.

De bridge blijft verantwoordelijk voor de vijfsecondencontrole op ANT+-hartslag; de door de bridge gemelde null wordt meteen verwerkt. Alleen als de volledige UDP-telemetriestroom langer dan één seconde stopt, wist Godot zelf de optionele waarden, passend bij de bestaande verbindingstime-out. Ongeldige KICKR-data wist een nog actuele hartslag op zichzelf niet.

## Bestaand gedrag
Vermogen, cadans, snelheid, geldigheidsvlag, korte dropout-overbrugging en de bestaande mid-demo-trainerreset blijven behouden. Null/ontbrekende numerieke velden geven veilige defaults: vermogen 0, snelheid/cadans -1 (niet beschikbaar). Malformed JSON en berichten die geen JSON-object zijn worden genegeerd zonder parsefouten in de console.
Live telemetrie blijft bij ieder pakket verversen. sample_id bepaalt uitsluitend de bestaande ontdubbeling van oorspronkelijke KICKR-meetpunten in de opname; herhaalde FTMS-samples worden dus niet dubbel opgeslagen.
De bestaande knopberichten RIGHT/SHIFT_UP_RIGHT, LEFT/SHIFT_DOWN_LEFT/SHIFT_DOWN_RIGHT en A behouden hun verwerking. Er zijn bewust geen wijzigingen gedaan aan hoe spelmodi die knopwaarden gebruiken.

## Getest
Godot 4.7.2 headless: 11 controles geslaagd: import, scriptcontrole, nieuwe bridgeprotocoltest, records, ploegenachtervolging, modelintegratie, individuele achtervolging, HUD, menu, volledige scratchwedstrijden en hoofdscene laden.
De protocoltest controleert het opgegeven voorbeeldbericht; alle twaalf versnellingen; ontbrekende/null/ongeldige velden; hartslag bij valid:false; gearwijziging zonder nieuw sample_id; verversen van vermogen/cadans/snelheid bij hetzelfde sample_id; ontdubbeling in de opname; bestaande knoppen en dropout; ongeldig JSON en de optionele-velden-time-out.
Ook de echte ontvangstroute is getest met een tijdelijk lokaal UDP-poortnummer en een UDP-testzender in Godot. Het pakket werd via PacketPeerUDP ontvangen en de onafhankelijke hartslag werd verwerkt. Hiervoor is geen Python-bridge gestart of gewijzigd; het testpoortnummer voorkomt een conflict met een eventueel draaiende bridge op 51723.

Niet getest: de echte Python-bridge v0.13.1, fysieke KICKR, ANT+/Garmin-hartslagsensor, Zwift Ride-shifters of omschakelen van echte hardware tussen SIM/ERG/STOP. De loopbacktest bewijst de lokale UDP-verwerking met representatieve JSON-berichten. De bestaande certificatenopslagmelding in deze omgeving blijft aanwezig; geen scriptfouten in de genoemde controles. Nieuwe HUD-plaatsing en gebruik van deze waarden in spelmodi vallen buiten deze patch.

## Zelf controleren
1. Start je bridge v0.13.1 en Godot. Controleer in de debugger trainer_selected_gear en trainer_heart_rate_bpm.
2. Een shifteractie moet trainer_selected_gear wijzigen, ook als sample_id gelijk blijft.
3. Hartslag moet kunnen wijzigen terwijl valid false is. Bij heart_rate_bpm:null moet de waarde null worden.
4. Bij ERG/STOP moet gear:null de vorige versnelling wissen. Er worden vanuit Godot geen ERG-commando's gestuurd.
5. Stop de volledige bridge: de optionele waarden moeten na circa één seconde niet meer beschikbaar zijn.

Automatische test: voer Godot headless uit met --script res://tests/test_bridge_protocol.gd vanuit de projectmap.
