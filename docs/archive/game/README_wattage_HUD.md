# Velodrome 250 X — wattage-HUD en ERG-menukeuze

## Installatie

Deze ZIP bevat uitsluitend gewijzigde en nieuwe bestanden. Sluit het spel, maak
een kopie van je project en pak de ZIP uit in de projectmap naast `project.godot`.
Behoud de map `tests` en bevestig het vervangen van de bestaande bestanden.
Open het project opnieuw in Godot 4.7.2; nieuwe scripts worden vanzelf geïmporteerd.

Basis: de huidige speelbare map
`C:\Users\romboti\OneDrive - Cronos\Documenten\Priv\godot\velodrome`.
De volledige bijgewerkte werkkopie staat in `work/power_hud_project` van deze
Codex-workspace. Het oorspronkelijke project is niet rechtstreeks overschreven.

## Gedrag

- Wattage staat bovenaan tussen het persoonlijke blok en de miniatuurpiste.
  Het getal blijft in het midden van de volledige balk, onafhankelijk van vulling.
- De lege balk is transparant, met alleen een dunne rand. Geen extra buitenkader,
  schaalcijfers of streepjes. Ook de miniatuurpiste heeft geen kader of titel.
- 0–600 W neemt 90% van de breedte in; 600–1500 W de resterende 10%.
  Boven 1500 W blijft het werkelijke getal zichtbaar terwijl de vulling vol blijft.
- De volledige vulling krijgt één kleur: tot en met 100 W wit, daarna tot 200 W
  lichtgroen, tot 300 W geel, tot 400 W oranje, tot 600 W rood, daarboven donkerrood.
- In de ploegentijdrit met een actief doel: vulling rood onder doel minus 20 W,
  lichtgroen vanaf die grens, ook bij hoger vermogen. Het rode driehoekje wijst
  van onderaf naar de doelpositie; de doelwaarde staat onder het driehoekje.
  Doelen blijven gebaseerd op de laatste kopbeurt van de speler. Eerste kopbeurt
  en automatisch uitbollen krijgen een korte tekst in plaats van een doelpijl.
- De persoonlijke box bevat snelheid, bestaande hartslagplaceholder, versnelling
  en waar toepasselijk slipstream. De lijst rondom jou blijft eronder.
- Alleen bij ploegenachtervolging staat nu de keuze Manueel / ERG in het menu.
  Manueel is standaard. De keuze wordt overgenomen bij de start van de rit.

## ERG is hier uitsluitend voorbereid

De ERG-menukeuze stuurt nog geen weerstand. Het menu vermeldt dit expliciet.
Deze patch verandert geen Python-code, UDP-verwerking, trainercommando's of fysica.
De beschikbare bridge-v0.14-overdracht wordt in een volgende stap geïntegreerd.

De HUD ondersteunt alvast `erg_active: true` plus een geldige `erg_target_w` in
zijn invoer. Dan staat op de plek van de versnelling bijvoorbeeld `ERG 300 W`.
Alleen een menuvoorkeur activeert deze melding niet: daarvoor moet de toekomstige
bridgekoppeling de werkelijk actieve toestand aanleveren. Zonder deze gegevens
blijft de bestaande versnelling zichtbaar. Hartslag aansluiten valt buiten deze patch.

## Uitgevoerde controles

Godot 4.7.2 headless: projectimport, statische controle van `main.gd`, nieuwe
wattage-/ERG-presentatietest, bestaande HUD-, menu-, ploegachtervolging-,
individuele achtervolging-, records- en UDP-protocoltests, en starten van de
hoofdscene. Alle controles geslaagd, zonder scriptfouten.

De nieuwe test controleert onder andere de schaal, kleurgrenzen, de marge van
20 W, het vaste midden van het getal, geen overlap met zijpanelen, menuhoogte bij
1920×1080, overname van de menukeuze en het onderscheid tussen gekozen en actieve ERG.
De bestaande HUD- en ploegtests zijn aangepast aan de nieuwe presentatie.

In deze omgeving meldt Godot ook dat de Windows-rootcertificaten niet gelezen
kunnen worden. Die omgevingsmelding staat los van de HUD-controles.

Niet uitgevoerd: visuele beoordeling van een GPU-gerenderde spelrun, handmatig
spelen, hardwaretests met KICKR/shifters/hartslag, echte ERG-besturing, exportbuilds
of controle op alle schermverhoudingen. Headless lay-outchecks gebruiken 1920×1080.

## Zelf testen

1. Start Scratch. Verander het demovermogen en bekijk de gecentreerde waarde,
   één kleur per vulling en de lege transparante ruimte. Controleer vooral de
   overgangen bij 100, 200, 300, 400 en 600 W.
2. Controleer bij 600 W dat de balk 90% vol is en bij 1500 W volledig vol.
3. Open ploegenachtervolging en wissel tussen Manueel en ERG. Beide laten de
   bestaande rit starten; ERG biedt in deze patch nog geen automatische weerstand.
4. Rijd een kopbeurt en stuur rechts. Controleer uitbollen en daarna de vaste
   doelpijl. Bij doel 300 W is 279 W rood, 280 W of meer lichtgroen.
5. Controleer de minimap zonder achtergrond of titel, de lijst links en X om de
   developer-HUD te openen en weer te sluiten.

Gerichte automatische tests vanuit de projectmap:

```powershell
& 'C:\pad\naar\Godot.exe' --headless --path . --script res://tests/test_power_meter.gd
& 'C:\pad\naar\Godot.exe' --headless --path . --script res://tests/test_hud.gd
& 'C:\pad\naar\Godot.exe' --headless --path . --script res://tests/test_team_pursuit.gd
```
