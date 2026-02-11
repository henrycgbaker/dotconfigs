---
phase: 004-fix-uat-deploy-provenance-project-wizard
plan: 01
subsystem: deployment
type: gap-closure
completed: 2026-02-09
duration: 2min

requires:
  - lib/symlinks.sh backup_and_link function
  - plugins/claude/deploy.sh deployment logic
provides:
  - Source file provenance in all deploy output messages
  - Relative source paths in backup_and_link output
affects:
  - User experience during deploy operations
  - Deploy dry-run transparency

tech-stack:
  added: []
  patterns:
    - Relative path computation via parameter substitution

key-files:
  created: []
  modified:
    - lib/symlinks.sh
    - plugins/claude/deploy.sh

decisions: []

tags: [deployment, ux, output, provenance, gap-closure]
---

# Phase [004] Plan [01]: Deploy Source Provenance Summary

**One-liner:** Added source file path provenance to all deploy output messages using relative path display.

## Purpose

Closed UAT test 12 gap: Deploy output previously only showed target paths (e.g. "Unchanged: settings.json") without showing SSOT source paths. Users needed to see where files originate (e.g. "plugins/claude/templates/settings.json -> ~/.claude/settings.json") for transparency and debugging.

## What Was Built

### 1. Enhanced backup_and_link() Output

Updated `lib/symlinks.sh` `backup_and_link()` function to compute and display relative source paths:

- Added `rel_src` computation using `${src#$dotconfigs_root/}` parameter substitution
- Updated all status messages: Linked, Updated, Overwrote, Backed up
- Enhanced conflict prompts to show both source and target paths
- Format: `source -> destination` for all operations

### 2. Enhanced Deploy Messages

Updated `plugins/claude/deploy.sh` to show source provenance in all deployment status messages:

**Settings.json section:**
- Compute `rel_settings` from `$DOTCONFIGS_ROOT`
- Updated Unchanged/Would link/Would overwrite/Would prompt messages

**CLAUDE.md section:**
- Compute `rel_claude_md` from `$DOTCONFIGS_ROOT`
- Updated all status messages similarly

**Hooks section:**
- Compute `rel_hook` for each hook in loop
- Updated all status messages

**Skills section:**
- Compute `rel_skill` for each skill in loop
- Updated all status messages

All messages now follow consistent `source -> target` format for both dry-run and real deployment.

## Task Commits

| # | Task | Commit | Files Modified |
|---|------|--------|----------------|
| 1 | Update backup_and_link() to show source -> dest mapping | 4b0d741 | lib/symlinks.sh |
| 2 | Add source provenance to deploy.sh echo statements | a461bbc | plugins/claude/deploy.sh |

## Verification

Confirmed all success criteria:

1. ✅ `./dotconfigs deploy --dry-run` output shows source paths for every listed file
2. ✅ No regression: deploy still counts created/updated/skipped/unchanged correctly
3. ✅ Source paths are relative to dotconfigs root (not absolute) for readability
4. ✅ Dry-run and real deploy output are consistent

Example output:
```
Unchanged: plugins/claude/settings.json -> /Users/henrybaker/.claude/settings.json
Unchanged: plugins/claude/CLAUDE.md -> /Users/henrybaker/.claude/CLAUDE.md
Unchanged: plugins/claude/hooks/block-destructive.sh -> /Users/henrybaker/.claude/hooks/block-destructive.sh
```

## Deviations from Plan

None - plan executed exactly as written.

## Decisions Made

None - implementation followed straightforward parameter substitution pattern.

## Next Phase Readiness

**Blockers:** None

**Concerns:** None

**Dependencies satisfied:**
- UAT test 12 gap (deploy source provenance) is now closed
- Plan 004-02 (project wizard UX improvements) can proceed independently

## Self-Check: PASSED

All created files: (none - modified existing files only)
All commits verified:
- 4b0d741: ✓ Found in git log
- a461bbc: ✓ Found in git log
