# Phase 6: Git Plugin - Research

**Researched:** 2026-02-07
**Domain:** Git configuration management (hooks, identity, workflow settings, aliases)
**Confidence:** HIGH

## Summary

This phase implements a dedicated git plugin for managing git configuration through the established dotconfigs plugin pattern. The plugin manages four key areas: git hooks deployment, identity configuration, workflow settings, and aliases. Research focused on understanding git's configuration scopes, hook deployment patterns (especially the `core.hooksPath` mechanism), conventional commit validation, and standard workflow settings beyond the basics.

The standard approach is to use `git config --global` for user-wide settings (identity, workflow preferences, aliases) and either per-project hook deployment (copying to `.git/hooks/`) or global hook deployment via `core.hooksPath`. The critical finding is that `core.hooksPath` creates an either/or situation: when set, git uses ONLY those hooks, completely ignoring per-project hooks in `.git/hooks/`. This has major implications for the deployment model.

For conventional commit validation, the established pattern is a commit-msg hook with regex validation. Pre-push hooks typically focus on branch protection (preventing force-push to main/master). Git workflow settings have strong consensus around `pull.rebase=true`, `push.default=simple`, and `fetch.prune=true` as modern best practices.

**Primary recommendation:** Deploy hooks per-project by default (via project.sh copying to `.git/hooks/`), with opt-in global deployment via `core.hooksPath` that includes a clear conflict warning about overriding per-project hooks.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Identity & scope:**
- Single identity (one name + email), applied globally via `git config --global`
- Name + email only — no GPG signing
- .env is the source of truth (GIT_* prefix)
- First-run wizard pre-fills from existing git config if no .env keys exist; after that, .env values pre-fill
- Deploy warns on drift (if git config differs from .env) before overwriting
- Global identity only for deploy; per-repo identity is Claude's discretion via project.sh

**Hook behaviour:**
- commit-msg hook: conventional commit validation (enforce `type(scope): description` format)
- Pre-push hook scope and deployment model: **deferred to research** (see findings below)
- Claude Code hooks (PreToolUse/PostToolUse → `~/.claude/hooks/`) remain managed by Claude plugin — separate concern

**Wizard flow:**
- Grouped sections with menu to pick (not linear walk-through)
- Menu shows section status: configured vs not configured
- "Configure all" option walks through every section sequentially
- "Done — save and exit" option in menu triggers summary + confirm
- After configuring a section, returns to menu (pick another or Done)
- Always pre-fill from .env values (whether configuring one section or all)
- Opinionated defaults: settings enabled by default (pull.rebase=true, defaultBranch=main, etc.), user opts out
- Summary + confirm before saving to .env (consistent with Claude plugin)

**Alias design:**
- Default alias set (all enabled by default, user can disable any):
  - `git unstage` → `reset HEAD --`
  - `git last` → `log -1 HEAD`
  - `git lg` → `log --oneline --graph --all --decorate`
  - `git amend` → `commit --amend --no-edit`
  - `git undo` → `reset HEAD~1 --mixed`
  - `git wip` → `commit -am "WIP"`
- User can add custom aliases via wizard
- Deploy warns + overwrites if alias exists with a different definition (drift warning pattern)

### Claude's Discretion

- Per-repo identity handling in project.sh (whether to include it)
- .env storage format for aliases (one key per alias vs serialised)
- Exact pre-push hook behaviour (informed by research)
- Workflow settings set: research which `git config` settings to include beyond pull.rebase and init.defaultBranch

</user_constraints>

## Standard Stack

Git configuration management relies entirely on git's built-in tooling. No external libraries are required for core functionality.

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| git config | 2.9+ | Configuration management | Native git command, universally available |
| bash | 3.2+ | Hook scripts | Universal scripting language for git hooks |
| grep/sed | POSIX | Config parsing/manipulation | Standard Unix tools, highly portable |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| jq | 1.6+ | JSON config manipulation (optional) | If using JSON for complex config storage |
| perl | 5.x | Regex validation (optional) | More complex conventional commit patterns |

### Hook Management Approaches

Git 2.9+ introduced `core.hooksPath`, enabling global hook deployment. Prior to this, hooks were strictly per-repository in `.git/hooks/`.

**No installation required** — git config and hooks are native git functionality.

## Architecture Patterns

### Recommended Plugin Structure
```
plugins/git/
├── setup.sh           # Wizard entry point: plugin_git_setup()
├── deploy.sh          # Deployment: plugin_git_deploy()
├── project.sh         # Per-repo setup: plugin_git_project()
├── hooks/             # Hook templates
│   ├── commit-msg     # Conventional commit validation
│   └── pre-push       # Branch protection
└── templates/         # Config snippets
    └── gitconfig-workflow.conf  # Workflow settings template
```

### Pattern 1: Git Config Scope Hierarchy

**What:** Git has three configuration scopes: system (all users), global (current user), local (current repository). Settings cascade with local > global > system precedence.

**When to use:**
- Global scope (`--global`) for user identity, workflow preferences, aliases
- Local scope (`--local`) for per-repo overrides (handled via project.sh)
- System scope (`--system`) generally not touched by dotfiles tools

**Example:**
```bash
# Global identity (applies to all repos for this user)
git config --global user.name "Your Name"
git config --global user.email "your@email.com"

# Global workflow settings
git config --global pull.rebase true
git config --global push.default simple
git config --global init.defaultBranch main

# Check effective value (respects precedence)
git config --get user.name

# Show where setting comes from
git config --show-origin user.name
```

**Source:** [Git Config Documentation](https://git-scm.com/docs/git-config)

### Pattern 2: Hook Deployment Strategies

**What:** Two approaches for deploying git hooks: per-project (copy to `.git/hooks/`) or global via `core.hooksPath`.

**Critical distinction:** When `core.hooksPath` is set, git uses ONLY those hooks. Per-project hooks in `.git/hooks/` are completely ignored. This is an either/or choice, not additive.

**Per-project deployment:**
```bash
# In project.sh or deploy context
cp "$PLUGIN_DIR/hooks/commit-msg" "$REPO_ROOT/.git/hooks/commit-msg"
chmod +x "$REPO_ROOT/.git/hooks/commit-msg"
```

**Global deployment:**
```bash
# One-time global setup
HOOKS_DIR="$HOME/.dotconfigs/git-hooks"
mkdir -p "$HOOKS_DIR"
cp "$PLUGIN_DIR/hooks/"* "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/"*
git config --global core.hooksPath "$HOOKS_DIR"
```

**Hybrid approach (advanced):**
The `git-hooks-core` project enables running both global AND per-project hooks by:
1. Setting `core.hooksPath` to a global hooks directory
2. Global hooks explicitly invoke `.git/hooks/` scripts if they exist
3. Allows composition of global + per-project behaviour

**Recommendation for this phase:** Per-project deployment by default (via `project.sh`), with optional global deployment via wizard choice. If global deployment selected, warn that it overrides per-project hooks and suggest using the hybrid pattern if both are needed.

**Sources:**
- [Git Hooks Documentation](https://git-scm.com/docs/githooks)
- [git-hooks-core hybrid approach](https://github.com/pivotal-cf/git-hooks-core)

### Pattern 3: Grouped Wizard with Menu

**What:** Interactive wizard using bash `select` that presents a numbered menu of configuration sections, allows configuring individual sections or all at once, and returns to menu after each section.

**When to use:** Complex multi-section configuration that users may want to approach incrementally (like the git plugin wizard).

**Example:**
```bash
plugin_git_setup() {
    # Load existing .env for pre-fill
    [[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

    while true; do
        echo ""
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║              dotconfigs — Git Configuration                ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Current configuration status:"
        echo "  1. Identity:          ${GIT_USER_NAME:+✓ configured}"
        echo "  2. Workflow Settings: ${GIT_WORKFLOW_ENABLED:+✓ configured}"
        echo "  3. Aliases:           ${GIT_ALIASES_ENABLED:+✓ configured}"
        echo "  4. Hooks:             ${GIT_HOOKS_ENABLED:+✓ configured}"
        echo ""

        PS3="Select an option: "
        options=("Configure Identity" "Configure Workflow Settings" "Configure Aliases" "Configure Hooks" "Configure All" "Done — save and exit")

        select opt in "${options[@]}"; do
            case $opt in
                "Configure Identity")
                    _git_wizard_identity
                    break  # Return to menu
                    ;;
                "Configure Workflow Settings")
                    _git_wizard_workflow
                    break
                    ;;
                "Configure Aliases")
                    _git_wizard_aliases
                    break
                    ;;
                "Configure Hooks")
                    _git_wizard_hooks
                    break
                    ;;
                "Configure All")
                    _git_wizard_identity
                    _git_wizard_workflow
                    _git_wizard_aliases
                    _git_wizard_hooks
                    break
                    ;;
                "Done — save and exit")
                    _git_wizard_save  # Show summary, confirm, save
                    return 0
                    ;;
                *)
                    echo "Invalid option"
                    continue
                    ;;
            esac
        done
    done
}
```

**Sources:**
- [Bash Select Documentation](https://www.baeldung.com/linux/shell-script-simple-select-menu)
- [Select Loop Patterns](https://linuxize.com/post/bash-select/)

### Pattern 4: Configuration Drift Detection

**What:** Before deploying git config, compare desired state (.env) with actual git config state and warn if they differ.

**When to use:** When .env has been previously written but git config may have been manually changed since last deploy.

**Example:**
```bash
_git_check_drift() {
    local has_drift=false

    # Check identity drift
    if [[ -n "${GIT_USER_NAME:-}" ]]; then
        local current_name=$(git config --global --get user.name 2>/dev/null || echo "")
        if [[ -n "$current_name" && "$current_name" != "$GIT_USER_NAME" ]]; then
            echo "⚠️  Drift detected: user.name"
            echo "   Current:  $current_name"
            echo "   .env:     $GIT_USER_NAME"
            has_drift=true
        fi
    fi

    if [[ -n "${GIT_USER_EMAIL:-}" ]]; then
        local current_email=$(git config --global --get user.email 2>/dev/null || echo "")
        if [[ -n "$current_email" && "$current_email" != "$GIT_USER_EMAIL" ]]; then
            echo "⚠️  Drift detected: user.email"
            echo "   Current:  $current_email"
            echo "   .env:     $GIT_USER_EMAIL"
            has_drift=true
        fi
    fi

    if [[ "$has_drift" == "true" ]]; then
        echo ""
        echo "Deploy will overwrite current git config with .env values."
        if ! wizard_yesno "Continue?" "y"; then
            return 1
        fi
    fi

    return 0
}
```

**When to check:**
- At start of deploy.sh (after loading .env, before applying changes)
- For identity, aliases, workflow settings
- NOT for hooks (hooks are files, not git config values)

### Anti-Patterns to Avoid

- **Using `core.hooksPath` without warning about per-project hook override:** This breaks tools like Husky, pre-commit framework, and any project-specific hooks. Always warn and offer per-project deployment as default.
- **Hardcoding hook paths:** Use `git rev-parse --show-toplevel` to find repo root, `git rev-parse --git-dir` for .git directory location.
- **Forgetting chmod +x on hooks:** Hooks must be executable. Always `chmod +x` after copying.
- **Not pre-filling from existing git config on first run:** If .env doesn't exist but git config has values, pre-fill the wizard with current git config values for better UX.
- **Storing aliases as single serialised string:** Use individual .env keys per alias for easier management and drift detection.

## Don't Hand-Roll

Problems that look simple but have existing solutions or established patterns:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Conventional commit validation | Custom parser | Regex pattern from conventional-commits spec | Well-tested regex exists, handles edge cases (scope, breaking changes, etc.) |
| Hook management | Custom orchestration | git config core.hooksPath OR per-project copy | Git's built-in mechanism, no custom tooling needed |
| Config drift detection | Custom tracking | git config --get with comparison | Native git command, reliable |
| Alias management | Custom alias storage | git config alias.* | Git's native alias system, works across all tools |
| Pre-push branch protection | Custom git command parsing | Hook with stdin parsing per githooks spec | Official git hooks protocol, handles all edge cases |

**Key insight:** Git's configuration system and hooks are mature and well-documented. Use native git commands (`git config`, hook files in standard locations) rather than building abstractions on top. The complexity is in the wizard UX and deployment orchestration, not in the git interaction layer.

## Common Pitfalls

### Pitfall 1: core.hooksPath Overrides ALL Per-Project Hooks

**What goes wrong:** User sets `core.hooksPath` globally, then wonders why project-specific hooks (Husky, pre-commit framework, custom project hooks) stop working.

**Why it happens:** Git's design: when `core.hooksPath` is set, `.git/hooks/` is completely ignored. It's not additive, it's replacement.

**How to avoid:**
1. Default to per-project hook deployment (copy to `.git/hooks/`)
2. If offering global deployment, show clear warning: "This will override all per-project hooks in .git/hooks/ for all repositories"
3. Offer hybrid option: global hooks that chain to `.git/hooks/` if they exist

**Warning signs:**
- User reports "my project's pre-commit hook stopped working"
- Husky shows "hooks not found" errors
- Pre-commit framework shows "hook not executable" errors

**Sources:**
- [core.hooksPath conflict with Husky](https://github.com/typicode/husky/issues/391)
- [pre-commit refusing to install with global hooksPath](https://github.com/pre-commit/pre-commit/issues/1198)

### Pitfall 2: Conventional Commit Regex Too Strict

**What goes wrong:** Regex rejects valid conventional commits due to overly strict scope/subject validation.

**Why it happens:** Trying to enforce too many rules in regex (character limits, scope naming, etc.) leads to false positives.

**How to avoid:**
- Use the minimal conventional commits regex: `^(feat|fix|docs|style|refactor|test|chore|build|ci|perf|revert)(\([a-zA-Z0-9_.-]+\))?(!)?:\s.+$`
- Don't enforce subject line length in regex (warn separately if needed)
- Allow flexible scope content (alphanumeric, dash, underscore, dot)
- Don't block on warnings (warn about length/capitalisation, but don't fail the commit)

**Warning signs:**
- Valid-looking commits get rejected
- Users report "scope not accepted" errors
- Regex needs constant tweaking for edge cases

**Sources:**
- [Conventional Commits Spec](https://www.conventionalcommits.org/en/about/)
- [Conventional Commit Regex Examples](https://gist.github.com/marcojahn/482410b728c31b221b70ea6d2c433f0c)

### Pitfall 3: Not Handling Merge Commits in Hooks

**What goes wrong:** Hooks reject merge commits or squash merges because they don't follow conventional format.

**Why it happens:** Git generates merge commit messages automatically ("Merge branch 'feature' into main"), which don't match conventional commit regex.

**How to avoid:**
- Check for merge context: `[ -f "$REPO_ROOT/.git/MERGE_HEAD" ]` (active merge)
- Check for squash merge: `[ -f "$REPO_ROOT/.git/SQUASH_MSG" ]` (squash merge in progress)
- Skip conventional commit validation during merges, OR
- Only validate the message if it was user-supplied (not git-generated)

**Warning signs:**
- Merge commits fail validation
- "git merge --squash" followed by "git commit" fails
- Users report needing to use --no-verify for merges

**Existing pattern:** The current `githooks/commit-msg` in this repo already handles this (lines 69-89) by detecting squash merge state and relaxing validation.

### Pitfall 4: Forgetting to Pre-fill from Git Config on First Run

**What goes wrong:** User already has git config set (user.name, user.email), runs wizard, gets prompted with empty defaults instead of their current values.

**Why it happens:** Wizard only checks .env for pre-fill values, doesn't check actual git config state.

**How to avoid:**
```bash
# In wizard, before prompting
local default_name="${GIT_USER_NAME:-}"
if [[ -z "$default_name" ]]; then
    # .env doesn't have it, check git config
    default_name=$(git config --global --get user.name 2>/dev/null || echo "")
fi

wizard_prompt "Git user.name" "$default_name" GIT_USER_NAME
```

**Warning signs:**
- User complains wizard "lost" their git config
- User has to re-enter values they already configured
- Poor first-run experience

### Pitfall 5: Alias Name Conflicts with Git Commands

**What goes wrong:** Alias shadows a built-in git command, causing confusion.

**Why it happens:** User creates alias like `git commit` thinking it will extend the command, but git uses alias instead of built-in.

**How to avoid:**
- Validate alias names don't match built-in git commands
- List of built-in commands to avoid: commit, push, pull, fetch, merge, rebase, checkout, switch, branch, status, log, diff, add, rm, mv, reset, tag
- Use clearly distinct names (e.g., "ci" not "commit", "unstage" not "reset")

**Warning signs:**
- Git behaves unexpectedly
- Built-in command options stop working
- Error messages mention alias instead of command

**Implementation:**
```bash
RESERVED_COMMANDS=(commit push pull fetch merge rebase checkout switch branch status log diff add rm mv reset tag)

_git_validate_alias_name() {
    local alias_name="$1"
    for cmd in "${RESERVED_COMMANDS[@]}"; do
        if [[ "$alias_name" == "$cmd" ]]; then
            echo "Error: Cannot create alias '$alias_name' - conflicts with git command"
            return 1
        fi
    done
    return 0
}
```

## Code Examples

Verified patterns from official sources and established conventions:

### Conventional Commit Validation (commit-msg hook)

```bash
#!/bin/bash
# Source: Conventional Commits spec + community patterns

COMMIT_MSG_FILE=$1
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")
SUBJECT_LINE=$(echo "$COMMIT_MSG" | head -1)

# Conventional commit regex (allows optional scope and breaking change indicator)
PATTERN='^(feat|fix|docs|style|refactor|test|chore|build|ci|perf|revert)(\([a-zA-Z0-9_.-]+\))?(!)?:\s.+$'

# Skip validation during merge
if [ -f "$(git rev-parse --git-dir)/MERGE_HEAD" ]; then
    exit 0
fi

# Validate format
if ! echo "$SUBJECT_LINE" | grep -qE "$PATTERN"; then
    echo "ERROR: Commit message does not match Conventional Commits format"
    echo ""
    echo "Format: type(scope): description"
    echo ""
    echo "Types: feat, fix, docs, style, refactor, test, chore, build, ci, perf, revert"
    echo "Scope: optional, alphanumeric with - _ ."
    echo "Breaking: optional ! before colon"
    echo ""
    echo "Examples:"
    echo "  feat(api): add user authentication"
    echo "  fix: resolve null pointer exception"
    echo "  docs(readme): update installation steps"
    echo "  refactor(core)!: breaking change to plugin API"
    echo ""
    echo "See: https://www.conventionalcommits.org"
    exit 1
fi

exit 0
```

**Sources:**
- [Conventional Commits Gist](https://gist.github.com/mathiasschopmans/70e8d466c620d950f2ca2cea08c4e279)
- [Conventional Commits Spec](https://www.conventionalcommits.org/en/about/)

### Pre-Push Hook for Branch Protection

```bash
#!/bin/bash
# Source: Community patterns for branch protection

PROTECTED_BRANCHES="^(main|master)$"
CURRENT_BRANCH=$(git symbolic-ref HEAD | sed -e 's,.*/\(.*\),\1,')

# Check if pushing to protected branch
if echo "$CURRENT_BRANCH" | grep -qE "$PROTECTED_BRANCHES"; then
    # Check if force push
    PUSH_COMMAND=$(ps -ocommand= -p $PPID 2>/dev/null || echo "")
    if echo "$PUSH_COMMAND" | grep -qE "force|delete|-f"; then
        echo "ERROR: Force push to protected branch '$CURRENT_BRANCH' is not allowed"
        echo ""
        echo "Protected branches: main, master"
        echo ""
        echo "If you absolutely must force push, use: git push --no-verify"
        exit 1
    fi
fi

exit 0
```

**Sources:**
- [Pre-push Force Protection Gist](https://gist.github.com/stefansundin/d465f1e331fc5c632088)
- [Git Pre-push Hook Tutorial](https://hiltonmeyer.com/articles/protect-git-branch-and-prevent-master-push.html)

### Drift Detection Pattern

```bash
# Check if current git config differs from .env values
_git_detect_drift() {
    local drift_detected=false

    # Identity drift
    if [[ -n "${GIT_USER_NAME:-}" ]]; then
        local current=$(git config --global --get user.name 2>/dev/null || echo "")
        if [[ -n "$current" && "$current" != "$GIT_USER_NAME" ]]; then
            echo "⚠️  user.name: '$current' → '$GIT_USER_NAME'"
            drift_detected=true
        fi
    fi

    if [[ -n "${GIT_USER_EMAIL:-}" ]]; then
        local current=$(git config --global --get user.email 2>/dev/null || echo "")
        if [[ -n "$current" && "$current" != "$GIT_USER_EMAIL" ]]; then
            echo "⚠️  user.email: '$current' → '$GIT_USER_EMAIL'"
            drift_detected=true
        fi
    fi

    # Workflow settings drift
    if [[ -n "${GIT_PULL_REBASE:-}" ]]; then
        local current=$(git config --global --get pull.rebase 2>/dev/null || echo "")
        if [[ -n "$current" && "$current" != "$GIT_PULL_REBASE" ]]; then
            echo "⚠️  pull.rebase: '$current' → '$GIT_PULL_REBASE'"
            drift_detected=true
        fi
    fi

    # Return status
    [[ "$drift_detected" == "true" ]] && return 0 || return 1
}

# Usage in deploy.sh
if _git_detect_drift; then
    echo ""
    echo "Configuration drift detected. Deploy will overwrite git config with .env values."
    if ! wizard_yesno "Continue?" "y"; then
        echo "Deploy cancelled."
        return 1
    fi
fi
```

**Source:** Derived from git config --show-origin pattern in [Git Config Documentation](https://git-scm.com/docs/git-config)

### Alias Management

```bash
# Set git alias via git config
_git_deploy_alias() {
    local alias_name="$1"
    local alias_command="$2"

    # Check for existing alias with different definition
    local current=$(git config --global --get "alias.$alias_name" 2>/dev/null || echo "")
    if [[ -n "$current" && "$current" != "$alias_command" ]]; then
        echo "⚠️  Alias '$alias_name' exists with different definition"
        echo "   Current:  $current"
        echo "   New:      $alias_command"
    fi

    # Set alias
    git config --global "alias.$alias_name" "$alias_command"
    echo "  ✓ git $alias_name → $alias_command"
}

# Deploy all aliases from .env
_git_deploy_aliases() {
    # Example: GIT_ALIAS_UNSTAGE="reset HEAD --"
    # Parse .env and deploy each GIT_ALIAS_* key

    _git_deploy_alias "unstage" "reset HEAD --"
    _git_deploy_alias "last" "log -1 HEAD"
    _git_deploy_alias "lg" "log --oneline --graph --all --decorate"
    _git_deploy_alias "amend" "commit --amend --no-edit"
    _git_deploy_alias "undo" "reset HEAD~1 --mixed"
    _git_deploy_alias "wip" "commit -am 'WIP'"
}
```

**Source:** [Git Aliases Documentation](https://git-scm.com/book/en/v2/Git-Basics-Git-Aliases)

## Recommended Workflow Settings

Based on research, these settings represent modern git best practices:

| Setting | Value | Purpose | Source |
|---------|-------|---------|--------|
| `pull.rebase` | `true` | Rebase instead of merge on pull, cleaner history | [Best Practices](https://spin.atomicobject.com/git-configurations-default/) |
| `push.default` | `simple` | Push only current branch to upstream | [Git Core Developers](https://blog.gitbutler.com/how-git-core-devs-configure-git) |
| `fetch.prune` | `true` | Auto-remove deleted remote branches | [Recommended Settings](https://www.brandonpugh.com/blog/git-config-settings-i-always-recommend/) |
| `init.defaultBranch` | `main` | Default branch name for new repos | Git 2.28+ standard |
| `merge.ff` | `false` | Always create merge commit (optional, team preference) | Explicit merge history |
| `core.autocrlf` | `input` (macOS/Linux) | Normalise line endings | Cross-platform safety |

**Additional useful settings (Claude's discretion to include):**

| Setting | Value | Purpose |
|---------|-------|---------|
| `rerere.enabled` | `true` | Reuse recorded conflict resolutions |
| `help.autocorrect` | `10` | Auto-run corrected command after 1 second |
| `diff.algorithm` | `histogram` | Better diff algorithm |
| `log.date` | `relative` | Show relative dates in log |
| `branch.autoSetupMerge` | `true` | Auto-track remote branches |

**Sources:**
- [Three Git Configurations That Should Be the Default](https://spin.atomicobject.com/git-configurations-default/)
- [Git Config Settings I Always Recommend](https://www.brandonpugh.com/blog/git-config-settings-i-always-recommend/)
- [How Core Git Developers Configure Git](https://blog.gitbutler.com/how-git-core-devs-configure-git)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hooks in `.git/hooks/` only | `core.hooksPath` for global hooks | Git 2.9 (2016) | Centralised hook management possible |
| `master` default branch | `main` default branch | Git 2.28 (2020) | Industry-wide shift to inclusive language |
| `push.default = matching` | `push.default = simple` | Git 2.0 (2014) | Safer push behaviour (current branch only) |
| Manual hook copying per repo | Hook management tools (Husky, pre-commit) | ~2018 onwards | Automated, version-controlled hooks |
| Conventional Commits optional | Conventional Commits standard | ~2020 onwards | Standardised commit format across ecosystem |

**Deprecated/outdated:**
- **Per-repo hook copying as primary approach:** Still works, but `core.hooksPath` enables cleaner global management (with caveats about conflicts)
- **Husky v4 and earlier:** Husky v5+ (2021) changed architecture; old tutorials don't apply
- **Git config without scopes:** Always specify `--global` or `--local` explicitly to avoid confusion

## Open Questions

None — research comprehensively answered all planning questions.

## Recommendations for Claude's Discretion Areas

Based on research findings:

### 1. Per-repo identity in project.sh

**Recommendation:** Include it as an option in the wizard, disabled by default.

**Reasoning:**
- Useful for work vs personal repos, or multi-identity setups
- Common pattern: global identity as default, per-repo override for specific projects
- Low complexity to implement (just `git config --local user.name/email`)

**Implementation:**
```bash
# In project.sh wizard
if wizard_yesno "Configure project-specific git identity?" "n"; then
    wizard_prompt "Project git user.name" "" PROJECT_GIT_NAME
    wizard_prompt "Project git user.email" "" PROJECT_GIT_EMAIL

    git config --local user.name "$PROJECT_GIT_NAME"
    git config --local user.email "$PROJECT_GIT_EMAIL"
fi
```

### 2. .env storage format for aliases

**Recommendation:** One key per alias (not serialised).

**Reasoning:**
- Easier drift detection (compare individual alias values)
- Simpler to parse and update
- Follows existing .env patterns in this codebase (see Claude plugin's space-separated lists)
- Allows individual alias enable/disable in future

**Format:**
```bash
# .env format
GIT_ALIAS_UNSTAGE="reset HEAD --"
GIT_ALIAS_LAST="log -1 HEAD"
GIT_ALIAS_LG="log --oneline --graph --all --decorate"
GIT_ALIAS_AMEND="commit --amend --no-edit"
GIT_ALIAS_UNDO="reset HEAD~1 --mixed"
GIT_ALIAS_WIP="commit -am 'WIP'"

# Or: space-separated list of enabled defaults + custom aliases
GIT_ALIASES_ENABLED="unstage last lg amend undo wip"
GIT_ALIAS_UNSTAGE="reset HEAD --"  # individual definitions
# ... etc
```

Second format (enabled list + definitions) is more flexible for toggling defaults on/off.

### 3. Pre-push hook behaviour

**Recommendation:** Protect main/master from force-push, allow normal push, configurable via .env.

**Reasoning:**
- Prevents accidental force-push to protected branches (common mistake)
- Doesn't block normal workflow (push to main is allowed for solo projects)
- Configurable protection level matches existing pre-commit hook pattern (warn/block/off)

**Implementation:**
```bash
# .env
GIT_HOOK_PREPUSH_PROTECTION=warn  # warn | block | off

# Pre-push hook
PROTECTED_BRANCHES="^(main|master)$"
CURRENT_BRANCH=$(git symbolic-ref HEAD | sed -e 's,.*/\(.*\),\1,')

if echo "$CURRENT_BRANCH" | grep -qE "$PROTECTED_BRANCHES"; then
    PUSH_COMMAND=$(ps -ocommand= -p $PPID 2>/dev/null || echo "")
    if echo "$PUSH_COMMAND" | grep -qE "force|delete|-f"; then
        if [[ "$GIT_HOOK_PREPUSH_PROTECTION" == "block" ]]; then
            echo "ERROR: Force push to $CURRENT_BRANCH blocked"
            exit 1
        elif [[ "$GIT_HOOK_PREPUSH_PROTECTION" == "warn" ]]; then
            echo "WARNING: Force pushing to $CURRENT_BRANCH"
        fi
    fi
fi
```

### 4. Workflow settings to include

**Recommendation:** Include the "Big 3" by default (pull.rebase, push.default, fetch.prune) plus init.defaultBranch. Offer advanced settings as opt-in.

**Core settings (enabled by default):**
- `pull.rebase = true`
- `push.default = simple`
- `fetch.prune = true`
- `init.defaultBranch = main`

**Advanced settings (opt-in via wizard):**
- `rerere.enabled = true` (reuse recorded resolutions)
- `diff.algorithm = histogram` (better diffs)
- `merge.ff = false` (always create merge commits)
- `help.autocorrect = 10` (auto-run corrected commands)

**Reasoning:** The Big 3 + defaultBranch are universally recommended. Advanced settings are preference-dependent or opinionated.

## Sources

### Primary (HIGH confidence)

Official Git Documentation:
- [Git Hooks Documentation](https://git-scm.com/docs/githooks) — Hook types, parameters, execution
- [Git Config Documentation](https://git-scm.com/docs/git-config) — Configuration scopes, commands
- [Git Aliases](https://git-scm.com/book/en/v2/Git-Basics-Git-Aliases) — Alias system

Conventional Commits:
- [Conventional Commits Specification](https://www.conventionalcommits.org/en/about/) — Official spec
- [Conventional Commit Regex Gist](https://gist.github.com/marcojahn/482410b728c31b221b70ea6d2c433f0c) — Community-verified regex

Git Hook Examples:
- [Conventional Commit Hook Gist](https://gist.github.com/mathiasschopmans/70e8d466c620d950f2ca2cea08c4e279) — Working bash implementation
- [Pre-push Protection Gist](https://gist.github.com/stefansundin/d465f1e331fc5c632088) — Force-push prevention

### Secondary (MEDIUM confidence)

Best Practices Articles:
- [Three Git Configurations That Should Be the Default](https://spin.atomicobject.com/git-configurations-default/)
- [Git Config Settings I Always Recommend](https://www.brandonpugh.com/blog/git-config-settings-i-always-recommend/)
- [How Core Git Developers Configure Git](https://blog.gitbutler.com/how-git-core-devs-configure-git)

Hook Deployment Patterns:
- [Git Hooks Complete Guide | DataCamp](https://www.datacamp.com/tutorial/git-hooks-complete-guide)
- [Mastering Git Hooks | Kinsta](https://kinsta.com/blog/git-hooks/)
- [git-hooks-core GitHub](https://github.com/pivotal-cf/git-hooks-core) — Hybrid approach reference

Configuration Management:
- [Git Config Scopes | Medium](https://medium.com/@yadavprakhar1809/understanding-the-three-levels-of-git-config-local-global-and-system-e95c26aac8ee)
- [Git Config Tutorial](https://ihatetomatoes.net/git-config-tutorial/)

Bash Select Menus:
- [Creating a Simple Select Menu | Baeldung](https://www.baeldung.com/linux/shell-script-simple-select-menu)
- [Bash Select | Linuxize](https://linuxize.com/post/bash-select/)

Alias Best Practices:
- [Git Alias Tutorial | DataCamp](https://www.datacamp.com/tutorial/git-alias)
- [Git Aliases | Atlassian](https://www.atlassian.com/git/tutorials/git-alias)

### Tertiary (LOW confidence)

Community Discussions:
- [core.hooksPath conflicts with Husky](https://github.com/typicode/husky/issues/391) — Known limitation
- [pre-commit refusing to install](https://github.com/pre-commit/pre-commit/issues/1198) — Global hooksPath issue

## Metadata

**Confidence breakdown:**
- Git config scopes and commands: HIGH — Official documentation, stable since Git 2.0
- Hook deployment patterns: HIGH — Official docs + established community patterns
- Conventional commits: HIGH — Official spec + widely adopted
- Workflow settings recommendations: MEDIUM — Strong consensus but some team preference variation
- Bash select patterns: HIGH — POSIX standard, well-documented
- core.hooksPath conflicts: HIGH — Documented in multiple tool issue trackers

**Research date:** 2026-02-07
**Valid until:** 2026-09-07 (6 months) — Git config is stable, hook patterns unlikely to change significantly. Conventional commits spec is stable.
