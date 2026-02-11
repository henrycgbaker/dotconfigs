---
phase: 08
plan: 03
subsystem: hooks-git
tags: [git-hooks, pre-commit, prepare-commit-msg, post-merge, post-checkout, post-rewrite, secrets-detection, dependency-detection]
requires:
  - phase-08-plan-01  # Unified hook config architecture
provides:
  - pre-commit-hook-with-secrets-detection
  - prepare-commit-msg-hook-with-branch-prefix
  - post-merge-dependency-detection
  - post-checkout-branch-info
  - post-rewrite-dependency-detection
affects:
  - 08-04  # May use same config patterns
  - future-git-workflows  # Complete git hook suite now available
tech-stack:
  added: []
  patterns:
    - multi-check-pre-commit-pattern
    - informational-post-hook-pattern
    - branch-based-commit-prefix-extraction
key-files:
  created:
    - plugins/git/hooks/pre-commit
    - plugins/git/hooks/prepare-commit-msg
    - plugins/git/hooks/post-merge
    - plugins/git/hooks/post-checkout
    - plugins/git/hooks/post-rewrite
  modified: []
key-decisions:
  - "Secrets detection blocks hard (no warn mode) — security-critical"
  - "Large file detection warns only — not a correctness issue"
  - "Debug statement detection configurable strict mode (warn vs block)"
  - "Branch prefix only on branch commits, skips merge/squash/amend"
  - "Post-* hooks informational only — never block workflow"
  - "Post-rewrite only checks rebase (not amend) — amend is single commit"
patterns-established:
  - "Pre-commit multi-check pattern: independently configurable checks"
  - "Informational post-hooks: helpful reminders, never blocking"
  - "Portable file size detection: wc -c (not stat)"
duration: "2m 37s"
completed: 2026-02-08
---

# Phase 08 Plan 03: Git Workflow Hooks Suite

**Five new git hooks covering pre-commit validation (secrets, large files, debug statements), commit message preparation from branch name, and post-operation info (dependency changes, branch info, migration reminders)**

## Performance

- **Duration:** 2m 37s
- **Started:** 2026-02-08T17:21:34Z
- **Completed:** 2026-02-08T17:24:11Z
- **Tasks:** 3
- **Files created:** 5

## Accomplishments

### Complete Git Workflow Coverage

Expanded from 2 hooks (commit-msg, pre-push) to 7 hooks, covering the full practical git workflow:

1. **pre-commit** — Validates staged changes before commit creation
   - Secrets detection: AWS keys, API keys, Stripe keys, Google keys, private keys (hard block)
   - Large file warning: configurable threshold, default 1MB (warn only)
   - Debug statement detection: console.log, debugger, pdb, breakpoint, binding.pry (configurable strict mode)

2. **prepare-commit-msg** — Auto-prefixes commit messages from branch name
   - Maps feature/* → feat:, fix/* → fix:, docs/* → docs:, etc.
   - Skips merge/squash/amend commits (already have messages)
   - Skips if message already has conventional prefix
   - Handles detached HEAD gracefully

3. **post-merge** — Dependency change detection after merge
   - Detects package.json, requirements.txt, Gemfile, go.mod, Cargo.toml, composer.json changes
   - Detects migration directory changes (db/migrate/, migrations/, alembic/, prisma/)
   - Shows install/migration commands
   - Informational only (never blocks)

4. **post-checkout** — Branch info on checkout
   - Shows branch name, last commit, author, date
   - Shows divergence from main/master (ahead/behind commits)
   - Only runs on branch checkout (not file checkout)
   - Handles detached HEAD gracefully

5. **post-rewrite** — Dependency detection for rebase workflows
   - Same checks as post-merge but for rebase scenarios
   - Only runs on rebase (not amend)
   - Informational only (never blocks)

### Unified Configuration Pattern

All five hooks follow the pattern established in Plan 08-01:

- Multi-path config discovery (`.githooks/config`, `.claude/git-hooks.conf`, etc.)
- GIT_HOOK_* naming convention
- Per-hook _ENABLED toggle
- Per-check independent configuration
- Config hierarchy: hardcoded default → env var → config file
- Metadata headers for auto-documentation

### Bash 3.2 Compatibility

All hooks verified compatible with macOS default bash:
- No namerefs (`local -n`, `declare -n`)
- No associative arrays (`declare -A`)
- Portable file size detection using `wc -c` (not `stat`)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create pre-commit hook** - `479cd8f` (feat)
2. **Task 2: Create prepare-commit-msg hook** - `97ba0d7` (feat)
3. **Task 3: Create post-merge, post-checkout, and post-rewrite hooks** - `1c17932` (feat)

## Files Created/Modified

### Created

- **plugins/git/hooks/pre-commit** — Pre-commit validation with secrets detection (hard block), large file check (warn), debug statement detection (configurable strict mode). 228 lines, 3 independently configurable checks, bash 3.2 compatible.

- **plugins/git/hooks/prepare-commit-msg** — Commit message preparation with branch-based prefix extraction. Supports feature/fix/docs/refactor/test/chore/perf/style/build/ci branches. Skips merge/squash/amend. 144 lines, bash 3.2 compatible.

- **plugins/git/hooks/post-merge** — Post-merge dependency and migration detection. Checks package.json, requirements.txt, Gemfile, go.mod, Cargo.toml, composer.json. Checks db/migrate/, migrations/, alembic/, prisma/. Shows install/migration commands. 164 lines, informational only.

- **plugins/git/hooks/post-checkout** — Post-checkout branch information display. Shows branch name, last commit, author, date, divergence from main/master. Only runs on branch checkout. 138 lines, informational only.

- **plugins/git/hooks/post-rewrite** — Post-rewrite dependency detection for rebase. Same checks as post-merge. Only runs on rebase (not amend). 154 lines, informational only.

## Decisions Made

### 1. Secrets Detection Hard Block

**Decision:** Secrets detection in pre-commit has no warn mode — always blocks.

**Rationale:** Security-critical. Committing secrets (API keys, private keys, AWS credentials) is never acceptable. No legitimate use case for warning-only mode. Hard block forces fix before commit.

**Alternative considered:** Warn mode for "known safe" patterns — rejected because false confidence is worse than hard block with `--no-verify` escape hatch.

### 2. Large File Detection Warn Only

**Decision:** Large file detection warns but doesn't block.

**Rationale:** Not a correctness/security issue. Large files may be intentional (datasets, media assets, etc.). Warn gives visibility without forcing `--no-verify`. Users can adjust threshold or disable check if needed.

### 3. Debug Statement Detection Configurable Strict Mode

**Decision:** Debug statements default to warn, configurable strict mode blocks.

**Rationale:** Some projects intentionally commit debug logging (verbose modes, troubleshooting docs). Default warn raises awareness. Strict mode available for projects with zero-debug-statements policy.

**Variables:** `GIT_HOOK_DEBUG_CHECK` (enable/disable), `GIT_HOOK_DEBUG_CHECK_STRICT` (warn vs block).

### 4. Branch Prefix Only on Branch Commits

**Decision:** prepare-commit-msg only prefixes on branch commits, skips merge/squash/amend.

**Rationale:** Merge/squash/amend commits already have messages or user is crafting manually. Auto-prefixing would interfere. Also skips if message already has conventional prefix (avoids double-prefixing on retry).

### 5. Post-Hooks Informational Only

**Decision:** All post-* hooks (post-merge, post-checkout, post-rewrite) never block, always exit 0.

**Rationale:** Post-hooks run after operation completes. Blocking at this point is confusing (operation already succeeded). Informational reminders are helpful without disrupting workflow.

### 6. Post-Rewrite Only Checks Rebase

**Decision:** post-rewrite only runs checks on rebase, not amend.

**Rationale:** Amend is single commit change (rarely affects dependencies). Rebase can pull in many commits from upstream, making dependency changes likely. Checking amend would be noisy without value.

**Implementation:** `if [[ "$REWRITE_TYPE" != "rebase" ]]; then exit 0; fi`

### 7. Portable File Size Detection

**Decision:** Use `wc -c < "$file"` for file size, not `stat`.

**Rationale:** `stat` syntax differs between macOS (BSD) and Linux (GNU). `wc -c` is portable POSIX. Bash 3.2 compatible, works everywhere.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness

### For Deployment

**Status:** READY

**Hooks created:** 5 new hooks, 7 total in plugins/git/hooks/
**Config template:** plugins/git/templates/git-hooks.conf already has all GIT_HOOK_* variables (from Plan 08-01)
**Deployment:** `dotconfigs deploy git` will copy all 7 hooks to configured location

### For Phase 08-04 (Squash Merge Workflow)

**Status:** READY

**Relevant hooks:**
- prepare-commit-msg: Supports branch-based prefixing (feature/* → feat:)
- commit-msg: Validates conventional commits on main branch
- pre-push: Branch protection (warn/block pushing to main)

**Workflow compatibility:** All hooks designed to work with branch + squash merge workflow. prepare-commit-msg auto-prefixes on branch commits, commit-msg validates on main, pre-push protects main from direct pushes.

### Bash 3.2 Compatibility

**Status:** VERIFIED

Grepped all 5 new hooks for bash 4+ features:
```bash
grep -rE 'local -n|declare -n|declare -A' plugins/git/hooks/post-* plugins/git/hooks/pre-commit plugins/git/hooks/prepare-commit-msg
```

Result: No matches. All hooks bash 3.2 compatible.

## Self-Check: PASSED

All created files exist:
- plugins/git/hooks/pre-commit: FOUND
- plugins/git/hooks/prepare-commit-msg: FOUND
- plugins/git/hooks/post-merge: FOUND
- plugins/git/hooks/post-checkout: FOUND
- plugins/git/hooks/post-rewrite: FOUND

All commits exist:
- 479cd8f: FOUND (Task 1 — pre-commit)
- 97ba0d7: FOUND (Task 2 — prepare-commit-msg)
- 1c17932: FOUND (Task 3 — post-merge, post-checkout, post-rewrite)
