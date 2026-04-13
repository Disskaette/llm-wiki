# Hard Gates — Bibliothek-Plugin

10 nicht verhandelbare Regeln. Source-of-Truth fuer alle Skills und Agents.
Inline-Kopie in using-bibliothek SKILL.md muss identisch sein.

---

<HARD-GATE: KEIN-BUCH-OHNE-VOLLSTAENDIGE-LESUNG>
Bedingung: keine (universell)
Jedes Dokument wird beim Ingest KOMPLETT gelesen. Jede Seite, jedes Kapitel.
Kein Ueberspringen, kein "Kapitel 7 scheint nicht relevant".
Erst nach vollstaendiger Lesung wird entschieden was ins Wiki kommt.
Bei Dokumenten >800K Tokens: Split-Ingest-Protokoll (Phase 0), aber jeder
Teil wird vollstaendig gelesen.
Durchsetzung: Hybrid (Prompt-Law: Ingest-Phase 1 IRON LAW + Kontext-Budget-Stopp.
Keine mechanische Seitenzahl-Verifikation — LLM muss Lesung dokumentieren.
Split-Plan bei >800K Tokens schafft nachvollziehbare Kapitel-Zuordnung.)
</HARD-GATE>

<HARD-GATE: KEIN-INHALT-OHNE-SEITENANGABE>
Bedingung: keine (universell)
Jede Aussage auf einer Wiki-Seite braucht Quelle + Seitenangabe.
"Steht im Fingerloos" ist FAIL.
"Fingerloos 2016, S. 234-237" ist PASS.
"Winter 2021, Kap. 4.3" ist PASS.
"EC2, §9.2.5, Gl. (9.13)" ist PASS.
Ausnahme: MOC-Seiten (reine Navigationsseiten ohne inhaltliche Aussagen).
Durchsetzung: Machine-Law (check-wiki-output.sh Check 6)
</HARD-GATE>

<HARD-GATE: KEIN-ZAHLENWERT-OHNE-QUELLE>
Bedingung: keine (universell)
Jeder Zahlenwert (Festigkeit, Steifigkeit, Beiwert, Prozentangabe, Dimension,
geometrische Groesse) MUSS eine Quellenangabe mit Seitenreferenz haben.
Beispiel PASS: "f_v,R = 1,2 N/mm² (Ehrhart/Brandner 2018, S. 8, Tab. 3)"
Beispiel FAIL: "f_v,R betraegt typischerweise 1,2 N/mm²"
Ausnahme: Eigene Berechnungsergebnisse die im selben Abschnitt hergeleitet werden.
Durchsetzung: Machine-Law (check-wiki-output.sh Check 4)
</HARD-GATE>

<HARD-GATE: KEIN-NORMBEZUG-OHNE-ABSCHNITT>
Bedingung: Domain-Typ "norm" ist in seitentypen.md aktiv.
Nicht "nach EC5", sondern "EC5, §6.1.5" oder "DIN EN 1995-1-1, Abschnitt 6.1.5".
Nicht "gemaess CEN/TS 19103", sondern "CEN/TS 19103, §7.2".
Jeder Normverweis braucht den konkreten Abschnitt, Absatz oder Gleichungsnummer.
Durchsetzung: Machine-Law (check-wiki-output.sh Check 5)
</HARD-GATE>

<HARD-GATE: KEINE-KONZEPTSEITE-OHNE-QUERVERWEIS>
Bedingung: keine (universell)
Jede Konzept-, Verfahrens- und Baustoffseite muss mindestens EINEN Wikilink
[[...]] zu einer anderen Wiki-Seite enthalten (nicht zur eigenen Quellenseite).
Isolierte Seiten sind verboten — sie brechen die Navigierbarkeit.
Durchsetzung: Machine-Law (check-wiki-output.sh Check 7)
</HARD-GATE>

<HARD-GATE: KEIN-SCHLAGWORT-OHNE-VOKABULAR>
Bedingung: keine (universell)
Jedes Schlagwort im Frontmatter-Feld `schlagworte:` MUSS im kontrollierten
Vokabular (`wiki/_vokabular.md`) existieren. Neue Begriffe werden ueber
/vokabular angelegt — NIEMALS ad-hoc in einer Quellen- oder Konzeptseite.
Synonyme werden als Verweis auf den bevorzugten Term gefuehrt.
Durchsetzung: Machine-Law (check-wiki-output.sh Check 3)
</HARD-GATE>

<HARD-GATE: KEIN-UPDATE-OHNE-DIFF>
Bedingung: keine (universell)
Wenn eine bestehende Wiki-Seite durch ein neues Buch aktualisiert wird:
1. Das Diff muss in `wiki/_log.md` dokumentiert werden
2. Format: Was hat sich geaendert, warum, welche neue Quelle
3. Bei Wertaenderungen: alter Wert → neuer Wert mit Quellenangabe beider
Durchsetzung: Hybrid (Skill-Phase prueft + _log.md Pflicht-Schritt; Shell-Check 13 deferred)
</HARD-GATE>

<HARD-GATE: KEIN-WIDERSPRUCH-OHNE-MARKIERUNG>
Bedingung: keine (universell)
Wenn zwei Quellen unterschiedliche Werte oder Aussagen liefern:
1. NICHT stillschweigend eine Version waehlen
2. Explizit markieren: `[WIDERSPRUCH: Quelle A sagt X, Quelle B sagt Y]`
3. Wenn moeglich: Erklaerung warum die Werte abweichen
4. Beide Quellen mit Seitenangabe zitieren
Durchsetzung: Hybrid (Shell-Check auf WIDERSPRUCH-Marker + Konsistenz-Pruefer)
</HARD-GATE>

<HARD-GATE: KEINE-WIKI-AENDERUNG-OHNE-QUELLENLESUNG>
Bedingung: keine (universell)
Jede Aenderung an einer Wiki-Seite (Neuanlage oder Update) erfordert das
Lesen der zugehoerigen Originalquelle im selben Context.

SCHREIBPFAD: Wer ins Wiki schreibt, liest die Originalquelle.
- /ingest: PDF komplett lesen (Gate 1)
- /synthese: Relevante Kapitel aus PDFs nochmal laden
- /normenupdate: Neue Norm-Ausgabe lesen

LESEPFAD: Beim Navigieren und Suchen wird dem Wiki vertraut.
- Fachfragen werden aus Wiki-Seiten beantwortet
- PDFs werden NICHT fuer Suchanfragen geladen

LINT-PFAD: Stichprobenartige Verifikation.
- /wiki-lint prueft zufaellige Seiten gegen Original-PDFs

Wiki-Seiten werden nie auf Basis anderer Wiki-Seiten geschrieben.
Durchsetzung: Hybrid (Prompt-Law: Skill-Phase erzwingt PDF-Lesung.
Quellen-Pruefer Part D+E verifiziert stichprobenartig gegen PDF.
Keine mechanische Pruefung ob PDF tatsaechlich geladen wurde.)
</HARD-GATE>

<HARD-GATE: KORREKTE-UMLAUTE>
Bedingung: keine (universell)
In ALLEN Ausgabedateien MUESSEN deutsche Umlaute als Unicode geschrieben werden:
ä, ö, ü, Ä, Ö, Ü, ß (Unicode U+00E4, U+00F6, U+00FC, U+00C4, U+00D6, U+00DC, U+00DF).
NIEMALS ASCII-Ersetzungen: ae statt ä, oe statt ö, ue statt ü, ss statt ß.
Beispiel PASS: "Träger", "Größe", "Übertragung", "Maßnahme"
Beispiel FAIL: "Traeger", "Groesse", "Uebertragung", "Massnahme"
Ausnahme: Dateinamen (ASCII-kompatibel, Bindestriche statt Umlaute).
Ausnahme: Plugin-interne Governance-Dateien (hard-gates.md, naming-konvention.md, etc.)
nutzen ASCII fuer Shell-Script-Kompatibilitaet. Seitentypen.md und Templates
nutzen echte Umlaute, weil sie als Referenz fuer Wiki-Output dienen.
Durchsetzung: Machine-Law (check-wiki-output.sh Check 9)
</HARD-GATE>
