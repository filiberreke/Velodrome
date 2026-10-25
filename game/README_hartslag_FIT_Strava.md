# Hartslag in FIT en Strava-export

## Installatie

Pak deze ZIP uit naast `project.godot`, over de laatste eerste-voorwielpatch.
Vervang `main.gd` en `fit_export.gd` en behoud de map `tests`. Alleen gewijzigde
en nieuwe bestanden zijn opgenomen. Open het project daarna opnieuw in Godot.
De volledige bijgewerkte werkkopie staat in `work/heart_rate_export_project`.
Het oorspronkelijke project is niet rechtstreeks overschreven.

## Wijziging

- De actuele `heart_rate_bpm` uit de bridge wordt met elke nieuwe geaccepteerde
  spelersmeting opgeslagen in `ride_records`.
- Zowel FIT indoor als FIT met virtuele GPS bevat nu de hartslag. De bestaande
  Strava-upload gebruikt dezelfde FIT-schrijver en bevat daardoor dezelfde gegevens.
- Hartslag is ook opgenomen als extra laatste kolom in de CSV-opname en als
  `HeartRateBpm` in de bestaande TCX-export.
- De hartslag hoort uitsluitend bij de speler. Ploegdata en gegevens van de
  AI-kopman worden niet gebruikt. De bestaande ploeg-/eerste-voorwieltiming blijft behouden.

De FIT-schrijver gebruikt veld 3 van het recordbericht, uint8, zoals beschreven
in het [Garmin FIT-protocol](https://developer.garmin.com/fit/protocol/).
Ontbrekende, ongeldige of verouderde hartslag wordt als onbeschikbaar geschreven
(FIT-invalidwaarde 255); er wordt geen hartslag van 0 bpm verzonnen. De CSV-cel
blijft dan leeg en het TCX-hartslagelement wordt weggelaten.

De bridge blijft bepalen wanneer een ANT+-meting verouderd is en levert dan null.
De bestaande Godot-watchdog voor uitblijvende UDP-telemetrie blijft actief.
Hartslag die op een herhaald `sample_id` verandert, wordt live verwerkt en komt
met de volgende nieuwe KICKR-meting in de opname; bestaande metingen worden niet
achteraf overschreven en originele KICKR-metingen worden niet gedupliceerd.
De bestaande FIT-export blijft maximaal één record per seconde schrijven.

Eerder gemaakte opnamen zonder opgeslagen hartslag kunnen niet achteraf worden
aangevuld. Zonder echte hartslagmeting genereert de demo geen fictieve hartslag.
Voor de HUD of de Python-bridge zijn geen wijzigingen nodig voor deze exportpatch.

## Getest

Godot 4.7.2 headless: import, statische scriptcontrole, nieuwe hartslagexporttest,
bestaande UDP-protocoltest, eerste-voorwiel-/Strava-FIT-test, HUD-test,
ploegenachtervolgingstest en starten van de hoofdscene. Alle controles geslaagd,
zonder scriptfouten.

De nieuwe test:

- schrijft en decodeert zowel indoor-FIT als GPS-FIT;
- controleert hartslagwaarden, ontbrekende/ongeldige gegevens en de FIT-CRC;
- controleert dat vermogen, cadans, snelheid en afstand behouden blijven;
- voert echte Godot-telemetrieverwerking uit met geldige en vervallen hartslag;
- onderschept lokaal het FIT-bestand uit de daadwerkelijke Strava-uploadfunctie
  en leest de hartslag daaruit terug, zonder netwerkverkeer naar Strava;
- leest de geschreven CSV en TCX terug en controleert de hartslag en lege waarden.

Niet uitgevoerd: een echte upload en verwerking door Strava, een hardwaretest met
Garmin/ANT+/KICKR, een visuele spelrun of exportbuilds. De gebruikelijke melding
over de onleesbare Windows-rootcertificaten verschijnt ook hier, los van de geslaagde tests.

## Zelf testen

1. Start de bridge met hartslagband en rijd een nieuwe rit.
2. Exporteer FIT of gebruik de bestaande Strava-uploadknop na afloop.
3. Controleer de hartslaggrafiek. Een CSV-opname bevat nu ook `heart_rate_bpm`.
4. Controleer een rit zonder hartslagband: er hoort geen fictieve 0-bpm-reeks te zijn.

Gerichte automatische test vanuit de projectmap:

```powershell
& 'C:\pad\naar\Godot.exe' --headless --path . --script res://tests/test_heart_rate_export.gd
```
