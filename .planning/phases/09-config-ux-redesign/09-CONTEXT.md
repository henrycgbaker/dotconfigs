# Phase 9: Config UX Redesign - Context

**Gathered:** 2026-02-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Redesign the configuration UX: opt-in config selection at global and project levels, project-configs wizard with global value indicators, settings.json logical separation, CLAUDE.md exclusion, .env->JSON migration evaluation, and remaining bug fixes from quick task 002.

Command structure (established in quick-002, refined here):
- `dots setup` — one-time tool initialisation
- `dots global-configs {plugin}` — manage global preferences (opt-in selection)
- `dots project-configs {plugin} [path]` — manage local overrides (path defaults to `.`, runnable from dotconfigs repo OR project repo)
- `dots deploy [plugin]` — apply configs to filesystem (separate from config commands)
- `dots status [plugin]` / `dots list` — existing commands (unchanged)

</domain>

<decisions>
## Implementation Decisions

### Opt-in wizard flow
- **Category menus:** Group configs by category (3 categories for Claude: Deploy targets, Content, Behaviour). User picks a category, then toggles configs within it
- **Opt-in model:** Wizard shows ALL configs initially. User picks which to manage. Unselected configs get NO value set (no hardcoded default). Wizard walks through selected configs only
- **Opinionated defaults:** For opted-in configs, show pre-filled suggested value — user presses Enter to accept or types to change
- **Summary:** Final summary shows selected configs with values + skipped ones greyed as `[not managed]`
- **Re-run behaviour:** Edit mode — show current state (managed/not managed), user picks numbers to edit. No full re-selection unless explicitly requested

### Global vs project indicators
- **Visual indicators:** Colour + label system — globally-set configs shown in distinct colour (e.g. cyan) with 'G' badge, locally-set shown in green with 'L'
- **Override UX:** When overriding a global value locally, local field starts blank but shows the global value as reference — forces explicit choice
- **Summary provenance:** Show effective value AND provenance label (Global / Local) in summaries
- **Storage:** Plugin config files (each plugin owns its config) — not centralised .dotconfigs.json
- **Deploy-time overrides per-project:** Deferred to researcher — needs codebase context to determine if deploy-time settings (CLAUDE.md sections, deploy target, git identity) should be overridable per-project. **REQUIRES POST-RESEARCH DISCUSSION:** How does `dots deploy` interact with global vs project configs? Currently deploy is global-only (reads .env, writes to filesystem). If project-level overrides exist, does deploy need scope awareness (e.g. `--project /path`)? Or does deploy always apply the resolved config (global + local merged)? This is not understood well enough yet — must be discussed with user after research clarifies the config storage model

### Settings.json separation
- **Language rules:** Wizard offers Python + Node checkboxes (ruff/pytest for Python, eslint/npm for Node). Selected rules included in assembled settings.json
- **Auto-gitignore:** setup command adds root settings.json to .gitignore automatically when setting up the dotconfigs repo
- **Assembly model:** One file with clear comment sections (core, hooks, language). Deploy rebuilds the whole file each time
- **Template style:** Complete working example in plugins/claude/templates/ — full settings.json with all common rules, users delete what they don't want

### .env -> JSON migration
- **Decision:** Deferred to researcher — evaluate .env vs JSON for bash 3.2 CLI config (jq dependency risk, migration patterns, portability)
- **jq dependency:** Acceptable if research justifies it
- **Migration UX:** No backward compatibility needed — clean break if migrating
- **Research questions:** Is jq widely available enough? What's the portability risk on bash 3.2? What migration patterns exist for .env -> JSON in shell tools?

### CLAUDE.md exclusion
- Goes in .git/info/exclude (NOT .gitignore — no Claude/CLAUDE.md references in tracked files)
- Global default set in setup + per-project override in project-configs
- User wants ALL CLAUDE.md files excluded from all repos generally

### Bug fixes (from quick-002 gaps)
- Fix remaining `select` loops (2 in git setup, 1 in claude project) — replace with `read` prompts
- Fix stale "dotconfigs" references in plugin banners — should say "dots"
- `dots list` should say "deployed" / "not deployed" instead of "installed" / "not installed"
- CLAUDE.md exclusion: wizard UI works but never applied during deploy — needs to write to .git/info/exclude

### Claude's Discretion
- Exact colour choices for G/L badges (as long as visually distinct in standard terminals)
- Category grouping for git plugin configs
- Internal implementation of settings.json section assembly
- Precedence resolution is up to each tool/plugin — brief docs mention only, not detailed (out of scope)

</decisions>

<specifics>
## Specific Ideas

- Edit mode mock-up for re-runs (user approved this specific UX):
  ```
  [1] Deploy target path          = ~/.claude
  [2] GSD framework install       = true
  [3] Settings enabled            = true
  [4] CLAUDE.md sections          = code-style communication...
  [5] Hooks enabled               = block-destructive.sh...
  [6] Skills enabled              [not managed]

  Enter numbers to edit (e.g. 3,6), or 'done':
  ```
- Project-configs shows global values as reference when overriding — blank input, global shown alongside
- Summary always shows provenance (G/L) so user knows where each effective value comes from

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 09-config-ux-redesign*
*Context gathered: 2026-02-09*
