CONFIGURATIE EN VASTE RENNERPROFIELEN

Persoonlijke bestanden
---------------------
Kopieer riders_config.example.cfg naar riders_config.cfg in deze map.
De sample is gebaseerd op de aangeleverde 13 renners, met behoud van namen,
profieltypes, outfits, helmen, vizieren en rugnummers. Alle drie de factoren
staan voor iedere renner op 1.0. Zonder persoonlijk bestand gebruikt het
spel de sample; aanvullende AI-slots krijgen vaste standaardidentiteiten.

Strava: kopieer strava_config.example.cfg naar strava_config.cfg in deze map.
Vul je eigen gegevens in; persoonlijke configs worden niet gecommit.

Bij een export staan deze bewerkbare bestanden in config/ naast het spel.
Lever de samplebestanden daar ook los mee, of neem config/*.example.cfg op
in het exportfilter. Gegenereerde instellingen en OAuth-tokens blijven in
de schrijfbare Godot-gebruikersmap, nu onder user://config/.

Migratie
--------
De bestaande riders_config.cfg en strava_config.cfg uit de oude hoofdmap
verhuizen bij het laden automatisch naar config/. Gebruikersinstellingen
(display_settings.cfg, rider_profile.cfg, player_appearance.cfg) en
strava_tokens.cfg verhuizen naar user://config/.
Een bestaand doelbestand wordt nooit overschreven. Bij een alleen-lezen
installatie blijft het oude bestand als leesfallback beschikbaar. Bij een
conflict blijven beide bestanden behouden en krijgt het nieuwe pad voorrang.
De .gitignore sluit persoonlijke bestanden uit en laat *.example.cfg toe.

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
