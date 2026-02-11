# v4 Deferred Work (Original v3 Plans Backup)

**Created:** 2026-02-11
**Reason:** v3 simplified to explicit JSON config + deploy MVP. Wizard/UX work deferred to v4.

## What's Here

These are the original v3 planning docs before the simplification rewrite. The wizard refactor, CLI restructure, and advanced UX features are deferred to v4.

## Deferred Features (Revisit for v4)

- **Interactive wizards** — `plugins/*/setup.sh` (currently ~770 lines of wizard code)
- **lib/wizard.sh** — Toggle menus, checkbox UIs, edit modes (~360 lines)
- **Wizard-driven .env generation** — Setup wizard → .env → deploy pipeline
- **CLI commands**: `global-configs`, `project-init` with interactive prompts
- **CLAUDE.md template assembly** — Fragment concatenation from `templates/claude-md/`
- **Per-hook toggle configuration** — Individual hook enable/disable via wizard
- **Edit mode on re-run** — Show current config, allow item-by-item editing
- **Category-based wizard menus** — Deploy targets, Content, Behaviour categories
- **VS Code extension auto-install** — v3 captures installed extensions list via `code --list-extensions` into `plugins/vscode/extensions.txt`; v4 should add `dotconfigs install-extensions` or post-deploy hook that reads the list and runs `code --install-extension` for each

## Original v3 Roadmap (Phases 11-14)

- Phase 11: JSON Config Foundation (kept, simplified)
- Phase 12: Wizard Refactor → DEFERRED TO V4
- Phase 13: CLI Restructure + Per-Module Scope → partially kept (scope via config), wizard merge deferred
- Phase 14: Migration + Documentation → kept, simplified

## Key Files to Revisit

- `plugins/claude/setup.sh` — Claude wizard (shelved, not deleted)
- `plugins/git/setup.sh` — Git wizard (shelved, not deleted)
- `lib/wizard.sh` — Shared wizard framework (shelved, not deleted)
- `quick/002-*` — Bug fixes for wizard that may not apply after simplification

## Quick Task 002 (Was In Progress)

Git wizard bugs + CLI rename. May not apply after v3 simplification since wizards are deferred.
See `quick/` directory for the 4 plans.
