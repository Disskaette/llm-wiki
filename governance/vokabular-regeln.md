# Vokabular-Regeln — Kontrolliertes Fachvokabular

## Zweck

Das kontrollierte Vokabular (`wiki/_vokabular.md`) ist das Rueckgrat der
Querschnittsuche. Es stellt sicher, dass dasselbe Konzept in allen 455+
Buechern unter demselben Begriff gefunden wird — nicht einmal als
"Querkrafttragfaehigkeit", einmal als "Schubbemessung", einmal als
"Shear resistance".

## Regeln

1. Jeder Term hat genau EINE bevorzugte Bezeichnung (deutsch).
2. Synonyme (auch englische) werden als Verweise gefuehrt.
3. Neue Terme werden NUR ueber /vokabular angelegt.
4. Ad-hoc-Einfuegen in Frontmatter ist verboten (Hard Gate 6).
5. Jeder Term hat: bevorzugte Bezeichnung, Synonyme, Oberbegriff, verwandte Terme.
6. Hierarchie maximal 3 Ebenen tief (sonst unwartbar).

## Format in _vokabular.md

```markdown
### Aufhaengebewehrung
- Synonyme: Querkraftaufhaengung, indirect support reinforcement, hanging reinforcement
- Oberbegriff: [[bewehrung]]
- Verwandte: [[indirekte-lagerung]], [[querkraft]], [[ec2-9-2-5]]
- Angelegt: 2026-04-09
```

## Wann wird ein neuer Term angelegt?

- Beim Ingest: Das LLM identifiziert Fachbegriffe die noch nicht im Vokabular sind
- Es sammelt diese in einer Liste und ruft /vokabular auf
- /vokabular prueft: Ist das wirklich ein neuer Term oder ein Synonym fuer einen bestehenden?
- Nur genuein neue Konzepte werden als neuer Term angelegt
- Alles andere wird als Synonym zum bestehenden Term hinzugefuegt

## Kategorien (Oberbegriffe erster Ebene)

- Holzbau
- Stahlbeton
- Verbundbau
- Bauphysik
- Brandschutz
- Geotechnik
- Stahlbau
- Tragwerksplanung
- Baustoffe
- Normenwesen
- Pruefverfahren
- Mathematik-Mechanik

## Qualitaetskontrolle

Der Vokabular-Pruefer (Agent) prueft bei jedem Ingest:
1. Alle Schlagworte im Frontmatter existieren im Vokabular
2. Keine Synonyme statt bevorzugter Terme verwendet
3. Oberbegriff-Zuordnung konsistent
4. Keine Duplikate (gleicher Term unter verschiedenen Schreibweisen)
