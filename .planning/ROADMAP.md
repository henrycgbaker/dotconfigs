# Roadmap: dotconfigs v2.0

## Overview

Transform dotclaude into dotconfigs — an extensible plugin-based configuration manager. Extract the monolithic deploy.sh (1085 lines) into a plugin architecture where `claude` and `git` become independent plugins sharing a common library layer. New `dotconfigs` CLI entry point replaces deploy.sh.

Phase numbering continues from v1.0 (phases 1–3 complete).

## Phases

**Phase Numbering:**
- Integer phases (4, 5, 6, 7): Planned milestone work
- Decimal phases (5.1, 5.2): Urgent insertions (marked with INSERTED)

- [x] **Phase 4: Core Infrastructure & CLI Entry Point** - Create dotconfigs entry point, shared lib, plugin discovery, interface contract
- [x] **Phase 5: Claude Plugin Extraction** - Migrate deploy.sh wizard and deployment into plugins/claude/ with .env namespacing
- [x] **Phase 6: Git Plugin** - New git plugin for hooks, identity, workflow settings, and aliases
- [ ] **Phase 7: Integration & Polish** - Status/list commands, conflict detection, testing, documentation

## Phase Details

### Phase 4: Core Infrastructure & CLI Entry Point
**Goal**: Working `dotconfigs` CLI that discovers plugins and routes subcommands — the skeleton onto which plugins are mounted
**Depends on**: v1.0 complete (branch has bash 3.2 fixes to fold in)
**Requirements**: PLUG-01, PLUG-02, PLUG-03, PLUG-04, PLUG-05, CLI-01, COMP-01
**Plans:** 2 plans

Plans:
- [x] 04-01-PLAN.md — Shared library layer (lib/wizard.sh, symlinks.sh, discovery.sh, validation.sh)
- [x] 04-02-PLAN.md — CLI entry point (dotconfigs) + plugin stubs (plugins/claude/) + end-to-end verification

**Success Criteria** (what must be TRUE):
  1. `dotconfigs setup claude` routes to and executes `plugins/claude/setup.sh`
  2. `dotconfigs deploy claude` routes to and executes `plugins/claude/deploy.sh`
  3. Adding a new plugin requires only creating `plugins/<name>/setup.sh` and `deploy.sh` — zero changes to entry point
  4. `lib/wizard.sh`, `lib/symlinks.sh`, `lib/discovery.sh` exist and are sourced by entry point
  5. All code is bash 3.2 compatible (no namerefs, associative arrays, bash 4 string ops)
  6. Plugin not found produces clear error message with list of available plugins

**Key decisions:**
- Entry point sources lib/*.sh eagerly (small files), plugins lazily (only when invoked)
- Plugin functions use `plugin_<name>_<action>` naming convention
- Validation helper `lib/validation.sh` added for common checks (is_git_repo, path_exists, etc.)

### Phase 5: Claude Plugin Extraction
**Goal**: All existing Claude Code configuration functionality works through `plugins/claude/` with the same UX as current deploy.sh
**Depends on**: Phase 4
**Requirements**: CLI-02, CLI-03, CLPL-01, CLPL-02, CLPL-03, CLPL-04, CONF-01, CONF-02, CONF-03, MIGR-01, COMP-03
**Plans:** 5 plans

Plans:
- [x] 05-01-PLAN.md — Move assets (templates, hooks, commands) into plugins/claude/ + update discovery
- [x] 05-02-PLAN.md — Setup wizard extraction (plugin_claude_setup with CLAUDE_* key prefixing)
- [x] 05-03-PLAN.md — Deploy logic extraction (plugin_claude_deploy with CLAUDE_* key reading)
- [x] 05-04-PLAN.md — Project command (dotconfigs project + plugin_claude_project with .dotconfigs.json)
- [x] 05-05-PLAN.md — Cleanup (delete deploy.sh, update .env.example, remove scripts/lib/)

**Success Criteria** (what must be TRUE):
  1. `dotconfigs setup claude` runs interactive wizard — identical UX to current `deploy.sh global`
  2. `dotconfigs deploy claude` deploys CLAUDE.md, settings.json, hooks, skills — identical result to current deploy
  3. `dotconfigs project .` scaffolds project with .claude/settings.json, CLAUDE.md, .git/info/exclude
  4. `.env` uses CLAUDE_* prefixed keys for claude-specific settings
  5. Wizard pre-fills from existing `.env` values on re-run
  6. Templates, hooks, and commands live under `plugins/claude/`
  7. GSD framework coexistence maintained (file-level symlinks)
  8. deploy.sh is deleted after extraction (clean break, no wrapper)

**Migration strategy:**
- Extract `cmd_global()` wizard steps → `plugin_claude_setup()`
- Extract `deploy_global()` deployment logic → `plugin_claude_deploy()`
- Extract `cmd_project()` → `plugin_claude_project()` (top-level `dotconfigs project` with plugin hooks)
- Move `hooks/`, `commands/`, `templates/` → `plugins/claude/`
- Delete `scripts/lib/` (replaced by `lib/` in Phase 4)
- Delete `deploy.sh` (clean break, no wrapper)

### Phase 6: Git Plugin
**Goal**: Git configuration (hooks, identity, workflow settings, aliases) managed through `plugins/git/` with full wizard and deploy flow
**Depends on**: Phase 4 (plugin infrastructure); Phase 5 optional but recommended (proves plugin pattern)
**Requirements**: GITP-01, GITP-02, GITP-03, GITP-04, GITP-05
**Plans:** 3 plans

Plans:
- [x] 06-01-PLAN.md — Hook templates (commit-msg, pre-push) + decouple git hooks from Claude plugin
- [x] 06-02-PLAN.md — Setup wizard (grouped menu with identity, workflow, aliases, hooks sections)
- [x] 06-03-PLAN.md — Deploy logic, per-project support, plugin metadata

**Success Criteria** (what must be TRUE):
  1. `dotconfigs setup git` runs wizard for git identity, workflow settings, aliases, hooks
  2. `dotconfigs deploy git` applies git configuration: hooks to .git/hooks/, identity via `git config --global`, workflow settings, aliases
  3. Git hooks (commit-msg, pre-push) deploy from `plugins/git/hooks/`
  4. `git config --global init.defaultBranch main` set when enabled
  5. `git config --global pull.rebase true` set when enabled
  6. Git aliases (st, co, br, ci, unstage, last) installed when enabled
  7. Hooks deploy per-project by default; global core.hooksPath opt-in with conflict warning
  8. All settings written to .env under GIT_* prefix

**Plugin structure:**
```
plugins/git/
├── setup.sh       # Identity, workflow, aliases, hooks wizard
├── deploy.sh      # Apply git config, deploy hooks
├── hooks/         # commit-msg, pre-push templates
└── templates/     # Git config snippets (gitconfig-workflow.conf)
```

### Phase 7: Integration & Polish
**Goal**: Production-ready dotconfigs CLI with status visibility, help, conflict detection, and clean migration
**Depends on**: Phases 5 and 6
**Requirements**: CLI-04, CLI-05, CLI-06, CLI-07, COMP-02, QUAL-03, QUAL-04
**Plans:** 5 plans

Plans:
- [x] 07-01-PLAN.md — Shared infrastructure (lib/colours.sh, drift detection, help system)
- [x] 07-02-PLAN.md — Status and list commands with per-file drift detection
- [x] 07-03-PLAN.md — Deploy enhancements (--dry-run, --force, conflict diff, summary)
- [x] 07-04-PLAN.md — Documentation (README with architecture diagrams, .env.example polish)
- [x] 07-05-PLAN.md — CLI usability (PATH symlink during deploy, smart project path detection)

**Success Criteria** (what must be TRUE):
  1. `dotconfigs status` shows deployment state across all plugins
  2. `dotconfigs status claude` shows claude-specific deployment state
  3. `dotconfigs list` shows available plugins with installed/not-installed status
  4. `dotconfigs help [command]` shows contextual help
  5. Running `dotconfigs deploy` twice is safe (idempotent)
  6. Deploying over existing non-owned files warns before overwriting
  7. Tested on macOS (bash 3.2) and Linux (bash 4+)
  8. README documents installation, CLI usage, and plugin overview
  9. `.env.example` documents all CLAUDE_* and GIT_* keys with descriptions and defaults
  10. `dotconfigs` is on PATH — callable from any directory

## Progress

**Execution Order:**
Phases execute in numeric order: 4 → 5 → 6 → 7
(Phases 5 and 6 may run in parallel if infrastructure is stable after Phase 4)

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 4. Core Infrastructure & CLI Entry Point | 2/2 | ✓ Complete | 2026-02-07 |
| 5. Claude Plugin Extraction | 5/5 | ✓ Complete | 2026-02-07 |
| 6. Git Plugin | 3/3 | ✓ Complete | 2026-02-07 |
| 7. Integration & Polish | 5/5 | ✓ Complete | 2026-02-07 |

## Accumulated Context

### From v1.0

- **GSD coexistence:** File-level symlinks for dotclaude's own files (commands/*.md, hooks/*), so GSD and dotclaude coexist in ~/.claude/
- **Settings.json bug:** Deny rules have Claude Code bugs (#6699, #8961) — PreToolUse hook workaround in place
- **Bash 3.2 fixes:** Branch has uncommitted fixes for `local -n`, `${var,,}`, wizard pre-fill — fold into Phase 4

### Target Directory Structure

```
dotconfigs/
├── dotconfigs              # CLI entry point
├── lib/                    # Shared libraries
│   ├── wizard.sh
│   ├── symlinks.sh
│   ├── discovery.sh
│   ├── validation.sh
│   └── colours.sh          # NEW in Phase 7
├── plugins/
│   ├── claude/
│   │   ├── setup.sh        # Wizard → .env
│   │   ├── deploy.sh       # .env → filesystem
│   │   ├── project.sh      # Project scaffolding
│   │   ├── hooks/          # Claude Code hooks
│   │   ├── commands/       # /commit, /squash-merge
│   │   ├── templates/      # CLAUDE.md sections, settings.json templates
│   │   └── DESCRIPTION     # Plugin metadata
│   └── git/
│       ├── setup.sh        # Git identity/workflow wizard
│       ├── deploy.sh       # Apply git config
│       ├── project.sh      # Per-project hooks + identity
│       ├── hooks/          # commit-msg, pre-push
│       └── DESCRIPTION     # Plugin metadata
├── .env                    # Unified config (all plugins, CLAUDE_*/GIT_* namespaced)
└── .env.example            # Documented settings
```
