---
phase: 08
plan: 04
subsystem: claude-hooks
tags: [claude-code, pretooluse-hook, security, file-protection]
requires:
  - phase-08-plan-01  # Unified config architecture
provides:
  - pretooluse-destructive-guard
  - pretooluse-file-protection
  - settings-hooks-template
affects:
  - phase-08-plan-05  # May reference hook configuration
tech-stack:
  added: []
  patterns:
    - claude-code-hooks-api
    - json-stdin-stdout
    - graceful-degradation
key-files:
  created:
    - plugins/claude/hooks/block-destructive.sh
    - plugins/claude/templates/settings/hooks.json
  modified: []
  deleted: []
key-decisions:
  - decision: "PreToolUse hook blocks destructive commands and sensitive file writes"
    rationale: "Active enforcement layer separate from buggy settings.json deny rules (Claude Code #6699, #8961)"
    scope: "claude-code-security"
  - decision: "Both guards independently configurable via CLAUDE_HOOK_* variables"
    rationale: "Users may want different combinations (block commands but allow file writes, etc.)"
    scope: "hook-configuration"
  - decision: "Graceful jq dependency handling (silent exit if missing)"
    rationale: "Don't block Claude Code workflow if jq not installed — hook provides defence-in-depth, not critical path"
    scope: "dependency-management"
  - decision: "10s timeout for PreToolUse, 30s for PostToolUse"
    rationale: "PreToolUse is blocking so needs fast response, PostToolUse (formatting) can take longer"
    scope: "hook-timeouts"
duration: "1m 8s"
completed: 2026-02-08
---

# Phase 08 Plan 04: PreToolUse Hook for Destructive Command Blocking

**One-liner:** PreToolUse hook blocks destructive bash commands (rm -rf /, git push --force) and protects sensitive files (.pem, credentials, SSH keys) with independent configurable guards.

## Performance

**Execution time:** 1 minute 8 seconds
**Tasks completed:** 2/2

## Accomplishments

### 1. Destructive Command Guard

Created `block-destructive.sh` PreToolUse hook with protections for:

**Bash tool destructive commands:**
- `rm -rf /` or `rm -rf ~` (filesystem deletion)
- `git push --force` without `--force-with-lease` (overwrites others' work)
- `git reset --hard` (discards uncommitted work)
- `git clean -fd` (deletes untracked files)
- `DROP TABLE` / `DROP DATABASE` (SQL destruction)
- `chmod -R 777` (security vulnerability)

**Write/Edit tool file protection:**
- `*.pem` files (private keys)
- `*credentials*` patterns (credentials files)
- `.env.production` (production secrets)
- `id_rsa` / `id_ed25519` (SSH keys)

Returns `{"decision": "block", "reason": "..."}` for matches, implicit allow otherwise.

### 2. Settings.json Hooks Template

Created `plugins/claude/templates/settings/hooks.json` with:

- **PreToolUse matchers:** Two separate matchers (Bash for commands, Write/Edit for file protection) pointing to same hook script
- **PostToolUse matcher:** Write/Edit → post-tool-format.py (Ruff formatting)
- **Portable paths:** Uses `$CLAUDE_PROJECT_DIR` variable for repo-relative paths
- **Timeouts:** 10s for PreToolUse (blocking), 30s for PostToolUse (non-blocking)

This template gets merged into settings.json during Claude plugin deployment.

### 3. Defence-in-Depth Architecture

This adds active interception separate from settings.json deny rules:

- **Settings.json deny rules** (base.json): Block Read operations on sensitive files
- **PreToolUse hook** (block-destructive.sh): Block Write/Edit on sensitive files + destructive Bash commands

Why both layers:
- Settings.json has known bugs (Claude Code #6699, #8961) — rules sometimes ignored
- PreToolUse hook provides reliable enforcement via stdin/stdout JSON protocol
- Complementary scopes: settings deny Read, hook blocks Write/Edit and Bash

## Task Commits

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Create PreToolUse destructive command guard hook | fb55eeb | plugins/claude/hooks/block-destructive.sh |
| 2 | Create settings.json hooks template | e674e2a | plugins/claude/templates/settings/hooks.json |

## Files Created/Modified

### Created

- **plugins/claude/hooks/block-destructive.sh** — PreToolUse hook with:
  - Metadata header (NAME, TYPE, PLUGIN, CONFIGURABLE)
  - Config loading from project or global `.claude/claude-hooks.conf`
  - Defaults: both guards enabled
  - jq dependency check (silent exit if missing)
  - Destructive command pattern matching
  - Sensitive file pattern matching
  - JSON output for block decisions
  - Bash 3.2 compatible

- **plugins/claude/templates/settings/hooks.json** — Settings overlay with:
  - PreToolUse array (two matchers for Bash and Write/Edit)
  - PostToolUse array (Ruff formatting matcher)
  - Portable `$CLAUDE_PROJECT_DIR` paths
  - Hook timeouts configured

### Modified

None.

### Deleted

None.

## Decisions Made

### 1. Active Enforcement Layer

**Decision:** Create PreToolUse hook for destructive command blocking separate from settings.json deny rules.

**Rationale:** Settings.json deny rules have known bugs (Claude Code issues #6699, #8961) where rules are sometimes ignored. PreToolUse hook provides reliable enforcement via Claude Code's stable hooks API (JSON stdin/stdout protocol).

**Impact:** Defence-in-depth security model — settings.json blocks Read operations (first line), PreToolUse hook blocks Write/Edit and Bash operations (second line). If settings bug allows operation through, hook still blocks it.

### 2. Independent Configuration

**Decision:** Two separate variables for destructive guard and file protection:
- `CLAUDE_HOOK_DESTRUCTIVE_GUARD` (blocks rm -rf, git push --force, etc.)
- `CLAUDE_HOOK_FILE_PROTECTION` (blocks writes to .pem, credentials, SSH keys)

**Rationale:** Users may want different combinations. Example: Block destructive commands globally but allow .env.production writes in specific trusted projects. Independent toggles provide flexibility without "all or nothing" approach.

**Implementation:** Each guard has its own `if` block in hook script, checks tool_name match, then applies patterns.

### 3. Graceful jq Degradation

**Decision:** If jq not installed, hook exits 0 silently (doesn't block workflow).

**Rationale:** Hook provides defence-in-depth security, not critical path blocking. Better to allow operations if jq missing than to break Claude Code workflow. Users still get settings.json protection (first line of defence). Hook installation documentation should mention jq as optional but recommended.

**Implementation:** `command -v jq >/dev/null 2>&1 || exit 0` at start of script.

### 4. Hook Timeouts

**Decision:** 10s for PreToolUse, 30s for PostToolUse.

**Rationale:**
- **PreToolUse is blocking** — Claude waits for hook to return before executing tool. Must be fast to avoid UI lag. 10s is generous for pattern matching.
- **PostToolUse is non-blocking** — Claude already executed tool, hook runs async. Formatting with Ruff can take longer on large files. 30s allows for complex formatting without killing hook prematurely.

**Implementation:** Timeout values in settings/hooks.json template.

### 5. Two PreToolUse Matchers

**Decision:** Two separate PreToolUse matchers (one for Bash, one for Write/Edit) both pointing to same hook script.

**Alternative considered:** Single matcher with multiple tool_name conditions.

**Rationale:** Claude Code hooks API matcher design expects specific tool matching. Clearer to have explicit matchers per tool category. Hook script handles both cases via internal tool_name checks.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness

### For Phase 08 Completion

**Status:** READY

This was the final implementation plan in Phase 08. Security layer complete:

- **08-01:** Config architecture (GIT_HOOK_*, CLAUDE_HOOK_* naming)
- **08-02:** Audit of existing git hooks and squash-merge workflow
- **08-03:** New git hooks (pre-commit, prepare-commit-msg)
- **08-04:** Claude Code PreToolUse hook (this plan)

Next step: Phase 08 completion review.

### Hook Configuration Complete

**Variables documented in lib/config.sh:**
- `CLAUDE_HOOK_DESTRUCTIVE_GUARD` (default: true)
- `CLAUDE_HOOK_FILE_PROTECTION` (default: true)
- `CLAUDE_HOOK_RUFF_FORMAT` (default: true) — from existing PostToolUse hook

**Template created:**
- `plugins/claude/templates/claude-hooks.conf` — from 08-01, now complete

**Settings template ready:**
- `plugins/claude/templates/settings/hooks.json` — for merge into settings.json

### Deployment Integration

**Ready for Claude plugin deploy command to:**
1. Copy hook script to project `.claude/hooks/` (local-only, not tracked)
2. Merge hooks.json template into global or project settings.json
3. Copy claude-hooks.conf template to project `.claude/` (for user customisation)

**Note:** Deploy logic not yet implemented — that's a separate v2.0 milestone. This plan provides the artifacts for deployment.

## Self-Check: PASSED

All created files exist:
- plugins/claude/hooks/block-destructive.sh: FOUND
- plugins/claude/templates/settings/hooks.json: FOUND

All commits exist:
- fb55eeb: FOUND (Task 1 — PreToolUse hook)
- e674e2a: FOUND (Task 2 — settings.json template)

Verification checks:
- bash -n block-destructive.sh: PASSED
- JSON validation: PASSED
- Cross-reference check: PASSED
- Bash 3.2 compatibility: PASSED
