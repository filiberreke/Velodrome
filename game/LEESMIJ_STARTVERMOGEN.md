# Velodrome 250 X - AI-startvermogen

Gebaseerd op de laatste achteruitkijkpatch, inclusief zes rijlijnen, snelheidsafhankelijke drafting en verbeterde AI-reacties.

## Correctie
- Tijdens de eerste 14 seconden kan de AI vanuit stilstand een startinspanning van ongeveer 350-450 W vragen, afhankelijk van CP/profiel en vorm.
- De extra startinspanning neemt af tussen ongeveer 8 en 14 seconden en naarmate de renner 29-40 km/u nadert; op 40 km/u vervalt de startondersteuning.
- De startinspanning wordt pas na de wielvolgvermogensberekening toegepast, zodat het volgen van een wiel de acceleratie vanuit stilstand niet onbedoeld afremt.
- De bestaande veiligheidsrem bij een geblokkeerde rijlijn blijft behouden.
- Het gevraagde vermogen blijft begrensd door de bestaande pcurve, PMAX, CP/W-prime en vermoeidheid via _phys_power. Er worden geen snelheden rechtstreeks gewijzigd.
- Moeilijkheidsgraad blijft op dezelfde plaats toegepast; de genoemde watts zijn doelwaarden voor difficulty=80, voor de latere profiel- en fysieke limitering.

## Installatie
Maak een back-up van je project. Vervang x_scratch_ai.gd door de versie uit deze ZIP. main.gd is ongewijzigd meegeleverd.

## Test
Start een scratch vanaf stilstand, vergelijk het vermogen van AI in de eerste 0-15 seconden en kijk of je met 200 W niet langer meteen een grote voorsprong neemt. Controleer ook dat bij volle rijlijnen renners nog afremmen in plaats van door elkaar heen te rijden.

Statisch gecontroleerd; niet in een draaiende Godot-runtime getest.
