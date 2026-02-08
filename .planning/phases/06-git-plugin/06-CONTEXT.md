# Phase 6: Git Plugin - Context

**Gathered:** 2026-02-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Git configuration management through `plugins/git/` — identity, workflow settings, hooks, and aliases. Full wizard + deploy flow following the established plugin pattern. Includes `project.sh` for per-repo deployment (hooks). Global config via `git config --global`, per-repo via `dotconfigs project`.

</domain>

<decisions>
## Implementation Decisions

### Identity & scope
- Single identity (one name + email), applied globally via `git config --global`
- Name + email only — no GPG signing
- .env is the source of truth (GIT_* prefix)
- First-run wizard pre-fills from existing git config if no .env keys exist; after that, .env values pre-fill
- Deploy warns on drift (if git config differs from .env) before overwriting
- Global identity only for deploy; per-repo identity is Claude's discretion via project.sh

### Hook behaviour
- commit-msg hook: conventional commit validation (enforce `type(scope): description` format)
- Pre-push hook scope and deployment model: **deferred to research**
  - Research should cover: global vs per-project hooks, `core.hooksPath` implications, coexistence between Claude Code hooks and git hooks, best practices
- Claude Code hooks (PreToolUse/PostToolUse → `~/.claude/hooks/`) remain managed by Claude plugin — separate concern

### Wizard flow
- Grouped sections with menu to pick (not linear walk-through)
- Menu shows section status: configured vs not configured
- "Configure all" option walks through every section sequentially
- "Done — save and exit" option in menu triggers summary + confirm
- After configuring a section, returns to menu (pick another or Done)
- Always pre-fill from .env values (whether configuring one section or all)
- Opinionated defaults: settings enabled by default (pull.rebase=true, defaultBranch=main, etc.), user opts out
- Summary + confirm before saving to .env (consistent with Claude plugin)

### Alias design
- Default alias set (all enabled by default, user can disable any):
  - `git unstage` → `reset HEAD --`
  - `git last` → `log -1 HEAD`
  - `git lg` → `log --oneline --graph --all --decorate`
  - `git amend` → `commit --amend --no-edit`
  - `git undo` → `reset HEAD~1 --mixed`
  - `git wip` → `commit -am "WIP"`
- User can add custom aliases via wizard
- Deploy warns + overwrites if alias exists with a different definition (drift warning pattern)

### Claude's Discretion
- Per-repo identity handling in project.sh (whether to include it)
- .env storage format for aliases (one key per alias vs serialised)
- Exact pre-push hook behaviour (informed by research)
- Workflow settings set: research which `git config` settings to include beyond pull.rebase and init.defaultBranch

</decisions>

<specifics>
## Specific Ideas

- Wizard should be consistent with Claude plugin wizard — both should use grouped/modular menu pattern
- Drift warning model (warn before overwrite) applies to both identity and aliases
- `dotconfigs project` already supports multi-plugin iteration — `plugins/git/project.sh` follows the established pattern

</specifics>

<deferred>
## Deferred Ideas

- **Claude wizard modularisation** — update existing Claude plugin wizard to match the grouped/menu pattern for consistency (change to Phase 5 / separate task)
- **Per-repo git project support** — extending `dotconfigs project` with git identity overrides beyond hooks (future enhancement)

</deferred>

---

*Phase: 06-git-plugin*
*Context gathered: 2026-02-07*
