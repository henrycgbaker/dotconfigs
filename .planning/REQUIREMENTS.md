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

## v2.0 Requirements (Complete)

All 32 v2.0 requirements delivered across phases 4-9. See MILESTONES.md for summary.

<details>
<summary>v2.0 requirement list (archived)</summary>

### Plugin Infrastructure

- [x] **PLUG-01**: Plugin discovery via filesystem scan of `plugins/*/`
- [x] **PLUG-02**: Plugin interface contract (`plugin_<name>_setup`, `plugin_<name>_deploy`)
- [x] **PLUG-03**: Lazy plugin loading
- [x] **PLUG-04**: Shared library layer (`lib/*.sh`)
- [x] **PLUG-05**: Plugin isolation — plugins import only from `lib/`

### CLI Restructure

- [x] **CLI-01**: Single `dotconfigs` entry point with subcommand routing
- [x] **CLI-02**: `dotconfigs setup [plugin]` runs per-plugin wizard
- [x] **CLI-03**: `dotconfigs deploy [plugin]` performs deployment from .env
- [x] **CLI-04**: `dotconfigs status [plugin]` shows deployment state
- [x] **CLI-05**: `dotconfigs list` shows plugins with status
- [x] **CLI-06**: Per-command and per-plugin help
- [x] **CLI-07**: `dotconfigs` on PATH via symlink

### Claude Plugin (Migration)

- [x] **CLPL-01** through **CLPL-04**: Wizard, deploy, assets, project scaffolding migrated to `plugins/claude/`

### Git Plugin (New)

- [x] **GITP-01** through **GITP-05**: Hooks, identity, workflow, aliases, hook scope

### Configuration

- [x] **CONF-01** through **CONF-04**: .env namespacing, unified config, pre-fill, versioning

### Migration & Compatibility

- [x] **MIGR-01/02**, **COMP-01/02/03**: Strangler fig, deploy.sh removed, bash 3.2, portability, GSD coexistence

### Quality

- [x] **QUAL-03/04**: Idempotent deploy, conflict detection

</details>

## v3.0 Requirements

### Hook Path Resolution

- [x] **PATH-01**: Global Claude hooks use absolute paths to `~/.claude/hooks/` (symlinks to dotconfigs repo)
- [x] **PATH-02**: Project Claude hooks use relative `.claude/hooks/` paths (resolved relative to project root)
- [x] **PATH-03**: Deploy bakes all paths at deploy time — no unresolved `$CLAUDE_PROJECT_DIR` variables in generated files

### JSON Configuration

- [ ] **CONF-05**: JSON config schema with version field (`"version": "3.0"`) for both global and project config
- [ ] **CONF-06**: Global `config.json` in dotconfigs repo root replaces `.env` as primary config
- [ ] **CONF-07**: Project `config.json` in `.dotconfigs/` per repo
- [ ] **CONF-08**: `jq` dependency checked in setup with install instructions
- [ ] **CONF-09**: Migration helper from `.env` to `config.json` (one-time, with backup)
- [ ] **CONF-10**: Config records user choices only (enabled modules, scope) — filesystem is the module manifest

### .dotconfigs/ Directory

- [ ] **PROJ-01**: `.dotconfigs/` directory replaces `.dotconfigs.json` for project-level config
- [ ] **PROJ-02**: `.dotconfigs/` auto-excluded via `.git/info/exclude` by default
- [ ] **PROJ-03**: `.dotconfigs/` existence validated on project command invocation

### CLI Restructure

- [ ] **CLI-08**: `global` command replaces `global-configs` (deprecation warning on old name)
- [ ] **CLI-09**: `project` command replaces `project-configs`/`project-init` (deprecation warning on old names)
- [ ] **CLI-10**: `global` and `project` merge wizard + deploy with confirmation summary before deploy
- [ ] **CLI-11**: `deploy` kept as explicit re-deploy from existing config (no wizard)
- [ ] **CLI-12**: `--no-deploy`, `--dry-run`, `--yes` flags for scripted/CI usage

### Wizard Refactor

- [ ] **WIZD-01**: Wizards write JSON config files (not `.env`)
- [ ] **WIZD-02**: Deploy reads JSON config independently of wizards (decoupled)
- [ ] **WIZD-03**: Adapt existing v2.0 wizards — refactor, don't discard. Schema designed for v4.0 wizard UX layer

### Per-Module Scope

- [ ] **SCOP-01**: Each module (hook/config/skill) independently scoped to global, project, or both
- [ ] **SCOP-02**: Scope is a deployment decision stored in config, not module metadata
- [ ] **SCOP-03**: Convention-based deploy targets — hooks→`hooks/`, skills→`commands/`

### Documentation

- [ ] **DOC-01**: Beginner-friendly README with installation, usage, and architecture overview
- [ ] **DOC-02**: Architecture diagram showing plugin → module → deploy flow

## Out of Scope

| Feature | Reason |
|---------|--------|
| Plugin marketplace/registry | Premature — personal config, not a framework |
| Cross-plugin dependencies | Breaks isolation; use shared lib instead |
| Plugin versioning | Plugins ship together in repo — git commit is the version |
| GUI or TUI interface | Adds complexity, breaks scriptability |
| Auto-update mechanism | git pull is sufficient |
| Full dotfiles management (vim, tmux, etc.) | Only dev-tool configs that benefit from SSOT |
| Shell plugin | Deferred to v4.0 (was v3.0 — descoped after research) |
| Conditional git identity switching | Complex (Git 2.36+ includeIf) — deferred |
| Rollback capability | Over-engineering for personal config |
| Windows support | macOS/Linux only |
| Team collaboration features | Personal configuration tool |
| Per-module manifest files | Filesystem IS the manifest — no metadata files needed |

## Traceability

### v2.0 (Complete)

| Requirement | Phase | Status |
|-------------|-------|--------|
| PLUG-01..05 | Phase 4 | Complete |
| CLI-01..07 | Phases 4-7 | Complete |
| CLPL-01..04 | Phase 5 | Complete |
| GITP-01..05 | Phase 6 | Complete |
| CONF-01..04 | Phase 5 | Complete |
| MIGR-01..02, COMP-01..03 | Phases 4-7 | Complete |
| QUAL-03..04 | Phase 7 | Complete |

### v3.0 (Active)

| Requirement | Phase | Status |
|-------------|-------|--------|
| PATH-01 | Phase 10 | Complete |
| PATH-02 | Phase 10 | Complete |
| PATH-03 | Phase 10 | Complete |
| CONF-05 | Phase 11 | Pending |
| CONF-06 | Phase 11 | Pending |
| CONF-07 | Phase 11 | Pending |
| CONF-08 | Phase 11 | Pending |
| CONF-09 | Phase 14 | Pending |
| CONF-10 | Phase 11 | Pending |
| PROJ-01 | Phase 11 | Pending |
| PROJ-02 | Phase 11 | Pending |
| PROJ-03 | Phase 11 | Pending |
| CLI-08 | Phase 13 | Pending |
| CLI-09 | Phase 13 | Pending |
| CLI-10 | Phase 13 | Pending |
| CLI-11 | Phase 13 | Pending |
| CLI-12 | Phase 13 | Pending |
| WIZD-01 | Phase 12 | Pending |
| WIZD-02 | Phase 12 | Pending |
| WIZD-03 | Phase 12 | Pending |
| SCOP-01 | Phase 13 | Pending |
| SCOP-02 | Phase 13 | Pending |
| SCOP-03 | Phase 13 | Pending |
| DOC-01 | Phase 14 | Pending |
| DOC-02 | Phase 14 | Pending |

**Coverage:**
- v2.0 requirements: 32/32 complete
- v3.0 requirements: 25/25 mapped

---
*Requirements defined: 2026-02-06 (v1), 2026-02-07 (v2), 2026-02-10 (v3)*
*Last updated: 2026-02-10*
