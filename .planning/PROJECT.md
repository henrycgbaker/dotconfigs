# dotconfigs

## What This Is

An extensible, plugin-based configuration manager for developer tools. Clone onto any machine (local Mac, remote servers, Docker, CI/CD) to get a consistent development environment. Currently manages Claude Code and Git configuration, with a plugin architecture that supports adding new config domains (shell, editors, etc.) without restructuring.

## Core Value

Single source of truth for all personal dev configuration — one repo, one CLI, one `.env`, deployed everywhere with minimal context footprint.

## Current Milestone: v2.0 Plugin Architecture

**Goal:** Transform dotclaude into dotconfigs — an extensible plugin-based configuration manager with `claude` and `git` plugins, shared library layer, and unified `dotconfigs` CLI.

**Target features:**
- Plugin architecture (`plugins/claude/`, `plugins/git/`, shared `lib/`)
- Unified CLI: `dotconfigs setup [plugin]`, `dotconfigs deploy [plugin]`
- Migrate existing Claude config into `plugins/claude/`
- New git plugin: hooks, identity, gitconfig workflow settings
- Bash 3.2 compatibility fixes
- Wizard always runs with pre-filled defaults from previous `.env`
- CLI entry point restructure with lib file split

## Requirements

### Validated

*Shipped and confirmed in v1.0:*

- ✓ Global CLAUDE.md reduced to 41 lines (CTXT-01) — v1.0
- ✓ Rules/ directory eliminated (CTXT-02) — v1.0
- ✓ Context burn reduced (CTXT-03) — v1.0
- ✓ Global settings.json with allow/deny/ask (SETT-01) — v1.0
- ✓ Project settings.json templates (SETT-02) — v1.0
- ✓ Settings layering: global → project (SETT-03) — v1.0
- ✓ Sensitive file protection (SETT-04) — v1.0
- ✓ block-sensitive.py removed (SETT-05) — v1.0
- ✓ Ruff auto-format hook (HOOK-01) — v1.0
- ✓ Conventional commits hook (HOOK-02) — v1.0
- ✓ AI attribution blocking (HOOK-03) — v1.0
- ✓ Layered branch protection (HOOK-04) — v1.0
- ✓ Hooks deployed as local-only (HOOK-05) — v1.0
- ✓ Configurable deploy.sh (DEPL-01) — v1.0
- ✓ Interactive wizard (DEPL-02) — v1.0
- ✓ Non-interactive deploy (DEPL-03) — v1.0
- ✓ Project scaffolding (DEPL-04) — v1.0
- ✓ Remote deployment (DEPL-06) — v1.0
- ✓ Git identity configurable (DEPL-07) — v1.0
- ✓ GSD installation option (DEPL-08) — v1.0
- ✓ .env.example (DEPL-09) — v1.0
- ✓ AI artefacts via .git/info/exclude (GHYG-01) — v1.0
- ✓ Hooks source of truth in repo (GHYG-02) — v1.0
- ✓ Over-engineering prevention in CLAUDE.md (QUAL-01) — v1.0
- ✓ /simplicity-check skill (QUAL-02) — v1.0
- ✓ /commit skill (SKIL-01) — v1.0
- ✓ /squash-merge skill (SKIL-02) — v1.0
- ✓ Registry scanning script (RGST-01) — v1.0

### Active

See REQUIREMENTS.md for v2.0 requirements.

### Future Milestones

- Explore agent hook (sonnet model for explore agents)
- README rewrite with latest usage workflows
- Shell plugin (`plugins/shell/` — aliases, zshrc, env vars)
- GitHub Actions template for claude-code-action integration
- CLAUDE.md starter template for new projects

### Out of Scope

- GSD agents and commands — GSD framework ships its own, no duplication
- Docker-specific rules/skills — not needed for current workflow
- Security-focused agents — overkill for solo dev
- Windows support — macOS/Linux only
- Team collaboration features — personal configuration
- Full dotfiles manager (vim, tmux, etc.) — only dev-tool configs that benefit from SSOT management

## Context

**Current state (post-v1):** ~30 files, lean CLAUDE.md (41 lines), working deploy.sh with wizard, settings.json, hooks, skills. All v1 requirements complete. Ready for architectural expansion.

**v1 tech debt:** deploy.sh uses subcommand design (not flag design per original spec) — accepted, cleaner. Bash 3.2 incompatibilities on macOS (${var,,}, local -n). Wizard skips on re-run when .env exists.

**Key insight:** The wizard/setup and deploy operations are conceptually separate. Setup writes config (.env), deploy reads config and acts. Separating these enables the plugin architecture — each plugin provides its own setup wizard and deploy logic.

**GSD relationship:** GSD is an external framework. dotconfigs provides the personal configuration layer underneath. GSD installation remains an optional deploy step.

## Constraints

- **Context budget**: Global CLAUDE.md must stay under ~100 lines
- **Deterministic-first**: If a tool/hook can enforce something, don't put it in CLAUDE.md
- **GSD compatibility**: Must not conflict with or duplicate GSD framework components
- **Portability**: Must work on macOS (bash 3.2+) and Linux without manual adjustment
- **Bash 3.2**: macOS ships bash 3.2 — no bash 4+ features (nameref, ${var,,}, associative arrays)
- **Plugin isolation**: Plugins must not import from each other, only from shared `lib/`

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Rename dotclaude → dotconfigs | Scope expanding beyond Claude to git + shell configs | v2.0 |
| Plugin architecture (plugins/claude/, plugins/git/) | Extensible SSOT — adding config domains = adding dirs, not forking | v2.0 |
| `dotconfigs` as CLI name | Matches repo name, unique, clear purpose | v2.0 |
| Separate setup from deploy | Setup writes .env, deploy reads .env — clean separation of concerns | v2.0 |
| Git plugin: hooks + identity + workflow | Git config is useful independently, deserves its own namespace | v2.0 |
| Shell plugin deferred to v3 | Focus v2 on restructure + 2 plugins, avoid scope creep | v2.0 |
| Full plugin system in v2 (not incremental) | Doing rename + restructure + plugin arch together avoids double-touching paths | v2.0 |
| .env files as "ask" not "deny" | Strict deny was annoying — Claude often needs .env for context | ✓ Good |
| File-level symlinks for GSD coexistence | Directory-level clobbers GSD; file-level lets both tools share dirs | ✓ Good |
| Subcommand CLI design (not flag-based) | `dotconfigs setup claude` reads better than `dotconfigs --setup --plugin=claude` | ✓ Good |

---
*Last updated: 2026-02-07 after v2.0 milestone definition*
