# Mixed-zone: twee interviews

Gebaseerd op de actieve projectmap `C:/Users/romboti/OneDrive - Cronos/Documenten/Priv/godot/velodrome`, inclusief de Sjampanje-uitbaters en Pursoet aan de zuidzijde. De ZIP bevat alleen de gewijzigde en nieuwe bestanden van deze uitbreiding.

## Aanpassing

- De bestaande journaliste met regenboogtrui interviewt nu een renster naar de tweede foto: opgestoken bruin/blond haar, witte lange mouwen, blauwe/cyaan borstband met twaalf gele Europese sterren, donkere koersbroek en een medaille aan een donker lint. De oude generieke renner met gele helm is vervangen.
- Een extra mannelijke journalist naar de eerste foto heeft kort grijs haar, een donkere groen/zwarte trui, donkere broek, horloge en interviewmicrofoon. Hij staat tegenover een mannelijke renner in een Europees kampioenentrui.
- De twee interviewparen staan op lokale Z +0,75 en −0,75 binnen de bestaande tent. Ze kijken elkaar aan. Tent, merkpanelen, vier dakmicrofoons en blauwe route behouden hun bestaande indeling.
- Het zijn low-poly interpretaties in de bestaande publieksstijl, zonder foto's als gezichtstexturen. Het zijn vaste poses; geen gesproken interviews, mondanimaties of wandelgedrag.

## Bestanden en hergebruik

Drie losse modellen onder `assets/people`: `journalist_grijs.glb`, `renner_europees_kampioen.glb`, `renster_europees_kampioen.glb`. Oorsprong tussen de voeten op de grond, Y omhoog, voorwaarts +Z. Geen Blender vereist om ze in Godot te gebruiken.

`north_infield.gd` plaatst de modellen en behoudt de bestaande regenboogjournaliste. De nieuwe journalist draagt zijn microfoon als deel van zijn eigen model. Het vrouwelijke interview gebruikt de bestaande microfoonopstelling.

Blender-bron: `assets/source_blender/crowd/build_mixed_interviews.py`, met de bestaande `people.py` en `vlib.py`. Opnieuw genereren met Blender 5.2.2: `blender --background --python assets/source_blender/crowd/build_mixed_interviews.py`.

## Tests

Geslaagd met Godot 4.7.2: import, hoofdscriptcontrole, hoofdscène twintig frames, nieuwe model-/plaatsingstest, bestaande journaliste-test en bars-test. Gecontroleerd: geldige en begrensde geometrie, menselijke schaal, opaque standaardmaterialen, Europese kleurvlakken/sterren, microfoon, twee gescheiden interviewparen die elkaar aankijken, bestaande tentbranding en route behouden.

Echte Godot GPU-captures gemaakt van de drie losse modellen en de mixed-zone, met OpenGL Compatibility op Intel Iris Xe. De grafische test leverde de beelden op en sloot af met code 0, maar meldde drie fouten bij initialisatie van GLES3-shaders (`shader_gles3.cpp:802`). Dat is geen foutloze grafische testrun; de model- en plaatsingstests zijn afzonderlijk headless geslaagd. Ook kan op deze computer de bestaande melding over de Windows-rootcertificaten verschijnen.

Niet getest: volledige interactieve wedstrijd, Windows-export, animaties of prestaties op andere GPU's. Er zijn geen wijzigingen aan wedstrijdlogica, AI, trainer- of exportcode.

## Zelf bekijken

1. Pak de patch in de bestaande projectmap uit, met behoud van de mappenstructuur, en laat Godot de nieuwe GLB's importeren.
2. Start de game en bekijk de Wielerpraat mixed-zone naast de blauwe loper naar het podium.
3. Bekijk de twee interviewparen vanaf de open zijden; controleer de microfoons, kapsels en kampioenentruien.
4. Optioneel: `Godot.exe --headless --path . --script res://tests/test_mixed_interviews.gd`. Verwacht `MIXED_INTERVIEWS_OK`.
