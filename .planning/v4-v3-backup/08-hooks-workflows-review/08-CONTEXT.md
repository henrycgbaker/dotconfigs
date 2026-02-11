# Phase 8: Hooks & Workflows Review - Context

**Gathered:** 2026-02-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Audit and rationalise all hooks, tools, and workflow enforcement across claude and git plugins. Ensure each mechanism lives in the right plugin with the right enforcement level. Expand hook coverage to industry-standard roster. Establish project-level config architecture. Auto-generate roster documentation.

</domain>

<decisions>
## Implementation Decisions

### Design Principle
- **Everything is configurable, with opinionated defaults** — applies universally to all hooks, tools, settings
- Each setting can be configured globally (dotconfigs .env) or per-project (project config)
- Hardcoded values are banned; even AI attribution blocking and WIP blocking get a config key with strong default ON

### hooks.conf Ownership — Split by Concern
- Git-related settings (CONVENTIONAL_COMMITS, BRANCH_PROTECTION, etc.) move to git plugin templates
- Claude-related settings (RUFF_ENABLED, etc.) stay in claude plugin templates
- Each plugin deploys its own config files during `dotconfigs project`
- Git plugin's project.sh deploys git hook config; claude plugin's project.sh deploys claude hook config

### hooks.conf Deploy — Split Into Two Files
- Per-project git hook config: user selects deploy location from a list of presets + custom path option
  - Preset options: `.githooks/config`, `.claude/git-hooks.conf`, `.git/hooks/hooks.conf`
  - Plus: "Specify custom path"
  - This is a wizard step during `dotconfigs setup git` / `dotconfigs project`
- Per-project claude hook config: separate file under `.claude/`

### Drop hooks.conf Profiles
- Remove the default/strict/permissive profile templates
- Individual settings only — user picks each setting independently via wizard
- Simpler, more flexible, consistent with "everything configurable" principle

### Enforcement Levels
- **AI attribution blocking:** Configurable with strong default ON (BLOCK_AI_ATTRIBUTION=true)
- **WIP blocking on main:** Configurable with strong default ON (WIP_BLOCK_ON_MAIN=true)
- **Conventional commits:** Configurable enforcement level — soft warn by default, configurable to hard block (CONVENTIONAL_COMMITS=true, CONVENTIONAL_COMMITS_STRICT=false)
- **Subject line length:** Configurable (MAX_SUBJECT_LENGTH=72 default)
- **Branch protection:** Already configurable (GIT_HOOK_PREPUSH_PROTECTION=warn default)

### Variable Naming — Claude's Discretion
- Unify BRANCH_PROTECTION / GIT_HOOK_PREPUSH_PROTECTION naming — Claude picks cleanest approach
- Ensure consistent naming convention across all config keys

### Squash Merge Workflow
- Keep /squash-merge as the only merge command (industry standard for solo dev + feature branches)
- Do NOT add /merge-branch alternative
- Audit /squash-merge against industry best practice — ensure it follows the standard pattern
- Add tradeoff documentation to the command output (git tracking limitation, why branch deletion handles it)

### Hook Roster — Maximal Coverage
- Expand from 2 git hooks to full practical roster:
  - **Existing:** commit-msg, pre-push
  - **Add:** pre-commit, prepare-commit-msg, post-merge, post-checkout
  - **Evaluate:** any other practical git hooks (Claude's discretion on what's worth including)
- Each hook is independently configurable (enable/disable globally and per-project)
- User picks from roster during setup wizard and project wizard

### New Hook Specifications

**pre-commit (git):**
- Secrets/credentials detection (hard block) — configurable
- Large file warning (threshold configurable, default 1MB) — configurable
- Debug statement detection (console.log, debugger, breakpoint, print) — configurable
- All checks independently toggleable

**prepare-commit-msg (git):**
- Branch-based prefix extraction: `feature/add-login` → `feat: ` — configurable, default ON
- Template mode with placeholders as alternative — configurable
- Both modes available, user picks

**post-merge (git):**
- Dependency change detection (package.json, requirements.txt, Gemfile changed → prompt reinstall) — configurable
- Migration file change detection (schema changed → remind to run migrations) — configurable

**post-checkout (git):**
- Branch info display (name, last commit, TODOs) — configurable
- Environment/branch-type info switching — configurable

**PreToolUse (Claude Code):**
- Destructive command guard (rm -rf, force push, reset --hard, DROP TABLE) — configurable
- File pattern protection (sensitive paths) — configurable
- Separate enforcement layer from settings.json (not a workaround for bugs #6699, #8961)

### Explore Agent Hook
- Research properly how explore agent model selection actually works before deciding
- Include as a research + decision task in the plan, not a build task yet

### Project-Level Config Architecture
- Global config: `dotconfigs/.env` — user's global preferences (setup writes, deploy reads)
- Project config: project-level file — overrides global defaults for this repo
  - File name and format: Claude's discretion (recommend consolidating metadata + overrides)
  - `.dotconfigs.json` already exists for project metadata — extend or add `.dotconfigs.env`
- `dotconfigs project .` runs interactive wizard — shows roster pre-filled from global defaults, user toggles overrides
- Precedence: project config > global .env > hardcoded defaults

### Auto-Generated Roster Documentation
- Single document listing ALL available hooks, tools, configs, and workflows with short explanations
- Generated using SSOT principles — mechanism at Claude's discretion (script reads plugin dirs, metadata headers, etc.)
- Linked from README
- Updates automatically when hooks/tools are added

### README Updates
- Brief GSD framework mention (2-3 lines: what it is, how to enable, link to repo)
- Link to auto-generated roster doc

### Claude's Discretion
- Variable naming unification approach
- Project-level config file format (consolidate .dotconfigs.json or add .dotconfigs.env)
- Auto-generated doc mechanism (script-based, metadata headers, etc.)
- Which additional git hooks beyond the specified six are worth including
- Exact preset paths for git hook config deployment
- Implementation details for all new hooks

</decisions>

<specifics>
## Specific Ideas

- "Maximal coverage — see what's available/recommended online, make everything configurable so user can pick and choose globally or per-project"
- Hook roster presented as a menu in both setup wizard (global) and project wizard (per-project)
- Same UX pattern for hooks as for every other setting — wizard-driven selection with configurable defaults

</specifics>

<deferred>
## Deferred Ideas

**Git plugin — future phases:**
- .gitattributes management (line endings, diff drivers, merge strategies per file type)
- .gitignore templates (language/framework-specific ignore patterns)
- Commit signing setup (GPG/SSH signing config)
- .git-blame-ignore-revs (skip formatting commits in blame)

**Claude plugin — future phases:**
- MCP server management (wizard step to configure Context7, etc.)
- Custom commands roster (let users pick from available slash commands to deploy)

**External (not this repo):**
- GSD framework: Add Explore agent to model profile lookup table (GSD PR)

</deferred>

---

*Phase: 08-hooks-workflows-review*
*Context gathered: 2026-02-08*
