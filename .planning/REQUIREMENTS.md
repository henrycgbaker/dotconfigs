# Requirements: dotconfigs (formerly dotclaude)

**Defined:** 2026-02-06
**Core Value:** Single source of truth for all personal dev configuration — one repo, one CLI, one `.env`, deployed everywhere with minimal context footprint.

## v1.0 Requirements (Complete)

All 29 v1.0 requirements delivered. See MILESTONES.md for summary.

<details>
<summary>v1.0 requirement list (archived)</summary>

### Context Reduction

- [x] **CTXT-01**: Global CLAUDE.md reduced to <100 lines containing only what Claude can't infer
- [x] **CTXT-02**: Rules/ directory eliminated -- content condensed to brief CLAUDE.md lines or dropped
- [x] **CTXT-03**: Session context burn measured and reduced from ~28% to <10%

### Settings & Permissions

- [x] **SETT-01**: Global settings.json with clean allow/deny/ask permissions
- [x] **SETT-02**: Project-level settings.json templates
- [x] **SETT-03**: Clear layering: global defaults → project overrides
- [x] **SETT-04**: Sensitive file protection — deny for secrets, ask for .env
- [x] **SETT-05**: block-sensitive.py hook removed, replaced by settings.json rules

### Hooks & Enforcement

- [x] **HOOK-01**: Auto-format hook (Ruff for Python via PostToolUse)
- [x] **HOOK-02**: Git commit-msg hook for conventional commits
- [x] **HOOK-03**: Git commit-msg hook blocking AI attribution
- [x] **HOOK-04**: Layered main branch protection
- [x] **HOOK-05**: All git hooks deployed as local-only

### Deployment

- [x] **DEPL-01** through **DEPL-09**: Configurable deploy.sh, wizard, CLI, project scaffolding, remote deployment, git identity, GSD option, .env.example

### Other

- [x] **GHYG-01/02**, **QUAL-01/02**, **SKIL-01/02**, **RGST-01**: Git hygiene, quality guards, skills, registry scanning

</details>

## v2.0 Requirements

### Plugin Infrastructure

- [ ] **PLUG-01**: Plugin discovery via filesystem scan of `plugins/*/` — no hardcoded plugin names in CLI
- [ ] **PLUG-02**: Plugin interface contract — each plugin provides `setup.sh` and `deploy.sh` with standard function signatures (`plugin_<name>_setup`, `plugin_<name>_deploy`)
- [ ] **PLUG-03**: Lazy plugin loading — plugins sourced only when invoked, not at startup
- [ ] **PLUG-04**: Shared library layer — `lib/*.sh` (wizard, symlinks, discovery, validation) sourced by plugins and entry point
- [ ] **PLUG-05**: Plugin isolation — plugins import only from `lib/`, never from other plugins

### CLI Restructure

- [ ] **CLI-01**: Single `dotconfigs` entry point script with subcommand routing
- [ ] **CLI-02**: `dotconfigs setup [plugin]` runs per-plugin interactive wizard
- [ ] **CLI-03**: `dotconfigs deploy [plugin]` performs per-plugin deployment from .env
- [ ] **CLI-04**: `dotconfigs status [plugin]` shows current deployment state
- [ ] **CLI-05**: `dotconfigs list` shows available plugins with status
- [ ] **CLI-06**: Per-command and per-plugin help (`dotconfigs help [command]`)

### Claude Plugin (Migration)

- [ ] **CLPL-01**: Wizard code migrated to `plugins/claude/setup.sh` — feature parity with current deploy.sh wizard
- [ ] **CLPL-02**: Deploy code migrated to `plugins/claude/deploy.sh` — CLAUDE.md build, settings.json, hooks, skills deployment
- [ ] **CLPL-03**: Assets moved under `plugins/claude/` (hooks/, commands/, templates/)
- [ ] **CLPL-04**: Project scaffolding preserved (`dotconfigs project .`)

### Git Plugin (New)

- [ ] **GITP-01**: Git hooks deployment — commit-msg and pre-push from `plugins/git/hooks/` to `.git/hooks/`
- [ ] **GITP-02**: Git identity wizard — configure global user.name and user.email
- [ ] **GITP-03**: Git workflow settings — init.defaultBranch, pull.rebase, push.default
- [ ] **GITP-04**: Git aliases — st, co, br, ci, unstage, last
- [ ] **GITP-05**: Hook scope — per-project deployment by default, opt-in global core.hooksPath with conflict warning

### Configuration

- [ ] **CONF-01**: .env namespacing — plugin-prefixed keys (CLAUDE_*, GIT_*)
- [ ] **CONF-02**: Unified .env file across all plugins — single source of config
- [ ] **CONF-03**: Pre-filled wizard defaults from existing .env on re-run (already partially built on branch)
- [ ] **CONF-04**: .env versioning (DOTCONFIGS_VERSION=2.0) with auto-migration from v1 schema

### Migration & Compatibility

- [ ] **MIGR-01**: Strangler fig migration — incremental extraction from deploy.sh into plugins
- [ ] **MIGR-02**: deploy.sh deprecated with wrapper that routes to `dotconfigs` CLI
- [ ] **COMP-01**: Bash 3.2 compatible — no namerefs, associative arrays, or bash 4 string ops
- [ ] **COMP-02**: macOS and Linux portable
- [ ] **COMP-03**: GSD framework coexistence maintained — file-level symlinks

### Quality

- [ ] **QUAL-03**: Idempotent deploy — running deploy twice produces same result
- [ ] **QUAL-04**: Conflict detection — warn before overwriting non-owned files

## Out of Scope

| Feature | Reason |
|---------|--------|
| Plugin marketplace/registry | Premature — personal config, not a framework |
| Cross-plugin dependencies | Breaks isolation; use shared lib instead |
| Plugin versioning | Plugins ship together in repo — git commit is the version |
| GUI or TUI interface | Adds complexity, breaks scriptability |
| Auto-update mechanism | git pull is sufficient |
| Full dotfiles management (vim, tmux) | Only dev-tool configs that benefit from SSOT |
| Shell plugin | Deferred to v3 |
| Conditional git identity switching | Complex (Git 2.36+ includeIf) — deferred to v2.1+ |
| SSH key per identity | Links to conditional identity — deferred |
| Rollback capability | Over-engineering for personal config |
| Windows support | macOS/Linux only |
| Configuration import from other tools | Scope creep |
| Team collaboration features | Personal configuration tool |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PLUG-01 | Phase 4 | Pending |
| PLUG-02 | Phase 4 | Pending |
| PLUG-03 | Phase 4 | Pending |
| PLUG-04 | Phase 4 | Pending |
| PLUG-05 | Phase 4 | Pending |
| CLI-01 | Phase 4 | Pending |
| CLI-02 | Phase 5 | Pending |
| CLI-03 | Phase 5 | Pending |
| CLI-04 | Phase 7 | Pending |
| CLI-05 | Phase 7 | Pending |
| CLI-06 | Phase 7 | Pending |
| CLPL-01 | Phase 5 | Pending |
| CLPL-02 | Phase 5 | Pending |
| CLPL-03 | Phase 5 | Pending |
| CLPL-04 | Phase 5 | Pending |
| GITP-01 | Phase 6 | Pending |
| GITP-02 | Phase 6 | Pending |
| GITP-03 | Phase 6 | Pending |
| GITP-04 | Phase 6 | Pending |
| GITP-05 | Phase 6 | Pending |
| CONF-01 | Phase 5 | Pending |
| CONF-02 | Phase 5 | Pending |
| CONF-03 | Phase 5 | Pending |
| CONF-04 | Phase 5 | Pending |
| MIGR-01 | Phase 5 | Pending |
| MIGR-02 | Phase 7 | Pending |
| COMP-01 | Phase 4 | Pending |
| COMP-02 | Phase 7 | Pending |
| COMP-03 | Phase 5 | Pending |
| QUAL-03 | Phase 7 | Pending |
| QUAL-04 | Phase 7 | Pending |

**Coverage:**
- v2.0 requirements: 31 total
- Mapped to phases: 31
- Unmapped: 0

---
*Requirements defined: 2026-02-06 (v1), 2026-02-07 (v2)*
*Last updated: 2026-02-07*
