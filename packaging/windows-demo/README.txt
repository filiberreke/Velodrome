Velodrome - Windows demo

Pak de ZIP volledig uit en start Start-Velodrome.cmd.
Houd Velodrome.exe, Velodrome.pck en de overige meegeleverde bestanden samen.
De Zwift Ride bridge wordt niet meegeleverd.

Bij de eerste start worden ontbrekende configuraties aangemaakt in config/:
- riders_config.cfg: 24 fictieve demorenners (8 per specialiteit).
- strava_config.cfg: lege client_id, client_secret en refresh_token.
  redirect_uri blijft http://localhost, zoals in het bestaande voorbeeld.
Je kunt deze bestanden daarna aanpassen. Behoud de rider-ID's voor records.
Strava is optioneel; zonder eigen gegevens is er geen account gekoppeld.
De 24 profielen zijn beschikbaar; de gekozen discipline bepaalt het aantal
deelnemers in de wedstrijd.

Bestaande configuraties worden nooit overschreven door het startbestand.
Ook een bestand op de oude locatie naast de exe of in de Godot-gebruikersmap
wordt behouden en krijgt voorrang op het aanmaken van een nieuw voorbeeld.
Het spel kan bestanden naast de exe zelf naar config/ verplaatsen.

Updates: pak de nieuwe demo uit in je bestaande map. De ZIP bevat alleen
sjablonen in defaults/ en bevat GEEN actieve config/*.cfg-bestanden.
Daardoor overschrijft uitpakken je eigen configuraties niet. Start daarna
Start-Velodrome.cmd; het maakt alleen nog ontbrekende bestanden aan.
Bewerk config/*.cfg, niet defaults/*.cfg.
Rechtstreeks Velodrome.exe starten slaat het aanmaken van voorbeelden over.

OAuth-tokens en opgeslagen instellingen blijven in de Godot-gebruikersmap:
%APPDATA%/Godot/app_userdata/Velodrome 250 - Sprint Beta/config/
De demo levert geen tokens, persoonlijke gegevens of bestaande records mee.
