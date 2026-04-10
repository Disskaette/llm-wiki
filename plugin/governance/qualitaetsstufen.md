# Qualitaetsstufen — Verarbeitungsstatus und Review

## Verarbeitungsstatus (Feld: `verarbeitung:`)

Beschreibt wie gruendlich die Quelle beim Ingest verarbeitet wurde.
Wird automatisch vom /ingest-Skill gesetzt.

| Stufe | Bedeutung | Erlaubt |
|-------|-----------|---------|
| **vollstaendig** | Buch komplett in einem Context gelesen, alle Kapitel verarbeitet, 4-Gate-Review bestanden | Voller Vertrauensgrad — Zahlenwerte, Seitenangaben, Querverweise |
| **gesplittet** | Buch war zu gross fuer einen Context, wurde in Teilen verarbeitet. Alle Teile gelesen, Konsolidierung durchgefuehrt | Zahlenwerte und Seitenangaben erlaubt, aber Hinweis `[SPLIT-INGEST]` bei kapiteluebergreifenden Aussagen |
| **nur-katalog** | Nur Inhaltsverzeichnis und Metadaten extrahiert (Fallback bei unlesbaren PDFs/Scans ohne OCR) | NUR Kapitelstruktur und Schlagworte. KEINE inhaltlichen Aussagen, KEINE Zahlenwerte |
| **fehlerhaft** | Ingest abgebrochen oder Gate-Review nicht bestanden | Wiki-Seiten existieren, sind aber UNVOLLSTAENDIG. Marker `[INGEST UNVOLLSTAENDIG]` auf der Quellenseite |

## Review-Status (Feld: `reviewed:`)

Beschreibt ob ein Mensch die Wiki-Seite geprueft hat.
Wird manuell oder via /wiki-lint gesetzt.

| Wert | Bedeutung |
|------|-----------|
| `false` | LLM-generiert, nicht von einem Menschen geprueft |
| `true` | Vom Nutzer stichprobenartig gegen Original-PDF geprueft |
| `2026-04-15` | Datum der letzten manuellen Pruefung (bevorzugt statt `true`) |

## Zusammenspiel

- `verarbeitung: vollstaendig` + `reviewed: false` = "LLM hat sauber gearbeitet, Mensch hat noch nicht geschaut"
- `verarbeitung: vollstaendig` + `reviewed: 2026-04-15` = "Hoechste Vertrauensstufe"
- `verarbeitung: gesplittet` + `reviewed: false` = "Vorsicht bei Kapiteluebergaengen"
- `verarbeitung: nur-katalog` + `reviewed: false` = "Nur als Verzeichnis nutzbar"
- `verarbeitung: fehlerhaft` = "Muss nochmal durch /ingest"

## Regeln

1. `verarbeitung:` wird NUR vom /ingest-Skill gesetzt — nie manuell aendern
2. `reviewed:` wird NUR manuell oder via /wiki-lint gesetzt — nie vom /ingest-Skill
3. Bei Re-Ingest (Update): `reviewed:` wird auf `false` zurueckgesetzt
4. /wiki-lint kann `reviewed: false`-Seiten zur Pruefung vorschlagen
