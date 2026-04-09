# LLM-Wiki — Entwickler-Kontext

## Was ist das?

Eigenstaendiges Claude-Code-Plugin das Fachbuecher in ein strukturiertes,
Obsidian-kompatibles Wiki einliest. Arbeitet ausschliesslich in `wiki/`
des Projekts wo es installiert ist. Keine externen Abhaengigkeiten.

## Architektur-Prinzipien

- **Eigenstaendigkeit:** Kennt keine anderen Plugins, schreibt nichts ausserhalb wiki/
- **Token-Last ist gewollt:** 1M Context-Fenster, Qualitaet vor Sparsamkeit
- **Obsidian als Frontend:** Wikilinks, YAML-Frontmatter, Graph View, Dataview
- **Deutsche Rechtschreibung:** Nomen gross in Schlagworten und Wiki-Text.
  Dateinamen lowercase ASCII. Governance-Dateien ASCII (Shell-Kompatibilitaet).

## Enforcement — 3 Schichten

1. **Prompt-Law** — Skill-Anweisungen, Hard Gates im Session-Context
2. **Subagent-Review** — 4 Pruefer + 2 Reviewer + 1 Validator (unabhaengige Instanzen)
3. **Machine-Law** — PostToolUse-Hook + check-wiki-output.sh (mechanisch)

Gate 1 (vollstaendige Lesung) und Gate 9 (Quellenlesung) sind HYBRID —
ehrlich klassifiziert weil keine mechanische Verifikation moeglich.

## Entwicklung

Nach jeder Aenderung IMMER:
```bash
bash hooks/check-consistency.sh .    # 12/12 PASS?
diff <(sed -n '/<!-- BEGIN HARD-GATES -->/,/<!-- END HARD-GATES -->/p' skills/using-bibliothek/SKILL.md | sed '1d;$d') governance/hard-gates.md   # Sync?
```

## Bekannte Patterns (aus 5 Review-Runden)

- `((PASS++))` crasht bei `set -e` wenn Counter=0 → immer `$((PASS + 1))`
- macOS awk hat kein `/i` Flag → `tolower()` verwenden
- `|| true` nach Subshell killt Exit-Code → `set +e` / `set -e` Wrapper
- `grep -c` gibt Exit 1 bei 0 Matches → `|| VAR=0`
- Inline-Kopie von hard-gates.md in using-bibliothek MUSS synchron bleiben
- Dokumentation und Implementation driften schnell auseinander → check-consistency.sh
