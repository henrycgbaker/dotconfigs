---
phase: 06-git-plugin
plan: 01
type: summary
subsystem: git-plugin
status: complete
tags: [git, hooks, commit-msg, pre-push, branch-protection, plugin-architecture]

requires:
  - "05-05: Claude plugin extraction complete"
provides:
  - "Git hook templates under plugins/git/hooks/"
  - "commit-msg hook with AI attribution blocking + conventional commits"
  - "pre-push hook with configurable branch protection"
  - "Claude plugin decoupled from git-hook management"
affects:
  - "06-02: Git plugin setup wizard (will configure these hooks)"
  - "06-03: Git plugin deploy (will install these hooks)"

tech-stack:
  added:
    - "plugins/git/hooks/commit-msg"
    - "plugins/git/hooks/pre-push"
  patterns:
    - "Hook templates with config-driven behaviour (.claude/hooks.conf)"
    - "Environment variable fallback (GIT_HOOK_PREPUSH_PROTECTION)"

key-files:
  created:
    - "plugins/git/hooks/commit-msg"
    - "plugins/git/hooks/pre-push"
  modified:
    - "plugins/claude/deploy.sh"

decisions:
  - id: "HOOK-01"
    what: "Git hooks source of truth moved to plugins/git/hooks/"
    why: "Plugin architecture requires git plugin to own git hooks"
    impact: "Old githooks/ directory deprecated but kept as reference"

  - id: "HOOK-02"
    what: "commit-msg uses research-based conventional commit regex"
    why: "More accurate validation with scope, breaking change support"
    impact: "Validates format: type(scope)!: description"

  - id: "HOOK-03"
    what: "pre-push protection configurable via GIT_HOOK_PREPUSH_PROTECTION"
    why: "Different repos may need different protection levels"
    impact: "Supports warn/block/off modes, defaults to warn"

  - id: "HOOK-04"
    what: "Claude plugin no longer manages git hooks or identity"
    why: "Separation of concerns - git plugin owns all git configuration"
    impact: "Removed sections 5-6 from deploy.sh (32 lines)"

metrics:
  duration: "1min 50s"
  completed: "2026-02-07"
---

# Phase [6] Plan [01]: Create Git Hook Templates Summary

Git hook templates created under plugins/git/hooks/ with AI attribution blocking, conventional commit validation, and configurable branch protection.

## Tasks Completed

### Task 1: Create git plugin hook templates
**Status:** ✅ Complete
**Commit:** `15fe2e5`

Created `plugins/git/hooks/` directory with two hook scripts:

**commit-msg hook:**
- Adapted from existing `githooks/commit-msg` with source-of-truth update
- AI attribution blocking (always enforced) with 11 patterns
- Conventional commit validation (config-driven via CONVENTIONAL_COMMITS)
- Updated regex from research: `^(feat|fix|docs|style|refactor|test|chore|build|ci|perf|revert)(\([a-zA-Z0-9_.-]+\))?(!)?:\s.+$`
- Handles merge commits (skips validation when MERGE_HEAD exists)
- Handles squash merges (relaxes WIP blocking when SQUASH_MSG exists)
- 72-character subject line warning
- Loads per-project config from `$REPO_ROOT/.claude/hooks.conf`

**pre-push hook:**
- New hook for branch protection (main/master)
- Configurable protection: block, warn, off
- Reads `GIT_HOOK_PREPUSH_PROTECTION` from environment with fallback to `.claude/hooks.conf`
- Detects force push by checking parent process command and stdin
- Protected branches regex: `^(main|master)$`
- Block mode: exits 1 with error
- Warn mode: prints warning, allows push
- Off mode: no-op

Both hooks have `#!/bin/bash` shebangs (executables, not sourced libraries).

**Files created:**
- `plugins/git/hooks/commit-msg` (114 lines)
- `plugins/git/hooks/pre-push` (76 lines)

### Task 2: Decouple git hooks from Claude plugin deploy
**Status:** ✅ Complete
**Commit:** `ee78327`

Removed git-hook management from `plugins/claude/deploy.sh`:

**Removed sections:**
- Section 5: "Copy git hooks and set core.hooksPath" (20 lines)
  - Copied hooks from `githooks/` to `~/.claude/git-hooks/`
  - Set `git config --global core.hooksPath`
- Section 6: "Configure git identity" (10 lines)
  - Set `git config --global user.name` from `CLAUDE_GIT_USER_NAME`
  - Set `git config --global user.email` from `CLAUDE_GIT_USER_EMAIL`

**Sections renumbered:**
- GSD framework: Section 7 → Section 5
- .git/info/exclude: Section 8 → Section 6

**Claude plugin now only handles:**
1. Settings.json symlink
2. CLAUDE.md build
3. Claude-specific hooks (PreToolUse/PostToolUse)
4. Skills (commands)
5. GSD framework installation
6. .git/info/exclude for dotconfigs repo

**Files modified:**
- `plugins/claude/deploy.sh` (32 lines removed, sections renumbered)

## Verification Results

✅ `plugins/git/hooks/commit-msg` exists with `#!/bin/bash` header
✅ `plugins/git/hooks/pre-push` exists with `#!/bin/bash` header
✅ commit-msg contains AI_PATTERNS (2 occurrences)
✅ pre-push contains PROTECTED_BRANCHES (2 occurrences)
✅ Claude deploy.sh has 0 references to `core.hooksPath`
✅ Claude deploy.sh has 0 references to `git config --global user`
✅ Claude deploy.sh has 0 references to `githooks_target`
✅ Claude deploy.sh function `plugin_claude_deploy` still exists
✅ Both hook scripts pass `bash -n` syntax check
✅ Claude deploy.sh passes `bash -n` syntax check
✅ Claude deploy retains all core functionality (5 deployment sections)

## Deviations from Plan

None - plan executed exactly as written.

## Decisions Made

**HOOK-01: Git hooks source of truth moved to plugins/git/hooks/**
- **Context:** Plugin architecture requires clear ownership boundaries
- **Decision:** Git plugin now owns all git hooks, templates stored in `plugins/git/hooks/`
- **Rationale:** Old `githooks/` directory was deployed by Claude plugin via core.hooksPath, violating separation of concerns
- **Impact:** `githooks/` directory deprecated (kept as reference), git plugin will deploy from new location
- **Alternatives considered:** Keep hooks in root githooks/ directory → rejected, violates plugin architecture

**HOOK-02: commit-msg uses research-based conventional commit regex**
- **Context:** Existing regex was simplified, lacked scope and breaking change support
- **Decision:** Updated to: `^(feat|fix|docs|style|refactor|test|chore|build|ci|perf|revert)(\([a-zA-Z0-9_.-]+\))?(!)?:\s.+$`
- **Rationale:** Research (06-00-RESEARCH.md) identified proper conventional commit format
- **Impact:** Now validates optional scope `(scope)` and breaking change indicator `!`
- **Alternatives considered:** Keep simple regex → rejected, misses valid conventional formats

**HOOK-03: pre-push protection configurable via GIT_HOOK_PREPUSH_PROTECTION**
- **Context:** Different repositories may need different protection levels
- **Decision:** Environment variable with three modes: block, warn, off (default: warn)
- **Rationale:** Balance between safety (protecting main/master) and flexibility (allowing force-push when needed)
- **Impact:** Users can set per-project override in `.claude/hooks.conf` or global in `.env`
- **Alternatives considered:** Always block → rejected, too restrictive for all workflows

**HOOK-04: Claude plugin no longer manages git hooks or identity**
- **Context:** Claude plugin was handling git configuration (hooks path, user identity)
- **Decision:** Removed git-related sections from `plugins/claude/deploy.sh`
- **Rationale:** Git plugin should own all git configuration, Claude plugin should focus only on Claude-specific functionality
- **Impact:** 32 lines removed, cleaner separation of concerns, git functionality moves to git plugin
- **Alternatives considered:** Keep hybrid approach → rejected, violates single responsibility principle

## Architecture Impact

**Plugin boundaries clarified:**
- Claude plugin: Claude Code settings, CLAUDE.md, Claude hooks, GSD framework
- Git plugin: All git configuration (hooks, identity, workflow)

**Hook deployment flow (future):**
- Setup: Git wizard collects config → writes to .env (GIT_* keys)
- Deploy: Git plugin reads .env → copies hooks to `~/.claude/git-hooks/` → sets core.hooksPath

**Configuration hierarchy:**
- Global: `.env` file (GIT_HOOK_PREPUSH_PROTECTION, etc.)
- Per-project: `.claude/hooks.conf` (overrides global)
- Hooks load config in order: env var → hooks.conf → defaults

## Next Phase Readiness

**Ready for 06-02 (Git Plugin Setup Wizard):**
- ✅ Hook templates exist and are ready for deployment
- ✅ Configuration keys identified (GIT_HOOK_PREPUSH_PROTECTION, GIT_USER_NAME, GIT_USER_EMAIL)
- ✅ Config file format known (.claude/hooks.conf)

**Ready for 06-03 (Git Plugin Deploy):**
- ✅ Source files to deploy: `plugins/git/hooks/commit-msg`, `plugins/git/hooks/pre-push`
- ✅ Target location: `~/.claude/git-hooks/`
- ✅ Required git config: `core.hooksPath`

**Blockers:** None

**Open questions:**
- Should old `githooks/` directory be deleted now or in a cleanup phase? (Low priority)
- Should `.claude/hooks.conf` be created automatically or require manual setup? (06-02 will decide)

## Task Commits

| Task | Name                                   | Commit    | Files                                                    |
|------|----------------------------------------|-----------|----------------------------------------------------------|
| 1    | Create git plugin hook templates       | `15fe2e5` | plugins/git/hooks/commit-msg, plugins/git/hooks/pre-push |
| 2    | Decouple git hooks from Claude deploy  | `ee78327` | plugins/claude/deploy.sh                                 |

## Metadata Commit

**Commit:** (pending - will be created after SUMMARY.md and STATE.md updates)
**Message:** `docs(06-01): complete git hook templates plan`

## Self-Check: PASSED

All created files verified:
- ✓ plugins/git/hooks/commit-msg
- ✓ plugins/git/hooks/pre-push

All commits verified:
- ✓ 15fe2e5 (feat: create git plugin hook templates)
- ✓ ee78327 (refactor: decouple git hooks from Claude plugin deploy)
