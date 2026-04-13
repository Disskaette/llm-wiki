# SPEC-007: Future — Skalierung, Lifecycle, Visualisierung

**Status:** Backlog
**Version:** 1.0
**Erstellt:** 2026-04-13
**Aktualisiert:** 2026-04-13

## Zusammenfassung

Sammlung von Features die bei wachsendem Wiki (450+ Quellen, 1000+ Seiten)
relevant werden. Basiert auf Recherche des LLM-Wiki-Oekosystems (Karpathy
Original, LLM Wiki v2, nashsu/llm_wiki, Enterprise-Kritik).

Nicht zur sofortigen Umsetzung — fuer zukuenftige Brainstorm-Sessions.

## Kontext: Wo steht das Plugin im Oekosystem?

Das Bibliothek-Plugin ist die rigoroseste Open-Source-Implementierung des
Karpathy LLM-Wiki-Patterns:
- 3-Schichten-Enforcement (Prompt → Agent-Review → Shell-Block) — einzigartig
- Gate-FAIL-Counter mit maschineller Blockade — einzigartig
- Kontrolliertes Vokabular mit Taxonomie — einzigartig
- 225+ Tests

Was andere haben und wir (noch) nicht:
- Confidence Scoring / Wissens-Lifecycle (LLM Wiki v2)
- Knowledge Graph Visualisierung (nashsu/llm_wiki: sigma.js + Louvain)
- Hybrid-Suche bei Skalierung (BM25 + Vector + Graph-Traversal)

## Feature-Kandidaten

### A: Knowledge Graph Visualisierung (sigma.js + Louvain)

**Problem:** Bei 450+ Quellen und 1000+ Wiki-Seiten wird Obsidian Graph View
unuebersichtlich (zu viele Knoten, keine automatische Cluster-Erkennung).

**Loesung:** sigma.js-basierte Visualisierung mit Louvain-Community-Detection:
- Automatische Erkennung von Wissens-Clustern ("Holzbau-Cluster", "Stahlbeton-Cluster")
- 4-Signal-Relevanzmodell (nashsu: Zitations-Haeufigkeit, Aktualitaet, Verlinkungsgrad, Textaehnlichkeit)
- Erkennung ueberraschender Verbindungen zwischen Clustern
- Gap-Analyse: "Zwischen Cluster A und B gibt es keine Bruecken-Konzepte"

**Aufwand:** Hoch (eigenstaendige Web-Komponente, Daten-Export aus Wiki)
**Abhaengigkeiten:** SPEC-005 (Domain-Agnostik) fuer generische Cluster-Labels
**Skalierungs-Schwelle:** Ab ~200 Quellen / ~500 Wiki-Seiten sinnvoll

**Brainstorm-Fragen:**
- Standalone-Web-App oder Obsidian-Plugin?
- Datenquelle: Frontmatter + Wikilinks parsen, oder eigene Graph-DB?
- Echtzeit-Update oder Batch-Generierung (z.B. bei /wiki-review)?
- Interaktiv (klicken → Seite oeffnen) oder statisch (Export als SVG/HTML)?

### B: Confidence Scoring / Wissens-Lifecycle

**Problem:** Alle Wiki-Inhalte werden gleich behandelt — ein Befund von 2006
hat das gleiche Gewicht wie einer von 2024. Selten zitierte Fakten verstopfen
das Wiki ohne Mehrwert.

**Loesung (aus LLM Wiki v2):**
- Jede Aussage bekommt ein Confidence-Level (0.0-1.0)
- Confidence steigt wenn mehrere Quellen bestaetigen
- Confidence sinkt ueber Zeit (Ebbinghaus-Decay) wenn nicht referenziert
- /wiki-review meldet Seiten mit niedriger aggregierter Confidence
- 4 Konsolidierungs-Stufen: Working Memory → Episodisch → Semantisch → Prozedural

**Aufwand:** Mittel (Frontmatter-Felder + Berechnung in wiki-review)
**Abhaengigkeiten:** Keine
**Skalierungs-Schwelle:** Ab ~100 Quellen sinnvoll (wenn aeltere Quellen verdraengt werden)

**Brainstorm-Fragen:**
- Confidence pro Seite oder pro Aussage?
- Decay-Rate konfigurierbar pro Domain? (Normen veralten schneller als Grundlagenforschung)
- Wie interagiert Confidence mit dem reviewed:-Feld?
- Soll Gate 2 (Quellen-Pruefer) Confidence setzen?

### C: Hybrid-Suche (BM25 + Vector)

**Problem:** Bei 1000+ Seiten reicht die Obsidian-Suche + Dataview nicht mehr
fuer praezise semantische Abfragen. Index-Dateien werden zu gross fuer den
Context.

**Loesung:**
- Lokale Vector-DB (LanceDB, SQLite-VSS, oder aehnlich)
- BM25 fuer exakte Terme + Vector fuer semantische Aehnlichkeit
- RRF-Fusion (Reciprocal Rank Fusion) fuer kombiniertes Ranking
- Optional: MCP-Server der die Suche als Tool bereitstellt

**Aufwand:** Hoch (externe Abhaengigkeit, Embedding-Pipeline, MCP-Server)
**Abhaengigkeiten:** SPEC-006 (Multi-Format — verschiedene Quelltypen indizieren)
**Skalierungs-Schwelle:** Ab ~500 Wiki-Seiten / Index-Dateien >50K Tokens

**Brainstorm-Fragen:**
- Lokales Embedding-Modell (Ollama) oder API (OpenAI/Voyage)?
- Wann wird indiziert? Bei jedem Ingest? Batch-Job?
- Wie integriert sich das mit dem bestehenden _index/-System?
- Brauchen wir das ueberhaupt wenn Obsidian Dataview gut genug ist?

### D: Erweiterte Input-Formate (DOCX, PPTX, EPUB)

**Problem:** SPEC-006 deckt PDF + Markdown + URL ab. Aber Vorlesungsfolien (PPTX),
Skripte (DOCX) und E-Books (EPUB) sind gaengige akademische Formate.

**Loesung:** Format-spezifische Extraktion (wie nashsu/llm_wiki):
- DOCX: python-docx → Markdown (Headings, Tabellen, Listen erhalten)
- PPTX: Slide-by-Slide Extraktion
- EPUB: Kapitel-basierte Extraktion

**Aufwand:** Mittel (Python-Scripts oder externe Tools noetig)
**Abhaengigkeiten:** SPEC-006 (Format-Erkennung-Framework)

## Priorisierung (Vorschlag)

| Feature | Nutzen bei 450 Buechern | Aufwand | Empfehlung |
|---------|------------------------|---------|------------|
| A: Graph + Louvain | Hoch (Cluster-Erkennung) | Hoch | Brainstorm-Session |
| B: Confidence Scoring | Mittel (Qualitaetssignal) | Mittel | Nach SPEC-005/006 evaluieren |
| C: Hybrid-Suche | Mittel (ab 500+ Seiten) | Hoch | Erst wenn Obsidian-Suche nicht reicht |
| D: DOCX/PPTX/EPUB | Niedrig (PDF + MD reicht meist) | Mittel | On-demand wenn konkret benoetigt |

## Quellen (Recherche 2026-04-13)

- [Karpathy LLM Wiki Gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
- [LLM Wiki v2 — Lifecycle + Governance](https://gist.github.com/rohitg00/2067ab416f7bbe447c1977edaaa681e2)
- [nashsu/llm_wiki — Desktop App mit Graph](https://github.com/nashsu/llm_wiki)
- [Enterprise Scaling Kritik](https://www.epsilla.com/blogs/llm-wiki-kills-rag-karpathy-enterprise-semantic-graph)
- [LLM Wiki vs RAG Vergleich](https://www.mindstudio.ai/blog/llm-wiki-vs-rag-markdown-knowledge-base-comparison)
