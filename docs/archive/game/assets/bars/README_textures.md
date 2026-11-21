# Vlakke merktexturen

De originele Sjampanje- en Pursoet-identiteiten zijn als afzonderlijke PNG's opgenomen. De `.tres`-resources beschrijven uitsneden voor woordmerk, monogram en beeldmerk. De builder vertaalt hun regio expliciet naar de UV-schaal en UV-offset van StandardMaterial3D, omdat AtlasTexture-regio's in een 3D-materiaal niet vanzelf een uitsnede toepassen. De originele letters worden daardoor niet opnieuw getekend.

Het ivoorkleurige Sjampanje-balie-etiket is met de ingebouwde image_gen-tool samengesteld op basis van `output/boarding/sjampanje-banner-v2-luxe.png`. Het is vlak drukwerk, geen afbeelding van de perspectivische bar-mockup. De oorspronkelijke foto/mockups worden niet op de 3D-geometrie geprojecteerd. De CPU/RGB-kleurvlakken gebruiken kleine gedeelde opaque texturen, zodat ze dezelfde kleurconversie krijgen als het drukwerk.

Ingebouwde toolmodus gebruikt; geen API/CLI-fallback.

Prompt voor `sjampanje_counter_label.png`:

Create ONE FLAT PRINT-READY opaque rectangular label texture, wide 3:1 aspect ratio, front orthographic artwork with absolutely NO perspective, NO 3D bar or mockup, NO shadows, NO bevel or lighting, NO border crop. Reference image role: exact existing fictional SJAMPANJE brand identity and mascot. Warm flat ivory background #FFF3D1. On LEFT roughly 63% compose upright classical high-contrast ROMAN SERIF uppercase wordmark 'SJAMPANJE', dark bottle green #064A32 with tasteful restrained antique gold #C7A24B accents. Small oval S monogram with laurel centered ABOVE the left wordmark. Preserve the luxurious upright serif lettering; NO script, NO italic, NO swoosh. All letters fully inside generous margins. On RIGHT 35% show the same recognisable scruffy cartoon man, black hat with blue band, striped yellow/blue shirt and green jacket, holding a champagne flute, with exact speech bubble 'Te enige egte!'. Flat clear graphic artwork for a low-poly Godot kiosk counter. Wordmark left must be fully visible independent of mascot, so left 63% can also serve as a standalone rear label. Preserve brand spelling exactly. Do not add extra text.
