# Phase 9: Config UX Redesign - Research

**Researched:** 2026-02-09
**Domain:** Configuration management UX patterns for CLI tools
**Confidence:** HIGH

## Summary

Phase 9 redesigns the configuration UX with opt-in config selection, project-level overrides with global value indicators, settings.json separation, CLAUDE.md exclusion, and evaluation of .env vs JSON for config storage. This research investigated: (1) .env vs JSON config patterns for bash 3.2, (2) global→project config hierarchy patterns, (3) category-based wizard UX, (4) terminal colour codes for provenance indicators, and (5) git exclusion patterns.

**Key findings:**
- .env remains superior for bash 3.2 despite JSON's structured benefits — no runtime dependency, simple parsing, env var semantics built-in
- jq is widely available but adds dependency risk on constrained systems
- Standard hierarchy pattern: project overrides global, files merge (not replace), provenance tracking critical for user confidence
- ANSI colour codes (green=32, cyan=36, yellow=33) universally supported, bash 3.2 compatible via `\033[XXm` escape sequences
- `.git/info/exclude` vs `.gitignore`: identical syntax, former is personal/local, latter is project-wide and version-controlled

**Primary recommendation:** Keep .env for global config storage, evaluate JSON only for per-project storage where jq availability can be verified; implement opt-in wizard with category grouping, edit-mode re-runs, and colour-coded G/L provenance indicators.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Opt-in wizard flow:**
- Category menus group configs by category (3 categories for Claude: Deploy targets, Content, Behaviour). User picks category, then toggles configs within it
- Opt-in model: Wizard shows ALL configs initially, user picks which to manage. Unselected configs get NO value set (no hardcoded default)
- Opinionated defaults: For opted-in configs, show pre-filled suggested value — user presses Enter to accept or types to change
- Summary: Final summary shows selected configs with values + skipped ones greyed as `[not managed]`
- Re-run behaviour: Edit mode — show current state (managed/not managed), user picks numbers to edit

**Global vs project indicators:**
- Visual indicators: Colour + label system — globally-set configs shown in distinct colour (cyan) with 'G' badge, locally-set shown in green with 'L'
- Override UX: When overriding a global value locally, local field starts blank but shows global value as reference
- Summary provenance: Show effective value AND provenance label (Global / Local)
- Storage: Plugin config files (each plugin owns its config) — not centralised .dotconfigs.json

**Settings.json separation:**
- Language rules: Wizard offers Python + Node checkboxes (ruff/pytest for Python, eslint/npm for Node)
- Auto-gitignore: setup command adds root settings.json to .gitignore automatically
- Assembly model: One file with clear comment sections (core, hooks, language)
- Template style: Complete working example in plugins/claude/templates/

**CLAUDE.md exclusion:**
- Goes in .git/info/exclude (NOT .gitignore — no Claude/CLAUDE.md references in tracked files)
- Global default set in setup + per-project override in project-configs
- User wants ALL CLAUDE.md files excluded from all repos generally

**Bug fixes (from quick-002):**
- Fix remaining `select` loops (2 in git setup, 1 in claude project) — replace with `read` prompts
- Fix stale "dotconfigs" references in plugin banners — should say "dots"
- `dots list` should say "deployed" / "not deployed" instead of "installed" / "not installed"
- CLAUDE.md exclusion: wizard UI works but never applied during deploy

### Claude's Discretion

- Exact colour choices for G/L badges (as long as visually distinct in standard terminals)
- Category grouping for git plugin configs
- Internal implementation of settings.json section assembly
- Precedence resolution documentation (brief mention only)

### Deferred Ideas (OUT OF SCOPE)

- .env → JSON migration decision deferred to researcher — evaluate here and make recommendation
- Deploy-time overrides per-project — research global vs project config interaction with deploy command

</user_constraints>

## Standard Stack

### Configuration Storage

| Component | Technology | Purpose | Why Standard |
|-----------|-----------|---------|--------------|
| Global config | .env files | Store user defaults | Simple parsing in bash, no dependencies, env var semantics |
| Project config | .dotconfigs.json | Per-project overrides | Structured data, merge semantics, already used in codebase |
| Config parsing | bash source + jq | Read configs | bash 3.2 compatible, jq for JSON when available |

### Terminal UI

| Component | Technology | Purpose | Why Standard |
|-----------|-----------|---------|--------------|
| Colour codes | ANSI escapes | Provenance indicators (G/L) | Universal terminal support, bash 3.2 compatible |
| Interactive input | bash read | Wizard prompts | No external dependencies, portable |
| Checkbox menus | Custom bash loop | Multi-select configs | Existing pattern in lib/wizard.sh |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| .env | JSON everywhere | Gains structure, loses simplicity; adds jq dependency for global config (risky) |
| ANSI escapes | tput | Gains abstraction, loses portability (terminfo dependency) |
| bash read | bash select | Loses on UX (select has poor re-run behaviour, cited as bug) |

**Installation:**
```bash
# No additional dependencies required
# jq optional but recommended for project config:
brew install jq           # macOS
sudo apt-get install jq   # Debian/Ubuntu
```

## Architecture Patterns

### Configuration Hierarchy Pattern

**Standard pattern:** Project config overrides global config with merge semantics.

```
Resolution order (last wins):
1. Global defaults (.env) — user preferences
2. Project overrides (.dotconfigs.json) — per-project customisation
3. Deploy resolves: global + project merged
```

**Merge behaviour:**
- Configs merge together, not replace
- Project values override global for same key
- Non-conflicting settings from both preserved

**Provenance tracking:**
- Each config knows its source (Global/Local)
- UI shows provenance with colour + label
- User always knows where effective value came from

**References:**
- [OpenCode Config Documentation](https://opencode.ai/docs/config/) — standard hierarchy pattern
- [Git Configuration Levels](https://medium.com/codetodeploy/fine-tuning-git-a-deep-dive-into-configuration-levels-63183ee78827) — local overrides global

### Opt-in Wizard Pattern

**First-run wizard UX:**
- Guided setup writes config users can tweak later
- Few high-signal prompts with safe defaults
- Clear escape hatch (not a questionnaire)

**Category-based grouping:**
```
Phase 1: Show category menu
  1) Deploy targets
  2) Content
  3) Behaviour
  Choose category [1-3]:

Phase 2: Toggle configs within category
  [x] 1) Deploy target path
  [ ] 2) GSD framework install
  Enter numbers to toggle, 'done' to finish:

Phase 3: Configure selected items
  Deploy target path [~/.claude]:
```

**Edit mode for re-runs:**
```
Current configuration:
[1] Deploy target path          = ~/.claude         (Global)
[2] GSD framework install       = true              (Global)
[3] Settings enabled            [not managed]

Enter numbers to edit (e.g. 3), or 'done':
```

**References:**
- [UX Patterns for CLI Tools](https://www.lucasfcosta.com/blog/ux-patterns-cli-tools) — first-run wizard pattern
- [Top 8 CLI UX Patterns](https://medium.com/@kaushalsinh73/top-8-cli-ux-patterns-users-will-brag-about-4427adb548b7) — guided setup best practices

### Colour-Coded Provenance Indicators

**Visual system:**
```bash
# Colour codes (ANSI escapes, bash 3.2 compatible)
GREEN='\033[32m'   # Local config
CYAN='\033[36m'    # Global config
YELLOW='\033[33m'  # Warning/drift
RESET='\033[0m'

# Display pattern
printf "%b[G]%b Deploy target: ~/.claude\n" "$CYAN" "$RESET"    # Global
printf "%b[L]%b Deploy target: ~/.projects\n" "$GREEN" "$RESET" # Local
```

**Badge system:**
- `[G]` in cyan = globally-set value
- `[L]` in green = locally-set value
- Consistent across all wizards

**Terminal compatibility:**
- ANSI codes work in all standard terminals
- bash 3.2 supports `\033[XXm` format
- TTY detection via `[[ -t 1 ]]` (already in lib/colours.sh)

**References:**
- [ANSI Color Codes](https://gist.github.com/JBlond/2fea43a3049b38287e5e9cefc87b2124) — complete ANSI reference
- [Bash ANSI Colors](https://bashcommands.com/bash-ansi-color-codes/) — bash-specific usage

### Git Exclusion Patterns

**`.gitignore` vs `.git/info/exclude`:**

| Aspect | .gitignore | .git/info/exclude |
|--------|-----------|-------------------|
| Scope | Project-wide, version-controlled | Personal/local only |
| Location | Repo root or subdirs | `.git/info/exclude` |
| Syntax | gitignore patterns | Identical to .gitignore |
| Use case | Team-wide excludes | Personal tool excludes |

**When to use `.git/info/exclude`:**
- Personal IDE/tool settings (CLAUDE.md, .claude/)
- Machine-specific files
- Temporary working files
- Don't want team-wide policy

**Pattern syntax (identical):**
```
CLAUDE.md              # Root only
**/*CLAUDE.md          # All directories
.claude/               # Directory and contents
```

**References:**
- [Git Ignore Documentation](https://git-scm.com/docs/gitignore) — official pattern reference
- [.gitignore vs .git/info/exclude](https://www.yopa.page/blog/2024-11-1-understanding-git-ignore-patterns-gitignore-vs-git-info-exclude.html) — when to use each

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing in bash | Custom sed/awk parser | jq + fallback | Edge cases (escaping, nesting), jq handles all JSON |
| Config merging | String concatenation | jq merge or bash overlay | Deep merge semantics complex, easy to miss keys |
| Terminal colours | Manual escape sequences everywhere | Centralised colour functions | TTY detection, consistent format, lib/colours.sh exists |
| Interactive menus | Ad-hoc read loops | lib/wizard.sh functions | Input validation, defaults, re-prompting built-in |

**Key insight:** Configuration UX has many edge cases (missing files, malformed data, interrupted wizards). Existing patterns in codebase (lib/wizard.sh, lib/colours.sh) already handle these. Extend, don't replace.

## Common Pitfalls

### Pitfall 1: JSON Dependency for Global Config

**What goes wrong:** Introducing jq as hard dependency for global config (.env → JSON migration)
**Why it happens:** JSON's structured data is appealing for complex configs
**How to avoid:** Keep .env for global config where bash source works natively; use JSON only for project config where jq can be verified/fallback provided
**Warning signs:**
- Tool fails on systems without jq
- Users must install jq before first run
- Error messages mention "jq not found"

**Research evidence:**
- jq widely available (homebrew, apt, dnf) but NOT guaranteed — [jq Installation](https://jqlang.org/download/)
- .env parsing via bash `source` requires no dependencies
- Current codebase already uses .env successfully for global config

### Pitfall 2: Config Override Confusion

**What goes wrong:** User doesn't understand which config is active (global vs project)
**Why it happens:** No visual indication of config source in wizard
**How to avoid:**
- Always show provenance labels (Global/Local) in summaries
- Use distinct colours for global (cyan) vs local (green)
- When setting local override, show global value as reference

**Warning signs:**
- User asks "why did my setting change?"
- User edits wrong config file
- Unexpected behaviour after project-configs wizard

**Research evidence:**
- Standard pattern across CLI tools shows provenance — [OpenCode Config](https://opencode.ai/docs/config/)
- Git shows "global" vs "local" in `git config --list --show-origin`

### Pitfall 3: Edit Mode Destroys Existing Config

**What goes wrong:** Re-running wizard resets all unselected configs
**Why it happens:** Wizard treats re-run as fresh setup
**How to avoid:**
- Detect existing config, enter "edit mode"
- Show current state (managed/not managed)
- Only modify user-selected items
- Never auto-reset unmanaged configs

**Warning signs:**
- User complains settings "disappeared" after re-run
- Configs change without explicit user action
- No way to add one config without reviewing all

**Research evidence:**
- User explicitly approved edit mode UX in CONTEXT.md
- Standard wizard pattern: re-run preserves existing choices — [Wizard Design Pattern](https://ui-patterns.com/patterns/Wizard)

### Pitfall 4: Hardcoded Defaults Pollute Config

**What goes wrong:** Unselected configs get default values written to .env
**Why it happens:** Code applies defaults before checking if user opted in
**How to avoid:**
- Only write config keys user explicitly selected
- Unselected configs remain unset (no key in .env)
- Application code handles missing keys, not wizard

**Warning signs:**
- `.env` file full of configs user never selected
- Can't distinguish "user chose default" from "user didn't choose"
- Config file grows on every wizard run

**Research evidence:**
- User decision: "Unselected configs get NO value set (no hardcoded default)" — CONTEXT.md
- Current codebase already conditionally writes keys via `wizard_save_env`

### Pitfall 5: Deploy Doesn't Apply CLAUDE.md Exclusion

**What goes wrong:** Wizard captures setting but deploy never writes to `.git/info/exclude`
**Why it happens:** Config written to .env but no deploy logic reads and applies it
**How to avoid:**
- Deploy command must read `CLAUDE_MD_EXCLUDE_*` vars
- Write patterns to `.git/info/exclude` during global deploy
- Write patterns during project-configs per-project wizard

**Warning signs:**
- User sets exclusion in wizard
- CLAUDE.md still tracked by git
- No evidence of patterns in `.git/info/exclude`

**Research evidence:**
- Bug explicitly noted in CONTEXT.md: "wizard UI works but never applied during deploy"
- Current deploy.sh has `.git/info/exclude` logic for dotconfigs repo only (line 440-452 of plugins/claude/deploy.sh)

## .env vs JSON Migration Analysis

### Current State

**Global config:** .env files (plugins/*/setup.sh → .env)
**Project config:** .dotconfigs.json (plugins/*/project.sh writes JSON)

### Research Question

Should global config migrate from .env to JSON?

### Analysis

**Arguments FOR JSON migration:**

1. **Structured data:** JSON supports nested objects, arrays, booleans natively
2. **Tooling:** jq provides powerful query/update capabilities
3. **Consistency:** Project config already uses JSON
4. **Type safety:** No string-only limitation

**Arguments AGAINST JSON migration:**

1. **Dependency risk:** jq not guaranteed on all systems, adds install requirement
2. **Bash 3.2 compatibility:** jq is external tool, .env parsing is native `source`
3. **Simplicity:** .env is human-readable, editable with any text editor
4. **Semantics:** Environment variables are natural fit for deployment config
5. **Current success:** .env works well for current use case

**jq Availability Research:**

- **macOS:** Available via homebrew (`brew install jq`) — [Homebrew Formula](https://formulae.brew.sh/formula/jq)
- **Debian/Ubuntu:** Available in official repos (`apt-get install jq`) — [jq Installation Guide](https://www.techbloat.com/how-to-install-jq.html)
- **Fedora/RHEL:** Available via dnf
- **Windows/WSL:** Available via package managers
- **BUT:** Not installed by default on any platform

**Portability Risk:**

From research: "jq is written in portable C with zero runtime dependencies, requiring only a single binary download" — [Working with JSON in bash](https://cameronnokes.com/blog/working-with-json-in-bash-using-jq/)

However, "zero runtime dependencies" means jq binary itself has no deps, NOT that systems have jq pre-installed.

**Migration UX:**

If migrating, no backward compatibility needed (clean break per user decision). Migration pattern:
```bash
# Read old .env, write new config.json
if [[ -f .env ]]; then
  source .env
  jq -n --arg target "$CLAUDE_DEPLOY_TARGET" \
        '{claude: {deploy_target: $target}}' > config.json
fi
```

### Recommendation: KEEP .env for Global Config

**Rationale:**

1. **No dependency required:** bash `source .env` works out-of-box on any system with bash 3.2
2. **Current structure is adequate:** Global config is relatively flat (plugin namespace → key/value pairs)
3. **JSON benefits minimal here:** Global config doesn't need deep nesting or complex queries
4. **Project config already uses JSON:** Where structure matters (per-project settings), JSON already in use
5. **User experience:** .env is simpler to debug (`cat .env` vs `jq . config.json`)

**Implementation strategy:**

- **Global config:** Stay with .env (plugins/*/setup.sh → .env)
- **Project config:** Continue using .dotconfigs.json (already established)
- **jq usage:** Optional dependency for project config with python fallback (already implemented in plugins/claude/project.sh lines 42-75)

**Confidence:** HIGH — based on portability requirements, current success, and lack of compelling benefits for global config use case.

**Sources:**
- [jq for JSON Processing](https://cameronnokes.com/blog/working-with-json-in-bash-using-jq/)
- [Shell Script .env vs JSON](https://medium.com/israeli-tech-radar/favor-config-files-over-env-vars-d9189d53c4b8)

## Deploy Command and Project Config Interaction

### Current State

**Deploy command:** Reads .env, writes to filesystem (global scope only)
**Project config:** Scaffolds per-project files via project.sh commands

### Research Question

How should `dots deploy` interact with project-level config? Does it need scope awareness (`--project /path`)?

### Analysis

**Current behaviour (from codebase analysis):**

1. `dots deploy` reads `.env` (global config)
2. Applies to filesystem (symlinks, git config, etc.)
3. No awareness of project-specific overrides
4. `dots project-configs <plugin> <path>` is separate — scaffolds files directly to project

**Project config current use:**

From plugins/claude/project.sh and plugins/git/project.sh:
- Creates `.claude/settings.json` (project-local)
- Copies hooks to `.git/hooks/` (project-local)
- Writes `.dotconfigs.json` (project metadata)
- Updates `.git/info/exclude` (project-local)

**Key insight:** Project commands already apply settings directly. They don't write intermediate config that deploy reads.

### Architecture Pattern

Two distinct commands with clear boundaries:

```
dots deploy              → global scope (reads .env, writes to ~/.claude)
dots project-configs     → project scope (writes to $PROJECT/.claude, $PROJECT/.git)
```

**No overlap needed** because:
1. Global deploy targets global location (`~/.claude`)
2. Project scaffold targets project location (`$PROJECT/.claude`)
3. No shared resolution step

**Project-level overrides are resolved at runtime by tools:**
- Claude Code reads `~/.claude/settings.json` THEN `./.claude/settings.json` (tool's config resolution)
- Git reads global config THEN local config (git's config resolution)
- dotconfigs doesn't need to merge/deploy — tools handle precedence

### Recommendation: No Deploy-Time Project Awareness Needed

**Rationale:**

1. **Clean separation:** Global deploy = global scope, project commands = project scope
2. **Tools handle precedence:** Claude Code and git already resolve global→project
3. **Current architecture works:** No user complaints about this pattern
4. **Added complexity not justified:** `dots deploy --project` would duplicate project-configs functionality

**Implementation:** No changes to deploy command needed for phase 9.

**Confidence:** HIGH — based on codebase analysis showing clean separation already works.

## Code Examples

### Opt-in Config Selection with Edit Mode

```bash
# Source: Synthesised from lib/wizard.sh patterns + user requirements

# Detect if config exists (edit mode vs first run)
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
    edit_mode=true
else
    edit_mode=false
fi

if [[ "$edit_mode" == "true" ]]; then
    # Edit mode: show current state
    echo "Current configuration:"
    echo ""

    local idx=1
    for config in "${ALL_CONFIGS[@]}"; do
        local config_var="PLUGIN_${config^^}"
        local current_value="${!config_var:-}"

        if [[ -n "$current_value" ]]; then
            printf "[%d] %-30s = %s\n" "$idx" "$config" "$current_value"
        else
            printf "[%d] %-30s %s\n" "$idx" "$config" "[not managed]"
        fi
        idx=$((idx + 1))
    done

    echo ""
    read -p "Enter numbers to edit (e.g. 1,3,5), or 'done': " edit_choice

    # Parse comma-separated numbers, configure only those
    IFS=',' read -ra EDIT_INDICES <<< "$edit_choice"
    for idx in "${EDIT_INDICES[@]}"; do
        idx=$(echo "$idx" | tr -d ' ')  # Trim whitespace
        if [[ "$idx" =~ ^[0-9]+$ ]]; then
            config_to_edit="${ALL_CONFIGS[$((idx - 1))]}"
            # Configure this one config...
        fi
    done
else
    # First run: category menu → toggle → configure
    # (existing wizard flow)
fi
```

### Provenance Indicators in Project Wizard

```bash
# Source: Synthesised from lib/colours.sh + hierarchy pattern research

# Load global value if exists
source "$DOTCONFIGS_ROOT/.env" 2>/dev/null
global_value="${CLAUDE_DEPLOY_TARGET:-}"

# Load project value if exists
if [[ -f "$project_path/.dotconfigs.json" ]] && command -v jq &>/dev/null; then
    project_value=$(jq -r '.plugins.claude.deploy_target // empty' "$project_path/.dotconfigs.json")
fi

# Show config with provenance
echo "Deploy target configuration:"
if [[ -n "$global_value" ]]; then
    printf "  %b[G]%b Global default: %s\n" "$COLOUR_CYAN" "$COLOUR_RESET" "$global_value"
fi

if [[ -n "$project_value" ]]; then
    printf "  %b[L]%b Project override: %s\n" "$COLOUR_GREEN" "$COLOUR_RESET" "$project_value"
    echo ""
    echo "Current effective value: $project_value (project override active)"
else
    echo ""
    echo "Current effective value: ${global_value:-<not set>} (using global)"
fi

# Prompt for local override (show global as reference)
echo ""
read -p "Project-specific deploy target [blank = use global]: " new_value

if [[ -n "$new_value" ]]; then
    # Save to project config
    echo "  → Set project override: $new_value"
else
    echo "  → Using global value"
fi
```

### CLAUDE.md Exclusion During Deploy

```bash
# Source: Pattern from plugins/claude/deploy.sh lines 440-452, extended for user setting

# In global deploy (plugins/claude/deploy.sh)
_claude_apply_md_exclusion() {
    local target_dir="$1"

    # Check if user enabled global exclusion
    if [[ "${CLAUDE_MD_EXCLUDE_GLOBAL:-false}" != "true" ]]; then
        return 0
    fi

    local exclude_file="$target_dir/.git/info/exclude"
    local pattern="${CLAUDE_MD_EXCLUDE_PATTERN:-CLAUDE.md}"

    # Ensure .git/info/exclude exists
    if [[ ! -f "$exclude_file" ]]; then
        echo "Warning: Not a git repository at $target_dir" >&2
        return 1
    fi

    # Add pattern if not present
    if ! grep -q "^${pattern}$" "$exclude_file" 2>/dev/null; then
        echo "$pattern" >> "$exclude_file"
        echo "  ✓ Added $pattern to .git/info/exclude"
    fi

    # Also add .claude/ directory
    if ! grep -q "^\.claude/$" "$exclude_file" 2>/dev/null; then
        echo ".claude/" >> "$exclude_file"
        echo "  ✓ Added .claude/ to .git/info/exclude"
    fi
}

# Call during deploy
if [[ "$dry_run" != "true" ]]; then
    # Apply exclusion to dotconfigs repo
    _claude_apply_md_exclusion "$DOTCONFIGS_ROOT"

    # Note: Project-level exclusion applied during project-configs wizard
fi
```

### Read-Based Category Menu (Replace Select)

```bash
# Source: Pattern synthesis from read prompt research + user requirements

# Category-based menu using read (not select)
_show_category_menu() {
    local categories=("Deploy targets" "Content" "Behaviour")

    echo "Configuration categories:"
    echo ""

    local idx=1
    for category in "${categories[@]}"; do
        echo "  $idx) $category"
        idx=$((idx + 1))
    done

    echo ""

    while true; do
        read -p "Select category [1-${#categories[@]}]: " choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#categories[@]}" ]]; then
            local selected_category="${categories[$((choice - 1))]}"
            echo "  → Selected: $selected_category"
            return $((choice - 1))
        else
            echo "Invalid choice. Please enter 1-${#categories[@]}." >&2
        fi
    done
}

# Usage
_show_category_menu
category_idx=$?

case $category_idx in
    0) # Deploy targets
        _configure_deploy_targets
        ;;
    1) # Content
        _configure_content
        ;;
    2) # Behaviour
        _configure_behaviour
        ;;
esac
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| bash select menus | read-based prompts | Phase 9 | Better re-run UX, explicit numbering |
| All-or-nothing config | Opt-in per-config | Phase 9 | Users manage only what they need |
| Global-only config | Global + project hierarchy | Phase 8 (v2.0) | Per-project customisation |
| Implicit defaults | Opinionated defaults + explicit opt-in | Phase 9 | Clearer user intent |
| "installed"/"not installed" | "deployed"/"not deployed" | Phase 9 | Accurate terminology |
| .gitignore for personal excludes | .git/info/exclude | Phase 9 | Personal settings stay local |

**Deprecated/outdated:**
- `bash select` for wizards: Poor re-run behaviour, no edit mode support
- Hardcoded defaults for unselected configs: Pollutes .env, can't distinguish user choice
- `dots setup <plugin>`: Renamed to `dots global-configs <plugin>` (legacy still works)

## Open Questions

### Question 1: Category Grouping for Git Plugin Configs

**What we know:**
- Claude plugin has 3 categories (user-defined): Deploy targets, Content, Behaviour
- Git plugin has ~20 configs across identity, workflow, aliases, hooks
- User decision: "Claude's Discretion" for git category grouping

**What's unclear:**
- Optimal category structure for git configs
- Whether all git configs should be opt-in or some always shown

**Recommendation:**
Propose categories based on git config groups already in setup.sh:
1. **Identity** (user.name, user.email)
2. **Workflow** (pull.rebase, push.default, fetch.prune, init.defaultBranch)
3. **Aliases** (unstage, last, lg, amend, undo, wip + custom)
4. **Hooks** (all hook toggles + scope)

These align with existing wizard sections and user mental model.

### Question 2: Deploy-Time Settings Override Scope

**What we know:**
- User wants project-level overrides for configs
- Current deploy reads .env (global only)
- Project commands write directly to project

**What's unclear:**
- Should deploy-time settings (git identity, CLAUDE.md sections) be overridable per-project?
- If yes, how does `dots deploy` know which project scope to use?

**Recommendation:**
Research indicates NO deploy-time scope needed (see "Deploy Command and Project Config Interaction" section above). Project commands already handle project scope. Propose this to user for confirmation.

### Question 3: Per-Project Config Storage Location

**What we know:**
- User decision: "Storage: Plugin config files (each plugin owns its config) — not centralised .dotconfigs.json"
- Current codebase uses `.dotconfigs.json` for project metadata

**What's unclear:**
- Does "not centralised" mean abandon `.dotconfigs.json`?
- Or does it mean plugin-specific config files in addition to `.dotconfigs.json` for metadata?

**Recommendation:**
Clarify with user. Likely interpretation: `.dotconfigs.json` for tool metadata (which plugins, versions), but plugin config in plugin-owned files (`.claude/config.json`, `.git/config`). This aligns with existing patterns (git uses `.git/config`, not `.dotconfigs.json`).

## Sources

### Primary (HIGH confidence)

**Configuration Patterns:**
- [OpenCode Config Documentation](https://opencode.ai/docs/config/) - Configuration hierarchy and precedence
- [Git Configuration Levels](https://medium.com/codetodeploy/fine-tuning-git-a-deep-dive-into-configuration-levels-63183ee78827) - Local overrides global pattern
- [mise-en-place Configuration](https://mise.jdx.dev/configuration.html) - Directory-based config merging

**JSON vs .env:**
- [Working with JSON in bash using jq](https://cameronnokes.com/blog/working-with-json-in-bash-using-jq/) - jq capabilities and portability
- [Favor Config Files over Env Vars](https://medium.com/israeli-tech-radar/favor-config-files-over-env-vars-d9189d53c4b8) - When to use each format
- [jq Download](https://jqlang.org/download/) - Installation availability across platforms

**Git Exclusion:**
- [Git Ignore Documentation](https://git-scm.com/docs/gitignore) - Official pattern reference
- [.gitignore vs .git/info/exclude](https://www.yopa.page/blog/2024-11-1-understanding-git-ignore-patterns-gitignore-vs-git-info-exclude.html) - When to use each

**Terminal Colours:**
- [ANSI Color Codes](https://gist.github.com/JBlond/2fea43a3049b38287e5e9cefc87b2124) - Complete ANSI escape reference
- [Bash ANSI Colors](https://bashcommands.com/bash-ansi-color-codes/) - bash-specific usage patterns

### Secondary (MEDIUM confidence)

**CLI UX Patterns:**
- [UX Patterns for CLI Tools](https://www.lucasfcosta.com/blog/ux-patterns-cli-tools) - First-run wizard, progressive disclosure
- [Top 8 CLI UX Patterns](https://medium.com/@kaushalsinh73/top-8-cli-ux-patterns-users-will-brag-about-4427adb548b7) - Modern CLI best practices
- [Wizard Design Pattern](https://ui-patterns.com/patterns/Wizard) - General wizard UX principles

**Interactive Input:**
- [Bash Read User Input](https://www.geeksforgeeks.org/linux-unix/bash-script-read-user-input/) - Read command usage
- [Bash Select Command](https://www.techedubyte.com/bash-select-command-interactive-menus-shell-scripts/) - Select vs read tradeoffs

### Tertiary (LOW confidence)

None - all sources verified with official documentation or cross-referenced with multiple credible sources.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - established tools, verified in codebase
- Architecture patterns: HIGH - standard patterns with official documentation
- .env vs JSON recommendation: HIGH - based on portability requirements and current success
- Pitfalls: MEDIUM - synthesised from research and codebase analysis, not all empirically tested
- Deploy-time scope decision: HIGH - clear architectural boundary identified

**Research date:** 2026-02-09
**Valid until:** 60 days (configuration UX patterns stable, bash 3.2 not changing)
