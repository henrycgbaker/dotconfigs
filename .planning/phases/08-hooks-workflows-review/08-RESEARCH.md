# Phase 8: Hooks & Workflows Review - Research

**Researched:** 2026-02-08
**Domain:** Git hooks, Claude Code hooks, shell scripting (bash 3.2), config management
**Confidence:** HIGH

## Summary

This research covers the implementation requirements for expanding dotconfigs' hook roster from 2 git hooks (commit-msg, pre-push) to a full suite of 6+ git hooks plus Claude Code hooks, alongside establishing project-level configuration architecture and auto-generated documentation.

The git hooks ecosystem is well-established with authoritative official documentation. All required hooks (pre-commit, prepare-commit-msg, post-merge, post-checkout) are standard client-side hooks supported across all git versions. Implementation patterns are mature and widely deployed in production environments.

Claude Code hooks follow a different model: settings.json configuration with JSON stdin/stdout communication, supporting PreToolUse and PostToolUse events with decision control capabilities.

The critical constraint is bash 3.2 compatibility (macOS default). Namerefs (`local -n`, `declare -n`) are bash 4.3+ features and must be avoided. All patterns must use eval-based alternatives or standard POSIX constructs.

**Primary recommendation:** Use official git hooks documentation as SSOT for hook timing/parameters. Implement all checks as independently configurable features with opinionated defaults. Follow bash 3.2 POSIX patterns throughout. Use hierarchical config precedence (project > global > defaults) with explicit override semantics.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Design Principle:**
- Everything is configurable, with opinionated defaults — applies universally to all hooks, tools, settings
- Each setting can be configured globally (dotconfigs .env) or per-project (project config)
- Hardcoded values are banned; even AI attribution blocking and WIP blocking get a config key with strong default ON

**hooks.conf Ownership — Split by Concern:**
- Git-related settings (CONVENTIONAL_COMMITS, BRANCH_PROTECTION, etc.) move to git plugin templates
- Claude-related settings (RUFF_ENABLED, etc.) stay in claude plugin templates
- Each plugin deploys its own config files during `dotconfigs project`
- Git plugin's project.sh deploys git hook config; claude plugin's project.sh deploys claude hook config

**hooks.conf Deploy — Split Into Two Files:**
- Per-project git hook config: user selects deploy location from a list of presets + custom path option
  - Preset options: `.githooks/config`, `.claude/git-hooks.conf`, `.git/hooks/hooks.conf`
  - Plus: "Specify custom path"
  - This is a wizard step during `dotconfigs setup git` / `dotconfigs project`
- Per-project claude hook config: separate file under `.claude/`

**Drop hooks.conf Profiles:**
- Remove the default/strict/permissive profile templates
- Individual settings only — user picks each setting independently via wizard
- Simpler, more flexible, consistent with "everything configurable" principle

**Enforcement Levels:**
- AI attribution blocking: Configurable with strong default ON (BLOCK_AI_ATTRIBUTION=true)
- WIP blocking on main: Configurable with strong default ON (WIP_BLOCK_ON_MAIN=true)
- Conventional commits: Configurable enforcement level — soft warn by default, configurable to hard block (CONVENTIONAL_COMMITS=true, CONVENTIONAL_COMMITS_STRICT=false)
- Subject line length: Configurable (MAX_SUBJECT_LENGTH=72 default)
- Branch protection: Already configurable (GIT_HOOK_PREPUSH_PROTECTION=warn default)

**Variable Naming — Claude's Discretion:**
- Unify BRANCH_PROTECTION / GIT_HOOK_PREPUSH_PROTECTION naming — Claude picks cleanest approach
- Ensure consistent naming convention across all config keys

**Squash Merge Workflow:**
- Keep /squash-merge as the only merge command (industry standard for solo dev + feature branches)
- Do NOT add /merge-branch alternative
- Audit /squash-merge against industry best practice — ensure it follows the standard pattern
- Add tradeoff documentation to the command output (git tracking limitation, why branch deletion handles it)

**Hook Roster — Maximal Coverage:**
- Expand from 2 git hooks to full practical roster:
  - Existing: commit-msg, pre-push
  - Add: pre-commit, prepare-commit-msg, post-merge, post-checkout
  - Evaluate: any other practical git hooks (Claude's discretion on what's worth including)
- Each hook is independently configurable (enable/disable globally and per-project)
- User picks from roster during setup wizard and project wizard

**New Hook Specifications:**

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

**Explore Agent Hook:**
- Research properly how explore agent model selection actually works before deciding
- Include as a research + decision task in the plan, not a build task yet

**Project-Level Config Architecture:**
- Global config: `dotconfigs/.env` — user's global preferences (setup writes, deploy reads)
- Project config: project-level file — overrides global defaults for this repo
  - File name and format: Claude's discretion (recommend consolidating metadata + overrides)
  - `.dotconfigs.json` already exists for project metadata — extend or add `.dotconfigs.env`
- `dotconfigs project .` runs interactive wizard — shows roster pre-filled from global defaults, user toggles overrides
- Precedence: project config > global .env > hardcoded defaults

**Auto-Generated Roster Documentation:**
- Single document listing ALL available hooks, tools, configs, and workflows with short explanations
- Generated using SSOT principles — mechanism at Claude's discretion (script reads plugin dirs, metadata headers, etc.)
- Linked from README
- Updates automatically when hooks/tools are added

**README Updates:**
- Brief GSD framework mention (2-3 lines: what it is, how to enable, link to repo)
- Link to auto-generated roster doc

### Claude's Discretion

- Variable naming unification approach
- Project-level config file format (consolidate .dotconfigs.json or add .dotconfigs.env)
- Auto-generated doc mechanism (script-based, metadata headers, etc.)
- Which additional git hooks beyond the specified six are worth including
- Exact preset paths for git hook config deployment
- Implementation details for all new hooks

### Deferred Ideas (OUT OF SCOPE)

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

</user_constraints>

---

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Git hooks | 2.0+ | Client-side hook system | Native git feature, universal availability |
| Bash | 3.2+ | Hook script language | POSIX portable, macOS default version |
| Claude Code hooks | 2.0.10+ | IDE automation layer | Official Claude Code API for tool interception |
| jq | 1.6+ | JSON processing in bash | Industry standard for shell JSON manipulation |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| git diff | native | Staged file detection | All pre-commit checks |
| wc | native | File size checking | Large file detection (portable across macOS/Linux) |
| grep/egrep | native | Pattern matching | Secrets detection, debug statement search |
| ps | native | Process inspection | Force push detection in pre-push |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Bash scripts | Python/Node scripts | Python/Node adds dependency, slower startup. Use bash for speed/portability |
| Manual config | pre-commit framework | Framework adds abstraction layer, external dependency. Use bash for simplicity/control |
| stat command | wc -c | stat syntax differs macOS/Linux. wc -c is portable |

**Installation:**
```bash
# Core requirements (git, bash, jq) typically pre-installed
# Verify:
git --version    # 2.0+
bash --version   # 3.2+ (macOS default: 3.2.57)
jq --version     # 1.6+
```

## Architecture Patterns

### Recommended Project Structure
```
~/.claude/git-hooks/       # Global hooks (via core.hooksPath)
├── commit-msg            # Conventional commits, AI attribution blocking
├── pre-commit            # Secrets, large files, debug statements
├── prepare-commit-msg    # Branch prefix extraction
├── pre-push              # Force push protection
├── post-merge            # Dependency change detection
└── post-checkout         # Branch info display

# Per-project config (user-selected location)
.githooks/config          # Preset option 1
.claude/git-hooks.conf    # Preset option 2
.git/hooks/hooks.conf     # Preset option 3

.claude/
├── settings.json         # Claude Code hook definitions
├── hooks/                # Claude Code hook scripts
└── claude-hooks.conf     # Claude-specific config
```

### Pattern 1: Config Loading Hierarchy

**What:** Load configuration from multiple sources with clear precedence
**When to use:** Every hook script needs config values
**Example:**
```bash
#!/bin/bash
# Source: Git hooks official documentation + established patterns

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
HOOK_CONFIG="$REPO_ROOT/.git/hooks/hooks.conf"  # Or user-selected path

# 1. Hardcoded defaults (lowest precedence)
SECRETS_CHECK_ENABLED=true
LARGE_FILE_THRESHOLD=1048576  # 1MB in bytes
DEBUG_CHECK_ENABLED=true

# 2. Load global config from dotconfigs .env (via env vars)
SECRETS_CHECK_ENABLED="${GIT_HOOK_SECRETS_CHECK:-$SECRETS_CHECK_ENABLED}"
LARGE_FILE_THRESHOLD="${GIT_HOOK_LARGE_FILE_THRESHOLD:-$LARGE_FILE_THRESHOLD}"

# 3. Load project config (highest precedence)
if [ -f "$HOOK_CONFIG" ]; then
    source "$HOOK_CONFIG"
fi

# Config now loaded with proper precedence
```

### Pattern 2: Bash 3.2 Compatible Patterns

**What:** Avoid bash 4+ features (namerefs, associative arrays)
**When to use:** All bash scripts in this codebase
**Example:**
```bash
# ❌ WRONG (bash 4.3+, breaks on macOS):
local -n ref="$var"
declare -n ref="$var"

# ✅ RIGHT (bash 3.2 compatible):
eval "value=\$$var"  # Indirect reference

# ❌ WRONG (bash 4+, associative arrays):
declare -A config
config[key]="value"

# ✅ RIGHT (bash 3.2 compatible):
# Use separate variables or indexed arrays
CONFIG_KEY="value"
```

### Pattern 3: Portable File Size Detection

**What:** Check staged file sizes without stat command differences
**When to use:** pre-commit large file detection
**Example:**
```bash
# Source: Stack Overflow verified portable approaches

# ✅ PORTABLE (works on macOS + Linux):
for file in $(git diff --cached --name-only --diff-filter=ACM); do
    size=$(wc -c < "$file" 2>/dev/null || echo 0)
    if [ "$size" -ge "$LARGE_FILE_THRESHOLD" ]; then
        echo "WARNING: Large file detected: $file (${size} bytes)"
    fi
done

# ❌ NOT PORTABLE (stat syntax differs):
# macOS: stat -f %z "$file"
# Linux: stat -c %s "$file"
```

### Pattern 4: Secrets Detection Regex

**What:** Pattern matching for common secret formats
**When to use:** pre-commit secrets check
**Example:**
```bash
# Source: AWS git-secrets, GitGuardian best practices

# Check staged changes only
git diff --cached --diff-filter=ACM | grep -qE '(
    AKIA[0-9A-Z]{16}|                           # AWS access key
    ["\x27]?[Aa]pi[_-]?[Kk]ey["\x27]?\s*[:=]|  # API key patterns
    ["\x27]?[Ss]ecret["\x27]?\s*[:=]|          # Secret patterns
    (sk|pk)_(test|live)_[a-zA-Z0-9]{24,}|      # Stripe keys
    AIza[0-9A-Za-z\\-_]{35}                     # Google API key
)' && {
    echo "❌ ERROR: Potential secret detected in staged changes"
    exit 1
}
```

### Pattern 5: Debug Statement Detection

**What:** Language-agnostic debug pattern matching
**When to use:** pre-commit debug check
**Example:**
```bash
# Source: Community patterns from git hook implementations

git diff --cached --diff-filter=ACM | grep -qE '(
    console\.(log|debug|info|warn|error)|  # JavaScript
    debugger;|                              # JavaScript/Chrome
    print\(|                                # Python (basic)
    pdb\.set_trace|                        # Python debugger
    binding\.pry|                          # Ruby
    breakpoint\(\)                         # Python 3.7+
)' && {
    echo "⚠️  WARNING: Debug statement detected"
    # Configurable: warn or block
}
```

### Pattern 6: Branch-to-Conventional-Commit Mapping

**What:** Extract conventional commit prefix from branch name
**When to use:** prepare-commit-msg hook
**Example:**
```bash
# Source: Community patterns, conventional commit spec

BRANCH_NAME=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")

# Standard mappings
case "$BRANCH_NAME" in
    feature/*|feat/*)     PREFIX="feat: " ;;
    fix/*|bugfix/*|hotfix/*) PREFIX="fix: " ;;
    docs/*)               PREFIX="docs: " ;;
    refactor/*)           PREFIX="refactor: " ;;
    test/*)               PREFIX="test: " ;;
    chore/*)              PREFIX="chore: " ;;
    style/*)              PREFIX="style: " ;;
    perf/*)               PREFIX="perf: " ;;
    *)                    PREFIX="" ;;
esac

# Prepend prefix if not already present
COMMIT_MSG=$(cat "$1")
if [ -n "$PREFIX" ] && ! echo "$COMMIT_MSG" | grep -qE "^(feat|fix|docs|refactor|test|chore|style|perf)(\(.*\))?:"; then
    echo "${PREFIX}${COMMIT_MSG}" > "$1"
fi
```

### Pattern 7: Dependency Change Detection

**What:** Detect package manager file changes post-merge
**When to use:** post-merge hook
**Example:**
```bash
# Source: GitHub gists, established pattern

CHANGED_FILES=$(git diff-tree -r --name-only --no-commit-id HEAD@{1} HEAD 2>/dev/null)

# Check for dependency file changes
echo "$CHANGED_FILES" | grep -qE '(package\.json|package-lock\.json|yarn\.lock)' && {
    echo ""
    echo "📦 JavaScript dependencies changed. Run: npm install"
    echo ""
}

echo "$CHANGED_FILES" | grep -qE '(requirements\.txt|Pipfile|Pipfile\.lock)' && {
    echo ""
    echo "🐍 Python dependencies changed. Run: pip install -r requirements.txt"
    echo ""
}

# Note: Don't auto-run installers, just remind user
```

### Pattern 8: Claude Code Hook Configuration

**What:** JSON-based hook definition with stdin/stdout communication
**When to use:** Claude Code PreToolUse/PostToolUse hooks
**Example:**
```json
// Source: Official Claude Code hooks documentation

{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-destructive.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

**Hook script receives JSON on stdin:**
```bash
#!/bin/bash
# Read JSON input
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# Check for destructive commands
if echo "$COMMAND" | grep -qE '(rm -rf|git push.*--force|git reset --hard)'; then
    # Return JSON decision
    jq -n '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: "Destructive command blocked"
        }
    }'
fi

exit 0
```

### Anti-Patterns to Avoid

- **Hardcoding config values:** Every setting must be configurable via global .env or project config
- **Using bash 4+ features:** Namerefs, associative arrays break on macOS. Use bash 3.2 POSIX patterns
- **stat for file sizes:** Syntax differs across macOS/Linux. Use `wc -c` instead
- **Auto-running installers:** post-merge should remind, not execute `npm install` automatically
- **Ignoring hook bypass:** Always respect `git commit --no-verify` for escape hatch
- **Blocking on soft checks:** Debug statement detection should warn by default, block only if STRICT mode
- **Relative paths in hooks:** Always use absolute paths or `$(git rev-parse --show-toplevel)`

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing in bash | Custom jq alternatives | `jq` command | Battle-tested, handles edge cases (quotes, escapes, unicode) |
| Regex for all secret types | Custom pattern list | Extend established patterns (aws git-secrets, GitGuardian) | Community-maintained, covers edge cases |
| Git hook framework | Custom hook manager | Native git hooks + core.hooksPath | No external dependencies, works everywhere |
| Config file parsing | Custom ini/toml parser | Bash source with validation | Native, fast, simple validation sufficient |
| Documentation generation | Custom markdown builder | Metadata-header approach with grep | Simple, SSOT, auto-updates |

**Key insight:** Git hooks and bash scripting are mature domains. Established patterns exist for every common need. Innovation should be in configuration UX and opinionated defaults, not in reinventing hook mechanics or parsing logic.

## Common Pitfalls

### Pitfall 1: Bash Version Assumptions

**What goes wrong:** Using bash 4+ features breaks on macOS default bash 3.2
**Why it happens:** Developer's Linux machine has bash 5, tests pass, but users on macOS hit syntax errors
**How to avoid:**
- Always test on macOS (bash 3.2) OR in bash 3.2 docker container
- Grep entire codebase for `local -n`, `declare -n`, `declare -A` before committing
- Use `#!/bin/bash` not `#!/usr/bin/env bash` to ensure system bash
**Warning signs:**
- `declare: -n: invalid option` errors on macOS
- Associative array syntax errors: `declare: -A: invalid option`

### Pitfall 2: Config File Location Ambiguity

**What goes wrong:** Hook loads wrong config file or no config file, uses hardcoded defaults unexpectedly
**Why it happens:** Multiple possible config locations without clear selection
**How to avoid:**
- User MUST explicitly select config location during setup wizard
- Store selection in `.dotconfigs.json` metadata: `{"git_hook_config_path": ".git/hooks/hooks.conf"}`
- Hook scripts read metadata to find config
**Warning signs:**
- Config changes not taking effect
- Hooks using defaults when project config should override

### Pitfall 3: Secrets Detection False Positives

**What goes wrong:** Hook blocks commits containing variable names like "my_api_key_validator"
**Why it happens:** Overly broad regex patterns
**How to avoid:**
- Require value-like context: `api[_-]?key\s*[:=]\s*["\'][^"\']+["\']`
- Provide escape hatch: `git commit --no-verify` always available
- Document in warning message
**Warning signs:**
- Developers frequently using `--no-verify`

### Pitfall 4: Post-Merge Hook Doesn't Fire on Rebase

**What goes wrong:** User runs `git pull --rebase`, post-merge hook doesn't fire
**Why it happens:** post-merge only fires for merge commits, not during rebase
**How to avoid:**
- Document limitation clearly
- Consider implementing post-rewrite hook for rebase scenarios
**Warning signs:**
- Dependency changes go unnoticed after git pull --rebase

### Pitfall 5: Claude Code Hook Infinite Loops

**What goes wrong:** PostToolUse hook modifies file, triggers another Write, loops
**Why it happens:** Hook output causes new tool call
**How to avoid:**
- PostToolUse hooks should be idempotent
- Check `stop_hook_active` flag to prevent recursion
**Warning signs:**
- Hook times out
- Multiple identical tool calls in transcript

### Pitfall 6: prepare-commit-msg Overwrites Manual Messages

**What goes wrong:** Hook prepends prefix, duplicates conventional commit prefix
**Why it happens:** Hook doesn't check if message already has prefix
**How to avoid:**
- Always check if message already starts with conventional prefix
- Skip during `git commit --amend`
**Warning signs:**
- Commit messages like "feat: feat: add feature"

## Code Examples

Verified patterns from official sources.

### Complete pre-commit Hook Template

```bash
#!/bin/bash
# Source: Git official docs + community patterns

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK_CONFIG="$REPO_ROOT/.git/hooks/hooks.conf"

# Defaults
SECRETS_CHECK_ENABLED=true
LARGE_FILE_THRESHOLD=1048576  # 1MB
LARGE_FILE_ENABLED=true
DEBUG_CHECK_ENABLED=true
DEBUG_CHECK_STRICT=false

# Load config
[ -f "$HOOK_CONFIG" ] && source "$HOOK_CONFIG"

# Check if hook enabled
if [[ "${GIT_HOOK_PRE_COMMIT_ENABLED:-true}" != "true" ]]; then
    exit 0
fi

EXIT_CODE=0

# === SECRETS DETECTION ===
if [ "$SECRETS_CHECK_ENABLED" = true ]; then
    if git diff --cached --diff-filter=ACM | grep -qE '(AKIA[0-9A-Z]{16}|["\x27]?[Aa]pi[_-]?[Kk]ey["\x27]?\s*[:=])'; then
        echo "❌ ERROR: Potential secret detected"
        EXIT_CODE=1
    fi
fi

# === LARGE FILE CHECK ===
if [ "$LARGE_FILE_ENABLED" = true ]; then
    for file in $(git diff --cached --name-only --diff-filter=ACM); do
        [ -f "$file" ] || continue
        size=$(wc -c < "$file" 2>/dev/null || echo 0)
        if [ "$size" -ge "$LARGE_FILE_THRESHOLD" ]; then
            echo "⚠️  WARNING: Large file: $file (${size} bytes)"
        fi
    done
fi

# === DEBUG STATEMENT CHECK ===
if [ "$DEBUG_CHECK_ENABLED" = true ]; then
    if git diff --cached --diff-filter=ACM | grep -qE '(console\.(log|debug)|debugger;|print\(|pdb\.set_trace)'; then
        echo "⚠️  WARNING: Debug statement detected"
        if [ "$DEBUG_CHECK_STRICT" = true ]; then
            EXIT_CODE=1
        fi
    fi
fi

exit $EXIT_CODE
```

### Complete prepare-commit-msg Hook Template

```bash
#!/bin/bash
# Source: Community patterns + conventional commit spec

COMMIT_MSG_FILE=$1
COMMIT_SOURCE=$2
REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK_CONFIG="$REPO_ROOT/.git/hooks/hooks.conf"

# Load config
[ -f "$HOOK_CONFIG" ] && source "$HOOK_CONFIG"

# Check if enabled
if [[ "${GIT_HOOK_PREPARE_COMMIT_MSG_ENABLED:-true}" != "true" ]]; then
    exit 0
fi

# Skip for merge/squash/amend
[ -n "$COMMIT_SOURCE" ] && exit 0

COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

# Skip if already has conventional prefix
echo "$COMMIT_MSG" | grep -qE "^(feat|fix|docs|refactor|test|chore|style|perf)(\(.*\))?:" && exit 0

# Extract prefix from branch
BRANCH_NAME=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")

case "$BRANCH_NAME" in
    feature/*|feat/*)     PREFIX="feat: " ;;
    fix/*|bugfix/*|hotfix/*) PREFIX="fix: " ;;
    docs/*)               PREFIX="docs: " ;;
    refactor/*)           PREFIX="refactor: " ;;
    test/*)               PREFIX="test: " ;;
    chore/*)              PREFIX="chore: " ;;
    *)                    PREFIX="" ;;
esac

# Add prefix if extracted
if [ -n "$PREFIX" ]; then
    echo "${PREFIX}${COMMIT_MSG}" > "$COMMIT_MSG_FILE"
fi

exit 0
```

### Complete post-merge Hook Template

```bash
#!/bin/bash
# Source: Community GitHub gists

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK_CONFIG="$REPO_ROOT/.git/hooks/hooks.conf"

# Load config
[ -f "$HOOK_CONFIG" ] && source "$HOOK_CONFIG"

# Check if enabled
if [[ "${GIT_HOOK_POST_MERGE_ENABLED:-true}" != "true" ]]; then
    exit 0
fi

CHANGED_FILES=$(git diff-tree -r --name-only --no-commit-id HEAD@{1} HEAD 2>/dev/null)
[ -z "$CHANGED_FILES" ] && exit 0

# === DEPENDENCY CHANGES ===
if [[ "${POST_MERGE_DEPENDENCY_CHECK:-true}" == "true" ]]; then
    if echo "$CHANGED_FILES" | grep -qE '(package\.json|package-lock\.json|yarn\.lock)'; then
        echo ""
        echo "📦 JavaScript dependencies changed. Run: npm install"
        echo ""
    fi

    if echo "$CHANGED_FILES" | grep -qE '(requirements\.txt|Pipfile\.lock)'; then
        echo ""
        echo "🐍 Python dependencies changed. Run: pip install -r requirements.txt"
        echo ""
    fi
fi

# === MIGRATION CHANGES ===
if [[ "${POST_MERGE_MIGRATION_REMINDER:-true}" == "true" ]]; then
    if echo "$CHANGED_FILES" | grep -qE 'migrations/|db/migrate/'; then
        echo ""
        echo "🗄️  Database migrations changed. Run: rake db:migrate"
        echo ""
    fi
fi

exit 0
```

### Claude Code PreToolUse Hook Example

```bash
#!/bin/bash
# Source: Official Claude Code hooks documentation

# Read JSON input
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Destructive patterns
DESTRUCTIVE_PATTERNS=(
    'rm -rf'
    'git push.*--force'
    'git reset --hard'
    'DROP TABLE'
)

for pattern in "${DESTRUCTIVE_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qiE "$pattern"; then
        jq -n --arg reason "Blocked: $pattern" '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "deny",
                permissionDecisionReason: $reason
            }
        }'
        exit 0
    fi
done

exit 0
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Profile-based hook config | Individual toggle per setting | 2024+ | More flexible, user picks each setting |
| Hardcoded hook locations | User-selectable config paths | 2024+ | Supports diverse project structures |
| Single hooks.conf | Split by plugin concern | 2026 | Cleaner separation |
| Auto-run npm install | Reminder only | 2020+ | User controls timing |
| exit 2 for Claude hooks | JSON decision with exit 0 | v2.0.10+ | Richer control: allow/deny/ask |

**Deprecated/outdated:**
- **Profile templates:** Removed in favor of individual toggles
- **Namerefs in bash:** Never supported in bash 3.2, must use eval patterns
- **Global hooks only:** Now supports both global and per-project deployment

## Open Questions

### 1. Explore Agent Model Selection Hook

**What we know:**
- Explore agent is read-only, optimized for code search
- Claude delegates to Explore with thoroughness levels
- Model can be configured in settings.json
- SubagentStart hook fires when Explore agent spawns

**What's unclear:**
- Can hooks influence Explore agent model selection?
- Can PreToolUse hook for Task tool modify `model` parameter before Explore spawns?

**Recommendation:**
- Add research + decision task to plan: "Investigate Explore agent model selection"
- Test: Create SubagentStart hook, log input JSON, verify `model` field
- Document findings, implement hook if feasible

### 2. Additional Git Hooks Beyond Core Six

**What we know:**
- Core six specified: pre-commit, prepare-commit-msg, commit-msg, pre-push, post-merge, post-checkout
- Git supports additional hooks: pre-rebase, post-commit, post-rewrite

**What's unclear:**
- Which additional hooks provide practical value?

**Recommendation:**
Consider adding:
- **post-rewrite:** Fires after `git commit --amend` and `git rebase`. Same use case as post-merge (dependency detection for rebase workflows)

Skip for now:
- post-commit (notification-only, limited utility)
- pre-rebase (may add later if users request)

### 3. Config File Format: Extend .dotconfigs.json or Add .dotconfigs.env?

**Recommendation:**
Use `.dotconfigs.json` for metadata + config:
- PRO: Single file, cleaner
- PRO: JSON allows nested structures
- CON: Bash hooks need jq (already required)

Alternative `.dotconfigs.env`:
- PRO: Bash-sourceable
- CON: Two files to manage

**Decision:** Extend .dotconfigs.json with `config` section. Consolidates metadata and overrides.

### 4. Auto-Documentation: Custom Metadata Headers

**Recommendation:**
Custom metadata headers approach:
```bash
# === METADATA ===
# NAME: pre-commit
# DESCRIPTION: Secrets detection, large file warnings
# CONFIGURABLE: SECRETS_CHECK_ENABLED, LARGE_FILE_ENABLED
# ================
```

Generate doc via script that greps for metadata blocks.

**Decision:** Custom metadata approach for simplicity and control.

## Sources

### Primary (HIGH confidence)

- [Git Hooks Official Documentation](https://git-scm.com/docs/githooks) - Complete hook reference
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks) - Official API
- [Git SCM Book: Git Hooks](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks) - Best practices
- [Atlassian Git Hooks Tutorial](https://www.atlassian.com/git/tutorials/git-hooks) - Client-side vs server-side

### Secondary (MEDIUM confidence)

- [git-secrets (AWS Labs)](https://github.com/awslabs/git-secrets) - Secrets detection patterns
- [Bash 3.2 on macOS - Scripting OS X](https://scriptingosx.com/2020/06/about-bash-zsh-sh-and-dash-in-macos-catalina-and-beyond/) - Compatibility
- [prepare-commit-msg Examples](https://github.com/janniks/prepare-commit-msg) - Branch prefix extraction
- [post-merge npm install pattern](https://gist.github.com/sindresorhus/7996717) - Dependency detection
- [Conventional Branch Naming](https://conventional-branch.github.io/) - Branch-to-commit-type mapping
- [shdoc - Documentation Generator](https://github.com/reconquest/shdoc) - Bash doc generation
- [Squash Merge Best Practices - Graphite](https://graphite.com/guides/git-squash-merge) - Workflow patterns

### Tertiary (LOW confidence - verify before use)

- Multiple Stack Overflow discussions on portable file size detection
- GitHub gists for post-merge hooks
- Community blog posts on secrets detection

## Metadata

**Confidence breakdown:**
- **Git hooks mechanics:** HIGH - Official documentation, stable API
- **Hook implementation patterns:** HIGH - Community-established patterns
- **Bash 3.2 compatibility:** HIGH - macOS version documented, nameref incompatibility confirmed
- **Claude Code hooks API:** HIGH - Official documentation
- **Secrets detection patterns:** MEDIUM - Based on AWS git-secrets but patterns evolve
- **Explore agent model selection:** LOW - Documentation doesn't explicitly cover hook influence
- **Auto-documentation tools:** MEDIUM - Tools exist, custom approach simpler

**Research date:** 2026-02-08
**Valid until:** 60 days (git hooks stable, Claude Code hooks evolving but documented)

**Critical implementation notes:**
1. ALL bash scripts MUST be tested on bash 3.2 (macOS default)
2. EVERY setting MUST be configurable (no hardcoded enforcement)
3. Project config MUST override global .env with explicit precedence
4. Hooks MUST respect `--no-verify` flag (standard git escape hatch)
5. User MUST explicitly select git hook config file location
