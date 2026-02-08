# Phase 5: Claude Plugin Extraction - Context

**Gathered:** 2026-02-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Migrate the existing monolithic deploy.sh wizard and deployment logic into `plugins/claude/`, maintaining identical UX whilst adopting the new plugin architecture from Phase 4. All current Claude Code configuration functionality (setup wizard, global deploy, project scaffolding) works through the plugin system. deploy.sh is deleted after extraction is complete.

</domain>

<decisions>
## Implementation Decisions

### .env namespacing
- All Claude plugin keys get `CLAUDE_*` prefix (full prefix, no exceptions)
- Clean break from old keys — re-run setup wizard to generate new `CLAUDE_*` keys
- Wizard pre-fills from old unprefixed keys as defaults (so users don't re-type), but saves as `CLAUDE_*`
- Old unprefixed keys are commented out with `# migrated to CLAUDE_*` note after wizard saves new keys

### Wizard flow
- Single sequential flow — same as current deploy.sh, one flow, answer everything, done
- Re-run shows current `CLAUDE_*` values as defaults — press Enter to keep, type to overwrite
- Summary of all settings shown at the end, confirm before writing to .env
- Setup and deploy are separate steps — `dotconfigs setup claude` writes .env only, `dotconfigs deploy claude` reads .env and acts

### Project command
- `dotconfigs project .` is a **top-level command**, not a plugin-specific action
- Each plugin hooks into the project command with its own project-level setup
- Plugin name is an optional filter: `dotconfigs project .` runs all plugins, `dotconfigs project claude .` runs just Claude
- Project setup is **interactive** — each plugin runs a short project-specific wizard
- Project settings stored in `.dotconfigs.json` in the project repo (single file for settings + metadata)
- User chooses per project whether to commit `.dotconfigs.json` or add to `.git/info/exclude`
- Phase 5 implements Claude's project contribution only; git project config comes in Phase 6

### Config format
- Global config: `.env` (bash-native sourcing, key-value pairs) — stays for v2.0
- Project config: `.dotconfigs.json` (structured JSON, parsed with jq)
- JSON everywhere deferred to v3.0 Python rewrite

### Templates
- Code-owned with variable substitution — users customise via wizard/.env, not by editing template files
- Templates use placeholders (e.g., `{{CLAUDE_GITHUB_USERNAME}}`) filled at deploy time

### Transition (no strangler fig)
- Clean break — no backwards-compatible deploy.sh wrapper
- deploy.sh kept during extraction for reference, deleted once extraction is complete
- Roadmap success criterion to be updated (remove strangler fig requirement)
- Command mapping: `deploy.sh global` → `dotconfigs deploy claude`, `deploy.sh project` → `dotconfigs project .`, `deploy.sh` (wizard) → `dotconfigs setup claude`

### Claude's Discretion
- Menu style for feature selection (bash select vs yes/no per feature)
- Which content stays shared (lib/) vs moves into plugin (plugins/claude/)
- GSD coexistence approach (keep symlinks or rethink for plugin architecture)
- Project-level config storage details (structure of .dotconfigs.json)
- What to drop from deploy.sh (dead code, obsolete features)

</decisions>

<specifics>
## Specific Ideas

- Wizard summary + confirm before saving mirrors the "review before commit" pattern — user sees all choices before they take effect
- Project config file (.dotconfigs.json) enables re-deploy without re-answering questions
- Pre-filling from old keys during migration means zero friction for existing users transitioning to v2.0
- Commenting out old keys (rather than deleting) gives users a safety net during migration

</specifics>

<deferred>
## Deferred Ideas

- **Python rewrite (v3.0)** — Rewrite dotconfigs in Python with JSON config everywhere. Bash is pragmatic for v2.0, Python is the long-term direction.
- **Git per-project config** — Git plugin would have a global SSOT registry of tools, hooks, workflows that can be selectively applied per project. Phase 6 territory.
- **Multi-plugin project orchestration** — `dotconfigs project .` running all plugins with cross-plugin awareness. Phase 7 integration concern.

</deferred>

---

*Phase: 05-claude-plugin-extraction*
*Context gathered: 2026-02-07*
