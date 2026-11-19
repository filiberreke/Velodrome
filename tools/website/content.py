# -*- coding: utf-8 -*-
from html import escape

# Teksten voor velodrome.wielerpraat.be. Bron van waarheid voor speelbaarheid: game/race_menu.gd (MODES + PLAYABLE).
REPO = "https://github.com/filiberreke/Velodrome"
PAGES = ["home", "races", "training", "manual", "downloads", "dev"]
SLUG = {
    "nl": {"home": "", "races": "wedstrijden", "training": "training", "manual": "handleiding", "downloads": "downloads", "dev": "ontwikkeling"},
    "en": {"home": "", "races": "races", "training": "training", "manual": "manual", "downloads": "downloads", "dev": "development"},
}

UI = {
    "nl": {
        "nav": {"home": "Home", "races": "Wedstrijden", "training": "Training", "manual": "Handleiding", "downloads": "Downloads", "dev": "Ontwikkeling"},
        "switch": "English", "switch_label": "Read this page in English",
        "skip": "Naar de inhoud", "menu": "Menu",
        "playable": "Speelbaar", "soon": "Binnenkort",
        "footer": "Vélodrome is een open-sourcespel onder GPLv3, gemaakt met Godot.",
        "source": "Broncode op GitHub",
        "site": "Vélodrome",
    },
    "en": {
        "nav": {"home": "Home", "races": "Races", "training": "Training", "manual": "Manual", "downloads": "Downloads", "dev": "Development"},
        "switch": "Nederlands", "switch_label": "Lees deze pagina in het Nederlands",
        "skip": "Skip to content", "menu": "Menu",
        "playable": "Playable", "soon": "Coming soon",
        "footer": "Vélodrome is open-source software under GPLv3, built with Godot.",
        "source": "Source code on GitHub",
        "site": "Vélodrome",
    },
}

# ---------------------------------------------------------------- races
RACES = {
 "nl": [
  ("scratch", "Scratch", True, "Eén peloton. Eén finish.", "Blijf uit de wind, kies je moment en sprint als eerste over de meet. Wie een ronde wint, staat voor in het klassement.", "Eerst één geneutraliseerde ronde"),
  ("points", "Puntenkoers", True, "Elke sprint een nieuwe kans.", "Elke 10 ronden een sprint met 5, 3, 2 en 1 punt; aan de finish tellen de punten dubbel. Een ronde winnen geeft +20, een ronde verliezen −20.", "Eerst één geneutraliseerde ronde"),
  ("elimination", "Afvalling", True, "Elke twee ronden valt de laatste af.", "Wie met het achterwiel als laatste over de meet komt, ligt eruit. Blijf uit de gevarenzone zonder te veel wind te pakken.", "4, 12 of 16 deelnemers"),
  ("keirin", "Keirin", True, "Volg het tempo. Ontketen je sprint.", "Zes renners met gelote startposities. Drie ronden achter de derny, die geleidelijk versnelt; daarna drie vrije ronden. Blijf in het wiel en kies je sprintmoment.", "6 renners, 6 ronden"),
  ("pursuit", "Achtervolging", True, "Jij, je tegenstander en de klok.", "Twee renners starten aan weerszijden van de piste. Jaag op de beste tijd of haal je tegenstander in. Je rijdt tegen een virtuele tegenstander of tegen een eigen opgeslagen rit. Geen slipstream.", "1 of 4 km"),
  ("team_pursuit", "Ploegenachtervolging", True, "Samen op jacht naar de snelste tijd.", "Rijd met twee of drie virtuele ploegmaats. Stuur op kop naar rechts voor een kopwissel en volg daarna het wattagedoel. Weerstand handmatig of met ERG.", "1 of 4 km"),
  ("time_trial", "Tijdrit", True, "Jij tegen de klok.", "500 m of 1 km met staande of vliegende start, met een vergelijking om de 125 meter tegen je vorige rit of je persoonlijk record.", "500 m of 1 km"),
  ("madison", "Ploegkoers", False, "Wissel af. Blijf in de wedstrijd.", "Rijd als duo, los elkaar af en strijd samen om punten en ronden. De handaflossing oefen je nu al in de pistetraining.", "Aflossen kan al in de training"),
  ("tempo", "Temporace", False, "Houd het tempo hoog.", "Deze discipline komt in een volgende versie.", ""),
  ("tournament", "Toernooien", False, "Meerdere wedstrijden, één klassement.", "Rijd een reeks wedstrijden na elkaar en tel je resultaten op.", ""),
 ],
 "en": [
  ("scratch", "Scratch", True, "One bunch. One finish.", "Stay out of the wind, pick your moment and be first across the line. Taking a lap moves you ahead in the standings.", "Starts with one neutralised lap"),
  ("points", "Points race", True, "Every sprint is a new chance.", "A sprint every 10 laps scores 5, 3, 2 and 1 points; the finish counts double. Gaining a lap earns +20, losing one costs −20.", "Starts with one neutralised lap"),
  ("elimination", "Elimination", True, "Every two laps, the last rider is out.", "Whoever crosses the line last, judged by the rear wheel, is eliminated. Stay out of the danger zone without spending too long in the wind.", "4, 12 or 16 riders"),
  ("keirin", "Keirin", True, "Follow the pace. Unleash your sprint.", "Six riders with drawn start positions. Three laps behind the derny as it gradually speeds up, then three free laps. Stay on the wheel and choose when to go.", "6 riders, 6 laps"),
  ("pursuit", "Individual pursuit", True, "You, your opponent and the clock.", "Two riders start on opposite sides of the track. Chase the best time or catch your opponent. Race a virtual opponent or one of your own saved rides. No drafting.", "1 or 4 km"),
  ("team_pursuit", "Team pursuit", True, "Chasing the fastest time together.", "Ride with two or three virtual teammates. Steer right at the front to swap turns, then follow the power target. Manual resistance or ERG.", "1 or 4 km"),
  ("time_trial", "Time trial", True, "You against the clock.", "500 m or 1 km from a standing or flying start, compared every 125 metres with your last ride or your personal best.", "500 m or 1 km"),
  ("madison", "Madison", False, "Take turns. Stay in the race.", "Ride as a pair, hand each other in and fight together for points and laps. You can already practise the hand sling in track training.", "Hand slings available in training"),
  ("tempo", "Tempo race", False, "Keep the pace high.", "This discipline arrives in a later version.", ""),
  ("tournament", "Tournaments", False, "Several races, one classification.", "Ride a series of races back to back and add up your results.", ""),
 ],
}

PISTE = {
 "nl": [("free_training", "Vrije training", "Vrij rondrijden met rondetijden en vier gekleurde pacers."),
        ("derny_training", "Dernytraining", "Volg de gangmaker en verhoog samen het tempo."),
        ("flying_training", "Vliegende start", "Gebruik de hoogte van de piste en verbeter je snelheid op de lijn."),
        ("take_lap", "Neem een ronde", "Win een ronde op een peloton dat een vast tempo rijdt."),
        ("hand_sling", "Aflossingstraining", "Oefen 10 of 20 handaflossingen met je ploegmaat.")],
 "en": [("free_training", "Free ride", "Ride laps at your own pace with lap times and four coloured pacers."),
        ("derny_training", "Derny training", "Follow the motor pacer and build up speed together."),
        ("flying_training", "Flying start", "Use the height of the banking to carry more speed onto the line."),
        ("take_lap", "Take a lap", "Gain a lap on a bunch riding at a fixed pace."),
        ("hand_sling", "Hand-sling training", "Practise 10 or 20 Madison exchanges with your teammate.")],
}


# De bestandsnamen volgen de Godot-export. Drie menuopties delen een preview.
MODE_PREVIEW_ALIASES = {
    "tournament": "scratch",
    "take_lap": "scratch",
    "hand_sling": "madison",
}

PREVIEW_ALT = {
    "scratch": ('Peloton op de hellende piste', 'Peloton on the banked track'),
    "points": ('Vijf renners sprinten naar de meet', 'Five riders sprinting for the line'),
    "elimination": ('De laatste renner net voorbij de finishlijn', 'The last rider clearing the finish line'),
    "keirin": ('Renners op een rij achter de gangmaker', 'Riders lined up behind the pacer'),
    "pursuit": ('Twee renners op tegenoverliggende rechte stukken', 'Two riders on opposite straights'),
    "team_pursuit": ('Twee ploegen op tegenoverliggende rechte stukken', 'Two teams on opposite straights'),
    "time_trial": ('Eén renner op de piste', 'One rider on the track'),
    "madison": ("Twee duo's in ploegkleuren", 'Two pairs of riders in team colours'),
    "tempo": ('Eén renner voor het peloton', 'One rider ahead of the bunch'),
    "free_training": ('Vier gangmakers in verschillende kleuren', 'Four pacers in different colours'),
    "derny_training": ('Een renner volgt de gemotoriseerde gangmaker', 'One rider following the motor pacer'),
    "flying_training": ('Een renner nadert de tijdmeetlijn', 'A rider approaching the timing line'),
}


def mode_art(lang, mode, PREVIEW):
    asset = MODE_PREVIEW_ALIASES.get(mode, mode)
    alt_nl, alt_en = PREVIEW_ALT[asset]
    image = PREVIEW(asset, alt_nl if lang == "nl" else alt_en)
    return f'<span class="mode-card-art">{image}</span>'


def race_card(lang, item, PREVIEW, href=None):
    mode, name, playable, hint, detail, meta = item
    slug = _id(name)
    card_class = "mode-card" if playable else "mode-card is-upcoming"
    status = "" if playable else f'<span class="mode-card-status">{UI[lang]["soon"]}</span>'
    inner = (f'{mode_art(lang, mode, PREVIEW)}'
             f'<span class="mode-card-title">{escape(name)}</span>{status}')
    if href is not None:
        return f'<a class="{card_class}" href="{href}#{slug}">{inner}</a>'
    meta_html = f'<p class="meta">{escape(meta)}</p>' if meta else ""
    return (f'<article class="race-entry" id="{slug}">'
            f'<div class="{card_class}">{inner}</div>'
            f'<div class="race-entry-copy"><h2>{escape(name)}</h2><p class="hint">{escape(hint)}</p>'
            f'<p>{escape(detail)}</p>{meta_html}</div></article>')


def page(lang, key, L, IMG, CHIP, PREVIEW):
    """Return (title, description, body_html). L(page) -> href, IMG(key, alt, cls) -> <img>."""
    nl = lang == "nl"
    if key == "home":
        race_list = "".join(race_card(lang, race, PREVIEW, L("races")) for race in RACES[lang] if race[2])
        title = "Vélodrome – baanwielrennen op 250 meter" if nl else "Vélodrome – track cycling on a 250-metre velodrome"
        desc = ("Baanwielerspel voor de pc: scratch, puntenkoers, afvalling, keirin en achtervolging tegen een virtueel peloton, met je trainer of het toetsenbord."
                if nl else "Track cycling game for PC: scratch, points race, elimination, keirin and pursuit against a virtual peloton, on your smart trainer or keyboard.")
        body = f'''
<section class="hero">
  {IMG("hero", "Renners met rugnummers op de houten piste van Vélodrome" if nl else "Numbered riders on the wooden track in Vélodrome", "hero-img", eager=True)}
  <div class="hero-copy wrap">
    <h1>{"Baanwielrennen op een piste van 250 meter." if nl else "Track racing on a 250-metre velodrome."}</h1>
    <p class="lede">{"Rijd tegen een virtueel peloton in scratch, puntenkoers, afvalling, keirin en achtervolging. Met je eigen trainer en echte watts, of gewoon met het toetsenbord." if nl else "Race a virtual peloton in scratch, points, elimination, keirin and pursuit. On your own smart trainer with real watts, or simply with a keyboard."}</p>
    <div class="actions">
      <a class="btn primary" href="{L("downloads")}">{"Naar de downloads" if nl else "Go to downloads"}</a>
      <a class="btn" href="{L("races")}">{"Bekijk de wedstrijden" if nl else "See the races"}</a>
    </div>
  </div>
</section>
<div class="boards" aria-hidden="true"></div>
<main id="main" class="wrap">
  <p class="status">{"Bèta in actieve ontwikkeling voor Windows. De ondersteuning voor trainers en controllers wordt nog op echte hardware getest." if nl else "Beta in active development for Windows. Trainer and controller support is still being tested on real hardware."}</p>

  <section class="features">
    <div class="feature"><h2>{"Rijden in het wiel" if nl else "Riding the wheel"}</h2>
      <p>{"Slipstream telt. Uit de wind blijven spaart energie voor later; een sprint die te vroeg komt, betaal je in de laatste bocht." if nl else "Drafting matters. Sheltering saves energy for later, and a sprint launched too early costs you in the final bend."}</p></div>
    <div class="feature"><h2>{"Tegenstanders met een eigen profiel" if nl else "Opponents with their own profile"}</h2>
      <p>{"Sprinters, tijdrijders en aanvallers koersen elk op hun manier: wegspringen, het tempo hoog houden of wachten op de bel. Elke renner heeft een paspoort met zijn sterktes." if nl else "Sprinters, time triallists and attackers each race their own way: jumping away, driving the pace or waiting for the bell. Every rider has a passport showing their strengths."}</p></div>
    <div class="feature"><h2>{"Echte watts" if nl else "Real watts"}</h2>
      <p>{"Koppel een Wahoo KICKR of KICKR CORE, stuur en schakel met Zwift Ride en zie je Garmin-hartslag in beeld. De piste stuurt helling en slipstream naar je trainer." if nl else "Connect a Wahoo KICKR or KICKR CORE, steer and shift with Zwift Ride and see your Garmin heart rate on screen. The track sends gradient and draft to your trainer."}</p></div>
    <div class="feature"><h2>{"Ook zonder trainer" if nl else "No trainer needed"}</h2>
      <p>{"Stuur met A en D en regel je vermogen met de pijltjestoetsen, in stappen van 25 W." if nl else "Steer with A and D and set your power with the arrow keys, in 25 W steps."}</p></div>
  </section>

  <section>
    <div class="split">
      <div>
        <h2>{"Zeven wedstrijdvormen om te rijden" if nl else "Seven race formats to ride"}</h2>
        <p>{"Scratch, puntenkoers en afvalling beginnen met één geneutraliseerde ronde. Daarna is het koers. De keirin start achter de derny." if nl else "Scratch, points and elimination open with one neutralised lap. Then it’s racing. The keirin starts behind the derny."}</p>
      </div>
      <figure>{IMG("screen", "Groot scherm boven de piste tijdens een puntenkoers" if nl else "Big screen above the track during a points race")}
        <figcaption>{"Het grote scherm hangt boven het middenplein." if nl else "The big screen hangs above the infield."}</figcaption></figure>
    </div>
    <div class="mode-grid home-mode-grid">{race_list}</div>
    <p><a class="more" href="{L("races")}">{"Alle wedstrijdvormen" if nl else "All race formats"}</a></p>
  </section>

  <section class="gallery">
    <h2>{"Een volle piste" if nl else "A full velodrome"}</h2>
    <div class="shots">
      <figure>{IMG("arena", "Overzicht van het overdekte velodroom met tribunes en middenplein" if nl else "Overview of the indoor velodrome with stands and infield")}
        <figcaption>{"Tribunes, middenplein en lichtring onder het dak." if nl else "Stands, infield and the light ring under the roof."}</figcaption></figure>
      <figure>{IMG("commentary", "Twee commentatoren in de commentaarcabine" if nl else "Two commentators in the commentary box")}
        <figcaption>{"De commentaarcabine opent elke wedstrijd." if nl else "The commentary box opens every race."}</figcaption></figure>
      <figure>{IMG("track", "Zicht vanaf de piste op de tribunes en het grote scherm" if nl else "View from the track towards the stands and big screen")}
        <figcaption>{"Vanaf de baan: het scherm, de boarding en het publiek." if nl else "From the track: the screen, the boards and the crowd."}</figcaption></figure>
    </div>
  </section>

  <section class="split reverse">
    <figure>{IMG("piste", "Menu Pistetraining in Vélodrome" if nl else "Track training menu in Vélodrome")}</figure>
    <div>
      <h2>{"Trainen op de piste en op vermogen" if nl else "Train on the track and on power"}</h2>
      <p>{"Bepaal je FTP met de ramp test, bouw workouts in de editor of importeer .zwo-bestanden. Op de piste oefen je achter de derny, de vliegende start of de handaflossing." if nl else "Find your FTP with the ramp test, build workouts in the editor or import .zwo files. On the track you practise behind the derny, the flying start or the hand sling."}</p>
      <p><a class="more" href="{L("training")}">{"Naar training" if nl else "Go to training"}</a></p>
    </div>
  </section>

  <section class="cta">
    <h2>{"Klaar om te rijden?" if nl else "Ready to ride?"}</h2>
    <p>{"Vélodrome is gratis en open source. Download de Windows-versie of bouw het spel zelf vanuit de broncode." if nl else "Vélodrome is free and open source. Download the Windows build or build the game yourself from source."}</p>
    <div class="actions"><a class="btn primary" href="{L("downloads")}">{"Naar de downloads" if nl else "Go to downloads"}</a>
      <a class="btn" href="{L("manual")}">{"Lees de handleiding" if nl else "Read the manual"}</a></div>
  </section>
</main>'''
        return title, desc, body

    if key == "races":
        tiles = [race_card(lang, race, PREVIEW) for race in RACES[lang]]
        title = "Wedstrijden – Vélodrome" if nl else "Races – Vélodrome"
        desc = ("Welke baanwedstrijden je in Vélodrome kunt rijden: scratch, puntenkoers, afvalling, keirin, achtervolging, ploegenachtervolging en tijdrit." if nl
                else "The track races you can ride in Vélodrome: scratch, points race, elimination, keirin, individual and team pursuit and time trial.")
        body = f'''<main id="main" class="wrap page">
  <header class="page-head"><h1>{"Wedstrijden" if nl else "Races"}</h1>
  <p class="lede">{"Zeven disciplines zijn speelbaar. Je rijdt tegen een virtueel peloton van renners met elk een eigen profiel en eigen wedstrijdgedrag." if nl else "Seven disciplines are playable. You race a virtual peloton of riders who each have their own profile and race behaviour."}</p></header>
  <figure class="wide">{IMG("hero", "Renners op de piste tijdens de intro" if nl else "Riders on the track during the intro")}</figure>
  <div class="race-entries">{''.join(tiles)}</div>
  <section class="prose">
    <h2>{"Records" if nl else "Records"}</h2>
    <p>{"Vélodrome bewaart je beste tijden lokaal: een top 10 voor achtervolging en ploegenachtervolging, en voor de tijdrit je laatste rit, je recente record en je record aller tijden, apart per afstand en startwijze. Een opgeslagen achtervolgingsrit kun je later opnieuw als tegenstander kiezen." if nl else "Vélodrome keeps your best times locally: a top 10 for individual and team pursuit, and for the time trial your last ride, recent best and all-time best, kept separately per distance and start type. A saved pursuit ride can later be chosen as your opponent."}</p>
  </section>
</main>'''
        return title, desc, body

    if key == "training":
        training_cards = []
        for mode, name, detail in PISTE[lang]:
            training_cards.append(f'''      <article class="mode-card">
        {mode_art(lang, mode, PREVIEW)}
        <h3 class="mode-card-title">{escape(name)}</h3>
        <p>{escape(detail)}</p>
      </article>''')
        piste = "\n".join(training_cards)
        title = "Training – Vélodrome" if nl else "Training – Vélodrome"
        desc = ("ERG-workouts, FTP-test en pistetraining in Vélodrome: derny, vliegende start, ronde nemen en handaflossing." if nl
                else "ERG workouts, FTP test and track training in Vélodrome: derny, flying start, taking a lap and the Madison hand sling.")
        body = f'''<main id="main" class="wrap page">
  <header class="page-head"><h1>{"Training" if nl else "Training"}</h1>
  <p class="lede">{"Twee soorten training: workouts op vermogen met je trainer in ERG, en oefeningen op de piste." if nl else "Two kinds of training: power-based workouts with your trainer in ERG mode, and drills on the track."}</p></header>

  <section class="split">
    <div class="prose">
      <h2>{"ERG-training" if nl else "ERG training"}</h2>
      <p>{"Bij ERG-training legt de trainer het vermogen op; jij trapt. Een echte trainer met verse vermogensmetingen is hiervoor nodig." if nl else "In ERG training the trainer sets the power and you pedal. This needs a real trainer sending fresh power readings."}</p>
      <h3>{"FTP-ramp test" if nl else "FTP ramp test"} {CHIP(True)}</h3>
      <p>{"Vijf minuten vrij opwarmen, daarna start de ramp op 100 W en stijgt elke minuut met 20 W. Je stopt als het niet meer gaat. Je FTP is 75% van je beste 60 seconden en wordt in je spelersprofiel bewaard." if nl else "Five minutes of free warm-up, then the ramp starts at 100 W and rises by 20 W every minute. You stop when you can’t go on. Your FTP is 75% of your best 60 seconds and is saved to your player profile."}</p>
      <h3>{"20-minuten FTP-test" if nl else "20-minute FTP test"} {CHIP(False)}</h3>
      <p>{"De klassieke test over 20 minuten komt in een volgende versie." if nl else "The classic 20-minute test arrives in a later version."}</p>
      <h3>{"Eigen workouts" if nl else "Your own workouts"} {CHIP(True)}</h3>
      <p>{"Bouw workouts in de editor of importeer een .zwo-bestand. Filter je bibliotheek op duur en op intensiteit, als percentage van je FTP." if nl else "Build workouts in the editor or import a .zwo file. Filter your library by duration and by intensity as a percentage of your FTP."}</p>
    </div>
    <figure>{IMG("exchange", "Aflossingstraining met wattagebalk en voortgang" if nl else "Hand-sling training with power bar and progress")}
      <figcaption>{"Aflossingstraining: de HUD toont je vermogen en de voortgang." if nl else "Hand-sling training: the HUD shows your power and progress."}</figcaption></figure>
  </section>

  <section aria-labelledby="track-training">
    <div class="split reverse">
      <figure>{IMG("piste", "Menu Pistetraining" if nl else "Track training menu")}</figure>
      <div class="prose">
        <h2 id="track-training">{"Pistetraining" if nl else "Track training"}</h2>
        <p>{"Al je trainingen worden bewaard en zijn later terug te zien onder Opgeslagen trainingen." if nl else "All sessions are saved and can be reviewed later under Saved sessions."}</p>
      </div>
    </div>
    <div class="mode-grid training-mode-grid">
{piste}
    </div>
  </section>

  <section class="prose">
    <h2>{"Je ritten exporteren" if nl else "Exporting your rides"}</h2>
    <p>{"Ritten kun je bewaren als CSV, TCX of FIT. Uploaden naar Strava is mogelijk, maar vraagt een eigen Strava-configuratie; zie de" if nl else "Rides can be saved as CSV, TCX or FIT. Uploading to Strava is possible but needs your own Strava configuration; see the"} <a href="{L("manual")}#{"instellingen" if nl else "data"}">{"handleiding" if nl else "manual"}</a>.</p>
  </section>
</main>'''
        return title, desc, body

    if key == "manual":
        keys = [("A / D", "Sturen" if nl else "Steer"),
                ("↑ / ↓", "Zonder trainer: vermogen +/− 25 W. Met trainer: virtueel schakelen" if nl else "Without a trainer: power +/− 25 W. With a trainer: virtual shifting"),
                ("+ / −", "Vermogen omhoog of omlaag" if nl else "Power up or down"),
                ("C / Q", "Volgende of vorige camera" if nl else "Next or previous camera"),
                ("B", "Achteruitkijken" if nl else "Look back"),
                ("V", "Rennersinfo" if nl else "Rider info"),
                ("R", "Opnieuw starten" if nl else "Restart"),
                ("Esc", "Pauzemenu" if nl else "Pause menu"),
                ("F10", "Instellingen" if nl else "Settings")]
        keyrows = "".join(f"<tr><td><kbd>{k}</kbd></td><td>{v}</td></tr>" for k, v in keys)
        hw = ([("Wahoo KICKR / KICKR CORE", "Bluetooth FTMS: vermogen, snelheid en cadans; SIM, ERG en hellingsimulatie. Andere FTMS-trainers zijn niet bevestigd."),
               ("Zwift Ride", "Bluetooth via de linker controller: 12 virtuele versnellingen, knoppen en analoge stuurpaddles. Knoppen in te stellen via Instellingen → Controller."),
               ("Garmin-hartslag (ANT+)", "Via een ANT+-USB-stick. Zet Broadcast Heart Rate aan op je horloge, bijvoorbeeld een vívoactive 5.")] if nl else
              [("Wahoo KICKR / KICKR CORE", "Bluetooth FTMS: power, speed and cadence; SIM, ERG and gradient simulation. Other FTMS trainers are not confirmed."),
               ("Zwift Ride", "Bluetooth via the left controller: 12 virtual gears, buttons and analogue steering paddles. Buttons can be remapped under Settings → Controller."),
               ("Garmin heart rate (ANT+)", "Through an ANT+ USB stick. Turn on Broadcast Heart Rate on your watch, for example a vívoactive 5.")])
        hwrows = "".join(f"<tr><th scope=\"row\">{a}</th><td>{b}</td></tr>" for a, b in hw)
        title = "Handleiding – Vélodrome" if nl else "Manual – Vélodrome"
        desc = ("Vélodrome installeren, bediening met toetsenbord, trainer en Zwift Ride koppelen via de bridge, en compatibiliteit." if nl
                else "Installing Vélodrome, keyboard controls, connecting a trainer and Zwift Ride through the bridge, and compatibility.")
        body = f'''<main id="main" class="wrap page">
  <header class="page-head"><h1>{"Handleiding" if nl else "Manual"}</h1>
  <p class="lede">{"Installeren, bedienen en je trainer koppelen." if nl else "Installing, controls and connecting your trainer."}</p>
  <nav class="toc" aria-label="{"Op deze pagina" if nl else "On this page"}"><a href="#{"installatie" if nl else "install"}">{"Installatie" if nl else "Installation"}</a><a href="#{"bediening" if nl else "controls"}">{"Bediening" if nl else "Controls"}</a><a href="#bridge">{"Trainer en bridge" if nl else "Trainer and bridge"}</a><a href="#{"compatibiliteit" if nl else "compatibility"}">{"Compatibiliteit" if nl else "Compatibility"}</a><a href="#{"instellingen" if nl else "data"}">{"Instellingen en gegevens" if nl else "Settings and data"}</a></nav></header>

  <section class="prose" id="{"installatie" if nl else "install"}">
    <h2>{"Installatie op Windows" if nl else "Installing on Windows"}</h2>
    <ol class="steps">
      <li>{"Download een versie via de" if nl else "Download a build from the"} <a href="{L("downloads")}">{"downloadpagina" if nl else "downloads page"}</a>.</li>
      <li>{"Pak het zip-bestand volledig uit naar een map waarin je mag schrijven. Houd alle bestanden bij elkaar." if nl else "Extract the whole zip file to a folder you can write to. Keep all files together."}</li>
      <li>{"All-in-one: start <code>Velodrome.exe</code>. Die start de bridge en het spel samen, en stopt de bridge als je het spel sluit. Start <code>VelodromeGame.exe</code> niet rechtstreeks." if nl else "All-in-one: start <code>Velodrome.exe</code>. It starts the bridge and the game together and stops the bridge when you close the game. Don’t start <code>VelodromeGame.exe</code> directly."}</li>
      <li>{"Alleen het spel: start <code>Start-Velodrome.cmd</code>. Bij de eerste start worden de instellingen aangemaakt, met 24 fictieve renners." if nl else "Game only: start <code>Start-Velodrome.cmd</code>. The first start creates your settings with 24 fictional riders."}</li>
    </ol>
  </section>

  <section class="split" id="{"bediening" if nl else "controls"}">
    <div class="prose">
      <h2>{"Bediening met het toetsenbord" if nl else "Keyboard controls"}</h2>
      <p>{"Dit zijn de standaardtoetsen tijdens een wedstrijd. Je kunt ze aanpassen in de instellingen (F10)." if nl else "These are the default keys during a race. You can change them in the settings (F10)."}</p>
      <div class="table-wrap"><table><thead><tr><th scope="col">{"Toets" if nl else "Key"}</th><th scope="col">{"Actie" if nl else "Action"}</th></tr></thead><tbody>{keyrows}</tbody></table></div>
      <p class="note">{"Zonder trainer gebruikt het spel een energiemodel om je vermogen te simuleren. Dat is geen echte vermogensmeting." if nl else "Without a trainer the game uses an energy model to simulate your power. It is not a real power measurement."}</p>
    </div>
    <figure>{IMG("hub", "Hoofdmenu van Vélodrome met Wedstrijden, Toernooien, ERG-training en Pistetraining" if nl else "Vélodrome main menu with Races, Tournaments, ERG training and Track training")}
      <figcaption>{"Het hoofdmenu. Met de pijltjes en Enter navigeer je zonder muis." if nl else "The main menu. Use the arrow keys and Enter to navigate without a mouse."}</figcaption></figure>
  </section>

  <section class="prose" id="bridge">
    <h2>{"Trainer en controller koppelen" if nl else "Connecting your trainer and controller"}</h2>
    <p>{"Het spel praat met je hardware via een aparte bridge. In de all-in-one-versie start die vanzelf. Draai je alleen het spel of werk je vanuit de broncode, dan start je de bridge zelf." if nl else "The game talks to your hardware through a separate bridge. In the all-in-one build it starts by itself. If you run the game only, or work from source, start the bridge yourself."}</p>
    <ol class="steps">
      <li>{"Sluit andere apps die je trainer, controller of ANT+-stick gebruiken, zoals Zwift of Garmin Express." if nl else "Close other apps that use your trainer, controller or ANT+ stick, such as Zwift or Garmin Express."}</li>
      <li>{"Zet bij Zwift Ride eerst de linker controller aan, daarna de rechter. Zet je trainer aan." if nl else "On Zwift Ride, turn on the left controller first, then the right one. Turn on your trainer."}</li>
      <li>{"Voor hartslag: steek de ANT+-stick in en zet Broadcast Heart Rate aan op je Garmin." if nl else "For heart rate: plug in the ANT+ stick and turn on Broadcast Heart Rate on your Garmin."}</li>
      <li>{"Vanuit de broncode: start <code>bridge/start_windows.bat</code> (Python 3.12, internet nodig bij de eerste start). Zonder hartslagstick: <code>start_windows.bat --no-ant</code>." if nl else "From source: run <code>bridge/start_windows.bat</code> (Python 3.12, internet needed on first run). Without a heart-rate stick: <code>start_windows.bat --no-ant</code>."}</li>
      <li>{"Start het spel. De bridge blijft zoeken tot je apparaten beschikbaar zijn en verbindt opnieuw als de verbinding wegvalt." if nl else "Start the game. The bridge keeps searching until your devices are available and reconnects if the connection drops."}</li>
    </ol>
    <p class="warn">{"Voel je onverwachte weerstand, stop dan met trappen. Als het spel of de verbinding wegvalt, kan de software niet garanderen dat je trainer de weerstand loslaat." if nl else "If you feel unexpected resistance, stop pedalling. If the game or the connection drops, the software can’t guarantee your trainer releases the resistance."}</p>
  </section>

  <section class="prose" id="{"compatibiliteit" if nl else "compatibility"}">
    <h2>{"Compatibiliteit" if nl else "Compatibility"}</h2>
    <p>{"Ondersteund in de code. Dat is geen garantie voor elk toestel of elke firmwareversie." if nl else "Supported in code. This is not a guarantee for every device or firmware version."}</p>
    <div class="table-wrap"><table><tbody>{hwrows}</tbody></table></div>
    <p>{"De ERG-modus werkt tussen 0 en 1300 W, binnen wat je trainer zelf aangeeft. De virtuele versnellingen zijn een benadering en gebruiken geen eigen protocol van Wahoo of Zwift." if nl else "ERG mode works between 0 and 1300 W, within what your trainer reports it can do. The virtual gears are an approximation and don’t use a native Wahoo or Zwift protocol."}</p>
  </section>

  <section class="prose" id="{"instellingen" if nl else "data"}">
    <h2>{"Instellingen en gegevens" if nl else "Settings and data"}</h2>
    <p>{"Renners en Strava stel je in met bestanden in de map <code>config/</code> naast het spel. Behoud de renner-ID’s als je namen wijzigt, zodat je records gekoppeld blijven. Voor Strava vul je je eigen gegevens in <code>strava_config.cfg</code> in." if nl else "Riders and Strava are configured with files in the <code>config/</code> folder next to the game. Keep the rider IDs when you change names so your records stay linked. For Strava, enter your own details in <code>strava_config.cfg</code>."}</p>
    <p>{"Je records, opgeslagen ritten en instellingen staan op Windows in:" if nl else "On Windows your records, saved rides and settings are stored in:"}</p>
    <pre><code>%APPDATA%\\Godot\\app_userdata\\Velodrome 250 - Sprint Beta\\</code></pre>
    <p>{"Bij trage pc’s kies je F10 → Beeld → Eenvoudige graphics. Die stand gebruikt minder publiek en een kortere intro, en wordt actief na een herstart." if nl else "On slower PCs, choose F10 → Display → Simple graphics. It uses a smaller crowd and a shorter intro and takes effect after a restart."}</p>
  </section>
</main>'''
        return title, desc, body

    if key == "downloads":
        title = "Downloads – Vélodrome" if nl else "Downloads – Vélodrome"
        desc = ("Vélodrome downloaden voor Windows: all-in-one met bridge of alleen het spel. Vereisten en releasenotes." if nl
                else "Download Vélodrome for Windows: all-in-one with the bridge, or the game only. Requirements and release notes.")
        body = f'''<main id="main" class="wrap page">
  <header class="page-head"><h1>{"Downloads" if nl else "Downloads"}</h1>
  <p class="lede">{"Alle versies staan op GitHub Releases. Kies de variant die bij jouw opstelling past." if nl else "All builds are published on GitHub Releases. Pick the variant that fits your setup."}</p></header>

  <div class="variants">
    <article class="variant main-variant">
      <h2>{"All-in-one" if nl else "All-in-one"}</h2>
      <p class="hint">{"Spel en bridge samen" if nl else "Game and bridge together"}</p>
      <p>{"Voor wie met een trainer, Zwift Ride of hartslagmeter rijdt. Eén programma start alles en stopt de bridge als je het spel sluit." if nl else "For riding with a trainer, Zwift Ride or heart-rate monitor. One program starts everything and stops the bridge when you close the game."}</p>
      <p class="meta">Windows x64 · <code>Velodrome.exe</code></p>
      <a class="btn primary" href="{REPO}/releases/latest">{"Download via GitHub Releases" if nl else "Download from GitHub Releases"}</a>
    </article>
    <article class="variant">
      <h2>{"Alleen het spel" if nl else "Game only"}</h2>
      <p class="hint">{"Standalone, zonder bridge" if nl else "Standalone, without the bridge"}</p>
      <p>{"Spelen met het toetsenbord. Wil je later toch een trainer koppelen, dan kun je de bridge apart starten." if nl else "Play with a keyboard. If you want to connect a trainer later, you can run the bridge separately."}</p>
      <p class="meta">Windows x64 · <code>Start-Velodrome.cmd</code></p>
      <a class="btn" href="{REPO}/releases/latest">{"Download via GitHub Releases" if nl else "Download from GitHub Releases"}</a>
    </article>
  </div>

  <p class="status">{"Staat er nog geen versie op Releases? Testbuilds verschijnen eerst als artifact onder" if nl else "No build on Releases yet? Test builds first appear as artifacts under"} <a href="{REPO}/actions">GitHub Actions</a>{"; daarvoor heb je een GitHub-account nodig." if nl else "; you need a GitHub account to download those."}</p>

  <section class="split">
    <div class="prose">
      <h2>{"Vereisten" if nl else "Requirements"}</h2>
      <ul class="plain">
        <li><strong>{"Systeem" if nl else "System"}</strong> {"Windows 64-bit. Het spel gebruikt de compatibiliteitsrenderer van Godot (OpenGL)." if nl else "64-bit Windows. The game uses Godot’s compatibility renderer (OpenGL)."}</li>
        <li><strong>{"Zonder trainer" if nl else "Without a trainer"}</strong> {"Een toetsenbord is genoeg." if nl else "A keyboard is enough."}</li>
        <li><strong>{"Met trainer" if nl else "With a trainer"}</strong> {"Bluetooth op je pc voor Wahoo KICKR en Zwift Ride; een ANT+-USB-stick voor Garmin-hartslag." if nl else "Bluetooth on your PC for Wahoo KICKR and Zwift Ride; an ANT+ USB stick for Garmin heart rate."}</li>
        <li><strong>macOS</strong> {"Een bundel voor Apple Silicon en Intel (macOS 12 of nieuwer) is in ontwikkeling en nog niet als release beschikbaar." if nl else "A bundle for Apple Silicon and Intel (macOS 12 or later) is in development and not yet available as a release."}</li>
      </ul>
      <p>{"Na het downloaden: zie" if nl else "After downloading, see"} <a href="{L("manual")}#{"installatie" if nl else "install"}">{"installatie in de handleiding" if nl else "installation in the manual"}</a>.</p>
    </div>
    <div class="prose">
      <h2>{"Releasenotes" if nl else "Release notes"}</h2>
      <p>{"Bij elke versie staan de wijzigingen op de releasepagina. Wat in de volgende versie komt, volg je via de mijlpaal op GitHub." if nl else "Each release lists its changes on the release page. Follow what comes next through the milestone on GitHub."}</p>
      <ul class="plain">
        <li><a href="{REPO}/releases">{"Alle releases" if nl else "All releases"}</a></li>
        <li><a href="{REPO}/milestones">{"Mijlpalen en planning" if nl else "Milestones and planning"}</a></li>
      </ul>
    </div>
  </section>
</main>'''
        return title, desc, body

    if key == "dev":
        title = "Ontwikkeling – Vélodrome" if nl else "Development – Vélodrome"
        desc = ("Vélodrome is open source onder GPLv3. Broncode, planning, issues en zelf bouwen met Godot 4.7." if nl
                else "Vélodrome is open source under GPLv3. Source code, roadmap, issues and building it yourself with Godot 4.7.")
        body = f'''<main id="main" class="wrap page">
  <header class="page-head"><h1>{"Ontwikkeling" if nl else "Development"}</h1>
  <p class="lede">{"Vélodrome is open source. Het spel is gebouwd met Godot; de hardwarebridge is geschreven in Python." if nl else "Vélodrome is open source. The game is built with Godot; the hardware bridge is written in Python."}</p></header>

  <section class="split">
    <div class="prose">
      <h2>{"Zelf bouwen" if nl else "Build it yourself"}</h2>
      <ol class="steps">
        <li>{"Clone de repository:" if nl else "Clone the repository:"}<pre><code>git clone {REPO}.git</code></pre></li>
        <li>{"Open <code>game/project.godot</code> in Godot 4.7.2 en laat de assets importeren." if nl else "Open <code>game/project.godot</code> in Godot 4.7.2 and let the assets import."}</li>
        <li>{"Start met F5. Zonder trainer rijd je met het gesimuleerde vermogen; een bridge is niet nodig." if nl else "Press F5. Without a trainer you ride on simulated power; no bridge is needed."}</li>
      </ol>
      <p>{"De bridge kun je zonder hardware testen met de virtuele bridge: <code>python bridge/tools/virtual_bridge_ui.py</code>." if nl else "You can test the bridge without hardware using the virtual bridge: <code>python bridge/tools/virtual_bridge_ui.py</code>."}</p>
    </div>
    <div class="prose">
      <h2>{"Meedoen" if nl else "Get involved"}</h2>
      <p>{"Een bug gevonden of een idee? Meld het als issue op GitHub. Vermeld je versie, je hardware en wat je deed." if nl else "Found a bug or have an idea? Open an issue on GitHub. Include your version, your hardware and what you were doing."}</p>
      <ul class="plain">
        <li><a href="{REPO}">{"Broncode" if nl else "Source code"}</a></li>
        <li><a href="{REPO}/issues">{"Issues" if nl else "Issues"}</a></li>
        <li><a href="{REPO}/issues/new">{"Een issue melden" if nl else "Open an issue"}</a></li>
        <li><a href="{REPO}/milestones">{"Planning per versie" if nl else "Roadmap per version"}</a></li>
      </ul>
      <p>{"Testen op echte hardware helpt het meest: vooral het rijgevoel op een KICKR, Zwift Ride en de ANT+-hartslag." if nl else "Testing on real hardware helps most: especially ride feel on a KICKR, Zwift Ride and ANT+ heart rate."}</p>
    </div>
  </section>

  <section class="prose">
    <h2>{"Wat er komt" if nl else "What’s coming"}</h2>
    <ul class="plain">
      <li><strong>{"Ploegkoers" if nl else "Madison"}</strong> {"als volledige wedstrijd, na de aflossingstraining die er al is." if nl else "as a full race, building on the hand-sling training that’s already in."}</li>
      <li><strong>{"Temporace en toernooien" if nl else "Tempo race and tournaments"}</strong> {"met één klassement over meerdere wedstrijden." if nl else "with one classification across several races."}</li>
      <li><strong>{"20-minuten FTP-test" if nl else "20-minute FTP test"}</strong> {"naast de ramp test." if nl else "alongside the ramp test."}</li>
      <li><strong>{"Inloggen met Bluesky" if nl else "Sign in with Bluesky"}</strong> {"en een spelersprofiel, gepland voor versie 0.4." if nl else "and a player profile, planned for version 0.4."}</li>
    </ul>
  </section>

  <section class="prose">
    <h2>{"Licentie" if nl else "Licence"}</h2>
    <p>{"Vélodrome valt onder de GNU General Public License versie 3 (GPLv3). Je mag het spel gebruiken, aanpassen en verder verspreiden onder dezelfde licentie." if nl else "Vélodrome is licensed under the GNU General Public License version 3 (GPLv3). You may use, modify and redistribute it under the same licence."}</p>
    <p><a href="{REPO}/blob/main/LICENSE">{"Lees de volledige licentie" if nl else "Read the full licence"}</a></p>
  </section>
</main>'''
        return title, desc, body


def _id(name):
    import re, unicodedata
    s = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "-", s).strip("-")
