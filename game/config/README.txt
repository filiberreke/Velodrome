CONFIGURATIE EN VASTE RENNERPROFIELEN

Persoonlijke bestanden
---------------------
Kopieer riders_config.example.cfg naar riders_config.cfg in deze map.
Deze gedeelde catalogus dient voor losse wedstrijden en omnium. Het
voorbeeld bevat de 13 oorspronkelijke renners en de 48 voormalige
omniumrenners. Zonder persoonlijk bestand gebruikt het spel dit
voorbeeld. Losse wedstrijden krijgen nog standaardrenners voor lege
slots. Omnium biedt alleen de renners uit de catalogus aan; meerdere
renners mogen hetzelfde land hebben, met maximaal één per land per
startlijst. Willekeurige startlijsten gebruiken 8 tot 24 deelnemers,
inclusief speler, afhankelijk van de beschikbare landen in de categorie.

Strava: kopieer strava_config.example.cfg naar strava_config.cfg in deze map.
Vul je eigen gegevens in; persoonlijke configs worden niet gecommit.

Bij een export staan deze bewerkbare bestanden in config/ naast het spel.
Lever de samplebestanden daar ook los mee, of neem config/*.example.cfg op
in het exportfilter. Gegenereerde instellingen en OAuth-tokens blijven in
de schrijfbare Godot-gebruikersmap, nu onder user://config/.

Migratie
--------
De gedeelde loader zoekt riders_config.cfg in deze volgorde: config/
naast het spel (game/config/ in een broncheckout), user://config/, en
de oude hoofdmap. Daarna volgt riders_config.example.cfg. Het eerste
gevonden bestand wint, ook als het configuratiefouten bevat. De loader
verplaatst geen rennersbestanden. Voor Strava en gebruikersinstellingen
blijft de bestaande verhuizing naar config/ of user://config/ gelden.

Bestaande catalogi samenvoegen
-----------------------------
Gebruik de persoonlijke bestanden die je vroeger gebruikte. Controleer
ook omnium_mannen_24_riders_config.cfg en omnium_vrouwen_24_riders_config.cfg
in bovenstaande mappen. Gebruik de meegeleverde oude bestanden uit
game/config/ alleen als je geen aangepaste omniumroosters had. Gebruik
voor losse wedstrijden zonder persoonlijk bestand het oude
riders_config.example.cfg uit je vorige versie (met 13 renners).

Voorbeeld vanuit de hoofdmap van de repo (Bash, Godot 4.7):

  (set -o noclobber; godot --headless --no-header --path game \
    --script res://tools/migrate_rider_catalog.gd -- \
    /absoluut/pad/riders_config.cfg \
    /absoluut/pad/omnium_mannen_24_riders_config.cfg \
    /absoluut/pad/omnium_vrouwen_24_riders_config.cfg \
    > riders_config.migrated.cfg)

De converter behoudt secties en CFG-waarden, inclusief [player], IDs,
landen, categorieën, prestaties, records en uiterlijk. Godot herschrijft
de opmaak en laat opmerkingen weg. Ontbrekende IDs gebruiken de sectienaam;
een ontbrekende categorie krijgt men. Een ontbrekend of leeg profiel in
een oud omniumrooster wordt expliciet tt, zoals de oude loader gebruikte.
De converter stopt bij dubbele
secties, sleutels of IDs en meldt conflicterende velden bij dubbele IDs
tussen bestanden. Controleer de gemelde bronnen en corrigeer kopieën.
Als je een sectie hernummert, leg eerst haar effectieve ID expliciet vast.
Controleer ook de afgeleide defaults bij een ander slot (profiel, land,
naam als die ontbreken). Bewaar pas bij afsluitcode 0 een reservekopie van
je actieve persoonlijke CFG en plaats dan bewust het gecontroleerde
resultaat op die locatie. Bash kan bij een fout een leeg uitvoerbestand
achterlaten. Omnium- en racestanden worden nooit door de converter gelezen
of geschreven. Oude omnium-CFG's dienen alleen nog als conversiebron.

Identiteit en fysiologie
-----------------------
id: vaste sleutel voor records; behoud deze bij hernoemen of herschikken.
name: naam op de kaart en in de wedstrijd.
profile: tijdrijder, sprinter of aanvaller; behoudt het bestaande gedrag.
country: optioneel expliciet land-ID; anders afgeleid uit het nationale pak.
portrait_path: optionele lokale afbeelding (res://, user:// of absoluut pad).
portrait_url: optionele HTTPS-afbeelding; bij ontbreken of fout toont het
spel een statisch portret van het daadwerkelijke 3D-model en de outfit.

Basissen voor zowel scratch als puntenkoers:
                  CP (W)      Piek (W)        W-prime (J)
  tijdrijder       265         856.79          24120.4
  sprinter         240        1661.88          30638.0
  aanvaller        250        1149.10          32658.4

cp_factor, max_power_factor, w_prime_factor: vermenigvuldigers van deze
profielwaarden. 1.0 behoudt de exacte basis; bijvoorbeeld 1.02 is +2%.
Een ongeldige factor valt terug op 1.0. Kaartjes tonen afgeronde absolute
waarden, terwijl de berekening de volledige precisie behoudt.
Een factor 1.0 betekent niet dat scratch gelijk is aan de oude 270.86/235 W:
de hierboven afgesproken nieuwe basissen en kleinere dagvorm zijn actief.

Massakoersen behouden de bestaande tactiek, karaktertrekkingen, herstel,
vermoeidheid, drafting, sprintinzet en AI-procentwerking. Dagvorm is per
renner/wedstrijd 0.975..1.025 voor CP, piek en W-prime.
De AI-slider blijft gevraagd vermogen * percentage / 80 toepassen, voor de
bestaande fysiologische begrenzing; 80% blijft het referentieniveau.

Achtervolging gebruikt de geselecteerde identiteit en diens CP, piek en
W-prime, zonder gelote massakoers-dagvorm. Eerst kies je de afstand; daarna
kies je met pijlen een AI-profiel of eigen prestatie. Op deze tweede pagina
stel je ook de sterkte in. Bij AI is 80% het basisniveau: gevraagd vermogen
* percentage / 80, daarna de bestaande fysiologische begrenzing. Bij eigen
prestaties is 100% het originele tempo; het percentage schaalt de tijdlijn
alleen voor deze wedstrijd. Het opgeslagen ritbestand blijft ongewijzigd.
De laatst gekozen tegenstander en sterkte worden per discipline en
ploeggrootte bewaard in user://config/opponent_selection.cfg.
Ploegenachtervolging behoudt zijn bestaande treinmodel en nationale teams.

Lichaam en outfit
-----------------
De bestaande outfitvelden blijven bruikbaar. Zes optionele vormvelden:
  shoulder_width  -> ShoulderWidth
  torso_mass      -> TorsoMass
  hip_width       -> HipWidth
  thigh_mass      -> ThighMass
  calf_mass       -> CalfMass
  arm_mass        -> ArmMass
Waarden liggen tussen -1.0 en 1.0; ontbrekende velden behouden het huidige
profiellichaam. Dit verandert alleen het uiterlijk, niet massa of luchtweerstand.

Records
-------
Optionele opgegeven tijden in seconden:
  record_250m_s, record_1000m_s, record_4000m_s
Optionele opgegeven vermogens in watt:
  best_5s_w, best_15s_w, best_60s_w
Ontbrekende records blijven onbekend; er worden geen fictieve records geloot.

Voltooide individuele spelprestaties en waargenomen piekvermogen worden
automatisch opgeslagen in user://records/ai_riders.json, onder de vaste ID,
discipline, afstand, AI-percentage en fysiologische configuratie. Dagvorm
wordt als metadata bewaard. Gewijzigde factoren of manuele CP overschrijven
dus geen records uit een andere configuratie. Een teamuitslag of replay is
geen individueel AI-record. De 1km-kaartwaarde gebruikt passende prestaties
op het referentieniveau of een opgegeven startrecord. Tijden en watts op
kaartjes worden afgerond; de opgeslagen resultaten blijven precies.

De tegenstanderselectie en de achtervolgingsintro delen dezelfde kwartetkaart,
met landsvlag, portret, specialiteitskleur, iconen en vergelijkbare statbalken.
Pijlen wisselen van tegenstander. Eigen prestaties tonen datum/tijd, gereden
tijd, gemiddeld vermogen en een vermogensgrafiek. Escape/Terug gaat een stap terug.
