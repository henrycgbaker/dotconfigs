# Phase 11: JSON Config + Core Deploy - Research

**Researched:** 2026-02-11
**Domain:** Bash JSON parsing, file deployment, symlink management
**Confidence:** HIGH

## Summary

Phase 11 replaces the wizard-driven .env configuration model with explicit JSON config files (global.json, project.json) that define source→target mappings for file deployment. The core challenge is building a generic file deployer in Bash 3.2 that reads nested JSON, resolves paths, and creates symlinks/copies idempotently.

The standard approach is to use `jq` for JSON parsing in Bash, combined with robust symlink management using `ln -sfn`. The existing codebase already has solid symlink ownership detection and conflict handling patterns in `lib/symlinks.sh`. The key architectural shift is moving from plugin-aware deployment (plugins/*/deploy.sh) to a generic JSON-driven deployer that treats all modules uniformly.

Git config will be managed as a native INI file (`plugins/git/gitconfig`) symlinked directly to `~/.gitconfig`, allowing `git config --global` commands to write through the symlink back into the repo. This is simpler and more auditable than the current approach of using `git config` commands to write values.

**Primary recommendation:** Build a generic JSON parser that walks the config tree recursively using `jq`, extracts source/target/method/include for each module, and delegates to existing symlink management functions. Keep the deployer plugin-agnostic — it should work identically whether deploying "claude", "git", "vscode", or any arbitrary top-level key.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| jq | 1.7.1+ | JSON parsing in Bash | Industry-standard JSON processor for shell scripts, mature and universally available |
| bash | 3.2+ | Shell scripting | macOS requirement, must avoid bash 4+ features |
| ln | GNU/BSD | Symlink creation | Built-in, cross-platform, idempotent with `-sfn` flags |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| perl | 5.x | Path resolution (macOS) | macOS lacks `readlink -f`, use perl for absolute path resolution |
| sed | GNU/BSD | String manipulation | In-place editing, tilde expansion in gitconfig |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| jq | Python json.loads | Adds Python dependency, more complex for simple queries |
| jq | grep -oP regex | Fragile, breaks on nested structures, not recommended for production |
| jq | JSON.sh native parser | Added maintenance burden, slower, jq is already ubiquitous |

**Installation:**
```bash
# macOS
brew install jq

# Linux (Debian/Ubuntu)
apt-get install jq

# Check dependency
command -v jq >/dev/null 2>&1 || { echo "Error: jq is required"; exit 1; }
```

## Architecture Patterns

### Recommended Project Structure
```
dotconfigs/
├── global.json              # Global deployment config
├── project.json.example     # Reference for per-project config
├── lib/
│   ├── symlinks.sh         # Existing ownership/conflict handling
│   ├── json-parser.sh      # New: jq wrapper for config parsing
│   └── deploy.sh           # New: generic deployment engine
└── plugins/
    ├── claude/
    │   ├── hooks/
    │   ├── commands/
    │   └── settings.json
    ├── git/
    │   ├── gitconfig        # Native INI format
    │   ├── global-excludes
    │   └── hooks/
    └── vscode/
        ├── settings.json
        └── keybindings.json
```

### Pattern 1: JSON Config Schema

**What:** Nested JSON with arbitrary top-level keys, modules identified by presence of `source`+`target` fields

**When to use:** All deployment configuration

**Example:**
```jsonc
// Source: PROJECT.md requirements + global.json in repo
{
  "claude": {
    "hooks": {
      "source": "plugins/claude/hooks",      // Always relative to repo root
      "target": "~/.claude/hooks",            // Tilde-expanded for global
      "method": "symlink",                    // Required: symlink|copy|append
      "include": ["block-destructive.sh"]     // Optional: filter files
    }
  },
  "git": {
    "config": {
      "source": "plugins/git/gitconfig",
      "target": "~/.gitconfig",
      "method": "symlink"
    }
  }
}
```

**Key principles:**
- Top-level keys are arbitrary labels (tool is generic)
- `source` paths ALWAYS relative to repo root
- `target` paths absolute (global.json) or relative to project root (project.json)
- `method` field explicit, no defaults
- `include` array optional, omit to deploy all files

### Pattern 2: Recursive JSON Walking with jq

**What:** Use jq's `..` (recursive descent) and `select()` to find all module definitions

**When to use:** Discovering modules in nested JSON without hardcoding structure

**Example:**
```bash
# Find all objects with "source" and "target" fields
jq -r '
  .. |
  select(type == "object") |
  select(has("source") and has("target")) |
  "\(.source)|\(.target)|\(.method)|\(.include // [] | join(","))"
' global.json
```

**Why this works:**
- `..` recursively descends all values
- `select(type == "object")` filters to objects only
- `select(has("source") and has("target"))` identifies module definitions
- Tool doesn't care about key names ("claude", "git", etc.)

### Pattern 3: Idempotent Symlink Creation

**What:** Use `ln -sfn` to create symlinks that can be run repeatedly safely

**When to use:** All symlink creation

**Example:**
```bash
# Source: https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/
# -s: symbolic link
# -f: force (remove destination if exists)
# -n: treat destination as normal file if it's a symlink to a directory
ln -sfn "$source" "$target"
```

**Critical:** The `-n` flag prevents following symlinks to directories, which would create the link inside the target directory instead of replacing it.

### Pattern 4: Tilde Expansion in Bash

**What:** Tilde expansion only happens in specific contexts, not in variable assignments

**When to use:** Converting `~/.claude/hooks` to absolute paths

**Example:**
```bash
# Source: https://www.gnu.org/software/bash/manual/html_node/Tilde-Expansion.html
# Tilde expansion happens in unquoted variable assignments after = or :
target="~/.claude/hooks"        # NO expansion (quoted)
target=~/.claude/hooks          # YES expansion (unquoted)

# Workaround: Use eval or manual expansion
target="${target/#\~/$HOME}"    # Replace leading tilde with HOME
target=$(eval echo "$target")   # Eval expansion (use carefully)
```

**Recommended approach:**
```bash
expand_tilde() {
    local path="$1"
    # Replace leading ~ or ~/
    echo "${path/#\~/$HOME}"
}
```

### Pattern 5: Directory Source with Include Filter

**What:** When source is a directory, deploy individual files (not directory symlink)

**When to use:** Hooks directories, snippets directories

**Example:**
```bash
# Wrong: Creates directory symlink (breaks GSD coexistence)
ln -sfn "plugins/claude/hooks" "~/.claude/hooks"

# Right: Create target directory, symlink each file individually
mkdir -p ~/.claude/hooks
for file in plugins/claude/hooks/*; do
    ln -sfn "$PWD/$file" ~/.claude/hooks/$(basename "$file")
done

# With include filter
include_files=("block-destructive.sh" "post-tool-format.py")
for file in "${include_files[@]}"; do
    ln -sfn "$PWD/plugins/claude/hooks/$file" ~/.claude/hooks/$file
done
```

### Pattern 6: Git Config Write-Through Symlink

**What:** Symlink `~/.gitconfig` directly to `plugins/git/gitconfig` so `git config --global` writes back to repo

**When to use:** Git configuration management

**Example:**
```bash
# Deploy
ln -sfn "$DOTCONFIGS_ROOT/plugins/git/gitconfig" ~/.gitconfig

# User runs git config --global
git config --global user.email "new@example.com"

# Result: plugins/git/gitconfig is modified in the repo
# User sees change in git diff, can commit it
```

**Important:** Git follows symlinks when writing config. This is documented behavior (though some older versions had bugs). User changes are immediately visible in the repo.

**Reference:** Git config documentation states writes go to the file path, and symlinks are followed for writes (as of Git 2.x+).

### Anti-Patterns to Avoid

- **Hardcoding plugin names:** Tool should discover modules by finding source/target pairs, not by checking for "claude" or "git" keys
- **Directory symlinks for hooks:** Breaks coexistence with other tools (GSD). Always symlink files individually.
- **Implicit method defaults:** Explicitly require `"method": "symlink"` even when it's obvious. Prevents ambiguity.
- **Relative source paths in project.json:** Source paths must resolve against dotconfigs repo root, not project root. Only targets are relative to project.
- **Using bash 4+ features:** No associative arrays, no namerefs (`local -n`), no `${var,,}` lowercase expansion

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing in bash | Custom grep/sed parser | jq | jq handles nested objects, arrays, escaping, Unicode. Custom parsers break on edge cases. |
| Path resolution (macOS) | String manipulation | perl -MCwd -le 'print Cwd::abs_path(shift)' | Handles symlinks, relative paths, edge cases that string manipulation misses. |
| Symlink ownership detection | Check ls -l output | Existing `is_dotconfigs_owned()` in lib/symlinks.sh | Already handles cross-platform readlink differences, resolves paths correctly. |
| Config hierarchy | Multiple config sources | Existing `_config_resolve()` in lib/config.sh | Implements precedence: defaults → env vars → config file. |

**Key insight:** The codebase already has battle-tested symlink and config management. Phase 11 is about adding JSON parsing and reorganizing around JSON schema, not rewriting what works.

## Common Pitfalls

### Pitfall 1: Bash 3.2 Namerefs

**What goes wrong:** Using `local -n ref="$var"` or `declare -n` causes "invalid option" errors on macOS

**Why it happens:** Namerefs were added in Bash 4.3. macOS ships Bash 3.2 due to GPL v3 licensing.

**How to avoid:**
- Never use `local -n` or `declare -n`
- Use indirect expansion: `${!var_name}` instead
- For incrementing: Use `eval` carefully or pass by variable name

**Warning signs:**
- Code works on Linux but fails on macOS
- "local: -n: invalid option" error
- Code references copied from bash 4+ examples

**Reference:** https://mywiki.wooledge.org/BashFAQ/006 documents bash 3.2 limitations

### Pitfall 2: Tilde Expansion in Quoted Strings

**What goes wrong:** Target path `"~/.claude/hooks"` stays as literal tilde, symlink fails

**Why it happens:** Bash only expands tilde in unquoted contexts or after `=` in assignments

**How to avoid:**
```bash
# Wrong
target="~/.claude/hooks"
ln -sfn "$source" "$target"  # Creates literal "~/..." directory

# Right
expand_tilde() { echo "${1/#\~/$HOME}"; }
target=$(expand_tilde "~/.claude/hooks")
ln -sfn "$source" "$target"
```

**Warning signs:**
- Directories named `~` appearing in filesystem
- "No such file or directory" but path looks correct
- Works when target is absolute but fails with tilde

### Pitfall 3: Directory Symlink vs File Symlinks

**What goes wrong:** Creating `ln -sfn source_dir target_dir` creates directory symlink, other tools can't coexist

**Why it happens:** Intuitive to symlink entire directory, but breaks when multiple tools manage same target

**How to avoid:**
```bash
# Wrong
ln -sfn plugins/claude/hooks ~/.claude/hooks

# Right
mkdir -p ~/.claude/hooks
for file in plugins/claude/hooks/*; do
    ln -sfn "$PWD/$file" ~/.claude/hooks/$(basename "$file")
done
```

**Warning signs:**
- GSD hooks stop working after dotconfigs deploy
- Other tools complain about symlink where directory expected
- Requirement CONF-07 states "deploy each file individually"

**Reference:** REQUIREMENTS.md CONF-07, plus GSD coexistence decision in STATE.md

### Pitfall 4: jq Output Quoting

**What goes wrong:** jq outputs JSON strings with quotes: `"value"` instead of `value`

**Why it happens:** jq preserves JSON types by default

**How to avoid:**
```bash
# Wrong
value=$(echo "$json" | jq '.field')  # value="\"string\""

# Right - use -r for raw output
value=$(echo "$json" | jq -r '.field')  # value="string"
```

**Warning signs:**
- Variables contain extra quotes
- String comparisons fail unexpectedly
- Paths have quotes in the middle

**Reference:** https://jqlang.github.io/jq/manual/ documents `-r` flag for raw output

### Pitfall 5: Git Config Symlink Replacement

**What goes wrong:** Some Git versions replace symlinked `~/.gitconfig` with regular file on write

**Why it happens:** Older Git versions (pre-2.0) didn't preserve symlinks on write

**How to avoid:**
- Require Git 2.0+ (check with `git --version`)
- Test write-through after deployment
- Document known issue for older systems

**Warning signs:**
- `~/.gitconfig` becomes regular file after `git config --global`
- Changes don't appear in dotconfigs repo
- Works on one machine but not another

**Reference:** Git mailing list discussion at https://git.vger.kernel.narkive.com/IdZJvWVQ/config-replaces-config-symlink-with-real-file

Note: Modern Git (2.0+) preserves symlinks correctly. This is mainly a historical concern, but worth checking in deployment.

### Pitfall 6: jq Empty vs Missing Fields

**What goes wrong:** jq queries fail or produce unexpected output when optional fields are missing

**Why it happens:** `.field` fails on missing field, need `// empty` or `// []` for defaults

**How to avoid:**
```bash
# Wrong - fails if include is missing
jq -r '.include[]'

# Right - provide default
jq -r '.include // [] | .[]'
```

**Warning signs:**
- Parse errors on valid JSON
- Empty modules skipped
- Deployment fails on modules without `include` field

**Reference:** https://jqlang.github.io/jq/manual/ documents `//` alternative operator

## Code Examples

Verified patterns from official sources and existing codebase:

### Parse All Modules from JSON

```bash
# Source: Existing codebase pattern + jq manual
# Find all module definitions recursively
parse_modules() {
    local config_file="$1"

    # Use jq to find all objects with source and target
    jq -r '
        .. |
        select(type == "object") |
        select(has("source") and has("target")) |
        [
            .source,
            .target,
            .method,
            (.include // [] | join(","))
        ] |
        @tsv
    ' "$config_file"
}

# Usage
while IFS=$'\t' read -r source target method include; do
    echo "Module: $source -> $target ($method)"
    if [[ -n "$include" ]]; then
        IFS=',' read -ra include_files <<< "$include"
        echo "  Include: ${include_files[*]}"
    fi
done < <(parse_modules "global.json")
```

### Deploy Single Module with Method

```bash
# Source: Existing lib/symlinks.sh + new method support
deploy_module() {
    local source="$1"
    local target="$2"
    local method="$3"
    local include_list=("${@:4}")  # Remaining args are include files

    # Expand tilde in target
    target="${target/#\~/$HOME}"

    # Make source absolute if relative
    if [[ "$source" != /* ]]; then
        source="$DOTCONFIGS_ROOT/$source"
    fi

    case "$method" in
        symlink)
            if [[ -d "$source" ]]; then
                # Directory source: deploy files individually
                deploy_directory_symlinks "$source" "$target" "${include_list[@]}"
            else
                # File source: direct symlink
                backup_and_link "$source" "$target" "$(basename "$target")" "$interactive_mode"
            fi
            ;;
        copy)
            # Copy file (preserve permissions)
            mkdir -p "$(dirname "$target")"
            cp -p "$source" "$target"
            echo "  ✓ Copied $(basename "$source") -> $target"
            ;;
        append)
            # Append patterns to file
            mkdir -p "$(dirname "$target")"
            touch "$target"
            cat "$source" >> "$target"
            echo "  ✓ Appended $(basename "$source") -> $target"
            ;;
        *)
            echo "  ! Unknown method: $method" >&2
            return 1
            ;;
    esac
}
```

### Deploy Directory with Include Filter

```bash
# Source: Existing deploy.sh patterns + new include support
deploy_directory_symlinks() {
    local source_dir="$1"
    local target_dir="$2"
    shift 2
    local include_files=("$@")

    # Create target directory
    mkdir -p "$target_dir"

    # If include list provided, deploy only those files
    if [[ ${#include_files[@]} -gt 0 ]]; then
        for file in "${include_files[@]}"; do
            local src="$source_dir/$file"
            local tgt="$target_dir/$file"
            if [[ ! -f "$src" ]]; then
                echo "  ! Warning: $file not found in $source_dir" >&2
                continue
            fi
            backup_and_link "$src" "$tgt" "$file" "$interactive_mode"
        done
    else
        # No include list: deploy all files
        for src in "$source_dir"/*; do
            [[ ! -f "$src" ]] && continue
            local file=$(basename "$src")
            local tgt="$target_dir/$file"
            backup_and_link "$src" "$tgt" "$file" "$interactive_mode"
        done
    fi
}
```

### Check jq Dependency

```bash
# Source: Standard dependency checking pattern
check_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        cat >&2 <<EOF
Error: jq is required for JSON config parsing

Install with:
  macOS:   brew install jq
  Ubuntu:  sudo apt-get install jq
  Fedora:  sudo dnf install jq

See: https://jqlang.github.io/jq/download/
EOF
        return 1
    fi

    # Check version (require 1.5+)
    local version=$(jq --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    if [[ -z "$version" ]]; then
        echo "Warning: Could not detect jq version" >&2
        return 0
    fi

    # jq 1.5+ has stable API we rely on
    local major=$(echo "$version" | cut -d. -f1)
    local minor=$(echo "$version" | cut -d. -f2)
    if [[ $major -lt 1 ]] || [[ $major -eq 1 && $minor -lt 5 ]]; then
        echo "Warning: jq $version detected, 1.5+ recommended" >&2
    fi

    return 0
}
```

### Filter Modules by Group

```bash
# Support `dotconfigs deploy <group>` to deploy only one top-level key
parse_modules_in_group() {
    local config_file="$1"
    local group_key="$2"

    if [[ -z "$group_key" ]]; then
        # No group specified: parse all modules
        parse_modules "$config_file"
    else
        # Parse only modules under specified group
        jq -r --arg group "$group_key" '
            .[$group] |
            .. |
            select(type == "object") |
            select(has("source") and has("target")) |
            [
                .source,
                .target,
                .method,
                (.include // [] | join(","))
            ] |
            @tsv
        ' "$config_file"
    fi
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| .env config with space-separated values | JSON with explicit schema | v3.0 (2026-02) | User-editable config, no quoting issues, structured data |
| Plugin-specific deploy.sh scripts | Generic JSON-driven deployer | v3.0 (2026-02) | Add new plugin = add JSON entry, no code changes |
| `git config --global` commands in deploy | Native INI file symlinked to ~/.gitconfig | v3.0 (2026-02) | User edits file directly, changes visible in git diff |
| CLAUDE.md template assembly | Single maintained file | v3.0 (2026-02) | Simplicity, but deferred to v4 for template-based approach |
| Wizard-driven setup | Manual JSON editing | v3.0 (2026-02) | Transparency, control; wizards return in v4 as optional layer |

**Deprecated/outdated:**
- `.env` config format: Replaced by global.json and project.json (v3.0)
- `dotconfigs global-configs <plugin>`: Replaced by editing global.json directly (v3.0)
- Plugin-aware deployment: Replaced by generic deployer that reads JSON (v3.0)

**Note:** Wizards are not deprecated, they're deferred to v4. The mechanics must work manually first.

## Open Questions

Things that couldn't be fully resolved:

1. **Git config symlink write-through reliability**
   - What we know: Modern Git (2.0+) follows symlinks on write, mailing list confirms this
   - What's unclear: Whether all Git versions user might have will preserve symlink
   - Recommendation: Check Git version at deploy time, warn if < 2.0. Document known issue.

2. **Append method semantics**
   - What we know: Requirements specify "append" method for adding patterns to files
   - What's unclear: Idempotency — running twice appends twice. Should we check for duplicates?
   - Recommendation: Start with naive append (just `cat >> target`), add deduplication in Phase 12 if needed

3. **jq minimum version**
   - What we know: jq 1.5+ has stable recursive descent and alternative operator
   - What's unclear: Whether features we need (`..|select()`, `//`, `@tsv`) exist in all versions
   - Recommendation: Require jq 1.5+, check at setup time. Most systems have 1.6 or 1.7.

4. **Project JSON resolution timing**
   - What we know: `dotconfigs project <path>` should resolve sources against dotconfigs repo root
   - What's unclear: How to handle when user moves dotconfigs repo or clones to different path
   - Recommendation: Store dotconfigs root in .dotconfigs/config or environment, resolve at deploy time

## Sources

### Primary (HIGH confidence)

- [jq 1.8 Manual](https://jqlang.github.io/jq/manual/) - Official jq documentation for query syntax
- [Bash Reference Manual - Tilde Expansion](https://www.gnu.org/software/bash/manual/html_node/Tilde-Expansion.html) - Official bash documentation
- [Git Config Documentation](https://git-scm.com/docs/git-config) - Official Git configuration reference
- [How to write idempotent Bash scripts](https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/) - Symlink patterns with ln -sfn
- Existing codebase: lib/symlinks.sh, lib/config.sh - Proven patterns already in use

### Secondary (MEDIUM confidence)

- [Parsing JSON with jq](http://www.compciv.org/recipes/cli/jq-for-parsing-json/) - Tutorial on jq basics
- [Working with JSON in bash using jq](https://cameronnokes.com/blog/working-with-json-in-bash-using-jq/) - Practical examples
- [Guide to Linux jq Command](https://www.baeldung.com/linux/jq-command-json) - Comprehensive jq guide
- [Bash Associative Arrays](https://www.linuxjournal.com/content/bash-associative-arrays) - Documents bash 4.0+ feature not available in 3.2
- [BashFAQ/006](https://mywiki.wooledge.org/BashFAQ/006) - Bash 3.2 limitations and workarounds
- [Dotfiles management patterns](https://wiki.archlinux.org/title/Dotfiles) - Symlink vs copy tradeoffs
- [How to Copy Files and Retain Permissions](https://cybrkyd.com/post/how-to-copy-files-and-retain-permissions/) - Using cp -p

### Tertiary (LOW confidence)

- [Git config replaces symlink](https://git.vger.kernel.narkive.com/IdZJvWVQ/config-replaces-config-symlink-with-real-file) - Mailing list discussion, older Git versions
- WebSearch results about dotfiles managers - General patterns, not specific to this implementation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - jq is industry standard for bash JSON parsing, bash 3.2 is documented requirement
- Architecture: HIGH - Patterns verified in existing codebase (lib/symlinks.sh), jq queries tested
- Pitfalls: HIGH - Bash 3.2 limitations well-documented, tilde expansion tested, symlink patterns proven

**Research date:** 2026-02-11
**Valid until:** 2026-03-11 (30 days - stable domain, bash and jq don't change rapidly)

**Key files examined:**
- /Users/henrybaker/Repositories/dotconfigs/lib/symlinks.sh
- /Users/henrybaker/Repositories/dotconfigs/lib/config.sh
- /Users/henrybaker/Repositories/dotconfigs/global.json
- /Users/henrybaker/Repositories/dotconfigs/project.json.example
- /Users/henrybaker/Repositories/dotconfigs/plugins/git/gitconfig

**jq version available:** 1.7.1-apple (confirmed via `jq --version`)
