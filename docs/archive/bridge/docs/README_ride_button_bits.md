# Zwift Ride: fysieke knopnamen corrigeren

Bij hardwaretests kwamen meerdere knoppen onder een verkeerde naam binnen.
De oorspronkelijke decoder kopieerde de bitmaskers uit het
[Makinolo-artikel](https://www.makinolo.com/blog/2024/07/26/zwift-ride-protocol/).
De [actuele BikeControl-implementatie, vastgepind op commit 1458e97](https://github.com/OpenBikeControl/bikecontrol/blob/1458e974574fe2dc99546c3bda3cf2f99736e0b0/lib/bluetooth/devices/zwift/zwift_ride.dart#L326)
gebruikt vanaf Z andere bitmaskers. Dat verschil verklaart concreet waarom
een fysieke linker SHIFT-knop bijvoorbeeld als Z kon worden benoemd.

## Gebruikte tabel

Een `0x23`-bericht bevat een protobuf-uint32 in veld 1. Een nulbit betekent
ingedrukt. De analoge stuurpaddles worden afzonderlijk verwerkt.

| Fysieke knop | Naam in bridge / diagnostiek | Masker |
| --- | --- | --- |
| Links | LEFT | 0x0001 |
| Omhoog | UP | 0x0002 |
| Rechts | RIGHT | 0x0004 |
| Omlaag | DOWN | 0x0008 |
| A | A | 0x0010 |
| B | B | 0x0020 |
| Y | Y | 0x0040 |
| Z | Z | 0x0080 |
| Linker SHIFT + | SHIFT_UP_LEFT | 0x0100 |
| Linker SHIFT − | SHIFT_DOWN_LEFT | 0x0200 |
| Linker dropknop | POWER_LEFT / DROP_LEFT | 0x0400 |
| Links aan/uit | ONOFF_LEFT | 0x0800 |
| Rechter SHIFT + | SHIFT_UP_RIGHT | 0x1000 |
| Rechter SHIFT − | SHIFT_DOWN_RIGHT | 0x2000 |
| Rechter dropknop | POWER_RIGHT / DROP_RIGHT | 0x4000 |
| Rechts aan/uit | ONOFF_RIGHT | 0x8000 |

Links/rechts/pijltjes/A/B/Y waren al correct. De negen overige namen waren
verschoven of werden niet herkend. De ongebruikte bits 0x10000 en 0x20000
verzinnen nu geen drop- of aan/uitknoppen meer.

Beide linker SHIFT-knoppen blijven lichter schakelen; beide rechter zwaarder.
SHIFT stuurt niet en bedient geen menu's. DROP blijft gereserveerd voor arcade.
De naam POWER in het UDP-protocol blijft behouden voor bestaande ontvangers;
de Controller-test toont daarvoor DROP.

De beschikbare bronnen bewijzen geen betrouwbaar automatisch onderscheid
tussen twee fysieke firmware-indelingen. Daarom probeert de decoder niet twee
tegenstrijdige knoptabellen tegelijk: hetzelfde bit zou anders zowel pauze
als schakelen kunnen betekenen. Zowel het oudere als het actuele analoge
protobufformaat blijven ondersteund; dat staat los van de digitale knoptabel.

## Bijwerken en controleren

1. Werk de volledige bridge bij en herstart deze. Alleen de game vernieuwen
   verandert de Bluetooth-decoder niet.
2. Open Instellingen → Controller. Druk elke knop afzonderlijk in en laat los.
   Controleer dat de regel overeenkomt met de fysieke knop.
3. Z verlaat de Controller-test. Test vervolgens Z voor pauze/hervatten,
   B vasthouden voor achteromkijken en beide SHIFT-knoppen aan iedere kant.
4. Verwijder eventuele eigen naamwisselingen die alleen als tijdelijke
   compensatie voor de oude decoder waren toegevoegd; gebruik daarvoor
   desgewenst de standaard `button_mapping.json`.

De simulator verstuurt symbolische knopnamen en doorliep de Bluetooth-decoder
oorspronkelijk niet. Daardoor kon deze fout ondanks geslaagde simulatietests
blijven bestaan. Nieuwe tests gebruiken vaste, onafhankelijk vastgelegde
berichtbytes voor alle zestien knoppen, controleren de echte notificatiecallback
en testen ook de route berichtbytes → decoder → UDP → Godot met A/B/Z.
De bytes zijn protocolfixtures op basis van de broncode, geen nieuwe opname
van de fysieke Ride. Een hertest met de hardware blijft nodig.
