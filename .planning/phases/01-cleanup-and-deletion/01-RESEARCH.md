# Phase 1: Cleanup & Deletion - Research

**Researched:** 2026-02-06
**Domain:** Repository cleanup, file deletion, content condensation
**Confidence:** HIGH

## Summary

Phase 1 is purely destructive work — remove everything that doesn't belong in dotclaude. The repository currently contains 109 files (94 non-.git). The goal is to reduce to under 30 files by deleting GSD framework duplicates (11 agents, 28 commands, 2 GSD hooks), dead code (_archive/ directory with 7 archived agents, sync-project-agents.sh, backup files), and verbose rules files (7 files totalling ~450 lines). The rules/ directory triage requires extracting useful content before deletion: tool-enforced rules should be dropped entirely (Ruff handles them), semantic preferences should be condensed inline, and git/simplicity/docs rules should be heavily condensed. The buggy block-sensitive.py hook must be deleted (will be replaced by settings.json deny rules in Phase 3).

**Primary recommendation:** Delete in three waves (GSD duplicates, dead code, rules extraction+deletion). Extract useful rules content into CLAUDE.md before deleting each rules file. Single atomic commit with manifest of deletions in commit message body.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Rules triage:**
- Delete all 7 rules/ files after extracting useful content
- **Tool-enforced rules** (Ruff formatting, line length, import sorting): don't mention in CLAUDE.md — Claude picks this up from existing code and Ruff fixes the rest
- **Semantic preferences** tools can't enforce (pathlib over os.path, `X | None` over `Optional[X]`, f-strings): brief inline in CLAUDE.md
- **Git rules** (git-commits.md, git-workflow.md, git-exclude.md): condense all three into one compact Git section in CLAUDE.md
- **simplicity-first.md**: heavy condense to ~4 lines in CLAUDE.md — focus on non-obvious bits (no backwards-compat shims, three lines > premature abstraction, don't build for hypothetical)
- **no-unnecessary-files.md**: heavy condense to ~2 lines in CLAUDE.md — the whole rule is "don't create ad-hoc .md files unless asked"
- **modular-claude-docs.md**: one-liner in CLAUDE.md ("use hierarchical CLAUDE.md files for large directories"). Drop the verbose template. A `/docs-check` or `/docs-audit` skill deferred to Phase 6

**GSD boundary:**
- **Delete all GSD duplicates**: agents/gsd-*, commands/gsd/*, hooks/gsd-statusline.js, hooks/gsd-check-update.js
- **Keep custom skills**: commands/commit.md, commands/squash-merge.md, commands/pr-review.md (Phase 6 will rebuild as portable skills)
- **Keep post-tool-format.py**: working Ruff auto-format hook (Phase 4 will rebuild)
- **Delete block-sensitive.py**: roadmap mandates it — Phase 3 replaces with settings.json deny rules

**CLAUDE.md target shape:**
- **Phase 1 approach**: "Inline just enough" — replace `See rules/X.md` references with condensed inline content so nothing breaks
- Phase 2 then polishes and trims to <100 lines
- **Structure**: Claude's discretion on section reorganisation when inlining (e.g., merging Git sections makes sense)
- Extract useful content from each rules file BEFORE deleting it — single atomic operation per file

**Deletion safety:**
- **Scan full repo tree** — don't assume the roadmap's list is exhaustive; flag anything that looks like dead weight
- **Brief manifest** in commit message body listing what was removed and why (not a separate file)
- **Extract then delete** — for files with partially useful content, inline the useful bits into CLAUDE.md first, then delete
- **File count target (~30) is a guideline**, not hard. Quality over arbitrary count — if justified files push slightly over, that's fine

### Claude's Discretion

- CLAUDE.md section structure after inlining (reorganise if it makes sense)
- Exact wording of condensed rules
- Identifying additional dead weight files during full repo scan

### Deferred Ideas (OUT OF SCOPE)

- `/docs-check` or `/docs-audit` skill for reviewing repo structure for CLAUDE.md coverage — Phase 6 (Skills & Registry)
- Modular CLAUDE.md scaffolding as on-demand skill — Phase 6
</user_constraints>

## Standard Stack

**No external libraries required** — this is pure file deletion and content condensation.

### Tools Used
| Tool | Purpose |
|------|---------|
| Read | Extract useful content from rules files before deletion |
| Edit | Inline condensed rules into CLAUDE.md |
| Bash (rm, find) | Delete files and directories |
| Grep/Glob | Scan for additional dead weight files |

## Architecture Patterns

### Deletion Order

**Wave 1: GSD Framework Duplicates**
- agents/gsd-* (11 agents)
- commands/gsd/* (28 commands)
- hooks/gsd-statusline.js
- hooks/gsd-check-update.js

**Wave 2: Dead Code**
- _archive/ directory (7 archived agents)
- sync-project-agents.sh (disabled project sync script)
- commands/gsd/new-project.md.bak (backup file)
- .DS_Store (macOS artefact)

**Wave 3: Rules Extraction + Deletion**
For each rules file:
1. Read current content
2. Extract useful bits (per locked decisions)
3. Inline condensed content into CLAUDE.md
4. Delete rules file
5. Verify no dangling references remain

### CLAUDE.md Condensation Strategy

**Current state:** 50 lines (already lean, but rules references need inlining)

**What to inline (per locked decisions):**

1. **simplicity-first.md (80 lines → ~4 lines)**
   - Non-obvious bits only:
     - "Don't add backwards-compatibility shims when code can just change"
     - "Three similar lines > premature abstraction"
     - "Don't build for hypothetical future requirements"
   - Drop: verbose examples, anti-patterns list (Claude knows these)

2. **no-unnecessary-files.md (20 lines → ~2 lines)**
   - Core rule: "Don't create ad-hoc .md files (NOTES.md, WORK_PLAN.md, etc.) unless asked"
   - Drop: always OK / avoid lists (obvious from rule)

3. **modular-claude-docs.md (75 lines → ~1 line)**
   - "Use hierarchical CLAUDE.md files for large directories"
   - Drop: templates, structure examples, when-to-use guidance

4. **git-commits.md + git-workflow.md + git-exclude.md (merged → ~15 lines)**
   - Conventional commits format (feat/fix/docs/refactor)
   - Feature branch + squash merge workflow
   - Use .git/info/exclude for CLAUDE.md (not .gitignore)
   - Drop: verbose examples, PR best practices, safety guardrails (Claude knows these)

5. **python-standards.md (48 lines → ~5 lines)**
   - Semantic preferences: pathlib over os.path, `X | None` over `Optional[X]`, f-strings
   - "Ruff auto-formats via hook" (brief mention)
   - Drop: formatting details (Ruff enforces), docstring style, imports (tools enforce)

**Total CLAUDE.md after Phase 1:** ~75 lines (50 current + ~25 inlined)
Phase 2 will trim to <100 lines target.

### File Count Breakdown

**Current:** 109 files total

**To delete:**
- GSD agents: 11
- GSD commands: 28
- GSD hooks: 2
- Archive: 7 agents
- Dead scripts: 1 (sync-project-agents.sh)
- Rules files: 7
- Backup/temp: 2 (.DS_Store, .bak file)

**Total deletions:** 58 files

**Remaining:** ~51 files (well under 30-file guideline violation)

**Analysis:** The 30-file target appears to assume additional deletions beyond what's specified. Scan for:
- Redundant documentation (docs/usage-guide.md is 750 lines — out of scope per requirements)
- Project agents (kept per user decision — are source of truth)
- Planning docs (.planning/* — kept for project context)

**Recommendation:** Delete the 58 specified files. Flag docs/usage-guide.md as potential Phase 2 candidate (overlaps with README). Do not delete project agents or planning docs.

## Don't Hand-Roll

Not applicable — this is deletion work, no new implementations.

## Common Pitfalls

### Pitfall 1: Deleting Files Before Extracting Content
**What goes wrong:** Rules files contain useful content that's referenced elsewhere. Deleting without extraction breaks references.
**Why it happens:** Temptation to batch-delete all rules files at once.
**How to avoid:** Process each rules file atomically — read, extract, inline, delete, verify.
**Warning signs:** Dangling references like "See rules/X.md" remain in CLAUDE.md.

### Pitfall 2: Over-Inlining Rules Content
**What goes wrong:** Trying to preserve too much rules content bloats CLAUDE.md beyond Phase 2's <100 line target.
**Why it happens:** Uncertainty about what Claude can infer vs. needs explicit instruction.
**How to avoid:** Follow locked decision guidance — tool-enforced rules are dropped entirely, semantic preferences are brief one-liners.
**Warning signs:** Condensed rules exceed line budgets (simplicity-first >4 lines, python-standards >5 lines).

### Pitfall 3: Assuming Roadmap List is Exhaustive
**What goes wrong:** Additional dead weight files remain because they weren't explicitly listed.
**Why it happens:** Roadmap was written without full repo scan.
**How to avoid:** Full recursive scan for backup files, temp files, disabled scripts, commented code blocks.
**Warning signs:** File count remains >50 after deletions.

### Pitfall 4: Breaking settings.json by Deleting block-sensitive.py
**What goes wrong:** settings.json references block-sensitive.py in PreToolUse hooks. Deleting the script without updating settings.json breaks hook execution.
**Why it happens:** Overlooking the settings.json reference.
**How to avoid:** Remove block-sensitive.py reference from settings.json PreToolUse hooks section BEFORE deleting the script.
**Warning signs:** Claude Code logs hook execution errors after deletion.

### Pitfall 5: Deleting .git/info/exclude Patterns
**What goes wrong:** Project CLAUDE.md files become tracked if .git/info/exclude is deleted.
**Why it happens:** Overzealous cleanup.
**How to avoid:** .git/info/exclude is git configuration, not dotclaude content — never delete.
**Warning signs:** git status shows CLAUDE.md as untracked in projects.

## Code Examples

### Rules Extraction Pattern

```bash
# Read rules file
Read(file_path="/Users/henrybaker/Repositories/dotclaude/rules/simplicity-first.md")

# Extract non-obvious bits (manual parsing)
# Focus: backwards-compat shims, premature abstraction threshold, hypotheticals

# Inline into CLAUDE.md
Edit(
  file_path="/Users/henrybaker/Repositories/dotclaude/CLAUDE.md",
  old_string="## Simplicity First (Occam's Razor)\n...",
  new_string="## Simplicity First\n- Don't add backwards-compatibility shims when code can just change\n- Three similar lines > premature abstraction (only generalize at 3+ implementations)\n- Don't build for hypothetical future requirements\n- Minimum viable solution — solve only what was asked"
)

# Delete rules file
Bash(command="rm /Users/henrybaker/Repositories/dotclaude/rules/simplicity-first.md")
```

### settings.json Hook Update

```bash
# Remove block-sensitive.py reference BEFORE deleting the script
Edit(
  file_path="/Users/henrybaker/Repositories/dotclaude/settings.json",
  old_string='"PreToolUse": [\n      {\n        "matcher": "Read|Write|Edit",\n        "hooks": [\n          {\n            "type": "command",\n            "command": "python ~/.claude/hooks/block-sensitive.py"\n          }\n        ]\n      }\n    ]',
  new_string='"PreToolUse": []'
)

# Now safe to delete
Bash(command="rm /Users/henrybaker/Repositories/dotclaude/hooks/block-sensitive.py")
```

## State of the Art

Not applicable — deletion work has no evolving standards.

## Open Questions

1. **docs/usage-guide.md status**
   - What we know: 750-line usage guide exists, requirements mark it as "overkill"
   - What's unclear: Should it be deleted in Phase 1 or trimmed in Phase 2?
   - Recommendation: Flag for Phase 2 (context optimisation) — it overlaps with README but may have useful content to extract

2. **project-agents/ directory**
   - What we know: 3 projects with custom agents (ds01-infra, llm-efficiency-measurement-tool, deep_learning_lab_teaching_2025)
   - What's unclear: User decision says "source of truth", but are these still active projects?
   - Recommendation: Keep per user decision. Phase 6 will build project registry for scanning.

3. **Reference to commands/pr-review.md**
   - What we know: Locked decisions say "keep commands/pr-review.md", requirements say "/pr-review skill not needed"
   - What's unclear: Conflicting guidance
   - Recommendation: Keep in Phase 1 (follow locked decision), flag contradiction for user clarification

## Repository Scan Findings

**Additional files to consider:**

1. **docs/usage-guide.md** — 750 lines, marked "overkill" in requirements
2. **references.md** — Unknown content, potential dead weight
3. **TODO.md** — May contain stale TODOs if .planning/ docs supersede it
4. **.vscode/settings.json** — Editor-specific config, consider excluding via .git/info/exclude

**Recommendation:** Scan these in planning. Phase 1 deletes the 58 specified files. Phase 2 audits documentation for overlap/staleness.

## Sources

### Primary (HIGH confidence)
- Direct repository inspection via Read/Bash/Glob tools
- CONTEXT.md locked decisions (user-provided constraints)
- ROADMAP.md Phase 1 success criteria
- REQUIREMENTS.md CTXT-02, SETT-05

### Secondary (MEDIUM confidence)
- File count analysis (109 files - 58 deletions = 51 remaining, vs 30-file target)
- docs/usage-guide.md overlap with README (inference from "overkill" label)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - no libraries needed, pure deletion
- Architecture: HIGH - deletion order and extraction pattern verified from repo state
- Pitfalls: HIGH - drawn from locked decisions and common cleanup mistakes

**Research date:** 2026-02-06
**Valid until:** 90 days (cleanup approach doesn't change, but repo state evolves)
