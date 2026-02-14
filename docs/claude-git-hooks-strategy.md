# Optimal .claude & .git Configuration Strategy

**Goal**: Maximize efficiency & robustness while minimizing token/time overhead. Per-project configuration, not version controlled.

---

## Research Summary: Claude Code Hooks Best Practices

Based on [Claude Code documentation](https://code.claude.com/docs/en/hooks-guide) and [community best practices](https://www.eesel.ai/blog/hooks-in-claude-code):

### Performance Targets
- **PreToolUse**: < 100ms (blocking, runs before every tool)
- **PostToolUse**: < 500ms (non-blocking, runs after tool completes)
- **Heavy operations**: Use `async: true` or run in background

### Hook Scope Options
1. **User-wide**: `~/.claude/settings.json` - applies to ALL projects
2. **Project-specific**: `.claude/settings.json` - shareable via version control
3. **Local overrides**: `.claude/settings.local.json` - personal tweaks not committed

### Key Trade-offs
- **PreToolUse**: Blocking → slows down every tool call, but can prevent bad actions
- **PostToolUse**: Non-blocking → but can't undo actions, only cleanup
- **Async hooks**: Fast but results not available to Claude

---

## Questions to Clarify Your Workflow

### 1. Project Types & Frequency
- What types of projects do you work on most? (Python, JS/TS, multi-language, etc.)
- Roughly what % of your projects are:
  - Pure Python?
  - Pure JS/TS?
  - Mixed/polyglot?
  - Non-code (docs, configs, etc.)?

### 2. Current Pain Points
- Which hooks currently slow you down? (identity check, AI attribution, Ruff formatting, block-destructive?)
- Are there operations where you feel over-protected? (e.g., blocking destructive operations you actually want?)
- Are there gaps where Claude does something you wish was prevented/validated?

### 3. Git Workflow
- Do you use feature branches + squash merge consistently?
- How often do you commit? (every few changes, end of session, etc.)
- Do you ever work on shared repos where hooks should be different?

### 4. Formatting & Linting Preferences
- Ruff formatting: Do you want it on EVERY commit, or only when you explicitly request it?
- Would you prefer formatting to happen:
  - During Claude's work (PostToolUse) - instant feedback but slower
  - On commit (git pre-commit) - faster development but deferred
  - On demand only (manual/skill) - maximum control
- Other tools you use? (eslint, prettier, mypy, etc.)

### 5. Security & Safety
- Identity check: Must this be enforced on every commit, or just as a backstop?
- Block destructive operations: What operations SHOULD be blocked vs just warned?
- AI attribution blocking: Is this critical or nice-to-have?

### 6. Token/Time Budget
- Roughly how many tool calls happen in a typical Claude session for you?
- What's your tolerance for slowdown per tool call? (50ms? 100ms? 500ms?)
- Would you rather have:
  - Maximum safety (slower but more validation)
  - Maximum speed (faster but less handholding)
  - Balanced (smart validation only where it matters)

---

## Initial Architecture Hypothesis

### User-Wide (Global) Configs
**Should contain**: Universal policies that NEVER change across projects
- Security/safety (block obviously destructive operations)
- Logging/telemetry (if desired)
- Core identity enforcement (if applicable)

**Should NOT contain**: Tooling that varies by project (formatters, linters, test runners)

### Git Hooks (.git/hooks/)
**Should contain**: Commit-time validation and formatting
- Identity verification (pre-commit)
- AI attribution blocking (commit-msg)
- Code formatting (pre-commit, project-specific)
- Tests (pre-push, optional per project)

**Rationale**: Runs once per commit, not on every file edit. More efficient for formatters.

### Claude Code Hooks (.claude/settings.json)
**Should contain**: Runtime validation that needs immediate feedback
- Block TRULY destructive operations (rm -rf, force push to main, etc.)
- Logging/analytics (async)
- Dynamic tool input modification (if needed)

**Should NOT contain**: Formatters (too slow, better in git hooks)

### Project-Specific (.claude/settings.local.json)
**Should contain**: Per-project overrides
- Project-specific tool permissions
- Custom validation rules for specific codebases
- Development mode toggles (disable certain checks during prototyping)

---

## Your Workflow Requirements (Answered)

✅ **Project types**: 80% Python, 15% bash, 5% other
✅ **Commit frequency**: Frequent atomic commits on branches, squash merge to main
✅ **Formatting requirements**:
   - Branch commits: Can be unformatted (speed priority)
   - Main commits: Must be formatted (strict validation)
   - Collaborator projects: Specific per-project requirements
✅ **Speed vs safety**: Max speed during active dev, strict validation on merge to main

---

## Recommended Optimal Architecture

### 🚀 PRINCIPLE: "Fast on branches, strict on main, minimal overhead everywhere"

Based on [git hooks best practices](https://devtoolbox.dedyn.io/blog/git-hooks-complete-guide) and [Claude Code performance optimization](https://medium.com/@terrycho/best-practices-for-maximizing-claude-code-performance-f2d049579563):

---

## 1. Claude Code Hooks (MINIMAL - Only Critical Blocking)

**Location**: `~/.claude/settings.json` (user-wide)

**Philosophy**: Use ONLY for operations that:
- Must block 100% of the time (zero exceptions)
- Cannot be undone after execution
- Are truly catastrophic if executed

### Recommended Claude Hooks:

#### PreToolUse: Block Catastrophic Operations
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
            "timeout": 10,
            "async": false  // MUST block
          }
        ]
      }
    ]
  }
}
```

**What to block**:
- `rm -rf /` or similar filesystem destruction
- Force push to main/master
- Deletion of critical files (.env, credentials, etc.)
- Operations outside project directory

**What NOT to block** (move to git hooks or remove):
- Formatting (too slow, happens every edit)
- Identity checks (belongs in git hooks)
- Linting (move to CI or git pre-push)

#### Optional: Async Logging (if desired)
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/log-changes.sh",
            "timeout": 5,
            "async": true  // Non-blocking
          }
        ]
      }
    ]
  }
}
```

**Performance target**: < 50ms for PreToolUse (critical path)

---

## 2. Git Hooks (BRANCH-AWARE - Smart Validation)

**Location**: `.git/hooks/` per project (install from templates)

### Pre-commit Hook (Branch-Aware)

**Key innovation**: Different rules for branches vs main ([source](https://thelinuxcode.com/how-to-skip-git-commit-hooks-safely-in-2026/))

```bash
#!/usr/bin/env bash
# Branch-aware pre-commit hook

BRANCH=$(git rev-parse --abbrev-ref HEAD)

# ALWAYS RUN: Identity check (fast, ~10ms)
# ... identity validation ...

# CONDITIONALLY RUN: Formatting based on branch
if [[ "$BRANCH" == "main" ]] || [[ "$BRANCH" == "master" ]]; then
    # Strict validation on main
    echo "🔒 Main branch - running full validation..."
    # Run Ruff format + check
    # Run mypy (if configured)
    # Block if any issues
elif [[ "$BRANCH" == feature/* ]] || [[ "$BRANCH" == fix/* ]]; then
    # Fast validation on feature branches
    echo "⚡ Feature branch - minimal validation..."
    # Optional: Run Ruff format but don't block
    # Or: Skip entirely for speed
fi

# Source project-specific hook if exists
if [ -x .git/hooks/pre-commit.local ]; then
    .git/hooks/pre-commit.local
fi
```

**Performance target**:
- Feature branches: < 100ms (identity only)
- Main branch: < 500ms (full validation acceptable)

### Commit-msg Hook (Always Run)

```bash
#!/usr/bin/env bash
# Block AI attribution (fast, ~5ms)

# ... AI attribution check ...

# Source project-specific hook
if [ -x .git/hooks/commit-msg.local ]; then
    .git/hooks/commit-msg.local "$1"
fi
```

**Performance target**: < 50ms

### Pre-push Hook (Main Protection)

**NEW RECOMMENDATION**: Add pre-push hook for main branch ([source](https://git-scm.com/docs/githooks))

```bash
#!/usr/bin/env bash
# Pre-push hook - strict validation before pushing to main

while read local_ref local_oid remote_ref remote_oid; do
    # Check if pushing to main/master
    if [[ "$remote_ref" =~ refs/heads/(main|master) ]]; then
        echo "🔒 Pushing to main - running full validation..."

        # Run full test suite
        pytest || exit 1

        # Run Ruff check (not format, just validate)
        ruff check . || exit 1

        # Run mypy
        mypy . || exit 1

        echo "✅ All checks passed"
    fi
done

exit 0
```

**Performance target**: Can be slower (1-5s), runs infrequently

---

## 3. Project-Specific Configuration

**Location**: `.claude/settings.local.json` (gitignored, per-project)

### Use cases:
- Collaborator projects with specific requirements
- Projects using different formatters (black instead of ruff)
- Projects needing extra validation
- Development mode (disable checks temporarily)

### Example: Python project with extra validation
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash(pytest:*)",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/check-test-coverage.sh",
            "timeout": 30,
            "async": false
          }
        ]
      }
    ]
  }
}
```

### Example: Development mode toggle
```json
{
  "env": {
    "CLAUDE_DEV_MODE": "true"  // Skip heavy validations
  }
}
```

---

## 4. Hook Templates (Reusable Across Projects)

**Location**: `~/.claude/hooks/templates/`

### Template Strategy:

1. **pre-commit-python-fast** (feature branches)
   - Identity check only
   - ~50ms

2. **pre-commit-python-strict** (main branch)
   - Identity + Ruff format + Ruff check
   - ~300ms

3. **pre-commit-bash** (bash projects)
   - Identity + shellcheck
   - ~100ms

4. **pre-push-python-main** (main protection)
   - Full test suite
   - Full linting
   - Type checking
   - Can be slow (1-5s)

5. **commit-msg-standard** (all projects)
   - AI attribution blocking
   - ~5ms

---

## 5. Performance Budget & Measurements

| Hook Type | Location | When | Target | Max | Notes |
|-----------|----------|------|--------|-----|-------|
| PreToolUse (destructive block) | Claude | Every Bash call | < 50ms | 100ms | Critical path |
| PostToolUse (logging) | Claude | Every Write/Edit | N/A | N/A | Must be async |
| Pre-commit (branch) | Git | Every commit | < 100ms | 200ms | Identity only |
| Pre-commit (main) | Git | Main commits | < 500ms | 1s | Full validation |
| Commit-msg | Git | Every commit | < 50ms | 100ms | Fast check |
| Pre-push (main) | Git | Push to main | < 5s | 30s | Can be slow |

### Measurement Strategy:
```bash
# Add to hooks for performance tracking
START=$(date +%s%N)
# ... hook logic ...
END=$(date +%s%N)
DURATION=$(( ($END - $START) / 1000000 ))
echo "⏱️  Hook took ${DURATION}ms"
```

---

## 6. Migration Plan: Current → Optimal

### Current State Analysis:

| Hook | Current Location | Issue | Recommendation |
|------|------------------|-------|----------------|
| Ruff format | PostToolUse (Claude) | Runs every edit, slow | → Git pre-commit (main only) |
| Identity check | ~/githooks/pre-commit | Not enabled (no core.hooksPath) | → Git .git/hooks/pre-commit (per project) |
| AI attribution | ~/githooks/commit-msg | Not enabled | → Git .git/hooks/commit-msg (per project) |
| Block destructive | PreToolUse (Claude) | Good! | ✅ Keep as-is |

### What to Change:

1. **REMOVE**: `post-tool-format.py` from Claude hooks
   - ❌ Runs on every Write/Edit (dozens per session)
   - ✅ Move to git pre-commit (once per commit)
   - **Token savings**: ~50-100 per session

2. **MODIFY**: Git hooks to be branch-aware
   - ✅ Add branch detection logic
   - ✅ Skip formatting on feature branches
   - ✅ Strict validation on main

3. **ADD**: Pre-push hook for main protection
   - ✅ Final gate before main
   - ✅ Run full test suite
   - ✅ Validate format/lint/types

4. **KEEP**: Block-destructive Claude hook
   - ✅ Already minimal and fast
   - ✅ Only blocks truly catastrophic operations

---

## 7. Recommended Hook Content

### Minimal Destructive Block (Claude PreToolUse)
**File**: `~/.claude/hooks/block-destructive.sh`
**Purpose**: Block only truly catastrophic operations
**Performance**: < 50ms

```bash
#!/usr/bin/env bash
# Minimal destructive operation blocker

# Read stdin JSON
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Block patterns (very minimal list)
BLOCK_PATTERNS=(
    "rm -rf /"
    "rm -rf ~"
    "rm -rf \$HOME"
    "git push.*--force.*origin.*(main|master)"
    "git reset --hard origin/(main|master)"
)

for pattern in "${BLOCK_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qE "$pattern"; then
        echo "❌ BLOCKED: Catastrophic operation detected: $pattern" >&2
        exit 2  # Exit 2 = block execution
    fi
done

exit 0  # Allow execution
```

### Branch-Aware Pre-commit (Git)
**File**: `~/.claude/hooks/templates/pre-commit-python-branch-aware`
**Purpose**: Fast on branches, strict on main

```bash
#!/usr/bin/env bash
set -e

BRANCH=$(git rev-parse --abbrev-ref HEAD)
START=$(date +%s%N)

# ALWAYS: Identity check (fast)
EXPECTED_NAME="henrycgbaker"
EXPECTED_EMAIL="henry.c.g.baker@gmail.com"
ACTUAL_NAME=$(git config user.name)
ACTUAL_EMAIL=$(git config user.email)

if [ "$ACTUAL_NAME" != "$EXPECTED_NAME" ] || [ "$ACTUAL_EMAIL" != "$EXPECTED_EMAIL" ]; then
    echo "❌ ERROR: Git identity mismatch"
    echo "Expected: $EXPECTED_NAME <$EXPECTED_EMAIL>"
    echo "Actual: $ACTUAL_NAME <$ACTUAL_EMAIL>"
    exit 1
fi

# CONDITIONAL: Formatting based on branch
if [[ "$BRANCH" == "main" ]] || [[ "$BRANCH" == "master" ]]; then
    echo "🔒 Main branch - formatting required"

    STAGED_PY=$(git diff --cached --name-only --diff-filter=ACM | grep '\.py$' || true)
    if [ -n "$STAGED_PY" ] && command -v ruff &> /dev/null; then
        for file in $STAGED_PY; do
            [ -f "$file" ] && ruff format "$file" && ruff check --fix "$file" && git add "$file"
        done
    fi
else
    echo "⚡ Feature branch - skipping format (use 'ruff format .' manually if needed)"
fi

# Project-specific hook
[ -x .git/hooks/pre-commit.local ] && .git/hooks/pre-commit.local

END=$(date +%s%N)
echo "⏱️  Pre-commit: $(( ($END - $START) / 1000000 ))ms"
exit 0
```

### Main Protection Pre-push (Git)
**File**: `~/.claude/hooks/templates/pre-push-python-main`
**Purpose**: Final validation before main

```bash
#!/usr/bin/env bash
set -e

while read local_ref local_oid remote_ref remote_oid; do
    if [[ "$remote_ref" =~ refs/heads/(main|master) ]]; then
        echo "🔒 Validating push to main..."
        START=$(date +%s%N)

        # Full validation suite
        echo "  → Running tests..."
        pytest -x || { echo "❌ Tests failed"; exit 1; }

        echo "  → Checking format..."
        ruff check . || { echo "❌ Lint failed"; exit 1; }

        if command -v mypy &> /dev/null; then
            echo "  → Type checking..."
            mypy . || { echo "❌ Type check failed"; exit 1; }
        fi

        END=$(date +%s%N)
        echo "✅ All checks passed ($(( ($END - $START) / 1000000 ))ms)"
    fi
done

exit 0
```

---

## 8. Decision Tree: Where Does This Hook Belong?

```
Is this hook validation or an action?
│
├─ VALIDATION (checking/blocking)
│  │
│  ├─ Must block 100% of time, catastrophic if executed?
│  │  └─ YES → Claude PreToolUse hook (user-wide)
│  │  └─ NO → Continue...
│  │
│  ├─ Related to commit/push?
│  │  └─ YES → Git hook (per-project)
│  │     ├─ Every commit? → pre-commit
│  │     ├─ Every push? → pre-push
│  │     └─ Commit message? → commit-msg
│  │  └─ NO → Probably don't need it
│  │
│  └─ Different rules per branch?
│     └─ YES → Branch-aware git hook
│
├─ ACTION (formatting, logging, etc.)
│  │
│  ├─ Must happen every edit?
│  │  └─ NO → Git pre-commit (defer to commit time)
│  │  └─ YES → Consider if you really need this
│  │
│  ├─ Can be async/non-blocking?
│  │  └─ YES → Claude PostToolUse (async: true)
│  │  └─ NO → Git hook or manual action
│  │
│  └─ Different per project?
│     └─ YES → .claude/settings.local.json
│     └─ NO → User-wide template
```

---

## 9. Project-Type Specific Recommendations

### 80% Python Projects (Your Primary Use Case)

**Branch work** (fast):
```bash
# .git/hooks/pre-commit
- Identity check (10ms)
- Skip formatting
Total: ~20ms per commit
```

**Main branch** (strict):
```bash
# .git/hooks/pre-commit
- Identity check (10ms)
- Ruff format (200ms)
- Ruff check (100ms)
Total: ~310ms per commit

# .git/hooks/pre-push (to main)
- pytest (2s)
- ruff check (100ms)
- mypy (1s)
Total: ~3.1s per push (acceptable, infrequent)
```

### 15% Bash Projects

**All branches**:
```bash
# .git/hooks/pre-commit
- Identity check (10ms)
- shellcheck (50ms) - optional, can skip on branches
Total: ~60ms per commit
```

### 5% Other Projects

**Minimal validation**:
```bash
# .git/hooks/pre-commit
- Identity check (10ms)
Total: ~10ms per commit
```

---

## 10. Collaboration Workflow (Per-Project Overrides)

### Solo Projects (Your Default)
- Fast branch work, strict main
- Templates from `~/.claude/hooks/templates/`
- No version control of hooks

### Collaborator Projects (Special Cases)

**Option A**: Version-controlled hooks (team standard)
```bash
# Repo root: .githooks/
# Team shares: pre-commit, commit-msg, pre-push
# Each dev: git config core.hooksPath .githooks
```

**Option B**: Per-project Claude config
```bash
# .claude/settings.local.json (gitignored)
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash(git:push*main)",
        "hooks": [{
          "type": "command",
          "command": ".claude/hooks/team-validation.sh",
          "timeout": 60
        }]
      }
    ]
  }
}
```

---

## 11. Implementation Priority

### Phase 1: Remove Overhead (Immediate - Do First)
1. ✅ Remove `post-tool-format.py` from Claude settings.json
2. ✅ Remove formatting from PostToolUse hooks
3. **Token savings**: ~50-100 per session
4. **Time savings**: ~5-10s per session

### Phase 2: Branch-Aware Git Hooks (Core Workflow)
1. ✅ Create branch-aware pre-commit template
2. ✅ Install in dotconfigs repo (your SSOT)
3. ✅ Test on feature branch (should be fast)
4. ✅ Test commit to main (should format)
5. **Time impact**: +100ms per branch commit, +300ms per main commit

### Phase 3: Main Protection (Safety Gate)
1. ✅ Create pre-push template for main
2. ✅ Install in active Python projects
3. ✅ Test push to main (should run tests)
4. **Time impact**: +3s per push to main (acceptable, infrequent)

### Phase 4: Project Templates (Reusability)
1. ✅ Create template library in `~/.claude/hooks/templates/`
2. ✅ Document installation process
3. ✅ Add to dotconfigs SSOT registry
4. **Benefit**: Easy setup for new projects

### Phase 5: Per-Project Overrides (Advanced)
1. ✅ Create `.claude/settings.local.json` examples
2. ✅ Document collaboration patterns
3. ✅ Add to CLAUDE.md in projects
4. **Benefit**: Flexibility for special cases

---

## 12. Metrics & Success Criteria

### Performance Metrics (Measure These)

**Before Optimization** (Current State):
- PostToolUse formatting: ~200ms per file edit
- Typical session: 50 file edits = 10s total overhead
- Token usage: High (multiple format runs per session)

**After Optimization** (Target):
- Branch commits: < 100ms per commit (identity only)
- Main commits: < 500ms per commit (format included)
- Pre-push to main: < 5s (full validation)
- Token savings: ~50-100 per session

### Success Criteria:
- ✅ Branch work feels fast (< 100ms overhead)
- ✅ Main commits are validated (format enforced)
- ✅ Push to main has full quality gates
- ✅ No catastrophic operations possible (Claude hook blocks)
- ✅ Per-project overrides work (collaboration)

---

## 13. Dotconfigs SSOT Integration Plan

### Registry Structure (For Later Implementation)

```
dotconfigs/
├── plugins/
│   └── claude/
│       └── hooks/
│           ├── block-destructive.sh (Claude PreToolUse)
│           └── templates/
│               ├── git-pre-commit-python-branch-aware
│               ├── git-pre-commit-bash
│               ├── git-pre-push-python-main
│               └── git-commit-msg-standard
├── config/
│   └── claude/
│       ├── settings.json (base config)
│       └── README.md (installation guide)
└── docs/
    └── claude-git-hooks-strategy.md (this document)
```

### Deployment Strategy:
1. Templates in dotconfigs (SSOT)
2. Symlink to `~/.claude/hooks/` (user-wide)
3. Copy to `.git/hooks/` per project (project-specific)
4. Override with `.claude/settings.local.json` (per-project custom)

---

## 14. Final Architecture Summary

### Claude Code Hooks (Minimal)
- **PreToolUse**: Block catastrophic operations only (~50ms)
- **PostToolUse**: Optional async logging (non-blocking)
- **Location**: `~/.claude/settings.json`
- **Philosophy**: Zero-exception rules only

### Git Hooks (Branch-Aware)
- **Pre-commit**: Identity always, format on main only (100-500ms)
- **Commit-msg**: AI attribution blocking always (~5ms)
- **Pre-push**: Full validation when pushing to main (~3s)
- **Location**: `.git/hooks/` per project
- **Philosophy**: Fast on branches, strict on main

### Project Overrides
- **Location**: `.claude/settings.local.json` (gitignored)
- **Purpose**: Collaboration requirements, special validation
- **Philosophy**: Per-project flexibility

### Performance Budget
- Branch commits: ~100ms (fast iteration)
- Main commits: ~500ms (acceptable validation)
- Push to main: ~3s (infrequent, comprehensive)
- Claude overhead: ~50ms per Bash call (minimal)

---

## Questions & Next Steps

### Answers to Remaining Questions:

#### 1. Async logging: **No** ✅
- User decision: Not needed
- Rationale: Adds overhead without clear benefit

#### 2. Pre-push scope: **All pushes the same** ✅
- User decision: No differential validation by branch
- Rationale: Simpler, consistent validation before any remote push

#### 3. Mypy: **Pre-push only** ✅ (Recommended)
- Research basis: [Mypy does whole-program analysis](https://github.com/python/mypy/issues/13916), so running on changed files only saves no time
- Performance: Slower check (~1-2s for medium projects)
- Recommendation: **Pre-push hook** - comprehensive validation before remote, doesn't slow down commits
- Alternative: CI only (if pre-push feels too slow)

#### 4. Test coverage: **Pre-push only (optional)** ✅ (Recommended)
- Research basis: [pytest with coverage is slow](https://medium.com/@fistralpro/pytest-pre-commit-hook-b492edd0560e) and [problematic in pre-commit](https://github.com/pytest-dev/pytest/discussions/7793)
- Performance: Very slow (2-10s depending on suite size)
- Recommendation: **Pre-push hook with optional flag** - run full suite before remote push, but allow `--no-verify` for WIP pushes
- Best practice: [Enforce in CI](https://docs.pytest.org/en/4.6.x/contributing.html) as final gate, pre-push is developer convenience

### Implementation Status:
- ✅ Research completed
- ✅ Architecture designed
- ✅ Performance budgets defined
- ✅ All questions answered
- ⏳ Ready for additional configs exploration

---

## 15. Additional Hooks & Configs to Consider

Based on [advanced git hooks best practices](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks) and [Claude Code hackathon configs](https://github.com/affaan-m/everything-claude-code):

### Additional Git Hooks Worth Considering

#### post-merge (After `git pull`)
**Use case**: Auto-update dependencies after pulling changes

```bash
#!/usr/bin/env bash
# .git/hooks/post-merge

# Check if requirements changed
if git diff-tree -r --name-only --no-commit-id ORIG_HEAD HEAD | grep --quiet "requirements.txt\|pyproject.toml"; then
    echo "📦 Dependencies changed - updating..."
    pip install -r requirements.txt
fi

# Check if package-lock changed (for mixed projects)
if git diff-tree -r --name-only --no-commit-id ORIG_HEAD HEAD | grep --quiet "package-lock.json"; then
    echo "📦 npm dependencies changed - updating..."
    npm ci
fi
```

**Performance**: ~5-10s when triggered (infrequent)
**Value**: High - prevents "works on my machine" issues

#### prepare-commit-msg (Before commit message editor)
**Use case**: Auto-generate commit message template from branch name

```bash
#!/usr/bin/env bash
# .git/hooks/prepare-commit-msg

COMMIT_MSG_FILE=$1
COMMIT_SOURCE=$2

# Only for regular commits (not merge, squash, etc.)
if [ "$COMMIT_SOURCE" = "" ]; then
    BRANCH=$(git rev-parse --abbrev-ref HEAD)

    # Extract ticket number from branch (e.g., feature/PROJ-123-description)
    if [[ $BRANCH =~ (feature|fix|refactor)/([A-Z]+-[0-9]+) ]]; then
        TICKET="${BASH_REMATCH[2]}"
        # Prepend ticket to commit message
        echo "$TICKET: $(cat $COMMIT_MSG_FILE)" > $COMMIT_MSG_FILE
    fi
fi
```

**Performance**: < 10ms
**Value**: Medium - automates ticket linking

#### post-checkout (After `git checkout`)
**Use case**: Clean build artifacts, update dependencies

```bash
#!/usr/bin/env bash
# .git/hooks/post-checkout

PREV_HEAD=$1
NEW_HEAD=$2
BRANCH_SWITCH=$3

# Only on branch switch (not file checkout)
if [ "$BRANCH_SWITCH" = "1" ]; then
    echo "🧹 Cleaning Python cache..."
    find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
    find . -type f -name "*.pyc" -delete 2>/dev/null || true

    # Optional: Show what changed
    echo "📝 Changes in this branch:"
    git log --oneline $PREV_HEAD..$NEW_HEAD | head -5
fi
```

**Performance**: ~100ms
**Value**: Medium - keeps workspace clean

#### pre-rebase (Before rebase)
**Use case**: Prevent rebasing commits that have been pushed

```bash
#!/usr/bin/env bash
# .git/hooks/pre-rebase

# Prevent rebasing commits on main/master
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$BRANCH" == "main" ]] || [[ "$BRANCH" == "master" ]]; then
    echo "❌ ERROR: Cannot rebase main/master branch"
    exit 1
fi

# Check if commits have been pushed
UPSTREAM=$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null)
if [ -n "$UPSTREAM" ]; then
    UNPUSHED=$(git log $UPSTREAM..HEAD --oneline | wc -l)
    TOTAL=$(git log HEAD --oneline | wc -l)

    if [ "$UNPUSHED" -lt "$TOTAL" ]; then
        echo "⚠️  WARNING: Some commits have been pushed to remote"
        echo "Rebasing public history is dangerous!"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi
```

**Performance**: ~50ms
**Value**: High - prevents git history disasters

### Additional Claude Code Configurations

Based on [Claude Code best practices](https://www.eesel.ai/blog/hooks-in-claude-code) and [hackathon winning configs](https://blog.devgenius.io/the-claude-code-setup-that-won-a-hackathon-a75a161cd41c):

#### Stop Hook (Code Review Before Return)
**Use case**: Automatic code review after Claude completes tasks

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "agent",
            "prompt": "Review the changes made in this session. Check for:\n- Security vulnerabilities\n- Code quality issues\n- Missing tests\n- Documentation gaps\nProvide a brief summary.",
            "timeout": 60,
            "async": false
          }
        ]
      }
    ]
  }
}
```

**Performance**: ~5-10s (runs once at session end)
**Value**: High - catches issues before you review

#### PreCompact Hook (Backup Before Context Compression)
**Use case**: Backup session state before Claude compresses conversation

```json
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/backup-session.sh",
            "timeout": 10,
            "async": true
          }
        ]
      }
    ]
  }
}
```

**Performance**: Async (non-blocking)
**Value**: Medium - safety net for long sessions

#### Project-Specific Skills
**Use case**: Custom workflows for your common tasks

Example skill for your workflow:
```yaml
# ~/.claude/skills/quick-test/SKILL.md
name: quick-test
description: Run tests for changed files only

Usage: /quick-test

This skill:
1. Detects changed Python files
2. Finds associated test files
3. Runs only relevant tests (fast iteration)
```

**Value**: High - speeds up common workflows

#### CLAUDE.md Project Instructions
**Use case**: Per-project coding standards and context

```markdown
# .claude/CLAUDE.md (in each project)

## Project: MyApp

### Architecture
- FastAPI backend
- SQLAlchemy ORM
- Async/await patterns throughout

### Coding Standards
- All endpoints must have docstrings
- Database queries go in repositories (not endpoints)
- Use Pydantic models for validation

### Testing Requirements
- Unit tests for business logic
- Integration tests for API endpoints
- Minimum 80% coverage on new code

### Common Commands
- Run tests: `pytest -v`
- Run specific test: `pytest tests/test_api.py::test_create_user`
- Local server: `uvicorn main:app --reload`
```

**Value**: Very High - reduces repeated instructions

#### MCP Servers (Model Context Protocol)
**Use case**: External integrations and data sources

Example: Database schema access
```json
{
  "mcpServers": {
    "database": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "postgresql://localhost/mydb"
      }
    }
  }
}
```

**Value**: High - Claude can query schemas directly

### Recommended Additional Configs Summary

| Config | Location | Value | Performance | Priority |
|--------|----------|-------|-------------|----------|
| post-merge | .git/hooks/ | Auto-update deps | ~5s when triggered | **High** |
| prepare-commit-msg | .git/hooks/ | Auto ticket linking | < 10ms | Medium |
| post-checkout | .git/hooks/ | Clean cache | ~100ms | Medium |
| pre-rebase | .git/hooks/ | Prevent history rewrites | ~50ms | **High** |
| Stop hook | .claude/settings.json | Auto code review | ~5-10s (end of session) | **High** |
| PreCompact hook | .claude/settings.json | Backup sessions | Async | Low |
| CLAUDE.md | Project root | Project standards | N/A | **Very High** |
| Skills | ~/.claude/skills/ | Custom workflows | N/A | Medium |
| MCP servers | .claude/settings.json | External integrations | Varies | Medium |

### Decision Matrix: Should I Add This Config?

```
Is this config needed?
│
├─ Does it prevent a disaster? (pre-rebase, Stop hook)
│  └─ YES → **High priority**, add it
│
├─ Does it save manual work every time? (post-merge, CLAUDE.md)
│  └─ YES → **High priority**, add it
│
├─ Does it add convenience but not critical?
│  └─ YES → Medium priority, add if time allows
│
└─ Is it "nice to have" or experimental?
   └─ YES → Low priority, skip for now
```

---

## 16. Final Recommended Configuration (Complete)

### Claude Code Settings (`~/.claude/settings.json`)

```json
{
  "env": {
    "PYTHONDONTWRITEBYTECODE": "1",
    "PYTHONUNBUFFERED": "1"
  },
  "permissions": {
    "allow": [
      "Bash(ruff:*)",
      "Bash(pytest:*)",
      "Bash(git:*)",
      "Bash(pip:*)",
      "Bash(npm:*)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/block-destructive.sh",
            "timeout": 10,
            "async": false
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "agent",
            "prompt": "Review changes for security, quality, tests, and docs. Brief summary only.",
            "timeout": 60,
            "async": false
          }
        ]
      }
    ]
  }
}
```

### Git Hooks Template Library (`~/.claude/hooks/templates/`)

**1. pre-commit-python-branch-aware** (Main hook for Python projects)
- Identity check (always)
- Ruff format (main only)
- ~20ms on branches, ~310ms on main

**2. commit-msg-standard** (All projects)
- AI attribution blocking
- ~5ms

**3. pre-push-python** (Python projects)
- pytest (full suite)
- ruff check
- mypy (optional)
- ~3-5s

**4. post-merge** (All projects, **NEW**)
- Auto-update dependencies
- ~5s when triggered

**5. pre-rebase** (All projects, **NEW**)
- Prevent rebasing pushed commits
- ~50ms

**6. post-checkout** (Optional)
- Clean __pycache__
- ~100ms

### Per-Project CLAUDE.md (High Priority)

Every project should have:
```markdown
# Project: [Name]

## Architecture
[Key patterns, frameworks, structure]

## Coding Standards
[Project-specific rules]

## Testing Requirements
[Coverage, test patterns]

## Common Commands
[Frequently used commands]
```

### Summary of Changes from Earlier Plan

#### New Additions:
1. ✅ **Mypy**: Pre-push only (not pre-commit)
2. ✅ **pytest**: Pre-push only (not pre-commit)
3. ✅ **post-merge hook**: Auto-update dependencies (high value)
4. ✅ **pre-rebase hook**: Prevent git disasters (high value)
5. ✅ **Stop hook**: Auto code review at session end (high value)
6. ✅ **CLAUDE.md**: Per-project standards (very high value)

#### Confirmed Removals:
1. ❌ **Async logging**: Not needed
2. ❌ **Differential pre-push**: All pushes same validation
3. ❌ **PostToolUse formatting**: Already removed

---

## References
- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide)
- [Claude Code Hooks Best Practices](https://www.eesel.ai/blog/hooks-in-claude-code)
- [Hook Performance Optimization](https://www.marc0.dev/en/blog/claude-code-hooks-production-patterns-async-setup-guide-1770480024093)
- [DataCamp: Claude Code Hooks Tutorial](https://www.datacamp.com/tutorial/claude-code-hooks)
