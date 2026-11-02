# Starttoestel individuele achtervolging

Individuele achtervolging gebruikt aan beide tegenoverliggende startlijnen een rood
starttoestel met twee helpers. De achterasklem blijft dicht tijdens de intro,
stilstandscontrole en aftelling. De bestaande GO-overgang opent de klem en laat de
helpers het toestel 1,10 m achteruit trekken. Na 2,2 seconden wordt de opstelling
opgeruimd, ruim voordat een renner opnieuw passeert.

De helpers hebben afgewerkte poloshirts, handen met grijpende vingers, zachte
knie- en elleboogvormen, gezichtsdetails en sportschoenen. Hun shirts gebruiken de
actieve outfit van de bijbehorende renner: dezelfde kleuren of dezelfde nationale/
ploegatlas, inclusief externe PNG's. Torso en mouwen gebruiken de UV-indeling van
het bestaande rennermodel. De shirts van beide startlijnen zijn onafhankelijk;
een gewijzigde spelersoutfit wordt ook op de twee eigen helpers toegepast.

`pursuit_start.gd` bepaalt de stand uit de lokale rijrichting en dwarshelling van
`_at()`. De normaal wordt naar boven gericht. De vastgehouden fiets volgt hetzelfde
baanvlak, met de klem op de echte achteras van het achtervolgingsmodel:
lokale positie `(0, 0.335, -0.40)`. Tijdens de eerste drie meter wordt vloeiend
overgegaan naar de bestaande rijdende fietsweergave.

De animatie wordt handmatig met de simulatiestap bijgewerkt, zodat pauzeren ook de
helpers stilzet. Reset en herstart verwijderen de oude opstelling en maken twee
nieuwe gesloten toestellen. De tijdmeting, trainercontrole, racefysica en andere
spelvormen behouden hun bestaande startgedrag. Ploegenachtervolging gebruikt dit
toestel in deze wijziging nog niet.

Asset: `assets/start_gate/pursuit_start_gate_with_helpers.glb`.
Bewerkbare Blender-bron en generator: `assets/source_blender/start_gate/`.
De generator produceert zijn GLB naast zichzelf; kopieer die na een wijziging naar
de assetmap. `GATE_SKIP_RENDERS=1` slaat de voorbeeldrenders over.

Controle:

- `tests/test_pursuit_start.gd`: startflow, achterasuitlijning, omhoog gerichte
  baannormaal, twee helpers per toestel, klem vóór terugtrekken, pauze, herstart,
  standaardkleuren, verschillende landenshirts en een externe ploeg-PNG.
- Bestaande tests: `test_pursuit.gd`, `test_team_pursuit.gd`,
  `test_flying_time_trial.gd`.
- `tests/capture_pursuit_start.gd`: beelden vóór en na terugtrekken in
  `verification/pursuit_start/`.
