# CBAS – Craphunts Blacklisted Addon Suite

WoW-Forever-Addon (Midnight-Client, Interface 16001). Befehl im Spiel: `/crap`

| Ansicht | Inhalt |
|---|---|
| **Lage** | Startseite: zeigt nach Wichtigkeit sortiert, was gerade zählt (auffällige Mitspieler, Tipps am AH, Update, Layer) |
| **GScout** | Gildendatenbank: Rekrutierung, Loot-System, Leistungswert, Layer, Leistungskurve · Ansicht „Gildenlose“ |
| **Geierwacht** | Passt der Bedarf-Wurf zu Klasse und Spec? Main-/Offspec, Runs |
| **Can I have it** | Offspec-Teile fair bekommen: Rat bei jedem Drop (wer braucht es als Mainspec?) und höfliche, fertige Texte |
| **Flipper** | AH- und Händler-Flips mit Auctionator/TSM: Autopilot-Taste, 2h-Modus, Lager & Einstellen, Sniper, Verlauf/Prognose, Claude-Tipps |
| **Mage-Dienste** | Portale, Wasser & Essen verkaufen: Kunden aus dem Chat, Autopilot-Taste (anschreiben, einladen, handeln, Portal), Vorrat, Preise |
| Chat | Länderflaggen vor Spielernamen: `[Gruppe] 🇩🇪 Name`, Englisch als EN |
| Gruppensuche | CBAS-Infos zu jedem Suchergebnis (Blizzard & LFGForever): Sprache, Gilde, Leistung, Geier-Warnungen · Warn-Symbole direkt in der Ergebnisliste |
| Einstellungen | nach Bereichen sortiert, Version & Download-Link · Minimap-Knopf |

## Download & Installation
1. **[⬇ CBAS.zip herunterladen](https://github.com/Gastpilot/CBAS/releases/latest/download/CBAS.zip)** (immer die neueste Version).
2. Entpacken nach `World of Warcraft\_forever_\Interface\AddOns\`.
   Danach muss es den Ordner `Interface\AddOns\CBAS` geben.
3. WoW neu starten, im Spiel `/crap`.

> ⚠️ Nicht „Code → Download ZIP“ benutzen. Dabei hängt GitHub „-main“ an den Ordnernamen, und WoW lädt das Addon dann nicht.
> Wer es trotzdem so gemacht hat: aus `CBAS-main` nur den inneren Ordner `CBAS` nach `AddOns` kopieren.

Ausführliche Anleitung: [CBAS/LIESMICH.txt](CBAS/LIESMICH.txt) · Alle Versionen: [Releases](https://github.com/Gastpilot/CBAS/releases)

## Aufbau des Codes
| Ordner | Inhalt |
|---|---|
| `CBAS/Core/` | Datenbank, Parser, Leistungswert, Austausch, Inspizieren, Layer, Version |
| `CBAS/UI/` | Theme (Farben, Knöpfe, Schalter), Hauptfenster mit Seitenleiste, Einstellungen, Startseite Lage, Minimap-Knopf |
| `CBAS/GScout/` | Gildenliste, Gildenlose, Leistungskurve |
| `CBAS/Geierwacht/` | Loot-Prüfung und Can I have it |
| `CBAS/Flipper/` | AH-Analyse, Autopilot, Sniper, Lager, Verlauf |
| `CBAS/Chat/` | Länderflaggen, Gruppensuche-Infos |
| `CBAS/Mage/` | Mage-Dienste: Kunden, Autopilot (sichere Taste für Zauber), Oberfläche |
| `CBAS/Flags/`, `CBAS/Media/` | Bilder (erzeugt mit `tools/make_flags.py`, `tools/make_unicorn.py`) |

Tests: `pip install lupa --break-system-packages`, dann `bash tests/run.sh`.

## Grundregeln
- **Leichtgewichtig:** Werte zwischenspeichern statt neu rechnen, Listen nur bei offenem Fenster und gedrosselt aufbauen, keine unbegrenzt wachsenden Tabellen, Aufräumen beim Einloggen.
- **Blizzard-konform:** Kaufen und Einstellen immer nur per Tastendruck, keine Klick-Programme, Nachnahme wird nie bezahlt.

## Claude-Tipps
`tools/gen_tips.py` liest `WTF/Account/<Account>/SavedVariables/Auctionator.lua` und schreibt `CBAS/ClaudeTips.lua`:

```
python3 tools/gen_tips.py <Pfad>/Auctionator.lua CBAS/ClaudeTips.lua [neueste-Version]
```

## Update-Hinweis im Spiel
Einstellungen > Allgemein zeigt die installierte Version und den Download-Link. Neue Versionen erfährt CBAS von anderen CBAS-Spielern in Gilde und Gruppe (unsichtbare Addon-Nachricht `CBASv`, höchstens alle 5 Min., nicht in Instanzen) und aus der Tipp-Datei.

**Release-Ablauf:**
1. `ns.VERSION` in `Core/Core.lua`, `## Version` in `CBAS.toc` und die Kopfzeile in `LIESMICH.txt` hochzählen.
2. Ein Release `vX.Y.Z` veröffentlichen. Die `CBAS.zip` baut GitHub dann selbst (`.github/workflows/release.yml`).

Benötigt `pip install lupa cbor2`. Die erzeugte Datei enthält deine Marktdaten. Im Repo liegt nur eine leere Vorlage.
