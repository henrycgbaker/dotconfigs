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
- [x] **Phase 7: Integration & Polish** - Status/list commands, conflict detection, testing, documentation
- [x] **Phase 8: Hooks & Workflows Review** - Audit and rationalise hook/workflow placement across claude and git plugins
- [ ] **Phase 9: Config UX Redesign** - Opt-in config selection, project-configs wizard with global value indicators, CLAUDE.md exclusion, fix remaining bugs

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

### Phase 8: Hooks & Workflows Review
**Goal**: Audit and rationalise all hooks and workflow enforcement across claude and git plugins — ensure each mechanism lives in the right plugin with the right enforcement level
**Depends on**: Phase 7
**Plans:** 6 plans

Plans:
- [x] 08-01-PLAN.md — Config architecture + unified variable naming + existing hook refactor
- [x] 08-02-PLAN.md — Squash-merge audit + explore agent research
- [x] 08-03-PLAN.md — New git hooks (pre-commit, prepare-commit-msg, post-merge, post-checkout, post-rewrite)
- [x] 08-04-PLAN.md — Claude PreToolUse hook + settings template
- [x] 08-05-PLAN.md — Setup wizard + deploy + project expansion for full hook roster
- [x] 08-06-PLAN.md — Auto-generated roster documentation + README updates

**Scope includes these pending todos:**
- Review squash-merge vs native git merge workflow
- Evaluate explore agent hook (sonnet model for explore agents)
- Add brief GSD framework mention to README

**Success Criteria** (what must be TRUE):
  1. Every hook/enforcement mechanism has a clear rationale for which plugin owns it
  2. AI attribution blocking placement decided (git hook only vs both plugins)
  3. Conventional commit enforcement level decided and implemented (soft warn vs hard block)
  4. hooks.conf profiles live in the correct plugin directory
  5. No redundant overlap between plugins (or overlap is intentional and documented)
  6. Missing enforcement gaps identified and addressed
  7. Configuration hierarchy documented (hooks.conf vs .env vs hardcoded)
  8. Squash-merge vs git merge workflow decision made and implemented
  9. Explore agent hook evaluated (add or defer with rationale)
  10. README updated with GSD framework mention

### Phase 9: Config UX Redesign
**Goal**: Complete the configuration UX overhaul: opt-in config selection, project-configs wizard with global value indicators, settings.json logical separation, CLAUDE.md exclusion, .env→JSON migration discussion, CLI naming fix, and remaining bug fixes
**Depends on**: Phase 8 + Quick Task 002 (CLI restructure)
**Plans:** 9 plans (5 original + 4 gap closure)

Plans:
- [x] 09-01-PLAN.md — CLI naming reversal (dotconfigs primary, dots symlink) + list terminology fix
- [x] 09-02-PLAN.md — Lib infrastructure (G/L colour badges, wizard helpers, settings template, .gitignore)
- [x] 09-03-PLAN.md — Claude global-configs wizard rewrite (opt-in categories, edit mode)
- [x] 09-04-PLAN.md — Git global-configs wizard rewrite (opt-in categories, select→read, edit mode)
- [x] 09-05-PLAN.md — Project-configs G/L indicators + CLAUDE.md exclusion in deploy + settings assembly
- [x] 09-06-PLAN.md — [gap closure] Fix boolean opt-out and collection defaults in claude/setup.sh
- [x] 09-07-PLAN.md — [gap closure] Remove legacy githooks/, orphaned functions, record .env→JSON deferral
- [x] 09-08-PLAN.md — [gap closure] README overhaul (naming, commands, architecture diagram, directory tree)
- [x] 09-09-PLAN.md — [gap closure] Fix docs/usage-guide.md (remove TODO, fix dotclaude references)

**Bundled todos:**
- .env → JSON migration (needs discussion during planning)
- settings.json wizard design (resolved: Option A with logical separation)
- Rename CLI (resolved: revert rename, add `dots` as alias)
- dotgit hooks management (subsumed by opt-in toggleable hooks)

**Success Criteria** (what must be TRUE):
  1. `dotconfigs global-configs {plugin}` shows all available configs — user picks which to manage (opt-in)
  2. Selected configs show opinionated defaults (user can change) — unselected configs remain unset in .env
  3. `dotconfigs project-configs {plugin}` shows all configs with visual indicators for globally-set values (bold/colour/label)
  4. Project-level config overrides global (standard local-over-global precedence)
  5. CLAUDE.md exclusion applied during `dotconfigs deploy` — pattern written to .git/info/exclude (NOT .gitignore)
  6. Per-project CLAUDE.md override available in `dotconfigs project-configs`
  7. No hardcoded defaults fill unset values — if user doesn't set it, it stays unset
  8. All remaining `select` loops replaced with `read` prompts (2 in git setup, 1 in claude project)
  9. CLI naming: `dotconfigs` is primary executable, `dots` is convenience alias/symlink. All docs reference `dotconfigs`
  10. `dotconfigs list` says "deployed" / "not deployed" instead of "installed" / "not installed"
  11. settings.json: core defaults deployed in initial setup, hooks added later via hooks wizard (clean logical separation)
  12. Root settings.json gitignored (personal instance), template in plugins/claude/templates/
  13. .env → JSON migration: discuss during planning, implement if agreed (or defer to v3)

**Design decisions (from UAT discussion):**

*Config selection model:*
- **Opt-in model:** User explicitly chooses which configs to manage at each level. Not "set everything with defaults" — opt-in to manage, opt-out from suggested value
- **Unset = unset:** If user doesn't pick a config, nothing is written. No hardcoded fallback. Tools handle missing values gracefully
- **Global vs local:** global-configs sets .env (user's defaults), project-configs overrides per-project. Same wizard principle, project-configs additionally shows what's already set globally
- **Precedence:** Per-project config → .env (global) → unset. Each tool/plugin resolves its own precedence — brief mention in docs, not detailed (out of scope)

*CLI naming:*
- **Repo name:** `dotconfigs` (keep)
- **Tool/executable:** `dotconfigs` (keep as primary)
- **CLI shortcut:** `dots` as alias/symlink to `dotconfigs` (convenience only)
- **Docs:** All reference `dotconfigs`. Mention `dots` alias once in README
- **Action:** Revert quick task 002 rename (currently backwards: `dots` is primary, `dotconfigs` is symlink)

*settings.json:*
- **Option A:** Deploy with sensible core defaults (deny secrets, ask .env). No interactive rule configuration
- **Logical separation:** Initial setup deploys core settings.json (permissions, sandbox). Hooks (PostToolUse formatter, PreToolUse guard) are configured LATER through the hooks section of the wizard, then injected into settings.json during deploy
- **Template selection:** Wizard asks which language rules to include (python, node, both, none) — trivial addition
- **Personal instance:** Root settings.json must be gitignored before repo goes public. Contains user-specific rules (nvidia-smi, docker, /proc/* reads)
- **Template:** Clean assembled version in plugins/claude/templates/ is the public template

*CLAUDE.md exclusion:*
- Goes in .git/info/exclude (NOT .gitignore — no Claude/CLAUDE.md references in tracked files)
- Global default set in setup + per-project override in project-configs
- User wants ALL CLAUDE.md files excluded from all repos generally

*.env → JSON migration (discussion needed):*
- Current .env has quoting issues (fixed but symptomatic of format limitations)
- JSON would allow: nesting, arrays, types, no quoting issues, consistency with .dotconfigs.json
- Concerns: jq dependency (bash 3.2 portability), migration path for existing users, scope of changes
- Decision: discuss during Phase 9 planning, implement or defer to v3

## Progress

**Execution Order:**
Phases execute in numeric order: 4 → 5 → 6 → 7 → 8 → 9
(Phases 5 and 6 may run in parallel if infrastructure is stable after Phase 4)

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 4. Core Infrastructure & CLI Entry Point | 2/2 | ✓ Complete | 2026-02-07 |
| 5. Claude Plugin Extraction | 5/5 | ✓ Complete | 2026-02-07 |
| 6. Git Plugin | 3/3 | ✓ Complete | 2026-02-07 |
| 7. Integration & Polish | 5/5 | ✓ Complete | 2026-02-07 |
| 8. Hooks & Workflows Review | 6/6 | ✓ Complete | 2026-02-08 |
| 9. Config UX Redesign | 9/9 | ✓ Complete | 2026-02-09 |

## Accumulated Context

### From v1.0

- **GSD coexistence:** File-level symlinks for dotclaude's own files (commands/*.md, hooks/*), so GSD and dotclaude coexist in ~/.claude/
- **Settings.json bug:** Deny rules have Claude Code bugs (#6699, #8961) — PreToolUse hook workaround in place
- **Bash 3.2 fixes:** Branch has uncommitted fixes for `local -n`, `${var,,}`, wizard pre-fill — fold into Phase 4

### Deferred to v3

- **.env → JSON migration:** Discussed during Phase 9 planning. Current .env format works well — quoting bug was fixed in quick-002 and is not symptomatic of deeper format issues. JSON would require jq dependency (problematic for bash 3.2 portability) and a migration path for existing users. Deferred to v3 if the need arises.

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
