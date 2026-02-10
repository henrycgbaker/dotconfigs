# Roadmap: dotconfigs v3.0

## Overview

Targeted architecture rethink for dotconfigs -- fix the blocking hook path bug, migrate from .env to JSON config, decouple wizards from deploy, streamline the CLI, and add per-module scope. Not a rewrite: the v2.0 plugin architecture is sound; v3.0 fixes the deployment model on top of it. Shell plugin deferred to v4.0.

Phase numbering continues from v2.0 (phases 4-9 complete).

## Phases

**Phase Numbering:**
- Integer phases (10, 11, 12, 13, 14): Planned milestone work
- Decimal phases (11.1, 11.2): Urgent insertions (marked with INSERTED)

- [ ] **Phase 10: Hook Path Resolution** - Fix global hooks to use absolute paths, project hooks to use relative paths, bake all paths at deploy time
- [ ] **Phase 11: JSON Config Foundation** - JSON schema, global + project config.json, .dotconfigs/ directory, jq dependency
- [ ] **Phase 12: Wizard Refactor** - Wizards write JSON config, deploy reads JSON independently, adapt existing wizards
- [ ] **Phase 13: CLI Restructure + Per-Module Scope** - Merge wizard+deploy commands, add flags, per-module scope as config
- [ ] **Phase 14: Migration + Documentation** - .env-to-JSON migration helper, beginner-friendly README, architecture diagram

## Phase Details

### Phase 10: Hook Path Resolution
**Goal**: Global Claude hooks work correctly in any project directory, not just the dotconfigs repo
**Depends on**: Nothing (independent blocking bug fix)
**Requirements**: PATH-01, PATH-02, PATH-03
**Success Criteria** (what must be TRUE):
  1. Running `claude` in any project directory triggers global hooks from `~/.claude/hooks/` (symlinked to dotconfigs repo)
  2. Project-level hooks use relative `.claude/hooks/` paths that resolve correctly within the project
  3. No `$CLAUDE_PROJECT_DIR` variables appear in any deployed settings.json or hook references -- all paths are baked at deploy time
  4. Existing hook functionality (block-destructive, post-tool-format, PreToolUse guard) is preserved
**Plans**: TBD

Plans:
- [ ] 10-01: TBD

### Phase 11: JSON Config Foundation
**Goal**: Both global and project configuration stored as JSON with a versioned schema, replacing .env as the primary config format
**Depends on**: Phase 10 (hook paths must be correct before config references them)
**Requirements**: CONF-05, CONF-06, CONF-07, CONF-08, CONF-10, PROJ-01, PROJ-02, PROJ-03
**Success Criteria** (what must be TRUE):
  1. Global `config.json` exists in the dotconfigs repo root with a `"version": "3.0"` field and records only user choices (enabled modules, scope preferences)
  2. Project `.dotconfigs/config.json` exists per-repo with the same schema, recording project-level overrides
  3. `.dotconfigs/` directory is automatically excluded via `.git/info/exclude` when created
  4. `dotconfigs` validates `.dotconfigs/` existence on any project command invocation (clear error if missing)
  5. `jq` dependency is checked at setup time with install instructions for macOS (`brew install jq`) and Linux
**Plans**: TBD

Plans:
- [ ] 11-01: TBD
- [ ] 11-02: TBD

### Phase 12: Wizard Refactor
**Goal**: Wizards and deploy are fully decoupled -- wizards write JSON config, deploy reads JSON config, either can run independently
**Depends on**: Phase 11 (JSON config must exist for wizards to write to)
**Requirements**: WIZD-01, WIZD-02, WIZD-03
**Success Criteria** (what must be TRUE):
  1. Running `dotconfigs setup claude` writes choices to `config.json` (not `.env`) -- wizard output is a JSON file
  2. Running `dotconfigs deploy claude` reads `config.json` and deploys without asking any questions -- deploy is wizard-independent
  3. Hand-editing `config.json` and running deploy produces the same result as using the wizard
  4. Existing wizard flows (claude setup, git setup, project scaffolding) work with the new JSON backend -- adapted, not rewritten
  5. Config schema is forward-compatible with v4.0 wizard UX layer (no structural dead ends)
**Plans**: TBD

Plans:
- [ ] 12-01: TBD
- [ ] 12-02: TBD

### Phase 13: CLI Restructure + Per-Module Scope
**Goal**: Streamlined CLI commands that merge wizard + deploy with confirmation, plus per-module scope control for granular deployment
**Depends on**: Phase 12 (wizards must be decoupled before merging wizard+deploy into single commands)
**Requirements**: CLI-08, CLI-09, CLI-10, CLI-11, CLI-12, SCOP-01, SCOP-02, SCOP-03
**Success Criteria** (what must be TRUE):
  1. `dotconfigs global` runs wizard then shows a confirmation summary and deploys (replacing `global-configs`)
  2. `dotconfigs project` runs wizard then shows a confirmation summary and deploys (replacing `project-configs`/`project-init`)
  3. Old command names (`global-configs`, `project-configs`, `project-init`) produce deprecation warnings pointing to new names
  4. `dotconfigs deploy` re-deploys from existing config without running any wizard
  5. `--no-deploy`, `--dry-run`, and `--yes` flags work on `global` and `project` commands
  6. Each module (hook, config, skill) can be independently scoped to global, project, or both -- scope stored in `config.json`
  7. Deploy targets follow conventions: hooks deploy to `hooks/`, skills deploy to `commands/` -- no per-file path configuration needed
**Plans**: TBD

Plans:
- [ ] 13-01: TBD
- [ ] 13-02: TBD

### Phase 14: Migration + Documentation
**Goal**: Seamless upgrade path from v2.0 and clear documentation for new users
**Depends on**: Phase 13 (documents and migrates to the final v3.0 state)
**Requirements**: CONF-09, DOC-01, DOC-02
**Success Criteria** (what must be TRUE):
  1. Running `dotconfigs migrate` (or equivalent) converts existing `.env` to `config.json` with a backup of the original file
  2. Migration preserves all user choices from `.env` -- no config loss
  3. README covers installation, first-run experience, daily usage, and plugin overview in a beginner-friendly tone
  4. Architecture diagram shows the plugin -> module -> deploy flow and global/project config layering
**Plans**: TBD

Plans:
- [ ] 14-01: TBD
- [ ] 14-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 10 -> 11 -> 12 -> 13 -> 14

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 10. Hook Path Resolution | 0/0 | Not started | - |
| 11. JSON Config Foundation | 0/0 | Not started | - |
| 12. Wizard Refactor | 0/0 | Not started | - |
| 13. CLI Restructure + Per-Module Scope | 0/0 | Not started | - |
| 14. Migration + Documentation | 0/0 | Not started | - |
