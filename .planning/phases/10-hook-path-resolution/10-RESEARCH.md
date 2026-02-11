# Phase 10: Hook Path Resolution - Research

**Researched:** 2026-02-10
**Domain:** Shell path resolution, Claude Code hooks, symlink management
**Confidence:** HIGH

## Summary

Phase 10 fixes a critical bug where global Claude Code hooks only work when invoked from the dotconfigs repo itself. The problem is simple: `$CLAUDE_PROJECT_DIR` in deployed `~/.claude/settings.json` resolves to whatever project Claude is running in, not where the settings file lives. When hooks reference `$CLAUDE_PROJECT_DIR/plugins/claude/hooks/block-destructive.sh` from a non-dotconfigs project, that path doesn't exist.

The solution is equally simple: use absolute paths to `~/.claude/hooks/` (which are symlinks to the dotconfigs repo) for global hooks, and relative `.claude/hooks/` paths for project-local hooks. No runtime variables in deployed files — all paths baked at deploy time.

**Primary recommendation:** Deploy global settings.json with paths like `~/.claude/hooks/block-destructive.sh`, and project settings with relative paths like `.claude/hooks/block-destructive.sh`. Modify deploy.sh to resolve paths at deploy time using sed/awk substitution.

## Standard Stack

This phase uses no external dependencies beyond what's already in the codebase.

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Bash 3.2+ | System | Path substitution, symlink management | macOS compatibility requirement, project standard |
| sed | System | Template path resolution | POSIX-compliant text substitution, available everywhere |
| jq | 1.6+ | Optional JSON validation | Already required for hooks, used throughout dotconfigs |

### Existing Infrastructure

| Component | Location | Purpose |
|-----------|----------|---------|
| Hook symlinks | `~/.claude/hooks/` → `dotconfigs/plugins/claude/hooks/` | Already deployed, just need correct references |
| Settings template | `plugins/claude/templates/settings/settings-template.json` | Source of truth, needs path variable replacement |
| Deploy script | `plugins/claude/deploy.sh` | Assembles and deploys settings, needs path baking |
| Project wizard | `plugins/claude/project.sh` | Scaffolds project hooks, already uses relative paths correctly |

## Architecture Patterns

### Pattern 1: Runtime vs Deploy-Time Path Resolution

**What:** Choose whether to resolve paths when deploying config files or when executing hooks.

**Current (broken) approach:**
```json
{
  "command": "$CLAUDE_PROJECT_DIR/plugins/claude/hooks/block-destructive.sh"
}
```
This embeds a runtime variable that resolves to the current project, not the dotconfigs repo.

**Correct approach for global hooks:**
```json
{
  "command": "~/.claude/hooks/block-destructive.sh"
}
```
Path is baked at deploy time, `~` expands at shell execution time to user home.

**Correct approach for project hooks:**
```json
{
  "command": ".claude/hooks/block-destructive.sh"
}
```
Relative path resolves from project root (Claude Code's CWD).

**When to use:** Global hooks need stable absolute paths; project hooks need portable relative paths.

### Pattern 2: How Claude Code Resolves Hook Paths

According to official documentation and verified behaviour:

1. **Environment variables in hook commands** (`$CLAUDE_PROJECT_DIR`, `${CLAUDE_PLUGIN_ROOT}`) are expanded at hook execution time
2. **Relative paths** (no leading `/` or `~`) resolve relative to the project root
3. **Absolute paths with `~`** expand to user home directory at shell execution time
4. **Absolute paths** starting with `/` are used as-is

**Critical insight:** `$CLAUDE_PROJECT_DIR` is set to the current project's root when Claude Code runs a hook, NOT the location where the settings file lives. This means global settings in `~/.claude/settings.json` that use `$CLAUDE_PROJECT_DIR` will resolve to whatever project you're working in.

### Pattern 3: Template Path Substitution at Deploy Time

**What:** Replace placeholder variables in templates with actual paths when deploying, not leaving them as runtime variables.

**Implementation:**
```bash
# In deploy.sh, when building settings.json from template:
sed "s|\$DOTCONFIGS_ROOT|$DOTCONFIGS_ROOT|g" \
    "$template" > "$output"

# For tilde-based paths (preferred for portability):
sed 's|$DOTCONFIGS_ROOT/plugins/claude/hooks/|~/.claude/hooks/|g' \
    "$template" > "$output"
```

**Why this works:**
- `~/.claude/hooks/` is a stable path that doesn't change if dotconfigs repo moves
- It's already a symlink to the real hook files in dotconfigs repo
- Shell expands `~` at execution time, so it's portable across users
- No runtime variable resolution needed

### Pattern 4: Global vs Project Hook Deployment

**Global hooks** (deployed to `~/.claude/`):
- Must reference hooks via absolute paths: `~/.claude/hooks/script.sh`
- Settings file location: `~/.claude/settings.json` (assembled from template)
- Hook files: symlinks in `~/.claude/hooks/` → `dotconfigs/plugins/claude/hooks/`
- Lifespan: permanent until next deploy

**Project hooks** (deployed to `project/.claude/`):
- Must reference hooks via relative paths: `.claude/hooks/script.sh`
- Settings file location: `.claude/settings.json` or `.claude/settings.local.json`
- Hook files: copies in `.claude/hooks/` (per-project customisation)
- Lifespan: per-project, can drift from global version

**Hook script internals** (what's inside the hook files):
- Can use `$CLAUDE_PROJECT_DIR` safely because they execute in the project's context
- Example from `block-destructive.sh`:
  ```bash
  if [[ -f "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf" ]]; then
      source "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf"
  fi
  ```
- This works because the hook script runs AFTER path resolution, with `$CLAUDE_PROJECT_DIR` set correctly

### Anti-Patterns to Avoid

**Don't use `$CLAUDE_PROJECT_DIR` in global settings.json:**
```json
// WRONG - only works in dotconfigs repo
{
  "command": "$CLAUDE_PROJECT_DIR/plugins/claude/hooks/block-destructive.sh"
}
```

**Don't use absolute paths in project settings.json:**
```json
// WRONG - breaks portability, ties to specific machine
{
  "command": "/Users/henrybaker/Repositories/dotconfigs/plugins/claude/hooks/block-destructive.sh"
}
```

**Don't leave template variables unresolved in deployed files:**
```json
// WRONG - $DOTCONFIGS_ROOT won't be set at runtime
{
  "command": "$DOTCONFIGS_ROOT/plugins/claude/hooks/block-destructive.sh"
}
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON manipulation | Custom parsers, string concatenation | `jq` for queries, existing Python deep_merge in deploy.sh | Edge cases, escaping, type coercion |
| Symlink verification | Custom stat parsing | `readlink -f` + comparison (already in `check_file_state`) | Cross-platform symlink resolution is complex |
| Template substitution for complex transforms | sed chaining, awk scripts | Python with json module (already used in deploy.sh) | Readable, maintainable, handles nested structures |
| Home directory expansion | Manual `$HOME` substitution | Use `~` in paths, shell expands automatically | Consistent with Unix conventions, less error-prone |

**Key insight:** The existing codebase already has correct patterns for JSON merging (`_claude_merge_settings_json`), symlink checking (`check_file_state`), and template assembly (`_claude_assemble_settings`). The fix only requires changing what paths go into the template and ensuring they're not further modified.

## Common Pitfalls

### Pitfall 1: Confusing `$CLAUDE_PROJECT_DIR` Scope

**What goes wrong:** Developers assume `$CLAUDE_PROJECT_DIR` in `~/.claude/settings.json` points to the dotconfigs repo because "that's where I deployed from."

**Why it happens:** The variable name suggests it's project-specific, and in the dotconfigs repo it coincidentally works because CWD = repo root.

**How to avoid:**
- Never use `$CLAUDE_PROJECT_DIR` in deployed global settings.json
- Document clearly: this variable means "where Claude is running NOW" not "where settings came from"
- Use absolute paths (`~/.claude/hooks/`) for global, relative paths (`.claude/hooks/`) for project

**Warning signs:**
- Hooks work in dotconfigs repo but fail everywhere else
- Error messages like "command not found" or "no such file" in other projects
- Hook path contains `plugins/claude/` (that directory only exists in dotconfigs repo)

### Pitfall 2: Template Path Variables Not Resolved

**What goes wrong:** Deploy script copies template verbatim without substituting `$DOTCONFIGS_ROOT` or `$CLAUDE_PROJECT_DIR`, leaving these as literal strings in deployed settings.json.

**Why it happens:** Easy to forget the substitution step when assembling JSON from templates. The current `_claude_assemble_settings` just does `cp "$template" "$output_file"`.

**How to avoid:**
- Add explicit path resolution step in deploy
- Use different variable syntax in templates to make it obvious they need substitution
- Validate deployed settings.json doesn't contain unresolved variables

**Warning signs:**
- `grep -F '$' ~/.claude/settings.json` returns matches
- Hooks reference paths with `$DOTCONFIGS_ROOT` or `$CLAUDE_PROJECT_DIR` literally
- jq parse succeeds but hooks don't execute

### Pitfall 3: Tilde Expansion in Non-Shell Contexts

**What goes wrong:** Assuming `~/.claude/hooks/script.sh` expands to `/Users/henrybaker/.claude/hooks/script.sh` in all contexts.

**Why it happens:** Tilde expansion is a shell feature, not universal. JSON files don't expand `~`, but shell commands in hook execution do.

**How to avoid:**
- For settings.json: Use `~` in command paths (shell expands when executing)
- For file operations in Bash: Don't assume `~` works, use `$HOME` or absolute paths
- Document that `~` in hook commands is valid and expected

**Warning signs:**
- Paths with literal `~` character that aren't expanding
- File not found errors in non-shell contexts
- Worked in shell testing but fails in Claude Code

### Pitfall 4: Project Wizard Already Fixed But Global Deploy Broken

**What goes wrong:** Assuming the whole system is broken when actually just global deploy has the bug.

**Why it happens:** `hooks.json` template uses `.claude/hooks/` (correct for project), but `settings-template.json` uses `$CLAUDE_PROJECT_DIR/plugins/` (wrong for global).

**How to avoid:**
- Check both templates separately
- Verify global and project hooks independently
- Don't assume one fix applies to both

**Warning signs:**
- Project-scaffolded hooks work fine
- Globally deployed hooks fail
- Git grep shows two different path patterns in templates

## Code Examples

### Example 1: Deploy Global Settings with Resolved Paths

Current broken implementation in `_claude_assemble_settings`:
```bash
# plugins/claude/deploy.sh (CURRENT - BROKEN)
_claude_assemble_settings() {
    local plugin_dir="$1"
    local output_file="$2"
    local template="$plugin_dir/templates/settings/settings-template.json"

    if [[ ! -f "$template" ]]; then
        echo "Error: settings-template.json not found" >&2
        return 1
    fi

    cp "$template" "$output_file"  # No path substitution!
    return 0
}
```

Fixed implementation with path resolution:
```bash
# plugins/claude/deploy.sh (FIXED)
_claude_assemble_settings() {
    local plugin_dir="$1"
    local output_file="$2"
    local template="$plugin_dir/templates/settings/settings-template.json"

    if [[ ! -f "$template" ]]; then
        echo "Error: settings-template.json not found" >&2
        return 1
    fi

    # Replace $CLAUDE_PROJECT_DIR/plugins/claude/hooks/ with ~/.claude/hooks/
    # This makes global hooks reference the stable symlinked directory
    sed 's|\$CLAUDE_PROJECT_DIR/plugins/claude/hooks/|~/.claude/hooks/|g' \
        "$template" > "$output_file"

    return 0
}
```

**Key changes:**
- Single sed substitution replaces problematic path pattern
- Uses `~/.claude/hooks/` which is stable and already exists (deployed earlier in same script)
- No runtime variables left in deployed settings.json

### Example 2: Template Before and After

**Before (settings-template.json - BROKEN):**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/plugins/claude/hooks/block-destructive.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

**After deploy to ~/.claude/settings.json (FIXED):**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/block-destructive.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

### Example 3: Project Hooks Template (ALREADY CORRECT)

**Current hooks.json for project scaffolding:**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/block-destructive.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

**This is already correct** because:
- Relative path `.claude/hooks/` resolves from project root
- No `$CLAUDE_PROJECT_DIR` variable that could break
- Portable across machines and projects

### Example 4: Verification Test After Deploy

```bash
# Test that global hooks work from any directory
# Run this after deploying to verify the fix

# Deploy global settings
cd /Users/henrybaker/Repositories/dotconfigs
./dotconfigs deploy claude

# Test from dotconfigs repo (should work before and after fix)
claude "test that hooks are active" --resume

# Test from different project (FAILS before fix, WORKS after fix)
cd /tmp/test-project
claude "test that hooks are active" --resume

# Verify no unresolved variables in deployed settings
if grep -F '$CLAUDE_PROJECT_DIR' ~/.claude/settings.json; then
    echo "ERROR: Unresolved template variables in settings.json"
    exit 1
else
    echo "PASS: No template variables in deployed settings"
fi

# Verify hook paths are absolute with ~/.claude/hooks/
if grep -F '~/.claude/hooks/' ~/.claude/settings.json; then
    echo "PASS: Global hooks use correct path pattern"
else
    echo "ERROR: Global hooks missing ~/.claude/hooks/ paths"
    exit 1
fi
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `$CLAUDE_PROJECT_DIR` in global settings | `~/.claude/hooks/` absolute paths | v3.0 Phase 10 | Global hooks work everywhere |
| Template variables in deployed files | Paths baked at deploy time | v3.0 Phase 10 | No runtime resolution needed |
| Same path pattern for global and project | Different patterns: absolute vs relative | v3.0 Phase 10 | Each scope uses correct pattern |

**Current state (v2.0):**
- Global hooks only work in dotconfigs repo
- `$CLAUDE_PROJECT_DIR` resolves to CWD at runtime
- settings-template.json has paths that only exist in dotconfigs repo
- Project wizard (`project.sh`) already uses correct relative paths in `hooks.json`

**After Phase 10 (v3.0):**
- Global hooks work in any project
- All paths resolved at deploy time
- No `$CLAUDE_PROJECT_DIR` in deployed global settings.json
- Both global and project hooks use correct path patterns for their scope

## Open Questions

None. The solution is well-defined and all technical details are confirmed:

1. ✅ How does `$CLAUDE_PROJECT_DIR` resolve? → **Confirmed:** Resolves to current project root at hook execution time, not settings file location
2. ✅ Does `~` work in hook command paths? → **Confirmed:** Yes, shell expands at execution time
3. ✅ Are symlinks in `~/.claude/hooks/` already deployed? → **Confirmed:** Yes, deploy.sh already creates them
4. ✅ Does project wizard use correct paths? → **Confirmed:** Yes, `hooks.json` already uses `.claude/hooks/` relative paths
5. ✅ Can we use sed for path substitution? → **Confirmed:** Yes, simple single-line sed replacement is sufficient
6. ✅ Will this break existing functionality? → **Confirmed:** No, only fixes broken global hooks. Project hooks already work correctly.

## Sources

### Primary (HIGH confidence)

- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks) - Official documentation on hook path resolution, `$CLAUDE_PROJECT_DIR` variable, and configuration schema
- [GitHub Issue #9447: CLAUDE_PROJECT_DIR not propagated in plugin hooks](https://github.com/anthropics/claude-code/issues/9447) - Confirms variable works in settings files (fixed in v2.0.45 for plugins)
- Codebase inspection:
  - `plugins/claude/templates/settings/settings-template.json` - Current broken template
  - `plugins/claude/templates/settings/hooks.json` - Project template (already correct)
  - `plugins/claude/deploy.sh` - Current deploy logic (missing path substitution)
  - `plugins/claude/project.sh` - Project wizard (already correct)
  - `~/.claude/hooks/` - Verified symlinks exist and point to dotconfigs repo

### Secondary (MEDIUM confidence)

- `.planning/research/STACK.md` - Internal research documenting the bug and solution approach
- `.planning/research/SUMMARY.md` - Summary of v2.0 issues including hook path problem
- `.planning/REQUIREMENTS.md` - PATH-01, PATH-02, PATH-03 requirements for this phase

### Verified by Testing

- Confirmed `~/.claude/hooks/` symlinks exist and resolve correctly
- Confirmed `~/.claude/settings.json` currently contains `$CLAUDE_PROJECT_DIR/plugins/claude/hooks/` paths
- Confirmed `.planning/quick/004-*` documented this issue during UAT
- Confirmed global hooks work in dotconfigs repo but fail in other projects

## Metadata

**Confidence breakdown:**
- Hook path resolution mechanics: **HIGH** - Official documentation, verified in codebase and testing
- Solution approach: **HIGH** - Simple sed substitution, no architectural changes needed
- Existing infrastructure: **HIGH** - Symlinks already deployed, project wizard already correct
- Risk assessment: **HIGH** - Low risk change, only touches template assembly, preserves all existing functionality

**Research date:** 2026-02-10
**Valid until:** 90 days (stable API, unlikely to change)

**Dependencies:**
- No external libraries required
- Bash 3.2+ (already required for macOS compatibility)
- sed (POSIX standard, available everywhere)
- jq (optional, already required for hooks functionality)

**Assumptions:**
- `~/.claude/hooks/` symlinks are deployed before settings.json is assembled (true in current deploy order)
- Hook scripts themselves can safely use `$CLAUDE_PROJECT_DIR` (true, they execute in project context)
- Project wizard functionality should not change (true, it already works correctly)
