# CBAS – Craphunts Blacklisted Addon Suite

WoW-Forever-Addon (Midnight-Client, Interface 16001). Befehl im Spiel: `/crap`

| Reiter | Inhalt |
|---|---|
| **GScout** | Gildendatenbank: Rekrutierung, Loot-System, Leistungswert, Layer, Leistungskurve · Ansicht „Gildenlose“ |
| **Geierwacht** | Passt der Bedarf-Wurf zu Klasse und Spec? Main-/Offspec, Runs |
| **Flipper** | AH- und Händler-Flips mit Auctionator/TSM: Autopilot-Taste, 2h-Modus, Lager & Einstellen, Sniper, Verlauf/Prognose, Claude-Tipps |
| Zahnrad | Einstellungen |

## Installation
Ordner `CBAS` nach `World of Warcraft\_forever_\Interface\AddOns\` kopieren, WoW neu starten.
Ausführliche Anleitung: [CBAS/LIESMICH.txt](CBAS/LIESMICH.txt)

## Grundregeln
- **Leichtgewichtig:** Werte zwischenspeichern statt neu rechnen, Listen nur bei offenem Fenster und gedrosselt aufbauen, keine unbegrenzt wachsenden Tabellen, Aufräumen beim Einloggen.
- **Blizzard-konform:** Kaufen und Einstellen immer nur per Tastendruck, keine Klick-Programme, Nachnahme wird nie bezahlt.

## Claude-Tipps
`tools/gen_tips.py` liest `WTF/Account/<Account>/SavedVariables/Auctionator.lua` und schreibt `CBAS/ClaudeTips.lua`:

```
python3 tools/gen_tips.py <Pfad>/Auctionator.lua CBAS/ClaudeTips.lua
```

Benötigt `pip install lupa cbor2`. Die erzeugte Datei enthält deine Marktdaten. Im Repo liegt nur eine leere Vorlage.
