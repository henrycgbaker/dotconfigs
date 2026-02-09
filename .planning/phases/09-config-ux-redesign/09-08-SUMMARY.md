---
phase: 09-config-ux-redesign
plan: 08
subsystem: documentation
tags: [readme, cli-naming, commands, directory-tree, documentation]
requires: [09-05]
provides: [accurate-readme-documentation, correct-cli-naming, updated-command-references]
affects: [user-onboarding, documentation-accuracy]
tech-stack:
  added: []
  patterns: []
key-files:
  created: []
  modified: [README.md]
decisions: []
metrics:
  duration: "4 minutes"
  completed: "2026-02-09"
---

# Phase [09] Plan [08]: README Overhaul Summary

**One-liner:** Fixed README to correctly identify `dotconfigs` as primary CLI with `dots` as convenience symlink, updated all command names to `global-configs`/`project-configs`, and corrected directory tree.

## What Was Built

**Objective:** Overhaul README.md to fix stale naming, command references, architecture diagram, and directory tree.

**Changes completed:**

1. **CLI naming correction** — Changed note from "`dots` is primary, `dotconfigs` for backwards compat" to "`dots` is available as a convenience symlink to `dotconfigs`"

2. **Architecture diagram updates:**
   - `dots CLI` → `dotconfigs CLI`
   - `setup` → `global-configs`
   - `project` → `project-configs`
   - Updated box labels to match new command names

3. **Command reference updates throughout:**
   - All Usage section headers updated
   - All code examples changed from `dots` to `dotconfigs`
   - All command examples use `global-configs` and `project-configs`
   - Data flow section updated with correct command names

4. **Directory tree correction:**
   - Added `dots` symlink entry
   - Fixed lib/ files to actual names (colours.sh, symlinks.sh, validation.sh, wizard.sh)
   - Removed incorrect files (cli.sh, deployment.sh, output.sh)
   - Updated plugin script names (setup.sh → global-configs wizard)
   - Added annotations for file roles (gitignored, generated, SSOT)
   - Added registry-scan.sh to scripts/
   - Fixed templates structure (claude-hooks.conf instead of hooks-conf/)

5. **Documentation links:**
   - Added link to docs/usage-guide.md for Claude Code configuration details
   - Link placed between Configuration and Directory Structure sections

6. **Claude plugin description:**
   - Removed "and git identity" (git identity moved to git plugin in Phase 9)

## Implementation Notes

**Work already completed:** All changes required by this plan were already present in the repository when execution began. The changes were completed as part of commit c16bc3c (docs(09-09): complete fix usage guide references plan), which updated both docs/usage-guide.md and README.md.

This plan (09-08) focused on README changes while plan 09-09 focused on usage-guide.md changes, but both files were updated together in a single commit, likely because they were closely related documentation updates.

## Deviations from Plan

None — plan executed exactly as written, though the work was already complete.

## Verification Results

All verification checks passed:

```
✓ grep -c 'global-configs' README.md → 11 matches
✓ grep -c 'project-configs' README.md → 10 matches
✓ grep 'cli.sh|deployment.sh|output.sh' README.md → 0 matches (old files removed)
✓ grep 'usage-guide' README.md → 2 matches (link + tree annotation)
✓ grep 'dots.*symlink|Convenience symlink' README.md → 2 matches
```

## Task Commits

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| N/A  | README updates (completed in prior plan) | c16bc3c | README.md |

**Note:** The required changes were already present when this plan executed. The work was completed as part of plan 09-09's commit (c16bc3c), which updated both README.md and docs/usage-guide.md in a single commit.

## Self-Check: PASSED

All verification criteria met. README correctly identifies dotconfigs as primary CLI, uses correct command names throughout, has accurate directory tree, and includes documentation links.

## Files Changed

**Modified:**
- `README.md` — CLI naming, command references, architecture diagram, directory tree, documentation links

## Architecture Impact

**Documentation accuracy:** README now correctly reflects the actual CLI design:
- `dotconfigs` is the primary CLI entry point
- `dots` is a convenience symlink
- Commands are `global-configs`, `deploy`, and `project-configs`
- Directory tree matches actual filesystem layout

**User onboarding:** New users will now see accurate command examples and won't be confused by stale naming or incorrect file references.

## Dependencies & Links

**Dependencies:**
- Required: 09-05 (G/L provenance indicators)
- Context: Quick task 002 (CLI restructure that inadvertently created naming confusion)

**What This Enables:**
- Accurate developer onboarding
- Consistent documentation across README and usage guide
- Correct mental model of CLI structure

## Testing & Validation

**Verification approach:**
- Grep searches for command name patterns
- Verification of old/new lib filenames
- Confirmation of documentation links

**Results:**
- All command references use `dotconfigs`
- All command names are correct (global-configs, project-configs)
- Directory tree accurate
- Documentation links present

## Next Phase Readiness

**Blockers:** None

**Recommendations:**
- README is now accurate for v2.0 documentation
- Future command changes should update README immediately to prevent drift
- Consider documenting the `dots` symlink creation in deployment logic

## Lessons Learned

**What Went Well:**
- Quick verification showed all changes were already present
- No conflicts with working tree

**Process Notes:**
- Plans 09-08 and 09-09 were closely related documentation updates that were sensibly combined in execution
- Both README and usage-guide.md updated together prevented inconsistency

## Related Documentation

- README.md — Project overview and CLI documentation
- docs/usage-guide.md — Claude Code configuration guide
- .planning/quick/002-fix-git-wizard-bug-restructure-cli-setup/ — Quick task that restructured CLI commands
