# Phase 7: Integration & Polish - Context

**Gathered:** 2026-02-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Production-ready dotconfigs CLI with status visibility, help, conflict detection, and idempotent deploys. All plugins (claude, git) already exist from earlier phases — this phase adds the cross-cutting commands (`status`, `list`, `help`) and hardens deploy with conflict handling, `--force`, and `--dry-run`.

</domain>

<decisions>
## Implementation Decisions

### Status output format
- `dotconfigs status` shows ALL plugins in one view (no prompting to pick one)
- Per-file granularity: each managed file listed with its state
- Three-state model: not configured / configured but not deployed / deployed
- Drift detection: flag files that have changed since last deploy (symlink broken, config edited)
- Report drift only — no suggested fix commands
- ANSI colour output when TTY detected (green OK, yellow drift, red missing), plain text when piped
- `dotconfigs status <plugin>` filters to a single plugin

### List command
- Minimal output: plugin name + installed/not-installed status
- No descriptions — just `claude ✓ installed` / `git ✗ not installed`
- Uses same colour scheme as status

### Conflict detection
- When deploy encounters an existing file it didn't create: warn and prompt per-file (overwrite, skip, or diff)
- If user chooses overwrite: offer `.bak` backup before overwriting
- `--force` flag bypasses all conflict prompts and overwrites everything
- Ownership model: symlink check (SSOT architecture — repo is source of truth, symlinks express that; regular files at target location are foreign by definition)
- Cross-plugin file conflicts are not possible by design — plugins have separate namespaces; treat as a bug if it happens

### Idempotency & deploy behaviour
- `dotconfigs deploy` (no arg) deploys ALL configured plugins — one command to sync everything
- `dotconfigs deploy <plugin>` deploys a single plugin
- Always print deploy summary (files created, skipped, unchanged) — even when nothing changed
- `--dry-run` flag shows what deploy WOULD do without touching the filesystem

### PATH installation
- `dotconfigs deploy` creates a symlink so the CLI is callable from any directory
- Target location and mechanism at Claude's discretion

### Smart project path detection
- `dotconfigs project` works from either the dotconfigs repo or the target project repo
- If run from a project repo (not the dotconfigs repo): detect it, confirm with y/n, then use that path
- If run from the dotconfigs repo: require explicit path argument
- Detection: check if CWD is the dotconfigs repo (contains `dotconfigs` entry point + `plugins/` dir) vs a normal git repo

### Claude's Discretion
- Ownership detection mechanism details (symlink-based fits SSOT, Claude to decide exact implementation)
- Skip-unchanged vs always-overwrite on idempotent re-deploy
- Help command format and content
- Exact colour codes and formatting
- Testing approach for macOS (bash 3.2) + Linux (bash 4+)

</decisions>

<specifics>
## Specific Ideas

- Status mock-up reference (per-file):
  ```
  dotconfigs status

    claude                          ✓ deployed
      hooks/PreToolUse.sh           ✓ ok
      hooks/PostToolUse.sh          ✓ ok
      settings.json                 Δ drifted
      CLAUDE.md                     ✓ ok
      commands/commit.md            ✓ ok
      commands/squash-merge.md      ✓ ok

    git                             ✗ not configured
  ```
- List mock-up reference (minimal):
  ```
  Available plugins:

    claude   ✓ installed
    git      ✗ not installed
  ```
- SSOT architecture: symlinks naturally express single source of truth — the repo is canonical, deployed locations are references. Foreign files are anything that's not a symlink back to the repo.

</specifics>

### Documentation (final plan in phase)
- **Audience:** Semi-public — clear enough for others, no over-explaining or marketing fluff
- **README sections:** Overview, install, usage (setup/deploy/project/status/list), .env reference, directory structure
- **No example terminal output** — keep it concise
- `.env.example` polish: ensure all CLAUDE_* and GIT_* keys present and accurate; format at Claude's discretion
- No plugin developer guide — personal tool, not needed
- No separate config reference — `.env.example` and `dotconfigs help` cover it

</deferred>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 07-integration-and-polish*
*Context gathered: 2026-02-07*
