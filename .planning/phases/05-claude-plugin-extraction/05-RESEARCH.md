# Phase 5: Claude Plugin Extraction - Research

**Researched:** 2026-02-07
**Domain:** Bash shell scripting, plugin architecture, configuration migration
**Confidence:** HIGH

## Summary

Phase 5 extracts the monolithic deploy.sh wizard and deployment logic into the plugin architecture established in Phase 4. This is a code migration task, not greenfield development. The existing deploy.sh (1085 lines) contains proven wizard flows, deployment logic, symlink management, and conflict handling that must be preserved whilst adopting the new plugin structure.

The standard approach is surgical extraction: migrate working code into plugin functions with minimal modification, add .env key prefixing for namespace isolation, preserve existing UX patterns (bash select, yes/no prompts, step headers), and maintain platform portability (macOS/Linux sed, readlink differences).

**Primary recommendation:** Extract incrementally (wizard → setup.sh, deploy → deploy.sh, assets → plugins/claude/), test each extraction against existing .env config, delete deploy.sh only after full feature parity is verified.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**`.env` namespacing:**
- All Claude plugin keys get `CLAUDE_*` prefix (full prefix, no exceptions)
- Clean break from old keys — re-run setup wizard to generate new `CLAUDE_*` keys
- Wizard pre-fills from old unprefixed keys as defaults (so users don't re-type), but saves as `CLAUDE_*`
- Old unprefixed keys are commented out with `# migrated to CLAUDE_*` note after wizard saves new keys

**Wizard flow:**
- Single sequential flow — same as current deploy.sh, one flow, answer everything, done
- Re-run shows current `CLAUDE_*` values as defaults — press Enter to keep, type to overwrite
- Summary of all settings shown at the end, confirm before writing to .env
- Setup and deploy are separate steps — `dotconfigs setup claude` writes .env only, `dotconfigs deploy claude` reads .env and acts

**Project command:**
- `dotconfigs project .` is a **top-level command**, not a plugin-specific action
- Each plugin hooks into the project command with its own project-level setup
- Plugin name is an optional filter: `dotconfigs project .` runs all plugins, `dotconfigs project claude .` runs just Claude
- Project setup is **interactive** — each plugin runs a short project-specific wizard
- Project settings stored in `.dotconfigs.json` in the project repo (single file for settings + metadata)
- User chooses per project whether to commit `.dotconfigs.json` or add to `.git/info/exclude`
- Phase 5 implements Claude's project contribution only; git project config comes in Phase 6

**Config format:**
- Global config: `.env` (bash-native sourcing, key-value pairs) — stays for v2.0
- Project config: `.dotconfigs.json` (structured JSON, parsed with jq)
- JSON everywhere deferred to v3.0 Python rewrite

**Templates:**
- Code-owned with variable substitution — users customise via wizard/.env, not by editing template files
- Templates use placeholders (e.g., `{{CLAUDE_GITHUB_USERNAME}}`) filled at deploy time

**Transition (no strangler fig):**
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

</user_constraints>

## Standard Stack

### Core Libraries (Built-in)
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| bash | 3.2+ | Shell scripting | Native to macOS/Linux, no dependencies |
| sed | BSD/GNU | Text manipulation | Platform differences require handling |
| jq | 1.6+ | JSON parsing | Industry standard for JSON in bash |
| find | POSIX | File discovery | Universal, no dependencies |

### Supporting Tools
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| perl | 5.x | Portable absolute paths | macOS readlink -f alternative |
| source | bash builtin | Load config/libs | .env loading, function sourcing |
| git | 2.x | Config storage | git config for global settings |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| bash | Python | Would require rewrite (deferred to v3.0) |
| .env | JSON | Bash can't parse JSON natively (needs jq) |
| bash select | whiptail/dialog | Adds external dependency |

**Installation:**
```bash
# Core tools (typically pre-installed)
which bash sed find perl git

# jq (may need installation)
brew install jq           # macOS
apt-get install jq        # Debian/Ubuntu
```

## Architecture Patterns

### Recommended Plugin Structure
```
plugins/claude/
├── setup.sh              # Wizard → .env (plugin_claude_setup)
├── deploy.sh             # .env → filesystem (plugin_claude_deploy)
├── project.sh            # Project scaffolding (plugin_claude_project)
├── templates/
│   ├── claude-md/        # CLAUDE.md sections
│   ├── settings/         # settings.json overlays
│   └── hooks-conf/       # hooks.conf profiles
├── hooks/                # Claude Code hooks (PostToolUse, etc)
├── commands/             # Slash commands (commit, squash-merge)
└── DESCRIPTION           # One-line plugin description
```

### Pattern 1: Plugin Function Naming
**What:** Consistent naming for plugin entry points
**When to use:** All plugin functions
**Example:**
```bash
# Source: Current dotconfigs implementation
plugin_claude_setup() {
    # Interactive wizard that writes to .env
}

plugin_claude_deploy() {
    # Read .env, deploy to filesystem
}

plugin_claude_project() {
    # Project-specific scaffolding
}
```

**Key conventions:**
- All plugin functions prefixed with `plugin_<name>_<action>`
- Internal functions use leading underscore: `_claude_build_md`
- Double underscore for very internal: `__validate_key`

### Pattern 2: .env Key Prefixing and Migration
**What:** Namespace isolation via consistent key prefixes
**When to use:** All plugin-specific configuration
**Example:**
```bash
# OLD (deploy.sh, no prefix)
DEPLOY_TARGET="$HOME/.claude"
SETTINGS_ENABLED="true"
GSD_INSTALL="false"

# NEW (plugin/claude, CLAUDE_* prefix)
CLAUDE_DEPLOY_TARGET="$HOME/.claude"
CLAUDE_SETTINGS_ENABLED="true"
CLAUDE_GSD_INSTALL="false"
```

**Migration strategy:**
```bash
# 1. Wizard pre-fills from old keys
local old_target="${DEPLOY_TARGET:-$HOME/.claude}"
wizard_prompt "Deploy target" "$old_target" CLAUDE_DEPLOY_TARGET

# 2. Save with new prefix
wizard_save_env "$ENV_FILE" "CLAUDE_DEPLOY_TARGET" "$CLAUDE_DEPLOY_TARGET"

# 3. Comment out old keys
sed -i.bak 's/^DEPLOY_TARGET=/# migrated to CLAUDE_* \n# DEPLOY_TARGET=/' "$ENV_FILE"
```

### Pattern 3: Wizard Summary and Confirmation
**What:** Display all choices before committing to .env
**When to use:** End of setup wizards
**Example:**
```bash
wizard_header 9 "Configuration Summary"
echo "Deploy target:      $CLAUDE_DEPLOY_TARGET"
echo "Settings enabled:   $CLAUDE_SETTINGS_ENABLED"
echo "CLAUDE.md sections: ${CLAUDE_SECTIONS[*]}"
echo "Hooks enabled:      ${CLAUDE_HOOKS[*]}"
echo ""
if wizard_yesno "Save this configuration?" "y"; then
    save_config
else
    echo "Configuration not saved. Re-run wizard to try again."
    exit 0
fi
```

### Pattern 4: Platform-Portable sed
**What:** Handle macOS (BSD sed) vs Linux (GNU sed) differences
**When to use:** In-place file editing
**Example:**
```bash
# Source: Current codebase pattern
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|^${key}=.*|${key}=${value}|" "$env_file"
else
    sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
fi
```

### Pattern 5: Template Variable Substitution
**What:** Replace placeholders with runtime values
**When to use:** CLAUDE.md generation, settings.json merging
**Example:**
```bash
# Simple approach for bash-readable templates
while IFS= read -r line; do
    line="${line//\{\{CLAUDE_DEPLOY_TARGET\}\}/$CLAUDE_DEPLOY_TARGET}"
    line="${line//\{\{CLAUDE_GIT_USER\}\}/$CLAUDE_GIT_USER}"
    echo "$line"
done < "$template_file" > "$output_file"

# Alternative: envsubst (requires exported variables)
export CLAUDE_DEPLOY_TARGET CLAUDE_GIT_USER
envsubst < "$template_file" > "$output_file"
```

### Pattern 6: JSON Project Config (jq)
**What:** Read/write structured project settings
**When to use:** Per-project configuration in .dotconfigs.json
**Example:**
```bash
# Read value from JSON
project_type=$(jq -r '.plugins.claude.project_type // "generic"' .dotconfigs.json)

# Write value to JSON (merge-friendly)
jq '.plugins.claude.project_type = "python"' .dotconfigs.json > .dotconfigs.tmp
mv .dotconfigs.tmp .dotconfigs.json

# Check if key exists
if jq -e '.plugins.claude' .dotconfigs.json >/dev/null 2>&1; then
    echo "Claude config exists"
fi
```

### Anti-Patterns to Avoid

- **Sourcing .env blindly:** Code injection risk if .env contains `$(malicious)` commands. Current deploy.sh sources directly (acceptable for local use), but consider parsing for multi-user systems.
- **Assuming GNU sed:** macOS ships BSD sed. Always check `$OSTYPE` or provide backup extension.
- **Hard-coded paths in templates:** Use placeholders like `{{CLAUDE_DEPLOY_TARGET}}`, not `~/.claude`
- **Global namespace pollution:** Prefix all plugin functions/variables to avoid conflicts

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON merging | String concatenation | `jq -s '.[0] * .[1]' base.json overlay.json` | Handles nested objects, arrays, escaping |
| Absolute path resolution | `cd $dir && pwd` | `perl -MCwd -le 'print Cwd::abs_path(shift)'` (macOS) or `readlink -f` (Linux) | Cross-platform, handles symlinks correctly |
| .env parsing | Regex in bash | `set -a; source .env; set +a` (simple) or dedicated parser (complex) | Handles quoting, multiline, export automatically |
| Interactive prompts | Raw `read -p` loops | Existing wizard.sh functions (wizard_prompt, wizard_yesno, wizard_select) | Consistent UX, default handling, validation |
| Symlink ownership | `ls -l \| grep ^l` | `readlink` + path comparison (existing is_dotclaude_owned function) | Portable, handles absolute paths correctly |

**Key insight:** Bash lacks native JSON, safe .env parsing, and portable path handling. Use proven libraries (wizard.sh, validation.sh) and tools (jq, perl) rather than reimplementing.

## Common Pitfalls

### Pitfall 1: sed In-Place Editing Breaks on macOS
**What goes wrong:** `sed -i 's/foo/bar/' file` works on Linux, fails on macOS
**Why it happens:** BSD sed requires backup extension after -i flag
**How to avoid:** Always branch on `$OSTYPE`:
```bash
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' 's/foo/bar/' file  # Empty string = no backup
else
    sed -i 's/foo/bar/' file     # GNU sed
fi
```
**Warning signs:** "sed: 1: "file": undefined label" on macOS

### Pitfall 2: Array Serialisation to .env
**What goes wrong:** Bash arrays can't be stored directly in .env (which is sourced as bash, but only supports scalars)
**Why it happens:** .env format is `KEY=VALUE`, no native array syntax
**How to avoid:** Serialise arrays as space-separated strings:
```bash
# Write
hooks_str="${CLAUDE_HOOKS[*]}"  # Space-separated
wizard_save_env "$ENV_FILE" "CLAUDE_HOOKS" "$hooks_str"

# Read
IFS=' ' read -ra CLAUDE_HOOKS <<< "$CLAUDE_HOOKS"
```
**Warning signs:** Only first array element appears in .env

### Pitfall 3: Relative Paths in Symlinks
**What goes wrong:** Symlinks break when user navigates from different directory
**Why it happens:** Symlinks store paths as-is; relative paths are relative to link location
**How to avoid:** Always create symlinks with absolute source paths:
```bash
# BAD
ln -s ../templates/settings.json ~/.claude/settings.json

# GOOD
ln -s "$SCRIPT_DIR/templates/settings.json" ~/.claude/settings.json
```
**Warning signs:** "No such file or directory" when following symlinks

### Pitfall 4: Template Substitution Without Escaping
**What goes wrong:** Template contains `$VAR` or `$(cmd)`, gets expanded during generation
**Why it happens:** Bash parameter expansion happens in unquoted strings
**How to avoid:**
```bash
# Use single quotes or escape dollars
line="${line//\{\{VAR\}\}/$value}"  # Safe: {{ }} format
line="${line//\$VAR/$value}"        # Safe: escaped $

# Or read with IFS= to preserve literal content
while IFS= read -r line; do
    # Process line
done < "$template"
```
**Warning signs:** Template values disappear or unexpected command execution

### Pitfall 5: Forgetting to Export for envsubst
**What goes wrong:** `envsubst < template` produces empty values
**Why it happens:** envsubst only sees environment variables, not shell variables
**How to avoid:** Export before using envsubst:
```bash
export CLAUDE_DEPLOY_TARGET CLAUDE_GIT_USER
envsubst < template.md > output.md
```
**Warning signs:** `{{VAR}}` appears unchanged in output

### Pitfall 6: jq Modifying JSON Loses Formatting
**What goes wrong:** `jq '.key = "value"' file.json` loses comments, custom spacing
**Why it happens:** jq parses and re-serialises JSON (which doesn't support comments)
**How to avoid:** Accept jq's formatting as canonical, or use `--indent` for readability:
```bash
jq --indent 2 '.key = "value"' file.json > tmp.json
mv tmp.json file.json
```
**Warning signs:** User-added comments in .dotconfigs.json disappear

### Pitfall 7: Wizard Pre-Fill From Old Keys Fails Silently
**What goes wrong:** Old keys exist but wizard shows empty defaults
**Why it happens:** .env not loaded before wizard runs, or variable scope issue
**How to avoid:** Load existing .env early, preserve raw values:
```bash
# Early in setup function
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"  # Load old keys
fi

# Use old unprefixed as fallback
local default_target="${CLAUDE_DEPLOY_TARGET:-${DEPLOY_TARGET:-$HOME/.claude}}"
wizard_prompt "Deploy target" "$default_target" CLAUDE_DEPLOY_TARGET
```
**Warning signs:** Wizard shows defaults for first run but not on re-run

## Code Examples

Verified patterns from current codebase:

### Wizard Flow with Summary
```bash
# Source: deploy.sh lines 98-303
run_wizard() {
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         dotclaude Global Deployment Wizard                 ║"
    echo "╚════════════════════════════════════════════════════════════╝"

    # Steps 1-8: Gather config
    wizard_header 1 "Deploy Target"
    wizard_prompt "Deploy target directory" "${DEPLOY_TARGET:-$HOME/.claude}" DEPLOY_TARGET

    # ... (more steps)

    # Step 9: Summary
    wizard_header 9 "Configuration Summary"
    echo "Deploy target:      $DEPLOY_TARGET"
    echo "Settings enabled:   $SETTINGS_ENABLED"
    echo ""

    # Save after all steps complete
    save_config
}
```

### Discovery Pattern (Content Scanning)
```bash
# Source: lib/discovery.sh
discover_claude_sections() {
    local dotclaude_root="$1"
    local templates_dir="$dotclaude_root/templates/claude-md"

    if [[ ! -d "$templates_dir" ]]; then
        return 0
    fi

    find "$templates_dir" -type f -name "*.md" | while read -r template_path; do
        local filename section_name
        filename=$(basename "$template_path")
        # Extract: "01-communication.md" → "communication"
        section_name=$(echo "$filename" | sed -E 's/^[0-9]+-(.*)\.md$/\1/')
        echo "$section_name"
    done | sort
}
```

### Symlink Management with Conflict Handling
```bash
# Source: lib/symlinks.sh
backup_and_link() {
    local src="$1"
    local dest="$2"
    local name="$3"
    local interactive="$4"

    # If dest doesn't exist, create symlink
    if [[ ! -e "$dest" && ! -L "$dest" ]]; then
        ln -sfn "$src" "$dest"
        echo "  ✓ Linked $name"
        return 0
    fi

    # If dest exists and is owned by dotclaude, overwrite silently
    if is_dotclaude_owned "$dest" "$dotclaude_root"; then
        ln -sfn "$src" "$dest"
        echo "  ✓ Updated $name"
        return 0
    fi

    # Conflict: interactive prompt
    if [[ "$interactive" == "true" ]]; then
        echo "  ! Conflict: $name already exists"
        read -p "    [o]verwrite, [s]kip, [b]ackup: " choice
        case "$choice" in
            o|overwrite)
                ln -sfn "$src" "$dest"
                echo "  ✓ Overwrote $name"
                ;;
            b|backup)
                mv "$dest" "${dest}.backup.$(date +%Y%m%d-%H%M%S)"
                ln -sfn "$src" "$dest"
                echo "  ✓ Backed up and linked $name"
                ;;
            *)
                echo "  - Skipped $name"
                return 1
                ;;
        esac
    fi
}
```

### Settings.json Merging (JSON Overlays)
```bash
# Source: deploy.sh lines 732-772
merge_settings_json() {
    local base_file="$1"
    local overlay_file="$2"
    local output_file="$3"

    if command -v jq &> /dev/null; then
        # jq merge: overlay overwrites base
        jq -s '.[0] * .[1]' "$base_file" "$overlay_file" > "$output_file"
    else
        # Fallback: Python-based deep merge
        python3 <<EOF
import json

with open("$base_file") as f:
    base = json.load(f)
with open("$overlay_file") as f:
    overlay = json.load(f)

def deep_merge(base, overlay):
    for key, value in overlay.items():
        if key in base and isinstance(base[key], dict) and isinstance(value, dict):
            deep_merge(base[key], value)
        else:
            base[key] = value
    return base

result = deep_merge(base, overlay)

with open("$output_file", "w") as f:
    json.dump(result, f, indent=2)
EOF
    fi
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Monolithic deploy.sh | Plugin architecture | Phase 4 (v2.0) | Each config domain isolated, multi-plugin support |
| Unprefixed .env keys | CLAUDE_* prefixed keys | Phase 5 (v2.0) | Namespace isolation prevents key collisions |
| Wizard + deploy in one command | Separate setup/deploy commands | Phase 4 (v2.0) | Re-deploy without re-answering questions |
| Project config in bash | .dotconfigs.json with jq | Phase 5 (v2.0) | Structured project config, multi-plugin coordination |
| Bash everywhere | Python rewrite planned | v3.0 (future) | Better JSON, typing, testing |

**Deprecated/outdated:**
- `deploy.sh global --interactive`: Flag is now no-op (wizard always runs). Removed in Phase 5 — separate `setup` command makes flag unnecessary.
- Strangler fig migration: Originally planned to keep deploy.sh as wrapper. Changed to clean break in Phase 5.
- Single .env file assumption: v2.0 introduces per-plugin namespacing (CLAUDE_*, GIT_*), but still single file for bash sourcing simplicity.

## Open Questions

Things that couldn't be fully resolved:

1. **GSD Framework Coexistence**
   - What we know: GSD uses file-level symlinks (agents/, plugins/ → ~/.claude/), current deploy.sh handles this
   - What's unclear: Should plugin architecture preserve symlink approach, or integrate GSD as a plugin?
   - Recommendation: Keep current approach (symlink GSD files into ~/.claude/) until GSD plugin extraction (Phase 7). Document in Claude's discretion area.

2. **Menu Style for Feature Selection**
   - What we know: Current deploy.sh uses wizard_yesno for yes/no per feature (hooks, skills, sections)
   - What's unclear: Would bash select (numbered menu) be better UX? Less repetitive but harder to skip unwanted items.
   - Recommendation: Start with current wizard_yesno (minimal change), add select menu in future iteration if users request it.

3. **Project Config Structure (.dotconfigs.json)**
   - What we know: JSON storage, jq parsing, per-plugin namespace
   - What's unclear: Exact schema — flat `plugins.claude.*` keys vs nested objects? Metadata fields?
   - Recommendation: Start minimal (plugin name + enabled features), extend as git plugin (Phase 6) defines needs. Example schema:
   ```json
   {
     "version": "2.0",
     "plugins": {
       "claude": {
         "project_type": "python",
         "settings_profile": "strict"
       }
     }
   }
   ```

4. **Legacy Feature Removal**
   - What we know: deploy.sh has remote deployment (--remote, --method rsync), shell aliases setup
   - What's unclear: Which features to drop? Remote deploy used? Shell aliases still relevant?
   - Recommendation: Audit with user — if remote deploy unused, drop it. Shell aliases stay (convenient). GSD install moves to GSD plugin (Phase 7).

5. **Migration User Experience**
   - What we know: Wizard pre-fills from old keys, comments them out after save
   - What's unclear: Should wizard show explicit "migrating from old keys" message, or silent?
   - Recommendation: Silent pre-fill (less noise), but add one-time migration notice on first v2.0 run: "Detected v1 config, migrating to v2.0 format..."

## Sources

### Primary (HIGH confidence)
- Current codebase inspection:
  - deploy.sh (wizard flow, deployment logic, conflict handling)
  - lib/wizard.sh (prompt helpers, yes/no, env save)
  - lib/symlinks.sh (ownership detection, backup_and_link pattern)
  - lib/discovery.sh (content scanning, plugin discovery)
  - lib/validation.sh (path validation, git repo checks)
  - dotconfigs (CLI entry point, plugin routing)

### Secondary (MEDIUM confidence)
- [Baeldung: Set Environment Variables From File](https://www.baeldung.com/linux/environment-variables-file) — .env parsing best practices
- [Baeldung: Guide to Linux jq Command](https://www.baeldung.com/linux/jq-command-json) — JSON parsing in bash
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) — Function naming conventions
- [Fixing sed -i Portability](https://sqlpey.com/bash/sed-in-place-portability-fix/) — macOS vs Linux sed differences
- [Baeldung: Substitute Shell Variables in Text File](https://www.baeldung.com/linux/substitute-variables-text-file) — Template substitution patterns
- [Baeldung: Symlinks Permissions](https://www.baeldung.com/linux/symlinks-permissions) — Symlink ownership handling

### Tertiary (LOW confidence)
- [GitHub: bash-templater](https://github.com/johanhaleby/bash-templater) — Template variable substitution (example tool, not used)
- [Opensource.com: Parsing Config Files](https://opensource.com/article/21/6/bash-config) — Alternative config parsing approaches
- Various bash scripting convention articles — General best practices, not specific to this architecture

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — All tools verified in current codebase, versions known
- Architecture: HIGH — Patterns extracted from working deploy.sh, proven in production
- Pitfalls: HIGH — Based on actual platform differences (macOS sed, readlink) handled in current code
- Migration strategy: MEDIUM — User decisions define approach, but implementation details need validation during planning
- Project config schema: MEDIUM — Basic structure clear, exact schema needs definition during implementation

**Research date:** 2026-02-07
**Valid until:** 60 days (stable bash ecosystem, code migration task not subject to rapid external change)

**Key extraction targets from deploy.sh:**
- Lines 98-303: `run_wizard()` → plugin_claude_setup()
- Lines 427-536: `deploy_global()` → plugin_claude_deploy()
- Lines 774-1053: `cmd_project()` → plugin_claude_project()
- Lines 306-337: `save_config()` → _claude_save_config() (internal helper)
- Lines 48-95: `build_claude_md()` → _claude_build_md() (internal helper)

**Shared library dependencies:**
- lib/wizard.sh: Already migrated from scripts/lib/ in Phase 4
- lib/symlinks.sh: Already migrated from scripts/lib/ in Phase 4
- lib/discovery.sh: Already migrated from scripts/lib/ in Phase 4
- lib/validation.sh: New in Phase 4, ready for use

**Template migration:**
- templates/claude-md/ → plugins/claude/templates/claude-md/
- templates/settings/ → plugins/claude/templates/settings/
- templates/hooks-conf/ → plugins/claude/templates/hooks-conf/
- hooks/ → plugins/claude/hooks/
- commands/ → plugins/claude/commands/
