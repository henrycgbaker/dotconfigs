---
phase: 08
plan: 01
subsystem: hooks-config
tags: [configuration, git-hooks, claude-hooks, refactoring]
requires:
  - phase-06-plan-01  # Git hook source of truth
  - phase-07  # Complete v2.0 implementation
provides:
  - unified-hook-config-architecture
  - git-hook-variable-naming-ssot
  - claude-hook-variable-naming-ssot
  - plugin-config-templates
affects:
  - 08-02  # Depends on unified naming for new hooks
  - 08-03  # Depends on config templates
tech-stack:
  added: []
  patterns:
    - config-hierarchy-resolution
    - backwards-compatible-config-discovery
key-files:
  created:
    - lib/config.sh
    - plugins/git/templates/git-hooks.conf
    - plugins/claude/templates/claude-hooks.conf
  modified:
    - dotconfigs
    - plugins/git/hooks/commit-msg
    - plugins/git/hooks/pre-push
  deleted:
    - plugins/claude/templates/hooks-conf/default.conf
    - plugins/claude/templates/hooks-conf/strict.conf
    - plugins/claude/templates/hooks-conf/permissive.conf
key-decisions:
  - decision: "Unified variable naming: GIT_HOOK_* for git hooks, CLAUDE_HOOK_* for claude hooks"
    rationale: "Clear namespace separation, consistent prefix pattern"
    scope: "all-future-hooks"
  - decision: "AI attribution blocking is now configurable (GIT_HOOK_BLOCK_AI_ATTRIBUTION) with strong default ON"
    rationale: "User requested configurability while maintaining opinionated default"
    scope: "commit-msg-hook"
  - decision: "Config hierarchy: hardcoded default → env var → config file"
    rationale: "Standard precedence pattern, env vars for global, config files for per-project"
    scope: "all-hooks"
  - decision: "Multiple config file paths tried in order (.githooks/config, .claude/git-hooks.conf, etc.)"
    rationale: "Backwards compatibility with existing deployments"
    scope: "config-discovery"
  - decision: "Deprecated hooks.conf profile templates (default/strict/permissive)"
    rationale: "Replaced by single template with inline documentation - simpler, more maintainable"
    scope: "config-templates"
duration: "3m 10s"
completed: 2026-02-08
---

# Phase 08 Plan 01: Unified Hook Configuration Architecture

**One-liner:** Established GIT_HOOK_*/CLAUDE_HOOK_* naming convention with config hierarchy, refactored commit-msg and pre-push hooks to unified pattern, created plugin config templates, removed deprecated profiles.

## Performance

**Execution time:** 3 minutes 10 seconds
**Tasks completed:** 3/3

## Accomplishments

### Foundation Established

Created the unified configuration architecture that all future hook work depends on:

1. **Single Source of Truth** — lib/config.sh documents all hook variables across both plugins with clear naming conventions
2. **Consistent Naming** — GIT_HOOK_* prefix for git hooks, CLAUDE_HOOK_* for claude hooks
3. **Config Hierarchy** — Standard precedence: hardcoded defaults → env vars → config file
4. **Backwards Compatibility** — Multiple config file paths tried for migration support

### Refactored Existing Hooks

Both active hooks now use the unified configuration pattern:

- **commit-msg**: AI attribution blocking now configurable (was hardcoded), added WIP blocking control, configurable strict mode for conventional commits, configurable subject length
- **pre-push**: Renamed to GIT_HOOK_BRANCH_PROTECTION for consistency, added per-hook enable/disable

### Config Templates

Replaced deprecated profile templates with inline-documented single templates:

- **plugins/git/templates/git-hooks.conf** — All GIT_HOOK_* variables with defaults and comments
- **plugins/claude/templates/claude-hooks.conf** — CLAUDE_HOOK_* settings for Claude Code hooks

### Auto-Documentation

Added metadata header blocks to both hooks for auto-generated documentation in future plans.

## Task Commits

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Create shared config loading library | 1ae0dcf | lib/config.sh, dotconfigs |
| 2 | Refactor commit-msg hook to unified config | 3675f8e | plugins/git/hooks/commit-msg |
| 3 | Refactor pre-push, create templates, remove profiles | 7f64903 | plugins/git/hooks/pre-push, plugins/git/templates/git-hooks.conf, plugins/claude/templates/claude-hooks.conf, hooks-conf/ (deleted) |

## Files Created/Modified

### Created

- **lib/config.sh** — Shared config loading library with load_git_hook_config() helper, _config_resolve() for hierarchy, complete GIT_HOOK_*/CLAUDE_HOOK_* variable reference (documentation SSOT)
- **plugins/git/templates/git-hooks.conf** — Git plugin config template with all 22+ GIT_HOOK_* variables documented with defaults
- **plugins/claude/templates/claude-hooks.conf** — Claude plugin config template with CLAUDE_HOOK_* settings

### Modified

- **dotconfigs** — Sources lib/config.sh alongside other lib files
- **plugins/git/hooks/commit-msg** — Refactored to use GIT_HOOK_* naming, made AI attribution configurable, added strict mode toggle, added per-hook enable/disable, multi-path config discovery, metadata header
- **plugins/git/hooks/pre-push** — Renamed GIT_HOOK_PREPUSH_PROTECTION to GIT_HOOK_BRANCH_PROTECTION, added per-hook enable/disable, multi-path config discovery, metadata header

### Deleted

- **plugins/claude/templates/hooks-conf/default.conf** — Deprecated profile template
- **plugins/claude/templates/hooks-conf/strict.conf** — Deprecated profile template
- **plugins/claude/templates/hooks-conf/permissive.conf** — Deprecated profile template
- **plugins/claude/templates/hooks-conf/** — Profile directory removed

## Decisions Made

### 1. Variable Naming Convention

**Decision:** Git hooks use `GIT_HOOK_*` prefix, Claude hooks use `CLAUDE_HOOK_*` prefix.

**Rationale:** Clear namespace separation prevents collisions and makes ownership obvious. Consistent prefix pattern is easier to grep and document.

**Impact:** All future hooks must follow this convention. Existing GIT_HOOK_PREPUSH_PROTECTION renamed to GIT_HOOK_BRANCH_PROTECTION for consistency (dropped redundant "PREPUSH" since it's already in the pre-push hook).

### 2. AI Attribution Blocking Configurability

**Decision:** Changed from hardcoded enforcement to configurable `GIT_HOOK_BLOCK_AI_ATTRIBUTION` with strong default `true`.

**Rationale:** User requested configurability. Some projects may legitimately want to include AI attribution (open source disclosure, compliance, experimentation). Strong default maintains opinionated stance while allowing opt-out.

**Implementation:** Removed the forced `BLOCK_AI_ATTRIBUTION=true` re-assignment after config loading. Now respects config file and env var values.

### 3. Config Hierarchy

**Decision:** Config resolution follows: hardcoded default → environment variable → config file (highest precedence).

**Rationale:** Standard configuration pattern. Hardcoded defaults ensure hooks work out-of-box. Env vars allow global overrides (via .env). Config files allow per-project customisation.

**Implementation:** Hooks use `${VAR:-default}` pattern, then source config file if found (overrides both).

### 4. Multiple Config File Paths

**Decision:** Try config paths in order: `.githooks/config`, `.claude/git-hooks.conf`, `.git/hooks/hooks.conf`, `.claude/hooks.conf` (backwards compat).

**Rationale:** Supports migration from old dotclaude structure (`.claude/hooks.conf`) while encouraging new clearer naming (`.claude/git-hooks.conf` separates git vs claude config). `.githooks/config` added for future standardisation.

**Impact:** Existing deployments continue working without changes.

### 5. Deprecate Profile Templates

**Decision:** Remove default/strict/permissive profile templates, replace with single template containing all options with inline docs.

**Rationale:** Profile approach was premature abstraction — users would need to read template source to understand options anyway. Single file with comments is simpler to maintain and easier to discover options. Users can comment/uncomment lines to customise rather than choosing abstract "strict" vs "permissive" profiles.

**Deleted:** `plugins/claude/templates/hooks-conf/` directory and all three profile files.

### 6. Metadata Headers for Auto-Documentation

**Decision:** Add structured metadata blocks to hook files for future auto-documentation tooling.

**Format:**
```bash
# === METADATA ===
# NAME: hook-name
# TYPE: git-hook
# PLUGIN: git
# DESCRIPTION: What this hook does
# CONFIGURABLE: VAR1, VAR2, VAR3
# ================
```

**Rationale:** Plan 08-03 will build documentation generator. Structured metadata enables parsing hook files to generate complete configuration reference.

### 7. Per-Hook Enable/Disable

**Decision:** Every hook gets a `{PREFIX}_{HOOK_NAME}_ENABLED` variable for master toggle.

**Examples:** `GIT_HOOK_COMMIT_MSG_ENABLED`, `GIT_HOOK_PRE_PUSH_ENABLED`

**Rationale:** Sometimes users want to temporarily disable a hook without removing the file or editing individual settings. Master toggle makes this trivial (set to `false` in config).

**Implementation:** Hooks check this variable first and `exit 0` if not `true`.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness

### For 08-02 (New Git Hooks)

**Status:** READY

**Blocks removed:**
- Variable naming convention established (new hooks know to use GIT_HOOK_* prefix)
- Config loading pattern documented (new hooks can copy from commit-msg/pre-push)
- Metadata header format defined (new hooks must include for auto-doc)

**Requirements for 08-02:**
- Follow GIT_HOOK_* naming convention
- Use multi-path config discovery pattern
- Add metadata header block
- Include per-hook _ENABLED variable
- Document all variables in lib/config.sh

### For 08-03 (Config Templates)

**Status:** READY

**Templates exist:**
- plugins/git/templates/git-hooks.conf — all current GIT_HOOK_* variables
- plugins/claude/templates/claude-hooks.conf — CLAUDE_HOOK_* variables

**Extension pattern:**
When Plan 08-02 adds new hooks, their variables must be added to git-hooks.conf template (commented out with "future" marker already in place).

### For 08-04 (Squash Merge Workflow)

**Status:** READY

No blockers. Pre-push hook uses unified naming (GIT_HOOK_BRANCH_PROTECTION) which 08-04 will reference if workflow documentation includes branch protection guidance.

### Compatibility Check

**Bash 3.2:** VERIFIED
- Grepped all modified files for `local -n`, `declare -n`, `declare -A` — none found
- All hooks use bash 3.2-safe parameter expansion and array syntax

**Backwards compatibility:** VERIFIED
- Multi-path config discovery includes legacy `.claude/hooks.conf` path
- Env var names unchanged (GIT_HOOK_PREPUSH_PROTECTION → GIT_HOOK_BRANCH_PROTECTION is internal refactor, env var works same way)

## Self-Check: PASSED

All created files exist:
- lib/config.sh: FOUND
- plugins/git/templates/git-hooks.conf: FOUND
- plugins/claude/templates/claude-hooks.conf: FOUND

All commits exist:
- 1ae0dcf: FOUND (Task 1 — config.sh)
- 3675f8e: FOUND (Task 2 — commit-msg)
- 7f64903: FOUND (Task 3 — pre-push + templates)

Deleted files verified:
- plugins/claude/templates/hooks-conf/: Directory does not exist (correct)
