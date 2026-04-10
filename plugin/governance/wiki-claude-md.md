# wiki/CLAUDE.md — Template

Diese Datei wird beim Bootstrap (erster /ingest) als `wiki/CLAUDE.md` angelegt.
Sie stellt sicher, dass das Bibliothek-Plugin korrekt geladen und genutzt wird,
wenn Claude Code im wiki/-Verzeichnis arbeitet.

---

## Template-Inhalt (wird 1:1 als wiki/CLAUDE.md geschrieben):

```markdown
# Wiki — Technische Wissensdatenbank

Dieses Verzeichnis ist ein LLM-gepflegtes Wiki ueber Fachbuecher
des Konstruktiven Ingenieurbaus. Es wird vom **Bibliothek-Plugin** verwaltet.

## Regeln

1. **KEINE direkten Edits** — Wiki-Seiten werden ausschliesslich ueber
   Skills erstellt/geaendert: /ingest, /synthese, /normenupdate, /vokabular
2. **PostToolUse-Hook aktiv** — Jede Write/Edit-Operation auf wiki/**/*.md
   wird automatisch durch check-wiki-output.sh validiert
3. **10 Hard Gates** — Definiert in governance/hard-gates.md des Bibliothek-Plugins
4. **Obsidian-Vault** — Dieses Verzeichnis ist ein Obsidian-Vault.
   Oeffne es in Obsidian fuer Graph View, Suche und Navigation.

## Verzeichnisstruktur

- `quellen/` — Quellenseiten (Buch-Zusammenfassungen)
- `konzepte/` — Konzeptseiten (Fachbegriffe, Phaenomene)
- `normen/` — Normseiten (Paragraph-Kommentare)
- `baustoffe/` — Baustoffseiten (Materialeigenschaften)
- `verfahren/` — Verfahrensseiten (Rechenmethoden)
- `moc/` — Maps of Content (Navigationsseiten)
- `_pdfs/` — Original-PDFs (per [[link.pdf]] in Obsidian oeffnen)
  - `_pdfs/neu/` — Eingangsordner (neue PDFs hier ablegen)
- `_index/` — Teilindizes pro Seitentyp
- `_vokabular.md` — Kontrolliertes Fachvokabular
- `_log.md` — Chronologisches Aenderungsprotokoll

## Wichtig fuer LLMs

- LESEPFAD: Fachfragen aus Wiki-Seiten beantworten (PDFs NICHT laden)
- SCHREIBPFAD: Nur ueber Skills schreiben, Original-PDF im Context haben
- Jede Aussage braucht Quelle + Seitenangabe
- Jeder Zahlenwert braucht Quelle + Seitenangabe
- Jeder Normverweis braucht Abschnittsnummer
- Umlaute als echte Unicode-Zeichen schreiben (ä, ö, ü), NICHT als ASCII-Ersetzungen (ae/oe/ue)
```
