# Quick Task 002: Fix Git Wizard Bug + Restructure CLI Setup

**Status:** Planned (4 plans created)
**Created:** 2026-02-09
**Bundled Todos:** #2 (toggleable hooks), #4 (rename CLI to dots)

## Overview

Fixes two critical wizard bugs, renames CLI to 'dots', restructures command hierarchy, and adds opt-in config selection with new features.

## Issues Addressed

1. **Git wizard menu bug** — bash select loops 3x, doesn't accept Enter
2. **.env quoting bug** — Space-separated values not quoted, breaks sourcing
3. **CLI ergonomics** — 'dotconfigs' too long, rename to 'dots'
4. **Config hierarchy unclear** — Separate tool setup from config wizards
5. **Hook management** — Per-hook toggles instead of bulk enable/disable
6. **CLAUDE.md exclusion** — Global option to exclude from repos

## Plans

| Plan | Wave | Objective | Files | Autonomous |
|------|------|-----------|-------|------------|
| 002-01 | 1 | Fix git wizard select bug + .env quoting | plugins/git/setup.sh, lib/wizard.sh, plugins/claude/setup.sh | ✓ |
| 002-02 | 1 | Rename CLI to 'dots' (backwards compat symlink) | dots, dotconfigs, README.md, lib/symlinks.sh | ✓ |
| 002-03 | 2 | Restructure commands: setup/global-configs/project-configs | dots, lib/wizard.sh | ✓ |
| 002-04 | 3 | Opt-in config selection + toggleable hooks + CLAUDE.md exclusion | lib/wizard.sh, plugins/*/setup.sh | ✓ |

## Wave Structure

- **Wave 1** (parallel): Bug fixes + CLI rename
- **Wave 2**: CLI command restructure (depends on rename)
- **Wave 3**: New features (depends on restructure)

## Design Decisions

**CLI Structure:**
- `dots setup` — Tool initialization (PATH, deploy target)
- `dots global-configs {plugin}` — .env wizard (opt-in per config)
- `dots project-configs {plugin}` — Project overrides

**Config Model:**
- Opt-in to manage (pick which configs to set)
- Opt-out from suggested value (for picked configs)
- Unpicked configs = unset (no .env entry)

**Backwards Compatibility:**
- `dotconfigs` command → symlink to `dots`
- `dots setup <plugin>` → deprecation warning, calls global-configs
- `dots project <path>` → deprecation warning, calls project-configs

## Execution

```bash
# Execute all plans
/gsd:execute-plan quick/002 --wave 1  # Bug fixes + rename
/gsd:execute-plan quick/002 --wave 2  # Restructure
/gsd:execute-plan quick/002 --wave 3  # New features

# Or execute all at once
/gsd:execute-plan quick/002
```

## Success Criteria

- [x] Plans created (4 plans)
- [ ] Git wizard accepts Enter without looping
- [ ] .env values quoted and sourceable
- [ ] 'dots' command works
- [ ] New command structure functional
- [ ] Opt-in config selection working
- [ ] Per-hook toggles implemented
- [ ] CLAUDE.md exclusion option added
- [ ] All tests pass
- [ ] Documentation updated

## Related

- Todo #2: Toggleable hooks → Addressed in 002-04
- Todo #4: Rename CLI to dots → Addressed in 002-02
- UAT findings: Git wizard bug → Addressed in 002-01
