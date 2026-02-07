# Domain Pitfalls: CLI Restructure and Plugin Migration

**Domain:** Bash CLI tool restructuring (dotclaude → dotconfigs)
**Researched:** 2026-02-07
**Migration type:** Monolithic script → plugin architecture + repository rename

## Executive Summary

This document catalogues critical pitfalls when restructuring a working 1085-line bash script (`deploy.sh`) into a plugin-based architecture while simultaneously renaming the repository. Focus is on pitfalls specific to this migration's constraints: bash 3.2 compatibility (macOS), existing user installs with `.env` config, global git hooks via `core.hooksPath`, and symlink-based deployment.

## Critical Pitfalls

Mistakes that cause rewrites, data loss, or break existing user installs.

### Pitfall 1: Breaking Existing User Configs During .env Migration

**What goes wrong:** Users upgrade, their `.env` files become invalid, wizard skips because `.env` exists, deployment silently uses stale/incompatible config.

**Why it happens:**
- Plugin restructure changes `.env` schema (e.g., `DEPLOY_TARGET` → plugin-specific paths)
- Old `.env` lacks new required variables (e.g., plugin selection flags)
- Migration script assumes `.env` presence = valid config
- No version detection in `.env` files

**Consequences:**
- Silent breakage — users don't realize config is stale
- Deployment succeeds but with wrong plugin selection
- Partial deployments (some plugins installed, others skipped)
- User frustration: "worked before upgrade, broken now"

**Prevention:**
1. **Version `.env` files from v2 onwards:**
   ```bash
   # Add to .env in v2.0
   DOTCONFIGS_VERSION=2.0
   ```

2. **Add migration checker in load_config():**
   ```bash
   load_config() {
       if [[ ! -f "$ENV_FILE" ]]; then
           return 1
       fi
       source "$ENV_FILE"

       # Version detection
       local config_version="${DOTCONFIGS_VERSION:-1.0}"
       if [[ "$config_version" != "2.0" ]]; then
           echo "⚠️  Config file is v${config_version}, needs migration to v2.0"
           migrate_env_v1_to_v2
       fi
   }
   ```

3. **Provide backwards compatibility grace period:**
   - Keep v1 `.env` keys working in v2.0 (deprecate, don't delete)
   - Warn users: "DEPLOY_TARGET is deprecated, migrating to CLAUDE_DEPLOY_TARGET"
   - Auto-migrate on first run, save updated `.env`

4. **Document migration in CHANGELOG:**
   - Breaking changes section
   - Migration steps for manual .env editing
   - What happens on upgrade

**Detection:**
- Warning signs: Users report "wizard skipped but deployment wrong"
- Test: Fresh v1 install → upgrade to v2 → verify auto-migration

**Phase assignment:** Phase 1 (Setup: Migration framework)

**Sources:**
- [Versioning Your Design System Without Breaking Client Sites](https://www.designsystemscollective.com/versioning-your-design-system-without-breaking-client-sites-93b7c652f960)

---

### Pitfall 2: Breaking Shell Aliases Due to Path Changes

**What goes wrong:** Repository rename (dotclaude → dotconfigs) + entry point rename (deploy.sh → dotconfigs) breaks all shell aliases pointing to old paths.

**Why it happens:**
- Current v1 deploys: `alias deploy='bash /path/to/dotclaude/deploy.sh'`
- After rename: `/path/to/dotclaude` doesn't exist (user moves/reclones as dotconfigs)
- Aliases in `~/.zshrc` / `~/.bashrc` are hardcoded absolute paths

**Consequences:**
- `deploy` alias breaks silently
- Users don't notice until they try to use it
- Confusion: "command not found: /path/to/dotclaude/deploy.sh"
- Must manually edit RC files (error-prone)

**Prevention:**
1. **In v2 setup wizard, detect and update old aliases:**
   ```bash
   setup_shell_aliases() {
       local rc_file="$HOME/.zshrc"  # or detect
       local old_marker="# dotclaude aliases"
       local new_marker="# dotconfigs aliases"

       # Check for old dotclaude alias block
       if grep -q "^${old_marker}$" "$rc_file" 2>/dev/null; then
           echo "⚠️  Found old dotclaude aliases, migrating..."
           # Remove old block
           sed -i.bak "/^${old_marker}$/,/^# end dotclaude aliases$/d" "$rc_file"
           echo "  ✓ Removed old aliases"
       fi

       # Install new aliases
       # ... (existing logic)
   }
   ```

2. **Provide transition script for manual migration:**
   ```bash
   # scripts/migrate-aliases.sh
   # Scans all RC files, updates dotclaude → dotconfigs paths
   ```

3. **Warn during setup if old aliases detected:**
   ```
   ⚠️  Old 'deploy' alias detected pointing to old location
       Current: alias deploy='bash /old/path/dotclaude/deploy.sh'
       Will update to: alias dotconfigs='bash /new/path/dotconfigs'

       Proceed with migration? [Y/n]
   ```

4. **Document in README:**
   - "Upgrading from v1? Your shell aliases need updating."
   - Link to migration guide

**Detection:**
- Warning signs: Post-upgrade, `deploy` command not found
- Test: v1 install with aliases → rename repo → v2 setup → verify aliases updated

**Phase assignment:** Phase 2 (Setup: Wizard for git plugin)

**Sources:**
- [Consequences of renaming a repository](https://support.atlassian.com/bitbucket-cloud/kb/consequences-and-considerations-of-renaming-a-repository/)
- [Renaming a repository doesn't mention it will break workflows](https://github.com/github/docs/issues/15575)

---

### Pitfall 3: Git Hooks Conflicts with Other Hook Managers

**What goes wrong:** Setting global `core.hooksPath` conflicts with project-level hook managers (Husky, pre-commit, lefthook), causing "Cowardly refusing to install" errors or silent hook non-execution.

**Why it happens:**
- v1 sets: `git config --global core.hooksPath ~/.claude/git-hooks`
- User clones project using Husky → Husky install fails
- Or: Husky installs, but hooks in `.git/hooks/` never run (global path overrides local)
- Global setting is invisible to most users

**Consequences:**
- Projects with their own hook managers break
- Cryptic error messages from hook managers
- Silent failures: users think hooks are running, they're not
- Reputation damage: "dotconfigs broke my project"

**Prevention:**
1. **Do NOT use global core.hooksPath by default in v2:**
   ```bash
   # OLD (v1 — problematic):
   git config --global core.hooksPath "$githooks_target"

   # NEW (v2 — safe):
   # Use per-project .git/hooks/ copies instead
   # Only set global hooksPath if user explicitly opts in
   ```

2. **Provide opt-in global hooks with warning:**
   ```bash
   wizard_header 8 "Git Hooks Scope"
   echo "Git hooks can be deployed globally or per-project."
   echo ""
   echo "⚠️  WARNING: Global hooks (core.hooksPath) conflict with"
   echo "    project-level hook managers (Husky, pre-commit, lefthook)."
   echo ""
   echo "Recommended: Per-project (safe, no conflicts)"
   echo "Alternative: Global (convenient but may conflict)"
   echo ""
   if wizard_yesno "Deploy git hooks globally? (not recommended)" "n"; then
       GIT_HOOKS_SCOPE="global"
       echo "  You chose global. If projects use Husky/pre-commit, you may need to unset."
   else
       GIT_HOOKS_SCOPE="project"
   fi
   ```

3. **Detect and warn about existing global hooksPath:**
   ```bash
   deploy_git_plugin() {
       local existing_path=$(git config --global core.hooksPath 2>/dev/null || echo "")
       if [[ -n "$existing_path" && "$existing_path" != "$githooks_target" ]]; then
           echo "⚠️  Global core.hooksPath already set: $existing_path"
           echo "    This may be from another tool or old dotclaude install."
           if wizard_yesno "Overwrite with dotconfigs hooks?" "n"; then
               git config --global core.hooksPath "$githooks_target"
           else
               echo "  Skipped global hooks. Use per-project deployment instead."
               return
           fi
       fi
   }
   ```

4. **Provide per-project hook deployment in project scaffolding:**
   ```bash
   cmd_project() {
       # ... existing scaffolding ...

       # Copy git hooks to .git/hooks/ (NOT global)
       if [[ "$INSTALL_GIT_HOOKS" == "true" ]]; then
           echo "Installing git hooks locally (project-scoped)..."
           cp "$SCRIPT_DIR/githooks"/* "$project_path/.git/hooks/"
           chmod +x "$project_path/.git/hooks"/*
           echo "  ✓ Git hooks installed to .git/hooks/"
       fi
   }
   ```

**Detection:**
- Warning signs: Users report Husky/pre-commit errors after dotconfigs install
- Test: Install dotconfigs globally → clone Husky project → verify no conflicts

**Phase assignment:** Phase 3 (Deploy: Git plugin deployment)

**Sources:**
- [Setting a global hooks path causes "Cowardly refusing to install" everywhere](https://github.com/pre-commit/pre-commit/issues/1198)
- [If git core.hooksPath is set, hk doesn't work](https://github.com/jdx/hk/discussions/385)
- [Unset core.hookspath in lefthook install](https://github.com/evilmartians/lefthook/issues/1248)

---

### Pitfall 4: Bash 3.2 Incompatibilities Break macOS Users

**What goes wrong:** Plugin architecture uses bash 4+ features (nameref, associative arrays, `${var,,}`), script silently fails or crashes on macOS.

**Why it happens:**
- macOS ships bash 3.2.57 (2007 vintage, never updated due to licensing)
- Modern bash tutorials/AI-generated code uses bash 4+ features
- Developer tests on Linux (bash 5+), doesn't catch macOS breakage
- Bash 3.2 errors are cryptic: "declare: -A: invalid option"

**Consequences:**
- macOS users (majority of target audience) cannot use tool
- Confusing errors with no clear fix
- Workaround (install bash via Homebrew) is documented but not enforced
- Partial breakage: some features work, others silently skip

**Prevention:**
1. **Enforce bash 3.2 compatibility from Phase 1:**
   ```bash
   # At top of every script:
   # Bash 3.2 compatible (macOS default)
   if [[ "${BASH_VERSINFO[0]}" -lt 3 ]]; then
       echo "Error: Bash 3.2+ required"
       exit 1
   fi
   ```

2. **Avoid bash 4+ features entirely:**
   ```bash
   # BANNED SYNTAX (bash 4+):
   declare -A assoc_array          # Associative arrays (bash 4.0+)
   local -n nameref_var            # Namerefs (bash 4.3+)
   ${var,,}                        # Lowercase expansion (bash 4.0+)
   ${var^^}                        # Uppercase expansion (bash 4.0+)
   declare -g global_var           # -g flag (bash 4.2+)

   # SAFE ALTERNATIVES (bash 3.2):
   # Use space-separated strings instead of associative arrays
   plugins_enabled="claude git"

   # Use eval for indirect references instead of nameref
   eval "local value=\${${var_name}}"

   # Use tr for case conversion instead of ${var,,}
   lowercase=$(echo "$var" | tr '[:upper:]' '[:lower:]')
   ```

3. **Add pre-commit shellcheck with bash 3.2 enforcement:**
   ```bash
   # In githooks/pre-commit or CI
   shellcheck --shell=bash --enable=all --exclude=SC1090 \
              --severity=warning \
              **/*.sh
   ```

4. **Test on actual macOS bash 3.2:**
   ```bash
   # In CI or local test script
   if [[ "$OSTYPE" == "darwin"* ]]; then
       /bin/bash --version  # Should be 3.2.57
       /bin/bash ./dotconfigs setup --test
   fi
   ```

5. **Document compatibility clearly in README:**
   ```markdown
   ## Requirements

   - Bash 3.2+ (macOS default bash is 3.2.57 — compatible)
   - No bash 4+ features used (we support macOS out of the box)
   ```

**Detection:**
- Warning signs: macOS users report "invalid option" or "command not found"
- Test: Run full workflow on macOS with `/bin/bash` (not Homebrew bash)
- Check: `grep -r 'declare -A' **/*.sh` → should return nothing

**Phase assignment:** Phase 1 (Setup: Library code split) — enforce from start

**Sources:**
- [Document that bash 3.2 on macOS won't work](https://github.com/docopt/docopts/issues/24)
- [Associative array error on macOS for bash: : declare: -A: invalid option](https://dipeshmajumdar.medium.com/associative-array-error-on-macos-for-bash-declare-a-invalid-option-16466534e445)

---

### Pitfall 5: Plugin Source Path Resolution Breaks After Restructure

**What goes wrong:** Monolithic `deploy.sh` splits into `dotconfigs` + `lib/*.sh` + `plugins/*/setup.sh`. Source statements use relative paths that break when called from different contexts (direct invocation vs symlink vs plugin).

**Why it happens:**
- v1: `source "$SCRIPT_DIR/scripts/lib/wizard.sh"` — works because everything is relative to `deploy.sh`
- v2: Plugins in `plugins/claude/setup.sh` try to `source ../../lib/wizard.sh` — breaks if called via symlink
- `$SCRIPT_DIR` changes meaning depending on invocation context
- `source` resolves paths relative to calling script, not sourced script

**Consequences:**
- "No such file or directory" errors during setup/deploy
- Scripts work when invoked directly, fail when called via alias/symlink
- Hard to debug: same command works in one terminal, fails in another
- Plugin isolation breaks: plugins can't reliably import shared lib

**Prevention:**
1. **Use BASH_SOURCE[0] for absolute path resolution:**
   ```bash
   # In dotconfigs entry point:
   DOTCONFIGS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   export DOTCONFIGS_ROOT  # Make available to all sourced scripts

   # In plugins/claude/setup.sh:
   source "$DOTCONFIGS_ROOT/lib/wizard.sh"  # Absolute, always works
   ```

2. **Never use relative paths in source statements:**
   ```bash
   # BAD (breaks with symlinks):
   source ../../lib/wizard.sh

   # GOOD (always works):
   source "$DOTCONFIGS_ROOT/lib/wizard.sh"
   ```

3. **Validate DOTCONFIGS_ROOT is set:**
   ```bash
   # At top of all lib/*.sh and plugins/*/setup.sh:
   if [[ -z "$DOTCONFIGS_ROOT" ]]; then
       echo "Error: DOTCONFIGS_ROOT not set. Source from dotconfigs entry point only."
       exit 1
   fi
   ```

4. **Test via multiple invocation methods:**
   ```bash
   # Test suite must include:
   /absolute/path/to/dotconfigs setup       # Direct absolute
   ./dotconfigs setup                        # Direct relative
   alias dotconfigs='bash /path/dotconfigs'
   dotconfigs setup                          # Via alias
   ln -s /path/dotconfigs /tmp/dc
   /tmp/dc setup                             # Via symlink
   ```

**Detection:**
- Warning signs: "source: file not found" errors in testing
- Test: Create symlink to dotconfigs → invoke via symlink → verify all sources work

**Phase assignment:** Phase 1 (Setup: Library code split) — foundation for all plugins

**Sources:**
- [Study: including other bash scripts from relative paths and absolute paths](https://gist.github.com/jay3126/fab953d4e60cef6538ab1067570c4ecc)
- [BashFAQ/028](https://mywiki.wooledge.org/BashFAQ/028)

---

## Moderate Pitfalls

Mistakes that cause delays, technical debt, or user friction.

### Pitfall 6: Variable Scope Leakage Between Plugins

**What goes wrong:** Monolithic script becomes plugin-based. Plugins share global variables, causing cross-plugin contamination (plugin A sets `$DEPLOY_TARGET`, plugin B inherits wrong value).

**Why it happens:**
- v1 uses globals freely: `DEPLOY_TARGET`, `SETTINGS_ENABLED`, etc.
- v2 plugins run in same shell session, inherit parent environment
- No namespacing: both plugins use generic names like `$target`, `$config`
- Functions in lib/*.sh use globals, plugins call them with different contexts

**Prevention:**
1. **Namespace all plugin variables:**
   ```bash
   # In plugins/claude/setup.sh:
   CLAUDE_DEPLOY_TARGET=""
   CLAUDE_SETTINGS_ENABLED=""

   # NOT:
   DEPLOY_TARGET=""  # Clashes with git plugin
   ```

2. **Use local variables in functions:**
   ```bash
   # In lib/wizard.sh:
   wizard_prompt() {
       local prompt_text="$1"
       local default_value="$2"
       local variable_name="$3"
       local user_input        # Prevent leakage
       # ...
   }
   ```

3. **Pass context explicitly, don't rely on globals:**
   ```bash
   # BAD:
   deploy_settings() {
       # Assumes $DEPLOY_TARGET exists
       cp settings.json "$DEPLOY_TARGET/"
   }

   # GOOD:
   deploy_settings() {
       local deploy_target="$1"
       cp settings.json "$deploy_target/"
   }
   ```

4. **Enforce in code review:**
   - Checklist: "All plugin variables prefixed with plugin name?"
   - Checklist: "All function variables declared local?"

**Detection:**
- Test: Run claude setup, then git setup → verify no variable contamination
- Check: Search for unqualified globals in plugin code

**Phase assignment:** Phase 1 (Setup: Library code split)

**Sources:**
- [Classic pitfalls: accidental global variables](https://medium.com/mkdir-awesome/the-ultimate-guide-to-modularizing-bash-script-code-f4a4d53000c2)

---

### Pitfall 7: Symlink Ownership Detection Breaks After Restructure

**What goes wrong:** v1 uses `is_dotclaude_owned()` to check if symlink points into dotclaude repo. After rename to dotconfigs, ownership detection fails, causes re-prompts on every deploy.

**Why it happens:**
- Function in `scripts/lib/symlinks.sh` extracts repo path from symlink target
- Hardcoded assumption: path contains "dotclaude"
- After rename: path contains "dotconfigs", old logic breaks
- Symlinks created by v1 still point to old path

**Prevention:**
1. **Remove hardcoded repo name from ownership detection:**
   ```bash
   # In lib/symlinks.sh:
   is_dotconfigs_owned() {
       local target_path="$1"
       local dotconfigs_path="$2"  # Passed explicitly, not inferred

       if [[ ! -L "$target_path" ]]; then
           return 1
       fi

       # Get absolute path of link target
       local link_target=$(resolve_symlink "$target_path")

       # Check if starts with dotconfigs_path
       if [[ "$link_target" == "$dotconfigs_path"* ]]; then
           return 0
       fi

       return 1
   }
   ```

2. **Handle migration of v1 symlinks:**
   ```bash
   deploy_global() {
       # ... existing deployment ...

       # Detect old dotclaude symlinks
       if [[ -L "$DEPLOY_TARGET/settings.json" ]]; then
           local link_target=$(resolve_symlink "$DEPLOY_TARGET/settings.json")
           if [[ "$link_target" == *"/dotclaude/"* ]]; then
               echo "⚠️  Detected old dotclaude symlink, updating..."
               # Re-link to new dotconfigs path
               ln -sfn "$DOTCONFIGS_ROOT/settings.json" "$DEPLOY_TARGET/settings.json"
           fi
       fi
   }
   ```

**Detection:**
- Test: v1 deploy → rename repo → v2 deploy → verify no re-prompts

**Phase assignment:** Phase 4 (Deploy: Claude plugin deployment)

---

### Pitfall 8: Cross-Platform Symlink Resolution Differs

**What goes wrong:** macOS `readlink` doesn't support `-f` flag (GNU extension), symlink resolution breaks on macOS, ownership detection fails.

**Why it happens:**
- Linux: `readlink -f` resolves full absolute path
- macOS: `readlink` doesn't have `-f` → error or wrong result
- v1 already has workaround (perl fallback in symlinks.sh), but easy to forget when adding new symlink code

**Prevention:**
1. **Use existing cross-platform helper consistently:**
   ```bash
   # In lib/symlinks.sh (already exists in v1):
   resolve_symlink() {
       local target_path="$1"
       if [[ "$OSTYPE" == "darwin"* ]]; then
           # macOS: use perl
           perl -MCwd -le 'print Cwd::abs_path(shift)' "$target_path" 2>/dev/null
       else
           # Linux: use readlink -f
           readlink -f "$target_path" 2>/dev/null
       fi
   }
   ```

2. **Never call readlink -f directly:**
   ```bash
   # BAD:
   link_target=$(readlink -f "$path")

   # GOOD:
   link_target=$(resolve_symlink "$path")
   ```

3. **Enforce in code review:**
   - Checklist: "Any new readlink calls? Use resolve_symlink() instead."

**Detection:**
- Test on macOS: Verify all symlink operations work

**Phase assignment:** Phase 1 (Setup: Library code split) — centralize helper

**Sources:**
- [How to get GNU's readlink -f behavior on OS X](https://gist.github.com/esycat/5279354)

---

### Pitfall 9: Shell Aliases with Spaces in Path Break

**What goes wrong:** User installs dotconfigs to path with spaces (e.g., `/Users/John Doe/repos/dotconfigs`), shell aliases break, command not found errors.

**Why it happens:**
- v1 alias setup: `alias deploy='bash $dotclaude_root/deploy.sh'`
- If `$dotclaude_root` contains spaces and isn't quoted → shell splits on space
- Result: `alias deploy='bash /Users/John Doe/repos/dotconfigs'` → tries to run `bash /Users/John` with args `Doe/repos/dotconfigs`

**Prevention:**
1. **Quote all paths in alias definitions:**
   ```bash
   # In setup_shell_aliases():
   alias_block=$(cat <<EOF
   ${marker_start}
   alias ${alias_name}='bash "${dotconfigs_root}/dotconfigs"'
   alias registry-scan='bash "${dotconfigs_root}/scripts/registry-scan.sh"'
   ${marker_end}
   EOF
   )
   ```

2. **Escape internal quotes if needed:**
   ```bash
   # If path itself has quotes, escape them
   local escaped_path="${dotconfigs_root//\"/\\\"}"
   alias ${alias_name}='bash "${escaped_path}/dotconfigs"'
   ```

3. **Test with spaces in path:**
   ```bash
   # In test suite:
   mkdir -p "/tmp/path with spaces/dotconfigs"
   cd "/tmp/path with spaces/dotconfigs"
   ./dotconfigs setup
   source ~/.zshrc
   dotconfigs --version  # Should work
   ```

**Detection:**
- Test: Install to path with spaces → verify alias works

**Phase assignment:** Phase 2 (Setup: Wizard for git plugin)

**Sources:**
- [Spaces need to be escaped in the call to alias](https://fishshell.com/docs/current/cmds/alias.html)
- [Alias with windows path which contains a space](https://github.com/nushell/nushell/issues/3363)

---

### Pitfall 10: Git Config Overwrite Without Backup

**What goes wrong:** User has existing git identity/config, v2 git plugin overwrites without warning, user loses personal config.

**Why it happens:**
- v1 prompts for git identity, writes with `git config --global user.name`
- No detection of existing values
- No "keep existing" option
- No backup before overwrite

**Prevention:**
1. **Detect and pre-fill existing git config:**
   ```bash
   # In plugins/git/setup.sh:
   wizard_header 3 "Git Identity"

   # Get existing config
   local existing_name=$(git config --global user.name 2>/dev/null || echo "")
   local existing_email=$(git config --global user.email 2>/dev/null || echo "")

   if [[ -n "$existing_name" ]]; then
       echo "Current git user.name: $existing_name"
       if wizard_yesno "Keep existing git user.name?" "y"; then
           GIT_USER_NAME="$existing_name"
       else
           wizard_prompt "New git user.name" "$existing_name" GIT_USER_NAME
       fi
   else
       wizard_prompt "Git user.name" "" GIT_USER_NAME
   fi
   ```

2. **Allow blank to skip overwrite:**
   ```bash
   if [[ -n "$GIT_USER_NAME" ]]; then
       git config --global user.name "$GIT_USER_NAME"
       echo "  ✓ Set git user.name=$GIT_USER_NAME"
   else
       echo "  - Skipped git user.name (keeping existing)"
   fi
   ```

**Detection:**
- Test: Existing git config → setup → verify not overwritten without consent

**Phase assignment:** Phase 2 (Setup: Wizard for git plugin)

**Sources:**
- [Git Configuration Best Practices](https://developer.lsst.io/v/DM-5063/tools/git_setup.html)

---

## Minor Pitfalls

Mistakes that cause annoyance but are easily fixable.

### Pitfall 11: Load Order Dependencies Between Lib Files

**What goes wrong:** Plugin tries to use function from `lib/wizard.sh`, but `lib/config.sh` must be loaded first. Silent failures or cryptic errors.

**Why it happens:**
- Modularizing monolithic script creates dependencies
- No explicit declaration of load order
- Bash sources files in order they're listed
- Easy to miss: works during development, breaks in different invocation context

**Prevention:**
1. **Document load order in lib/README.md:**
   ```markdown
   ## Load Order

   Plugins should source lib files in this order:
   1. lib/config.sh (environment variables, path detection)
   2. lib/wizard.sh (interactive prompts)
   3. lib/symlinks.sh (file operations)
   ```

2. **Use defensive function existence checks:**
   ```bash
   # In lib/wizard.sh:
   if ! declare -f load_config >/dev/null 2>&1; then
       echo "Error: lib/config.sh must be sourced before lib/wizard.sh"
       exit 1
   fi
   ```

3. **Provide single lib/all.sh loader:**
   ```bash
   # lib/all.sh
   # Sources all lib files in correct order
   source "$DOTCONFIGS_ROOT/lib/config.sh"
   source "$DOTCONFIGS_ROOT/lib/wizard.sh"
   source "$DOTCONFIGS_ROOT/lib/symlinks.sh"

   # In plugins:
   source "$DOTCONFIGS_ROOT/lib/all.sh"  # One line, correct order
   ```

**Detection:**
- Test: Source lib files in wrong order → verify error message

**Phase assignment:** Phase 1 (Setup: Library code split)

**Sources:**
- [Load order matters when modularizing your configuration](https://carmelyne.com/modularizing-your-zshrc/)

---

### Pitfall 12: Plugin Discovery Breaks with Non-Standard Directory Layout

**What goes wrong:** v2 adds plugin discovery (list available plugins), assumes all plugins in `plugins/*/setup.sh`. User adds custom plugin with different structure, discovery breaks.

**Why it happens:**
- Hardcoded assumptions about plugin structure
- No validation of plugin directory contents
- Discovery script uses `find plugins/*/setup.sh` — fails if setup.sh missing

**Prevention:**
1. **Use manifest files for plugin registration:**
   ```bash
   # plugins/claude/plugin.conf
   PLUGIN_NAME=claude
   PLUGIN_DESCRIPTION="Claude Code configuration"
   PLUGIN_SETUP=setup.sh
   PLUGIN_DEPLOY=deploy.sh
   ```

2. **Discovery reads manifests, not file structure:**
   ```bash
   discover_plugins() {
       local dotconfigs_root="$1"
       for plugin_dir in "$dotconfigs_root/plugins"/*; do
           if [[ -f "$plugin_dir/plugin.conf" ]]; then
               source "$plugin_dir/plugin.conf"
               echo "$PLUGIN_NAME"
           fi
       done
   }
   ```

**Detection:**
- Test: Add plugin without setup.sh → verify discovery doesn't crash

**Phase assignment:** Phase 5 (Test: Integration testing)

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Phase 1: Library split | Source path resolution breaks (Pitfall 5) | Use BASH_SOURCE[0], test via symlink |
| Phase 1: Library split | Bash 3.2 incompatibility (Pitfall 4) | Enforce 3.2 syntax from day 1 |
| Phase 2: Setup wizards | .env migration breaks existing users (Pitfall 1) | Version .env files, auto-migrate |
| Phase 2: Setup wizards | Shell alias path breakage (Pitfall 2) | Detect old aliases, quote paths with spaces |
| Phase 3: Deploy git plugin | core.hooksPath conflicts (Pitfall 3) | Default to per-project hooks, warn on global |
| Phase 3: Deploy git plugin | Git config overwrite (Pitfall 10) | Detect existing, pre-fill, allow keep |
| Phase 4: Deploy claude plugin | Symlink ownership detection breaks (Pitfall 7) | Remove hardcoded repo name checks |
| Phase 5: Integration testing | Variable scope leakage (Pitfall 6) | Namespace all plugin variables |

## Testing Checklist

To verify pitfalls are avoided during development:

**Environment:**
- [ ] Test on macOS with `/bin/bash` (3.2.57)
- [ ] Test on Linux with bash 5+
- [ ] Test with fresh install (no prior .env)
- [ ] Test with v1 .env present (upgrade path)
- [ ] Test with path containing spaces
- [ ] Test via symlink invocation

**Migration:**
- [ ] v1 install → rename repo → v2 upgrade → verify aliases updated
- [ ] v1 install → v2 upgrade → verify .env migrated
- [ ] v1 symlinks → v2 deploy → verify ownership detection works
- [ ] Global core.hooksPath set → v2 install → verify warning displayed

**Integration:**
- [ ] Setup claude + git → verify no variable contamination
- [ ] Project with Husky → dotconfigs install → verify no hook conflicts
- [ ] Existing git config → git plugin setup → verify not overwritten

## Sources

Research sources used in this document:

**Bash Pitfalls:**
- [Common shell script mistakes](http://www.pixelbeat.org/programming/shell_script_mistakes.html)
- [BashPitfalls - Greg's Wiki](http://mywiki.wooledge.org/BashPitfalls)
- [The Ultimate Guide to Modularizing Bash Script Code](https://medium.com/mkdir-awesome/the-ultimate-guide-to-modularizing-bash-script-code-f4a4d53000c2)

**Bash 3.2 Compatibility:**
- [Document that bash 3.2 on macOS won't work](https://github.com/docopt/docopts/issues/24)
- [Associative array error on macOS](https://dipeshmajumdar.medium.com/associative-array-error-on-macos-for-bash-declare-a-invalid-option-16466534e445)

**Git Configuration:**
- [Git Configuration Best Practices](https://developer.lsst.io/v/DM-5063/tools/git_setup.html)
- [Popular git config options](https://jvns.ca/blog/2024/02/16/popular-git-config-options/)

**Git Hooks:**
- [Setting a global hooks path causes "Cowardly refusing to install"](https://github.com/pre-commit/pre-commit/issues/1198)
- [If git core.hooksPath is set, hk doesn't work](https://github.com/jdx/hk/discussions/385)
- [Unset core.hookspath in lefthook install](https://github.com/evilmartians/lefthook/issues/1248)

**Repository Migration:**
- [Consequences of renaming a repository](https://support.atlassian.com/bitbucket-cloud/kb/consequences-and-considerations-of-renaming-a-repository/)
- [Renaming a repository doesn't mention it will break workflows](https://github.com/github/docs/issues/15575)

**Symlink Management:**
- [How to get GNU's readlink -f behavior on OS X](https://gist.github.com/esycat/5279354)
- [How to Create Symlink in Linux and Mac](https://blog.purestorage.com/purely-educational/how-to-create-symlink-in-linux-and-mac/)

**Shell Aliases:**
- [Spaces need to be escaped in alias](https://fishshell.com/docs/current/cmds/alias.html)
- [Alias with windows path which contains a space](https://github.com/nushell/nushell/issues/3363)

**Path Resolution:**
- [Study: including bash scripts from relative/absolute paths](https://gist.github.com/jay3126/fab953d4e60cef6538ab1067570c4ecc)
- [BashFAQ/028](https://mywiki.wooledge.org/BashFAQ/028)

**Modularization:**
- [Modularizing your .zshrc](https://carmelyne.com/modularizing-your-zshrc/)
- [Bash Functions: Comprehensive Guide to Modular Scripting](https://linuxvox.com/blog/bash-functions/)
