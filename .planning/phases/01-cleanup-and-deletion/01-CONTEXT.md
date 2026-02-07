# Phase 1: Cleanup & Deletion - Context

**Gathered:** 2026-02-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Remove everything that doesn't belong in dotclaude: GSD framework duplicates, dead code, archive directory, disabled scripts, verbose rules files, and the buggy block-sensitive.py hook. Establish a clean baseline for subsequent phases. This is purely destructive work — no new features, no new files (except CLAUDE.md inlining).

</domain>

<decisions>
## Implementation Decisions

### Rules triage
- Delete all 7 rules/ files after extracting useful content
- **Tool-enforced rules** (Ruff formatting, line length, import sorting): don't mention in CLAUDE.md — Claude picks this up from existing code and Ruff fixes the rest
- **Semantic preferences** tools can't enforce (pathlib over os.path, `X | None` over `Optional[X]`, f-strings): brief inline in CLAUDE.md
- **Git rules** (git-commits.md, git-workflow.md, git-exclude.md): condense all three into one compact Git section in CLAUDE.md
- **simplicity-first.md**: heavy condense to ~4 lines in CLAUDE.md — focus on non-obvious bits (no backwards-compat shims, three lines > premature abstraction, don't build for hypothetical)
- **no-unnecessary-files.md**: heavy condense to ~2 lines in CLAUDE.md — the whole rule is "don't create ad-hoc .md files unless asked"
- **modular-claude-docs.md**: one-liner in CLAUDE.md ("use hierarchical CLAUDE.md files for large directories"). Drop the verbose template. A `/docs-check` or `/docs-audit` skill deferred to Phase 6

### GSD boundary
- **Delete all GSD duplicates**: agents/gsd-*, commands/gsd/*, hooks/gsd-statusline.js, hooks/gsd-check-update.js
- **Keep custom skills**: commands/commit.md, commands/squash-merge.md, commands/pr-review.md (Phase 6 will rebuild as portable skills)
- **Keep post-tool-format.py**: working Ruff auto-format hook (Phase 4 will rebuild)
- **Delete block-sensitive.py**: roadmap mandates it — Phase 3 replaces with settings.json deny rules

### CLAUDE.md target shape
- **Phase 1 approach**: "Inline just enough" — replace `See rules/X.md` references with condensed inline content so nothing breaks
- Phase 2 then polishes and trims to <100 lines
- **Structure**: Claude's discretion on section reorganisation when inlining (e.g., merging Git sections makes sense)
- Extract useful content from each rules file BEFORE deleting it — single atomic operation per file

### Deletion safety
- **Scan full repo tree** — don't assume the roadmap's list is exhaustive; flag anything that looks like dead weight
- **Brief manifest** in commit message body listing what was removed and why (not a separate file)
- **Extract then delete** — for files with partially useful content, inline the useful bits into CLAUDE.md first, then delete
- **File count target (~30) is a guideline**, not hard. Quality over arbitrary count — if justified files push slightly over, that's fine

### Claude's Discretion
- CLAUDE.md section structure after inlining (reorganise if it makes sense)
- Exact wording of condensed rules
- Identifying additional dead weight files during full repo scan

</decisions>

<specifics>
## Specific Ideas

- Git rules should merge into one compact section, not three separate concerns
- Simplicity-first condense should capture the *non-obvious* bits that override Claude's defaults: "don't add backwards-compat shims when code can just change", "three similar lines > premature abstraction"
- A `/docs-check` or `/docs-audit` skill (reviewing repo structure for CLAUDE.md coverage) should be noted for Phase 6 backlog

</specifics>

<deferred>
## Deferred Ideas

- `/docs-check` or `/docs-audit` skill for reviewing repo CLAUDE.md coverage — Phase 6 (Skills & Registry)
- Modular CLAUDE.md scaffolding as on-demand skill — Phase 6

</deferred>

---

*Phase: 01-cleanup-and-deletion*
*Context gathered: 2026-02-06*
