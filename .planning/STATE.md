# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-07)

**Core value:** Single source of truth for all personal dev configuration — one repo, one CLI, one `.env`, deployed everywhere with minimal context footprint.
**Current focus:** v2.0 Plugin Architecture — requirements and roadmap defined, ready for phase planning.

## Current Position

Phase: 8 of 8 (Hooks & Workflows Review)
Plan: 6 of 6 in phase
Status: Phase complete
Last activity: 2026-02-08 — Completed 08-06-PLAN.md execution

Progress: ██████████████ 100% (33/33 total plans across phases 4-8)

## Performance Metrics

**v1.0 (archived):**
- Total plans completed: 12
- Total execution time: 24min
- Average duration: 2.0min

**v2.0 (current):**
- Total plans completed: 22
- Total execution time: ~55.5min
- Average duration: 2.5min

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.

Key decisions carrying forward from v1:
- Subcommand CLI design (not flag-based)
- File-level symlinks for GSD coexistence
- .env for deploy configuration
- Settings.json layering (global → project)
- Hooks as local-only copies (not tracked in projects)
- macOS portability via perl for absolute path resolution
- bash select for menus (no dialog/whiptail dependencies)

New v2.0 decisions:
- [v2.0]: Rename dotclaude → dotconfigs
- [v2.0]: Plugin architecture (plugins/claude/, plugins/git/, shared lib/)
- [v2.0]: `dotconfigs` as CLI entry point name
- [v2.0]: Separate setup (wizard → .env) from deploy (.env → filesystem)
- [v2.0]: Git plugin covers hooks + identity + gitconfig workflow
- [v2.0]: Shell plugin deferred to v3
- [v2.0]: Bash 3.2 fixes already on branch (refactor/lean-claude-setup)
- [v2.0]: Strangler fig migration — deploy.sh deleted (clean break per user decision)
- [05-05]: deploy.sh clean break — deleted, not wrapped (user decision MIGR-01)
- [v2.0]: Plugin function naming: `plugin_<name>_<action>`
- [v2.0]: Eager lib loading, lazy plugin loading
- [04-01]: No shebangs in lib/ files (sourced libraries, not executables)
- [04-01]: Hybrid discovery.sh with plugin + legacy content discovery
- [04-01]: Filesystem-based plugin discovery (find + basename pattern)
- [04-02]: Subcommand-based CLI design (verified and implemented)
- [04-02]: Lazy plugin loading (source on-demand in cmd_setup/cmd_deploy)
- [04-02]: No shebang in plugin files (sourced libraries, not executables)
- [04-02]: Error output to stderr, usage to stdout, non-zero exit codes
- [05-01]: Assets organized under plugins/claude/ with subdirectories for templates, hooks, commands
- [05-01]: Discovery functions accept plugin_dir parameter for flexibility
- [05-01]: discover_hooks_conf_profiles function added for hooks.conf profile discovery
- [05-01]: All lib/ references changed from dotclaude to dotconfigs
- [05-02]: All Claude plugin keys get CLAUDE_* prefix (including git identity)
- [05-02]: Migration logic comments out old keys with notice (not deleted)
- [05-02]: 7-step wizard (dropped aliases, moved conflict review to deploy)
- [05-02]: Summary + confirm before saving (user can cancel)
- [05-03]: Plugin derives DOTCONFIGS_ROOT from PLUGIN_DIR location
- [05-03]: Settings.json symlinked from repo root (global shared file)
- [05-03]: Hooks/commands symlinked from plugin dir (plugin assets)
- [05-03]: Shell aliases and remote deploy dropped (dead code)
- [06-01]: Git hooks source of truth moved to plugins/git/hooks/
- [06-01]: commit-msg uses research-based conventional commit regex with scope and breaking change support
- [06-01]: pre-push protection configurable via GIT_HOOK_PREPUSH_PROTECTION (block/warn/off)
- [06-01]: Claude plugin no longer manages git hooks or identity
- [06-02]: Menu-based wizard (not linear walk-through) per user decision in 06-CONTEXT.md
- [06-02]: Opinionated defaults: settings enabled by default, user opts out
- [06-02]: Custom alias names validated against git built-in commands blacklist
- [06-02]: Global hooks scope shows explicit conflict warning about core.hooksPath overriding per-project hooks
- [06-02]: Pre-fill from .env values, fall back to git config on first run for identity
- [06-03]: deploy.sh warns on drift before overwriting git config
- [06-03]: Alias definitions fall back to hardcoded defaults when GIT_ALIAS_* env vars missing
- [06-03]: Hooks deploy per-project by default, global deployment is opt-in
- [06-03]: project.sh offers optional per-repo git identity configuration
- [07-01]: TTY-aware colour output via [[ -t 1 ]] check (ANSI when TTY, plain when piped)
- [07-01]: 5-state drift detection model (deployed, not-deployed, drifted-broken, drifted-foreign, drifted-wrong-target)
- [07-01]: Hierarchical help system (overview + per-command detail)
- [07-01]: Deploy-all mode when no plugin specified (dotconfigs deploy)
- [07-02]: Plugin status functions follow plugin_<name>_status() naming convention
- [07-02]: Status functions report per-file/per-config-item granularity
- [07-02]: Git config items use _print_config_status() helper (separate from file status)
- [07-02]: List command shows minimal output (plugin name + installed/not-installed)
- [07-03]: backup_and_link interactive_mode supports three values: true/false/force
- [07-03]: Diff option in conflict prompt shows file differences before decision
- [07-03]: Backup suffix changed from .backup to .bak per shell convention
- [07-03]: Deploy summary always printed (created/updated/skipped/unchanged)
- [07-03]: --dry-run takes precedence over --force when both specified
- [07-03]: Force mode suppresses git drift confirmation and all conflict prompts
- [07-04]: README with no example terminal output (concise documentation approach)
- [07-04]: ASCII architecture diagram in README (makes three-command model clear)
- [07-04]: Deprecation notice for CLAUDE_GIT_* keys (moved to GIT_* namespace)
- [08-01]: Unified hook variable naming: GIT_HOOK_* for git hooks, CLAUDE_HOOK_* for claude hooks
- [08-01]: AI attribution blocking now configurable (GIT_HOOK_BLOCK_AI_ATTRIBUTION) with strong default ON
- [08-01]: Config hierarchy: hardcoded default → env var → config file
- [08-01]: Multi-path config discovery for backwards compatibility
- [08-01]: Deprecated hooks.conf profile templates, replaced with single documented template
- [08-01]: Per-hook enable/disable via {PREFIX}_{HOOK_NAME}_ENABLED variables
- [08-01]: Metadata headers in hooks for auto-documentation
- [08-03]: Secrets detection blocks hard (no warn mode) — security-critical
- [08-03]: Large file detection warns only — not a correctness issue
- [08-03]: Debug statement detection configurable strict mode (warn vs block)
- [08-03]: Branch prefix only on branch commits, skips merge/squash/amend
- [08-03]: Post-* hooks informational only — never block workflow
- [08-03]: Post-rewrite only checks rebase (not amend) — amend is single commit
- [08-03]: Portable file size detection using wc -c (not stat) for macOS/Linux compatibility
- [08-04]: PreToolUse hook blocks destructive commands and sensitive file writes (defence-in-depth for buggy settings.json)
- [08-04]: Independent guards for destructive commands (CLAUDE_HOOK_DESTRUCTIVE_GUARD) and file protection (CLAUDE_HOOK_FILE_PROTECTION)
- [08-04]: Graceful jq degradation — hook exits silently if jq missing (non-blocking)
- [08-05]: Git setup wizard shows full hook roster (23 settings) with config file location selection
- [08-05]: Claude project wizard uses individual CLAUDE_HOOK_* toggles (no profile selection)
- [08-05]: GIT_HOOK_BRANCH_PROTECTION replaces GIT_HOOK_PREPUSH_PROTECTION
- [08-05]: Hook configuration files deployed by project commands (git-hooks.conf, claude-hooks.conf)
- [08-05]: Complete .env.example with 26 GIT_HOOK_* and 3 CLAUDE_HOOK_* variables
- [08-06]: Metadata-driven roster generation from hook METADATA blocks and command frontmatter
- [08-06]: Auto-generated ROSTER.md with hooks, commands, and config reference tables
- [08-06]: Configuration hierarchy documented in README (three-tier model with precedence)
- [08-06]: Plugin config ownership documented (git-hooks.conf vs claude-hooks.conf)

### Pending Todos

- [ ] **GSD framework**: Add Explore agent to model profile lookup table (GSD PR, not this repo)
- [x] **README**: Add brief mention of GSD framework — DONE in 08-06

### Blockers/Concerns

- Hook symlink manually fixed after 05-01 asset move — `dotconfigs deploy claude` will handle this automatically in future

**Resolved:**
- Pre-commit hook COMMIT_EDITMSG timing bug — FIXED in v1.0 03-03
- v1 CLI design mismatches (subcommands vs flags) — accepted as-is, cleaner design
- Settings.json deny rules bug (Claude Code #6699, #8961) — WORKAROUND: PreToolUse hook provides defence-in-depth (08-04)

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 001 | Fix milestone audit critical bugs (colour_cyan, PLUGIN_DIR) | 2026-02-07 | 1bd83e4 | [001-fix-milestone-audit-critical-bugs](./quick/001-fix-milestone-audit-critical-bugs/) |

## Session Continuity

Last session: 2026-02-08
Stopped at: Completed 08-06-PLAN.md execution (Phase 8 COMPLETE)
Resume file: None

---

**Phase 8 Status:** COMPLETE (6/6 plans). Hooks architecture and CLI integration complete: unified config (08-01), audit (08-02), new git hooks (08-03), PreToolUse hook (08-04), CLI integration (08-05), roster generation and README updates (08-06). All v2.0 work complete.
