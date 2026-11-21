VELODROME — MACOS MET BRIDGE

1. Kies arm64 voor Apple Silicon of x86_64 voor Intel.
   Gebruik macOS Monterey 12.3 of nieuwer.
2. Pak alle ZIP-lagen uit en houd de volledige map bundle bij elkaar.
3. Open Start-Velodrome.command. Houd het Terminalvenster open en geef
   Bluetooth-toegang als macOS daarom vraagt.

Als macOS de eerste start blokkeert, controleer in Privacy en beveiliging
of je de toepassing kunt openen. Als de start nog wordt geblokkeerd,
open Terminal in de uitgepakte map bundle. Voer voor een ZIP die je
rechtstreeks van de Vélodrome-downloadpagina hebt opgehaald deze
opdrachten uit, vanuit die map:

    xattr -dr com.apple.quarantine .
    chmod u+x Start-Velodrome.command

Open daarna Start-Velodrome.command opnieuw.

Handleiding: https://velodrome.wielerpraat.be/nl/handleiding/
Problemen melden: https://github.com/filiberreke/Velodrome/issues
