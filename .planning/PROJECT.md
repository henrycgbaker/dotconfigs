# dotconfigs

## What This Is

A generic file deployer for developer tool configuration. Clone onto any machine, define source→target mappings in JSON, run `dotconfigs deploy`. Currently manages Claude Code, Git, VS Code, and shell configuration.

## Core Value

Single source of truth for all personal dev configuration — one repo, one JSON config, deployed everywhere via symlinks. No magic, no wizards, no intermediary formats. The user has total manual control.

## Current Milestone: v3.0 Explicit Config MVP

**Goal:** Replace the wizard-driven .env approach with an explicit JSON config that maps source files to deployment targets. Every module has a `source` (where to read) and `target` (where to deploy). The tool is a generic file deployer — it doesn't know about Claude, Git, or VS Code. It just reads source→target pairs and symlinks files.

**Target features:**
- `global.json` in dotconfigs repo root — defines all global deployments
- `.dotconfigs/project.json` per-repo — defines per-project deployments
- `dotconfigs deploy` reads JSON, symlinks files. Idempotent. No questions asked.
- `dotconfigs status` checks symlink health against config.
- `dotconfigs migrate` one-time .env → global.json conversion
- Git identity/workflow/aliases as a gitconfig include file (Git's native INI format, not commands)
- VS Code plugin (settings, keybindings, snippets, extensions list)
- Shell plugin (zsh/bash init, aliases)
- Wizards deferred to v4 — users edit JSON directly
- Repo is archive of all modules; `include` field selects what's deployed

**Design principles:**
- Explicit over magic — every deployment path visible in the config
- Thin layer — leverage underlying tools' native formats (gitconfig, settings.json)
- Generic — top-level keys are arbitrary labels, tool doesn't care about plugin names
- File-based — everything is a file operation (symlink, copy, append)

## Requirements

### Validated

*Shipped and confirmed in v1.0 + v2.0:*

See MILESTONES.md for full v1.0 (29 req) and v2.0 (32 req) summaries.

### Active

See REQUIREMENTS.md for v3.0 requirements.

### Future Milestones

- v4.0: Wizard UX layer — interactive wizards that generate the same JSON configs
- v5.0+: Explore agent hook, GitHub Actions template, VS Code extension auto-install

### Out of Scope

- GSD agents and commands — GSD framework ships its own
- Docker-specific rules/skills — not needed for current workflow
- Windows support — macOS/Linux only
- Team collaboration features — personal configuration
- Full dotfiles manager (vim, tmux, etc.) — only dev-tool configs that benefit from SSOT
- Interactive wizards — deferred to v4.0 (see .planning/v4-v3-backup/)

## Context

**Current state (post-v2):** Plugin architecture working with claude + git plugins, shared lib/, unified CLI. Wizards, deploy, status all functional. ~40 files. v2.0 shipped 32/32 requirements.

**v2 problem:** The wizard-driven .env approach became the primary interface. Users can't easily hand-edit .env because the format is fragile (space-separated arrays, quoting issues). The wizard tail is wagging the config dog. Project scaffolding has 3 critical bugs (wizard functions unavailable in project.sh context). Global hooks had path resolution bugs (fixed in Phase 10).

**Key insight for v3:** Strip back to the simplest correct architecture: a JSON config with explicit source→target mappings, and a deploy command that reads it. No wizard, no .env, no intermediary. Get this working robustly, then layer wizard UX on top in v4.

**GSD relationship:** GSD is an external framework. dotconfigs provides the personal configuration layer underneath.

## Constraints

- **Bash 3.2**: macOS ships bash 3.2 — no bash 4+ features (nameref, ${var,,}, associative arrays)
- **jq dependency**: Required for JSON parsing. Checked at setup time.
- **Plugin isolation**: Plugins must not import from each other, only from shared `lib/`
- **Portability**: Must work on macOS (bash 3.2+) and Linux without manual adjustment
- **Context budget**: Global CLAUDE.md must stay under ~100 lines
- **Deterministic-first**: If a tool/hook can enforce something, don't put it in CLAUDE.md

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Rename dotclaude → dotconfigs | Scope expanding beyond Claude | v2.0 |
| Plugin architecture (plugins/claude/, plugins/git/) | Extensible SSOT — adding config domains = adding dirs | v2.0 |
| Separate setup from deploy | Clean separation of concerns | v2.0 |
| .env → JSON config (global.json) | .env quoting issues, need for structured config, user editability | v3.0 |
| Explicit source→target mappings | No magic — user sees exactly what goes where | v3.0 |
| Generic file deployer | Tool doesn't know about plugins — just reads source/target pairs | v3.0 |
| Git config as gitconfig include file | Consistent file model, native format, auditable | v3.0 |
| CLAUDE.md as single file (not assembled) | Simplicity — edit directly, no template fragments | v3.0 |
| Wizards deferred to v4 | Get manual mechanics right first | v3.0 |
| VS Code plugin in v3 | Simple file deployer makes adding plugins trivial | v3.0 |
| Shell plugin in v3 | Same deployer model — zsh config files symlinked | v3.0 |
| Extensions list capture (not install) | Capture via `code --list-extensions`, install deferred to v4 | v3.0 |
| Git config in native INI (not JSON) | No translation layer — user edits gitconfig directly | v3.0 |

---
*Last updated: 2026-02-11 after v3.0 simplification*
