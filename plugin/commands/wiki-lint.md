---
name: wiki-lint
description: "Wiki-Gesundheitscheck — Widersprueche, Verwaiste, Veraltete finden"
---

# /wiki-lint — Wiki-Datenqualitäts-Überprüfung

**Kurzbeschreibung:** Diagnostischer Skill — validiert alle Wiki-Seiten auf strukturelle Fehler, fehlende Metadaten, ungueltige Links, Vokabular-Verstoesse und Konsistenz-Verletzungen. Gibt Empfehlungen, modifiziert Wiki nicht.

**Ausloeser:**
- Nach Batch-Ingestion Qualitaetssicherung
- Regelmaessig auf Drift pruefen
- Vor Export-Operationen validieren
- Nach manuellen Edits verifizieren

**Skill:** → `skills/wiki-lint/SKILL.md`

**Aktive Gates:** 8, 9, 10 (diagnostisch)
