---
created: 2026-02-09T22:30
title: Rethink global vs project-level architecture
area: planning
files:
  - plugins/claude/project.sh
  - plugins/claude/deploy.sh
  - plugins/claude/setup.sh
  - plugins/claude/templates/settings/settings-template.json
  - plugins/claude/templates/settings/hooks.json
  - ~/.claude/settings.json
---

## Problem

Global config currently serves two conflicting roles:

1. **Template registry** — exposes available hooks, settings, sections via `.env` for project-init to draw from
2. **Active functionality** — hooks run globally via `$CLAUDE_PROJECT_DIR/plugins/claude/hooks/...` paths in `~/.claude/settings.json`, settings apply everywhere

Key tensions discovered during project-init wizard UX overhaul:

- **Global hooks only work from dotconfigs repo.** `$CLAUDE_PROJECT_DIR` resolves to wherever `claude` is invoked. Global `settings.json` hooks pointing to `$CLAUDE_PROJECT_DIR/plugins/claude/hooks/block-destructive.sh` only fire when CWD is the dotconfigs repo itself. In any other project, those paths don't resolve.
- **Project-init copies hooks locally** to `.claude/hooks/` with relative paths — these work everywhere. So project-init is currently the only way to get working hooks in a project.
- **Base template vs global settings** — the `base.json` template was far less capable than the user's actual global `~/.claude/settings.json`. We added a choice (copy global vs use template) but the whole model is confused.
- **claude-hooks.conf** is sourced by our hook scripts at runtime for fine-grained toggles — useful but its role vs `settings.json` vs `.env` is muddled.
- **settings.json format broke** — Claude Code updated to a new hooks format (`matcher` + `hooks` array). Both global and project templates had stale format. No single place to update.

Questions to resolve:

- Should global `~/.claude/settings.json` have hooks at all? Or should hooks only exist per-project (deployed by project-init)?
- If global has hooks, how do the paths work across repos? (Can't use `$CLAUDE_PROJECT_DIR` — it changes per project)
- Should `dotconfigs deploy` write to `~/.claude/settings.json` or `~/.claude/settings.local.json`?
- Is `.env` the right place for the template registry, or should templates be purely filesystem-based (discover what's in `plugins/claude/hooks/`)?
- How should `dotconfigs deploy` (global) and `dotconfigs project-init` (per-project) relate? Currently they're almost independent.

## Solution

TBD — needs architectural thinking. Possible directions:

- **Global = permissions only, project = everything else.** Global settings.json has permissions/sandbox/env but no hooks. Hooks only deployed per-project by project-init. Simpler, no path resolution issues.
- **Global = functional via absolute paths.** Deploy resolves `$CLAUDE_PROJECT_DIR` to the actual dotconfigs repo path at deploy time (not runtime). Hooks work globally but are tied to the dotconfigs repo location.
- **Plugin-based hooks.** Claude Code supports plugin hooks (`hooks/hooks.json` in a plugin dir). Could register dotconfigs as a Claude Code plugin instead of copying hooks around.
- **Hybrid.** Global provides sensible defaults (permissions, sandbox). Project-init layers on hooks + project-specific overrides. Clear separation of concerns.
