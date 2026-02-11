# Requirements: dotconfigs

**Defined:** 2026-02-06 (v1), 2026-02-07 (v2), 2026-02-11 (v3 rewrite)
**Core Value:** Single source of truth for all personal dev configuration — one repo, one JSON config, deployed everywhere via symlinks.

## v1.0 Requirements (Complete)

All 29 v1.0 requirements delivered. See MILESTONES.md.

## v2.0 Requirements (Complete)

All 32 v2.0 requirements delivered. See MILESTONES.md.

## v3.0 Requirements

### Hook Path Resolution (Complete)

- [x] **PATH-01**: Global Claude hooks use absolute paths to `~/.claude/hooks/`
- [x] **PATH-02**: Project Claude hooks use relative `.claude/hooks/` paths
- [x] **PATH-03**: Deploy bakes all paths at deploy time — no unresolved variables

### JSON Config Schema (Complete)

- [x] **CONF-01**: `global.json` in dotconfigs repo root with nested group→module→{source, target} structure
- [x] **CONF-02**: `.dotconfigs/project.json` per-repo with same schema, targets relative to project root
- [x] **CONF-03**: `source` paths ALWAYS relative to dotconfigs repo root (in both global.json and project.json); `target` paths absolute/tilde-expanded (global) or relative to project root (project)
- [x] **CONF-04**: Top-level keys are arbitrary labels — tool discovers modules by finding `source`+`target` pairs at any depth. Renaming "claude" to "ai-tools" still works.
- [x] **CONF-05**: Required `method` field: `symlink`, `copy` (for user-editable files like .gitignore), or `append` (for adding patterns). Always explicit — no implicit defaults.
- [x] **CONF-06**: Optional `include` field: array of filenames to deploy from a directory source. Omit to deploy all files. Enables repo as archive with selective deployment.
- [x] **CONF-07**: Directory sources deploy each file individually (not directory symlink — preserves GSD coexistence)
- [x] **CONF-08**: `jq` dependency checked at setup/deploy time with install instructions

### Core Deploy (Complete)

- [x] **DEPL-01**: `dotconfigs deploy` reads global.json, symlinks/copies all modules to targets
- [x] **DEPL-02**: `dotconfigs deploy <group>` filters to a top-level key (e.g., `dotconfigs deploy claude`)
- [x] **DEPL-03**: Deploy is idempotent — running twice produces same result
- [x] **DEPL-04**: Deploy reports per-module status: created, updated, unchanged, skipped
- [x] **DEPL-05**: `--dry-run` flag previews all operations without writing
- [x] **DEPL-06**: `--force` flag overwrites conflicts without prompting
- [x] **DEPL-07**: Conflict detection — non-dotconfigs-owned files at target prompt for resolution

### Project Deploy (Complete)

- [x] **PROJ-01**: `dotconfigs project <path>` reads `.dotconfigs/project.json` from target path and deploys
- [x] **PROJ-02**: Source paths in project.json resolve against dotconfigs repo root
- [x] **PROJ-03**: `.dotconfigs/` auto-excluded via `.git/info/exclude` when created
- [x] **PROJ-04**: `dotconfigs project-init <path>` creates `.dotconfigs/project.json` with sensible defaults

### Git Config as File (Complete)

- [x] **GITF-01**: Git identity (user.name, user.email), workflow (pull.rebase, etc.), and aliases all maintained in `plugins/git/gitconfig` in Git's native INI format — no translation layer
- [x] **GITF-02**: Gitconfig symlinked directly to `~/.gitconfig` — no intermediate file, no `[include]` directive needed
- [x] **GITF-03**: Global excludes deployed directly to `~/.config/git/ignore`, referenced via `core.excludesFile` in gitconfig
- [x] **GITF-04**: `git config --global` commands write through the symlink back into `plugins/git/gitconfig` in the repo (visible in `git diff`, committable)

### Migration

- [ ] **MIGR-01**: `dotconfigs migrate` converts existing `.env` to `global.json` (one-time, with backup)
- [ ] **MIGR-02**: Migration preserves all user choices from `.env`
- [ ] **MIGR-03**: Old wizard commands (`global-configs`, `setup <plugin>`) show deprecation message pointing to global.json

### VS Code Plugin

- [ ] **VSCD-01**: `plugins/vscode/` directory with settings.json, keybindings.json, snippets/
- [ ] **VSCD-02**: VS Code config files in global.json with correct macOS target paths (`~/Library/Application Support/Code/User/`)
- [ ] **VSCD-03**: `plugins/vscode/extensions.txt` — list of installed extension IDs, auto-populated by `dotconfigs setup` via `code --list-extensions`
- [ ] **VSCD-04**: Extensions list deployed as reference file (actual install functionality deferred to v4)

### Shell Plugin

- [ ] **SHEL-01**: `plugins/shell/` directory with init.zsh, aliases.zsh (user adds `source` line to ~/.zshrc once)
- [ ] **SHEL-02**: Shell config files in global.json deployed to `~/.dotconfigs/shell/`

### Status & CLI

- [ ] **CLI-01**: `dotconfigs status` checks all symlinks against global.json config
- [ ] **CLI-02**: `dotconfigs list` shows all groups from global.json with deploy status
- [ ] **CLI-03**: `dotconfigs help` updated for new command set
- [ ] **CLI-04**: Simplified command set: `setup`, `deploy`, `project`, `project-init`, `status`, `list`, `migrate`, `help`

### Documentation

- [ ] **DOC-01**: Beginner-friendly README: install, first-run, daily usage, adding plugins
- [ ] **DOC-02**: `global.json` schema reference with examples
- [ ] **DOC-03**: Architecture diagram: repo structure → config → deploy → targets

## Out of Scope

| Feature | Reason |
|---------|--------|
| Interactive wizards | Deferred to v4.0 (see .planning/v4-v3-backup/) |
| Template assembly (CLAUDE.md fragments) | Deferred to v4.0 — maintain single file for v3 |
| Per-hook toggle configuration | Deferred — use `include` filter in config instead |
| Plugin marketplace/registry | Premature — personal config tool |
| Cross-plugin dependencies | Breaks isolation |
| GUI or TUI interface | Adds complexity |
| Windows support | macOS/Linux only |
| VS Code extension auto-install | Deferred to v4.0 — v3 captures list, v4 installs |
| Merge method for gitignore | Complex — use copy for v3, merge in v4 |

## Traceability

### v3.0

| Requirement | Phase | Status |
|-------------|-------|--------|
| PATH-01..03 | Phase 10 | Complete |
| CONF-01..08 | Phase 11 | Complete |
| DEPL-01..07 | Phase 11 | Complete |
| PROJ-01..04 | Phase 11 | Complete |
| GITF-01..04 | Phase 11 | Complete |
| MIGR-01..03 | Phase 12 | Pending |
| VSCD-01..04 | Phase 12 | Pending |
| SHEL-01..02 | Phase 12 | Pending |
| CLI-01..04 | Phase 12 | Pending |
| DOC-01..03 | Phase 13 | Pending |

**Coverage:** 37 v3.0 requirements mapped (26 complete, 11 pending)

---
*Last updated: 2026-02-11 (v3.0 simplification rewrite)*
