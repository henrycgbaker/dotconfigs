# Phase 2: Context Optimisation - Context

**Gathered:** 2026-02-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Reduce always-loaded configuration to the minimum so every Claude session has maximum working context. CLAUDE.md stays under 100 lines with every line justifying its existence. No new capabilities — this is purely trimming and restructuring what's already there.

</domain>

<decisions>
## Implementation Decisions

### Content audit approach
- Apply "infer over instruct" principle from research — remove anything Claude does by default
- **Simplicity First section (4 lines): keep all 4** — user confirmed these are all genuinely non-obvious (3+ threshold, no backwards-compat shims, validate at edges only, no hypotheticals)
- **Git section: keep in CLAUDE.md** including commit format — Claude needs convention even outside /commit skill. Condense where possible
- **Python Code Style: keep in global** — user mostly works in Python, fine globally
- **Documentation section: keep** the hierarchical CLAUDE.md instruction — user actively uses this pattern. Will be reinforced by a /docs-audit skill in Phase 6

### Claude's Discretion
- **Communication Style trimming** — Claude to judge which of the 6 lines are truly non-default behaviour, guided by the "infer over instruct" research principle. Some (like "brief error updates") Claude likely does naturally
- **Language section** — Claude to judge whether examples (colour, analyse, etc.) are needed or if the rule alone suffices
- **Git section condensing** — keep the convention but tighten prose where possible

### Measurement approach
- **No formal measurement** — no token counting, no live session measurement
- Success = CLAUDE.md under 100 lines + every line justifies its existence
- The original "measurably under 10%" success criterion is replaced with "keep it lean"

### Global vs project split
- **Global CLAUDE.md = pure personal preferences** — no meta-instructions about the config system, no pointers to project-level overrides
- Python preferences stay global (not project-level)
- Everything currently in CLAUDE.md stays global scope — no content moves to project-level

### Structure & format
- No preamble — dive straight into instructions
- Section ordering, header structure, and formatting density are Claude's discretion — optimise for token efficiency while remaining scannable

</decisions>

<specifics>
## Specific Ideas

- "Every line justifies its existence" — the core test for whether something stays
- Research finding to apply: "Context bloat death spiral — Large CLAUDE.md consumes context, Claude forgets rules, add more rules, worse performance"
- The /docs-audit skill (Phase 6) will handle CLAUDE.md and README.md structure review going forward

</specifics>

<deferred>
## Deferred Ideas

- `/docs-audit` skill for CLAUDE.md and README.md structure review — Phase 6
- Quarterly audit process for CLAUDE.md content — could be part of /docs-audit skill

</deferred>

---

*Phase: 02-context-optimisation*
*Context gathered: 2026-02-06*
