# Phase 3: Settings, Hooks, Deploy & Skills - Context

**Gathered:** 2026-02-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Complete the dotclaude setup — settings.json permissions, deterministic hooks (Claude Code + git), configurable deployment system, and portable skills. The dotclaude repo is the single source of truth (SSOT) for all Claude configuration, from which specific instances are deployed to machines and projects.

</domain>

<decisions>
## Implementation Decisions

### GSD Coexistence
- Symlinks as ownership mechanism — dotclaude always deploys symlinks pointing back to the repo, never copies (exception: CLAUDE.md is built, see below)
- Ownership detection: `readlink` — if it points to dotclaude repo, it's ours
- GSD files are never touched — GSD manages its own namespace (`agents/gsd-*`, `commands/gsd/*`, `hooks/gsd-*.js`)
- Conflict resolution (interactive): warn per-file, prompt overwrite / skip / backup-then-link (.bak). Non-interactive mode: skip conflicts.
- Remote deployment: clone dotclaude repo on remote machine, then symlink — same ownership model everywhere

### Deploy System Architecture
- Single `deploy.sh` with subcommands: `deploy.sh global` (sets up ~/.claude/) and `deploy.sh project` (scaffolds a specific project)
- .env-driven configuration: all choices stored in `.env` (gitignored). `.env.example` committed with all settings documented. Each machine has its own `.env`.
- `deploy.sh` reads `.env` from repo root. First run without `.env` triggers wizard. Re-runs read `.env` silently. `--interactive` re-runs wizard.
- Non-interactive mode: `deploy.sh global --target DIR` (and other flags) skips wizard entirely

### Global Deploy Wizard (`deploy.sh global`)
- Step-by-step sequential prompts (8 steps):
  1. Deploy target (local ~/.claude/ or remote SSH host)
  2. Settings.json configuration
  3. CLAUDE.md section toggles
  4. Hooks — list each available hook individually, enable/disable
  5. Skills — which skills/commands to deploy
  6. GSD framework install (yes/no)
  7. Git identity (configure or use system default)
  8. Conflict review (only if existing files detected)
- Dynamic discovery — wizard scans repo directories to find available hooks/skills/agents/rules. No hardcoded lists. New additions to the repo automatically appear in the wizard.

### Project Deploy Wizard (`deploy.sh project`)
- Full wizard to guide users to best project setup
- Greenfield/brownfield detection — scans for existing `.claude/`, `CLAUDE.md`, `.git/info/exclude`
- Never blindly overwrites — same conflict resolution as global deploy
- Existing CLAUDE.md found → offer merge/append rather than replace
- Creates: `.claude/settings.json` (project permissions override), `CLAUDE.md` (project-specific), `.git/info/exclude` entries, optional project commands
- Detects project type (Python/Node/Go/etc.) from existing files, adjusts defaults accordingly

### CLAUDE.md Build System
- CLAUDE.md is the ONE exception to symlinks-only — it is built (assembled/generated), not symlinked
- Single source CLAUDE.md with toggleable sections controlled by .env flags (e.g., `CLAUDE_SIMPLICITY=true`, `CLAUDE_GIT=true`, `CLAUDE_PYTHON=true`)
- deploy.sh assembles the final CLAUDE.md from section templates + .env settings

### Profile System
- No named profile presets — .env IS the profile
- Each .env flag controls a specific aspect (settings, CLAUDE.md sections, hooks, skills)
- Per-machine configuration: each deployment (local or remote) has its own .env

### Git Hooks (via core.hooksPath)
- `core.hooksPath` set globally to `~/.claude/git-hooks/` — all repos use the same hook scripts automatically
- Hook scripts are config-driven: read per-project `.claude/hooks.conf` to determine behaviour
- Projects without `.claude/hooks.conf` get sensible defaults
- Universal rules baked into hooks (e.g., AI attribution check — always applies)
- Per-project rules controlled by config (e.g., `CONVENTIONAL_COMMITS=true/false`, `BRANCH_PROTECTION=warn/block`)
- `deploy.sh project` wizard creates `.claude/hooks.conf` with project-appropriate settings

### Hook Behaviour
- Auto-fix when safe: formatting hooks (ruff) auto-fix silently
- Validation hooks always block with explanation + suggested fix (e.g., "Commit blocked: message doesn't follow conventional format. Expected: type(scope): description")
- Main branch protection: default warn-only. Projects opt into hard block via `.claude/hooks.conf` (`BRANCH_PROTECTION=block`)

### Settings.json
- Ship settings.json with deny rules as specified (*.pem, *credentials*, *secret* → deny; .env → ask)
- Accept known Claude Code bugs (#6699, #8961) — no PreToolUse hook workaround. Rules will work when upstream fixes land.
- Project settings.json overrides global (native Claude Code behaviour)

### Deploy & Scan Paths
- No hardcoded directories — dotclaude never creates new directories, deploys wherever the user specifies
- Deploy target path stored in .env (`DEPLOY_TARGET=~/.claude` or any path)
- Scan paths stored in .env (`SCAN_PATHS=~/Repositories,~/Projects` — comma-separated, multiple allowed)
- Directory topology varies per machine — no assumptions about ~/Repositories or similar
- Wizard scan setup should be smart:
  - Probe common development directories (~/, ~/Projects, ~/code, ~/src, ~/Repositories, ~/Developer, ~/workspace, etc.)
  - Show which exist on this machine, let user select/add
  - Offer recursive scan option: find directories containing `.claude/` files as candidates
  - User can always manually specify paths

### Registry Scanner
- Dual purpose: (1) feeds deploy wizard with available configs from dotclaude repo, (2) audits what's deployed across projects
- Scan paths read from .env (see above) — no hardcoded defaults
- Output: human-readable table by default, `--json` flag for machine-readable
- Reports: project path, configs found (settings, CLAUDE.md, hooks, skills), sync status (up-to-date/outdated/custom)

### Skills
- /commit: relaxed on branches, conventional commit format on main
- /squash-merge: guides through full squash merge workflow
- /simplicity-check: on-demand complexity review against simplicity rules
- Skills deployed via symlinks (same as other files)

### Claude's Discretion
- Settings.json exact allow/deny/ask rule granularity beyond what's specified
- CLAUDE.md section template content and build mechanism
- Deploy wizard prompt wording and UX details
- Registry scanner implementation (script language, scan algorithm)
- Exact .claude/hooks.conf format and default values
- Project type detection heuristics

</decisions>

<specifics>
## Specific Ideas

- Repo is the SSOT for all Claude configs — should be documented in repo README/CLAUDE.md
- "I want this repo to detect, scan and dynamically develop as the generic SSOT for all my Claude configs from which I can deploy specific instances into projects"
- .env.example should be comprehensive — document every setting with comments and defaults
- Ruff already auto-formats via PostToolUse hook — carry forward existing behaviour
- Pre-commit hook has COMMIT_EDITMSG timing bug — must fix by moving validation to commit-msg hook (known from Phase 1)

</specifics>

<deferred>
## Deferred Ideas

- Rename repo to "dotconfigs" and manage both Claude and git configs from a monorepo — new milestone/phase
- Cloud sync for .env across machines — future consideration

</deferred>

---

*Phase: 03-settings-hooks-deploy-skills*
*Context gathered: 2026-02-06*
