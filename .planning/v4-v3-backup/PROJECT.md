# dotconfigs

## What This Is

An extensible, plugin-based configuration manager for developer tools. Clone onto any machine (local Mac, remote servers, Docker, CI/CD) to get a consistent development environment. Currently manages Claude Code and Git configuration, with a plugin architecture that supports adding new config domains (shell, editors, etc.) without restructuring.

## Core Value

Single source of truth for all personal dev configuration — one repo, one CLI, one `.env`, deployed everywhere with minimal context footprint.

## Current Milestone: v3.0 Architecture Rethink

**Goal:** Simplify the deployment model to a thin, explicit layer over underlying tools. Replace wizard-driven .env approach with JSON config files and a manifest-driven deploy. Add shell plugin. Wizards deferred to v4.0.

**Target features:**
- Module manifest: each plugin exposes modules (hooks, configs, skills) as files in plugin dirs. Setup builds a manifest (SSOT) from what exists. Users add modules by adding files — no wizard needed.
- JSON config files replace .env: global config in dotconfigs repo, project config in `.dotconfigs/` per-repo. Config defines which modules to deploy and where.
- Thin deployment layer: `deploy` reads config JSON, symlinks/copies modules to target locations. Leverages underlying tools' own config schemas (git config, Claude Code settings.json) — not a parallel config system.
- Per-module deploy targets: each module can specify custom deployment location
- Modules deployable at both global and project levels (e.g., AI attribution blocker at both)
- `.dotconfigs/` project directory (replaces `.dotconfigs.json`), added to `.git/info/exclude` or `.gitignore` (configurable)
- Decoupled global and project — each self-sufficient, idempotent
- Per-module scope (absorbed from v2.0 Phase 10)
- Shell plugin (research-informed scope)
- Beginner-friendly README
- Wizard-ready: config file schema must be designed so existing wizards (v2.0, shelved) can be adapted to generate the same JSON configs in v4.0. Don't paint ourselves into a corner.
- Preserve existing functionality — simplify, don't discard

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

See REQUIREMENTS.md for v3.0 requirements.

*v2.0 requirements (32/32): All complete. See MILESTONES.md.*

### Future Milestones

- v4.0: Wizard UX layer — interactive wizards on top of v3.0 config-file mechanics
- Explore agent hook (sonnet model for explore agents)
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

**Current state (post-v2):** Plugin architecture working with claude + git plugins, shared lib/, unified CLI. Wizards, deploy, status, project-configs all functional. ~40 files. v2.0 shipped 32/32 requirements across 44 plans.

**v2 tech debt:** Global-vs-project deployment model is confused — global hooks use `$CLAUDE_PROJECT_DIR` paths that only resolve in dotconfigs repo. Project-init is the only way to get working hooks in other repos. Wizard-driven .env approach has quoting issues and doesn't scale to JSON-structured config. Plugins have inconsistent UX between and within.

**Key insight for v3:** The tool should be a thin explicit layer — a manifest of what's available, a JSON config of what to deploy where, and a deploy command that reads config and acts. Leverage underlying tools' schemas (git config, Claude settings.json) tightly rather than building parallel infrastructure. Get the manual mechanics right first, add wizard UX later (v4.0).

**GSD relationship:** GSD is an external framework. dotconfigs provides the personal configuration layer underneath.

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
| Phase 10 absorbed into v3.0 | Per-hook scope is naturally solved by module-level deploy targets | v3.0 |
| Config-first, wizards later | Get manual JSON config + deploy working in v3.0, add wizard UX in v4.0 | v3.0 |
| Thin layer principle | Leverage underlying tool schemas tightly, don't build parallel config infrastructure | v3.0 |
| .env → JSON config | .env quoting issues + need for structured config (arrays, nesting) drives migration | v3.0 |
| .env files as "ask" not "deny" | Strict deny was annoying — Claude often needs .env for context | ✓ Good |
| File-level symlinks for GSD coexistence | Directory-level clobbers GSD; file-level lets both tools share dirs | ✓ Good |
| Subcommand CLI design (not flag-based) | `dotconfigs setup claude` reads better than `dotconfigs --setup --plugin=claude` | ✓ Good |

---
*Last updated: 2026-02-10 after v3.0 milestone definition*
