---
phase: 08-hooks-workflows-review
plan: 06
subsystem: documentation
tags: [roster, automation, metadata, readme, gsd]
requires: [08-01, 08-02, 08-03, 08-04, 08-05]
provides:
  - "Auto-generated ROSTER.md reference documentation"
  - "README GSD framework mention and roster link"
  - "Configuration hierarchy documentation"
affects: []
tech-stack:
  added: []
  patterns: [metadata-driven-documentation]
key-files:
  created:
    - scripts/generate-roster.sh
    - docs/ROSTER.md
  modified:
    - plugins/claude/hooks/post-tool-format.py
    - README.md
decisions:
  - id: DOC-01
    title: Metadata-driven roster generation
    choice: Parse METADATA blocks from hook files to auto-generate documentation
    rationale: Ensures roster stays in sync with actual hook implementations
    alternatives: Manual roster maintenance
    implications: Hooks require METADATA header blocks for roster inclusion
metrics:
  duration: 3min 19s
  completed: 2026-02-08
---

# Phase 08 Plan 06: Roster Generation & README Updates Summary

Auto-generated roster documentation from hook metadata headers and updated README with GSD framework mention.

**One-liner:** Metadata-driven roster generation script with comprehensive hook/command reference and README config hierarchy docs.

## What Was Built

### Roster Generation System
- Created `scripts/generate-roster.sh` to auto-generate `docs/ROSTER.md` from hook metadata
- Parses METADATA blocks from all hook files (bash `# ===` and Python `# ===` comments)
- Extracts command descriptions from YAML frontmatter in `.md` files
- Generates comprehensive tables: git hooks (7), claude hooks (2), commands (4)
- Includes complete configuration reference from `lib/config.sh` documentation
- Documents configuration hierarchy, file locations, and plugin ownership

### Metadata Headers
- Added METADATA header to `post-tool-format.py` following established pattern
- Standardised format across all hooks for consistent parsing

### README Enhancements
- Added GSD Framework section (2-3 lines) with link to GSD repository
- Expanded git plugin hook list from summary to full 7-hook roster with descriptions
- Created Configuration Hierarchy section with three-tier table
- Documented when to use each tier (hardcoded defaults, global .env, project config)
- Documented plugin config ownership (git-hooks.conf vs claude-hooks.conf)
- Added git hook config discovery path documentation
- Added roster link in configuration section
- Updated directory structure to reflect new scripts/ and docs/ directories

## Task Commits

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Create roster generation script and ROSTER.md | f85fc19 | scripts/generate-roster.sh, docs/ROSTER.md, plugins/claude/hooks/post-tool-format.py |
| 2 | Update README with GSD mention, roster link, config hierarchy | 6cba1fe | README.md |

## Verification Results

✅ All verification criteria passed:

1. **Roster generation works end-to-end**
   - `bash scripts/generate-roster.sh` runs without errors
   - `docs/ROSTER.md` generated successfully

2. **ROSTER.md is comprehensive**
   - Git hooks table: 7 hooks listed (commit-msg, pre-commit, pre-push, prepare-commit-msg, post-merge, post-checkout, post-rewrite)
   - Claude hooks table: 2 hooks listed (block-destructive, post-tool-format)
   - Commands table: 4 commands listed (/commit, /pr-review, /simplicity-check, /squash-merge)
   - Configuration reference: 23 GIT_HOOK_* variables + 3 CLAUDE_HOOK_* variables
   - Config hierarchy summary included
   - File locations and plugin ownership documented

3. **README enhancements complete**
   - GSD framework section added with description and link
   - Configuration hierarchy section with three-tier table
   - Roster link present in configuration section
   - Full git hook list (7 hooks with descriptions)

4. **Idempotent generation**
   - Running `generate-roster.sh` twice produces identical output (except timestamp)
   - Safe to re-run when hooks are added

## Decisions Made

**DOC-01: Metadata-driven roster generation**
- **Decision:** Parse METADATA blocks from hook files to auto-generate documentation
- **Rationale:** Single source of truth — hook metadata lives with implementation code, roster auto-syncs
- **Implication:** All hooks require METADATA header blocks for roster inclusion
- **Benefit:** Zero-maintenance documentation, impossible for roster to drift out of sync

## Deviations from Plan

None — plan executed exactly as written.

## Technical Notes

### Roster Generation Script Architecture

**Parsing strategy:**
- Find all files in `plugins/*/hooks/` and `plugins/*/commands/`
- Extract METADATA blocks using grep/sed (works for both bash `#` and python `#` comments)
- Parse YAML frontmatter from command `.md` files using awk

**Output structure:**
1. Auto-generation notice (don't edit manually)
2. Git Hooks table (name, description, config keys)
3. Claude Hooks table (name, description, config keys)
4. Commands table (command name, description)
5. Configuration Reference (three-tier hierarchy explanation + variable tables)
6. Config file locations and plugin ownership
7. Generation timestamp

**Bash 3.2 compatibility:**
- No associative arrays used
- Standard grep/sed/awk for parsing
- Simple while loops over find output

### README Configuration Hierarchy

**Three tiers documented:**
1. **Hardcoded defaults** — Built into hook code, sensible defaults for all users
2. **Global .env** — Personal preferences via setup wizard, applies across all projects
3. **Project config files** — Per-repository overrides deployed by `dotconfigs project`

**Precedence clearly stated:** Project config > Global .env > Hardcoded defaults

**Discovery paths documented:**
- Git hooks: 4 paths (`.githooks/config`, `.claude/git-hooks.conf`, `.git/hooks/hooks.conf`, `.claude/hooks.conf`)
- Claude hooks: 2 paths (`.claude/claude-hooks.conf`, `~/.claude/claude-hooks.conf`)

## Integration Notes

### For Future Hook Additions

When adding new hooks:
1. Include METADATA header in hook file:
   ```bash
   # === METADATA ===
   # NAME: hook-name
   # TYPE: git-hook | claude-hook
   # PLUGIN: git | claude
   # DESCRIPTION: One-line description
   # CONFIGURABLE: VAR_NAME_1, VAR_NAME_2
   # ================
   ```
2. Document config variables in `lib/config.sh` (comment format: `# VAR_NAME=default Description`)
3. Run `scripts/generate-roster.sh` to regenerate roster
4. ROSTER.md automatically includes new hook

### For Future Commands

When adding new commands:
1. Include YAML frontmatter in `.md` file:
   ```yaml
   ---
   description: One-line description
   allowed-tools: Bash, Read
   ---
   ```
2. Run `scripts/generate-roster.sh` to regenerate roster

## Next Phase Readiness

**Blockers:** None

**Phase 8 Status:** COMPLETE (6/6 plans)
- 08-01: Unified hook config architecture ✅
- 08-02: Hook audit and fixes ✅
- 08-03: New git hooks (pre-commit, prepare-commit-msg, post-*) ✅
- 08-04: PreToolUse hook for destructive command blocking ✅
- 08-05: CLI integration (wizards, deployment, config files) ✅
- 08-06: Roster generation and README updates ✅

**Phase 8 Deliverables:**
- Unified hook configuration (GIT_HOOK_*, CLAUDE_HOOK_*)
- 7 git hooks with per-hook configuration
- 2 claude hooks (destructive guard, ruff formatting)
- Project wizards deploy config files (git-hooks.conf, claude-hooks.conf)
- Complete hook/command/config reference (ROSTER.md)
- Auto-generated documentation pipeline

**Next Steps:**
- Phase 8 is complete — no further plans
- dotconfigs v2.0 is feature-complete
- Ready for production use

## Self-Check: PASSED

✅ All created files exist:
- scripts/generate-roster.sh
- docs/ROSTER.md

✅ All commits exist:
- f85fc19 (task 1)
- 6cba1fe (task 2)
