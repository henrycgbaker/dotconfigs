# Phase 8: Hooks & Workflows Review - Research

**Researched:** 2026-02-08
**Domain:** Git hooks architecture, plugin boundaries, workflow patterns
**Confidence:** HIGH

## Summary

Phase 8 is a review and rationalisation phase for the existing hook and workflow implementation across claude and git plugins. The codebase currently has:

- **2 git hooks** (commit-msg, pre-push) deployed globally via `core.hooksPath` or per-project to `.git/hooks/`
- **1 Claude Code hook** (post-tool-format.py) for Python auto-formatting
- **2 workflow commands** (/commit, /squash-merge) that guide commit creation
- **3 hooks.conf profiles** (default, strict, permissive) stored in claude plugin but controlling git hook behaviour
- **Mixed ownership** where claude plugin manages hooks.conf but git plugin owns the hooks that read it

The research identifies clear plugin boundary issues and provides recommendations for rationalising this architecture based on industry best practices for hook management, plugin separation, and workflow patterns.

**Primary recommendation:** Move hooks.conf templates to git plugin (they control git hooks), keep AI attribution blocking in git hook only, soft-warn conventional commits on main, evaluate explore agent hook as LOW priority (defer), update README with GSD section.

## Current State Audit

### Hooks Inventory

| Hook | Type | Location | Owner Plugin | What It Does |
|------|------|----------|--------------|--------------|
| commit-msg | Git | plugins/git/hooks/ | git | AI attribution blocking (hard) + conventional commits (soft warn) |
| pre-push | Git | plugins/git/hooks/ | git | Branch protection (configurable: block/warn/off) |
| post-tool-format.py | Claude Code | plugins/claude/hooks/ | claude | Ruff auto-format for Python files (non-blocking) |

### Commands Inventory

| Command | Location | Owner Plugin | What It Does |
|---------|----------|--------------|--------------|
| /commit | plugins/claude/commands/ | claude | Guides conventional commit creation |
| /squash-merge | plugins/claude/commands/ | claude | Guides squash merge workflow |
| /pr-review | plugins/claude/commands/ | claude | PR review checklist |
| /simplicity-check | plugins/claude/commands/ | claude | Code simplicity audit |

### Configuration Files

| File | Location | Owner Plugin | Controls What |
|------|----------|--------------|---------------|
| hooks.conf | plugins/claude/templates/hooks-conf/ | claude | Git hook behaviour (CONVENTIONAL_COMMITS, BRANCH_PROTECTION, RUFF_ENABLED) |
| .env | dotconfigs root | shared | Global config (CLAUDE_*, GIT_* namespaced) |
| .claude/hooks.conf | Per-project (deployed by claude plugin) | claude | Per-project git hook overrides |

### Enforcement Mechanisms

| Mechanism | Where | Level | Configurable? |
|-----------|-------|-------|---------------|
| AI attribution blocking | git/hooks/commit-msg | Hard block (exit 1) | NO (hardcoded BLOCK_AI_ATTRIBUTION=true) |
| Conventional commits | git/hooks/commit-msg | Soft warn (exit 0) | YES (CONVENTIONAL_COMMITS=true/false in hooks.conf) |
| WIP blocking on main | git/hooks/commit-msg | Hard block (exit 1) | NO (hardcoded, main only) |
| Branch protection | git/hooks/pre-push | Configurable | YES (GIT_HOOK_PREPUSH_PROTECTION=block/warn/off) |
| Ruff formatting | claude/hooks/post-tool-format.py | Non-blocking (exit 0) | YES (RUFF_ENABLED in hooks.conf, but file extension check first) |

### Configuration Hierarchy

**Current precedence (from highest to lowest):**
1. Hardcoded in hook scripts (AI attribution, WIP blocking)
2. .claude/hooks.conf (per-project overrides: CONVENTIONAL_COMMITS, BRANCH_PROTECTION, RUFF_ENABLED)
3. .env GIT_HOOK_PREPUSH_PROTECTION (only for pre-push, overridden by hooks.conf if present)
4. Hook defaults (if no config found)

**Problem:** The hierarchy is inconsistent. Some settings use .env (GIT_HOOK_PREPUSH_PROTECTION), others use hooks.conf (CONVENTIONAL_COMMITS), and some are hardcoded (AI attribution). This makes it unclear where to configure each behaviour.

### Identified Overlaps and Gaps

**Overlaps:**
- hooks.conf lives in claude plugin but controls git hooks behaviour
- Claude plugin project.sh deploys hooks.conf but git plugin project.sh deploys the hooks that read it
- Both plugins have RUFF_ENABLED in hooks.conf but only claude plugin has the Ruff hook

**Gaps:**
- No pre-commit hook (only commit-msg and pre-push)
- No prepare-commit-msg hook (could provide commit message templates)
- No PreToolUse Claude Code hook (only PostToolUse)
- Explore agent hook mentioned in todos but not implemented

**Misplacements:**
- hooks.conf templates in plugins/claude/ should be in plugins/git/ (they control git hooks)
- hooks.conf deployment in claude project.sh should move to git project.sh

## Architecture Patterns

### Pattern 1: Plugin Ownership by Concern

**What:** Each plugin owns configuration files that control mechanisms within that plugin's domain.

**When to use:** When you have clear domain boundaries (git vs Claude Code) and want to avoid cross-plugin dependencies.

**Application to dotconfigs:**
- **Git plugin** should own: git hooks, git hook configuration (hooks.conf), git workflow commands
- **Claude plugin** should own: Claude Code hooks, Claude Code settings, Claude-specific commands

**Why this matters:** Currently hooks.conf is deployed by claude plugin but controls git hooks. This creates a dependency where git plugin functionality is controlled by claude plugin configuration.

**Recommendation:** Move hooks.conf templates from `plugins/claude/templates/hooks-conf/` to `plugins/git/templates/hooks-conf/`. Update claude project.sh to not deploy hooks.conf, and update git project.sh to deploy it.

### Pattern 2: Configuration Hierarchy Clarity

**What:** Establish clear precedence for configuration sources and document them.

**Industry standard hierarchy (from highest to lowest):**
1. Per-project local config (.git/config, .claude/hooks.conf)
2. Global user config (~/.gitconfig, .env)
3. System-wide defaults (git system config)
4. Hardcoded defaults in scripts

**Current dotconfigs hierarchy issues:**
- AI attribution blocking: Hardcoded (always true)
- Conventional commits: hooks.conf (per-project)
- Branch protection: .env OR hooks.conf (inconsistent)
- Ruff formatting: hooks.conf (per-project)

**Recommendation:** Standardise on hooks.conf for all per-project git hook configuration. Remove GIT_HOOK_PREPUSH_PROTECTION from .env (or keep as default when hooks.conf doesn't exist).

### Pattern 3: Global vs Per-Project Hook Deployment

**What:** Hooks can deploy globally via `core.hooksPath` or per-project to `.git/hooks/`.

**Industry standard (2026):**
- **Global hooks:** Use for organisation-wide standards that apply to ALL repos (security checks, credentials scanning)
- **Per-project hooks:** Use for project-specific checks (linting rules, test requirements, project workflow)
- **Hybrid:** Global hooks as baseline, per-project overrides via `core.hooksPath` per-repo config

**Current dotconfigs approach:**
- Git plugin defaults to per-project deployment (`dotconfigs project git`)
- Global deployment available via setup wizard selection (GIT_HOOKS_SCOPE=global)
- When global: Uses `~/.dotconfigs/git-hooks/` and sets `core.hooksPath` globally
- Warning shown: "Global hooks override per-project hooks in .git/hooks/"

**Why this is correct:** Matches industry best practice. Per-project default allows repo-specific customisation. Global option for users who want consistency across all repos.

**No changes needed:** Current pattern is sound.

### Pattern 4: Hook Configuration Discovery

**What:** Hooks should discover and load configuration files in a standard way.

**Current dotconfigs approach:**
```bash
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
HOOK_CONFIG="$REPO_ROOT/.claude/hooks.conf"

# Load if exists
if [ -f "$HOOK_CONFIG" ]; then
    source "$HOOK_CONFIG"
fi
```

**Industry standard:** Look for config in standard locations, fall back to defaults. Some tools use:
- `.git/hooks/config` (git-hooks-core pattern)
- `.githooks/` directory (githooks pattern)
- `.pre-commit-config.yaml` (pre-commit framework)

**Current location (`.claude/hooks.conf`):**
- PRO: Namespaced under .claude/ avoids root clutter
- PRO: Deployed by project.sh so always present when needed
- CON: Non-standard location (not discoverable without docs)
- CON: Lives under .claude/ but controls git hooks (misleading)

**Recommendation:** Move to `.git/hooks/hooks.conf` or create `.githooks/` directory. If keeping under .claude/, at least move ownership to git plugin as discussed in Pattern 1.

## Squash Merge vs Merge Commit Workflow

### The Question

Current dotconfigs workflow uses squash merge (via /squash-merge command). User wants "blocks of validated work" with clean history but git doesn't track squash merges properly — branches appear unmerged even after squashing.

### Industry Standard (2026)

**According to 2023 Stack Overflow Survey:** 60% of developers use squash merge regularly.

**Context-dependent decision matrix:**

| Use Case | Recommended Strategy | Why |
|----------|----------------------|-----|
| Feature branch → main (will be deleted) | Squash merge | Clean linear history, branch is throwaway |
| Long-lived branch → main | Merge commit (--no-ff) | Preserves merge tracking, shows branch structure |
| Solo developer, frequent small changes | Squash merge | Reduces noise, one logical unit = one commit |
| Team with code review, large features | Merge commit | Preserves discussion context, shows who worked on what |
| Public API / library | Merge commit | Traceability matters for release notes |

**Key insight from research:** "Different strategies should be used situationally based on context — all have their merits, and no particular strategy is right 100% of the time."

### Current Dotconfigs Use Case

- **Solo developer** (or small team)
- **Feature branches** that are deleted after merge
- **Wants clean history** on main
- **Uses conventional commits** on main (enforced by hooks)

**This matches the "squash merge" use case perfectly.**

### The Git Tracking Problem

**User concern:** "git doesn't recognise commits as merged, branches show as unmerged"

**Why this happens:** Squash merge creates a new commit with different SHA. Git doesn't see the relationship between branch commits and the squashed commit.

**Solutions:**
1. **Delete branch immediately** after squash merge (current /squash-merge does this) — if branch is gone, "unmerged" status doesn't matter
2. **Use merge commit instead** (--no-ff) — preserves merge tracking but adds merge commit noise
3. **Use tags** to mark feature completions — doesn't solve tracking but adds metadata
4. **Accept the limitation** — if you squash merge, you lose per-commit tracking by design

**Recommendation for dotconfigs:** Keep squash merge workflow. The /squash-merge command already deletes branches, which is correct. The "unmerged" status is expected behaviour for squash merge and not a problem if branches are deleted. Document this in the command and README.

### Merge Commit Alternative

If user wants to try merge commits:

**Benefits:**
- Git tracks merge relationships
- `git log --graph` shows branch structure
- `git branch --merged` works correctly
- Easier to trace which branch delivered a feature

**Downsides:**
- Main branch history includes all WIP commits from feature branches
- More noise in `git log`
- Merge commits themselves clutter history

**Implementation:** Create new `/merge-branch` command alongside /squash-merge, let user choose per-situation.

```bash
# /merge-branch process
git checkout main
git pull
git merge --no-ff <branch-name> -m "type: description"
git branch -d <branch-name>
git push
```

**Decision:** Don't replace /squash-merge. Add /merge-branch as alternative if user requests it. For now, keep squash merge as primary workflow and document the tradeoff clearly.

## Conventional Commit Enforcement Levels

### Current Implementation

**commit-msg hook behaviour:**
- **AI attribution:** Hard block (exit 1, cannot disable)
- **WIP on main:** Hard block (exit 1, cannot disable, unless SQUASH_MSG detected)
- **Conventional format:** Soft warn (exit 0, shows note but allows commit)
- **Subject length >72:** Soft warn (exit 0, shows warning but allows commit)

### Industry Standard Enforcement Patterns

**From research:**
- **commitlint** distinguishes between "problems" (✖) and "warnings" (⚠)
- **CI/CD integration** typically hard-blocks on problems, warns on style issues
- **Local hooks** often use soft warnings to avoid blocking developer flow

**Common pattern:**
- **Security/policy violations:** Hard block (credentials, forbidden patterns)
- **Commit message format:** Soft warn locally, hard block in CI/CD
- **Style/length:** Soft warn only

### Evaluation of Current Approach

**What's right:**
- AI attribution hard block: Correct (policy enforcement)
- WIP hard block on main: Correct (prevents accidental WIP on clean branch)
- Conventional format soft warn: Correct (doesn't block if you have a good reason for non-conventional)
- Subject length soft warn: Correct (guideline not rule)

**What's configurable:**
- CONVENTIONAL_COMMITS=true/false determines if check runs at all
- If false, no validation runs (permissive projects)
- If true, check runs but only warns (guidance not enforcement)

**Recommendation:** Current enforcement levels are correct. Keep as-is.

### Missing Option: Hard Block Mode

Some teams want hard blocking for conventional commits (especially in CI/CD). Current hooks don't support this.

**Possible addition:**
```bash
# hooks.conf
CONVENTIONAL_COMMITS=true          # Enable check
CONVENTIONAL_COMMITS_STRICT=false  # true = hard block, false = warn
```

**Decision:** NOT NEEDED for Phase 8. Current soft-warn approach is correct for solo/small team use case. If team requests strict mode later, can add as enhancement.

## AI Attribution Blocking Placement

### Current State

AI attribution blocking lives ONLY in git plugin's commit-msg hook:
- File: `plugins/git/hooks/commit-msg`
- Lines 32-62: Pattern matching and hard block
- 11 patterns checked (Co-Authored-By, Generated by, AI-assisted, etc.)
- BLOCK_AI_ATTRIBUTION=true hardcoded, cannot disable

### Should It Also Live in Claude Plugin?

**Question:** Should PreToolUse Claude Code hook also block AI attribution before tool calls?

**Arguments FOR dual enforcement:**
- Defense in depth (multiple layers)
- Catches AI attribution earlier (before commit stage)
- Claude Code could auto-generate attribution in other contexts (PR descriptions, comments)

**Arguments AGAINST dual enforcement:**
- AI attribution primarily a git commit concern
- Claude Code hooks run on every tool call (high overhead for rare check)
- PreToolUse hook would need to inspect Bash tool calls for git commit -m "..." (fragile regex parsing)
- git hook catches it authoritatively when it matters

### Industry Pattern: Single Point of Enforcement

**Standard approach:** Enforce policies at the point where they matter:
- Commit message policies → commit-msg hook
- Code style policies → pre-commit hook or IDE integration
- Branch naming policies → pre-push hook or CI/CD

**Why not duplicate:**
- Duplication creates maintenance burden (patterns must stay in sync)
- Each layer has different capabilities (git hook sees final commit message, Claude hook sees tool call string)
- Single enforcement point is easier to reason about

**Recommendation:** Keep AI attribution blocking in git hook only. Do NOT add to Claude plugin. This is the correct single point of enforcement.

## Don't Hand-Roll

Problems in the hook/workflow domain that have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Git hook framework | Custom bash scripts deployed manually | pre-commit, husky, githooks | Version control, sharing, updates |
| Conventional commit validation | Regex in bash | commitlint, conform | Standard tooling, better error messages |
| Hook configuration management | Custom .conf files sourced with `source` | Standard config formats (TOML, YAML) | Type safety, validation, tooling |

**Why dotconfigs uses custom bash scripts:**
- **Simplicity:** Bash 3.2 compatible, no dependencies, runs everywhere
- **Integration:** Hooks need to read dotconfigs-specific config (.env, hooks.conf)
- **Education:** User can read and understand the hook logic directly
- **Portability:** No npm/pip/gem required, works in Docker/CI/CD/fresh machines

**Trade-off accepted:** More maintenance burden but better portability and simplicity. For a small number of hooks (2 git, 1 Claude Code), custom bash is manageable. If hook count grows beyond 5-6, reconsider using pre-commit framework.

**Recommendation:** Continue with custom bash hooks for now. Re-evaluate if hook complexity grows significantly.

## Common Pitfalls

### Pitfall 1: Global Hooks Override Per-Project Hooks

**What goes wrong:** User sets `core.hooksPath` globally, then wonders why per-project .git/hooks/ aren't running.

**Why it happens:** `core.hooksPath` replaces the default `.git/hooks/` directory entirely. There's no "merge" or "chain" behaviour.

**How to avoid:**
- Document clearly that global and per-project hooks are mutually exclusive
- Default to per-project deployment (current behaviour)
- Show warning when deploying globally: "Global hooks override per-project hooks in .git/hooks/"

**Current status:** Already handled correctly in git/deploy.sh line 370-371.

### Pitfall 2: hooks.conf Not Loaded by Hooks

**What goes wrong:** User creates .claude/hooks.conf but changes don't take effect.

**Why it happens:**
- hooks.conf path is hardcoded in hook scripts as `$REPO_ROOT/.claude/hooks.conf`
- If user creates it in different location, hooks won't find it
- If REPO_ROOT doesn't resolve correctly (not in git repo), hooks fail silently

**How to avoid:**
- Ensure `git rev-parse --show-toplevel` always works (check git repo first)
- Document where hooks.conf must be located
- Add validation in project.sh to ensure .claude/ directory exists

**Current status:** Partially handled. commit-msg and pre-push both have fallback to `"."` if not in git repo, but this could create subtle bugs. Need verification step.

### Pitfall 3: Hook Execution Permissions

**What goes wrong:** Hooks deployed but not executing (silently failing).

**Why it happens:** Hooks must be executable (`chmod +x`). If permissions aren't set correctly, git ignores them.

**How to avoid:**
- Always `chmod +x` after copying hooks (git/deploy.sh line 362, git/project.sh line 50)
- Verify executable bit in status command

**Current status:** Already handled in both deploy paths.

### Pitfall 4: Bash 3.2 Compatibility Breaking in Hooks

**What goes wrong:** Hooks work on Linux (bash 4+) but fail silently on macOS (bash 3.2).

**Why it happens:**
- Associative arrays (bash 4+)
- `local -n` namerefs (bash 4+)
- `${var,,}` lowercase expansion (bash 4+)
- `[[` with regex `=~` (works but differences in BASH_REMATCH)

**How to avoid:**
- Test all hooks on macOS (bash 3.2)
- Use portable constructs: `grep -E`, `sed`, `awk` instead of bash 4 features
- Document bash version requirement

**Current status:** Hooks appear bash 3.2 compatible (no namerefs, no associative arrays observed). Pre-push uses `grep -E` for regex. Good.

### Pitfall 5: Squash Merge Confusion with SQUASH_MSG

**What goes wrong:** During squash merge, git creates SQUASH_MSG file. Hooks must detect this state and adjust behaviour.

**Why it happens:** Normal merge creates MERGE_HEAD, squash merge creates SQUASH_MSG. Hooks should allow manual message crafting during squash merge.

**How to avoid:**
- Check for SQUASH_MSG file in commit-msg hook
- Skip WIP blocking during squash merge (user is crafting final message)
- Still validate conventional format but relax other checks

**Current status:** commit-msg hook lines 74-77 handle this correctly. Good.

## Explore Agent Hook

### The Question

Should dotconfigs add a PreToolUse Claude Code hook that forces explore agent to use Sonnet instead of Haiku?

### What Is Explore Agent

**From research:**
- Explore subagent is Claude Code's codebase search assistant
- Default model: Haiku (fast, cheap)
- Can manually request Sonnet: "Launch explore agent with Sonnet 4.5"
- Purpose: Search codebase, find patterns, understand structure

### Why User Might Want This

**Potential reasons:**
- Haiku misses context or gives shallow answers
- Sonnet provides better code understanding
- Willing to pay more for better search results

### Hook Implementation Feasibility

**PreToolUse hook receives:**
```json
{
  "tool_name": "AgentSpawn",
  "tool_input": {
    "agent": "explore",
    "model": "haiku",
    "task": "..."
  }
}
```

**Hook could:**
- Detect `tool_input.agent === "explore"`
- Modify `tool_input.model` to `"sonnet"`
- Return modified JSON to Claude Code

**Challenges:**
- Claude Code hook API may not support modifying tool_input (documentation unclear)
- Forcing model changes might break cost expectations
- User loses control over per-task model selection
- Haiku is fast enough for most explore tasks

### Recommendation

**Priority: LOW**

**Rationale:**
- Manual override already works: "use Sonnet for explore"
- Forcing Sonnet removes user control (can't choose per-task)
- Hook complexity doesn't justify benefit
- No evidence that Haiku explore is inadequate for dotconfigs use case

**Decision:** DEFER explore agent hook. Not needed for Phase 8. If user finds specific cases where Haiku explore fails, revisit with concrete examples. For now, manual override is sufficient.

## Configuration Hierarchy Documentation

### Current State (Undocumented)

The .env.example and README don't clearly explain configuration precedence.

### Recommended Hierarchy Documentation

**For git hooks:**

```
Precedence (highest to lowest):
1. .claude/hooks.conf (per-project, deployed by dotconfigs project git)
2. .env GIT_HOOK_* keys (global user config)
3. Hook defaults (if no config found)

Hardcoded (cannot override):
- AI attribution blocking (always on)
- WIP blocking on main branch (always on)
```

**For Claude Code hooks:**

```
Precedence (highest to lowest):
1. .claude/hooks.conf (per-project, if hook reads it)
2. .env CLAUDE_* keys (global user config)
3. Hook defaults

Note: Post-tool-format.py reads hooks.conf for RUFF_ENABLED
```

**Add to README:** Create "Configuration" section explaining:
- What .env controls (global settings)
- What hooks.conf controls (per-project overrides)
- Which settings are hardcoded and why
- How to override settings per-project

**Add to .env.example:** Comment each key with:
- Purpose
- Default value
- Whether it can be overridden in hooks.conf
- Example values

## GSD Framework README Mention

### Current State

README mentions GSD framework briefly in "claude" plugin section:
> "GSD framework — Optional installation of Get Shit Done planning agents"

And in Phase 5 success criteria:
> "GSD framework coexistence maintained (file-level symlinks)"

But there's no explanation of what GSD is or why someone would want it.

### Recommended Addition

**In README "Plugins" > "claude" section:**

```markdown
### GSD Framework Integration

dotconfigs supports optional installation of the [Get Shit Done](https://github.com/eldrgeek/get-shit-done-cc) framework, an AI-powered project planning system for Claude Code. When enabled during setup, GSD agents are installed globally and can be invoked from any project.

**What GSD provides:**
- `/gsd:plan-phase` — breaks down project phases into detailed task plans
- `/gsd:research-phase` — investigates domain requirements before planning
- `/gsd:discuss-phase` — guides decision-making discussions with Claude
- `/gsd:review-phase` — validates completed work against success criteria

**Coexistence:** dotconfigs and GSD share `~/.claude/` using file-level symlinks. Both can coexist without conflicts.

**Setup:** Enable during `dotconfigs setup claude` wizard, or install manually: `npx get-shit-done-cc --claude --global`
```

**Add to Quick Start:** After basic setup example:

```markdown
Optional: Install GSD framework for project planning assistance:
```bash
dotconfigs setup claude  # Enable "Install GSD framework?" in wizard
```

## Code Examples

### Pattern: Hook Configuration Loading

From plugins/git/hooks/commit-msg (lines 12-29):

```bash
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
HOOK_CONFIG="$REPO_ROOT/.claude/hooks.conf"

# Defaults
CONVENTIONAL_COMMITS=true
BLOCK_AI_ATTRIBUTION=true  # Cannot be disabled

if [ -f "$HOOK_CONFIG" ]; then
    source "$HOOK_CONFIG"
    # Force AI attribution blocking regardless of config
    BLOCK_AI_ATTRIBUTION=true
fi
```

**Key pattern:** Load defaults first, then source config file, then enforce hardcoded overrides. This ensures config can't disable security-critical checks.

### Pattern: TTY-Aware Output

From plugins/git/hooks/commit-msg (lines 51-60):

```bash
if echo "$COMMIT_MSG" | grep -qiE "$pattern"; then
    echo "❌ ERROR: Commit message contains AI attribution"
    echo "Pattern matched: $pattern"
    echo ""
    echo "Remove lines like:"
    echo "  - Co-Authored-By: ..."
    echo "  - Generated by: ..."
    echo "  - AI-assisted"
    echo ""
    echo "Take ownership of all committed code."
    exit 1
fi
```

**Why this works:** Git hooks run in TTY context when user runs `git commit`. No need for `[[ -t 1 ]]` check. Always show error messages.

**Note for Phase 7:** lib/colours.sh adds TTY detection for deploy scripts, but hooks don't need it (always interactive).

### Pattern: Squash Merge Detection

From plugins/git/hooks/commit-msg (lines 74-77):

```bash
IS_SQUASH_MERGE=false
if [ -f "$REPO_ROOT/.git/SQUASH_MSG" ] || [ -n "$GIT_MERGE_SQUASH" ]; then
    IS_SQUASH_MERGE=true
fi
```

**Why both checks:**
- SQUASH_MSG file exists during `git merge --squash`
- GIT_MERGE_SQUASH env var set during squash merge operations
- Check both to handle all cases reliably

## Open Questions

### Question 1: Should hooks.conf move to .git/hooks/ directory?

**What we know:**
- Current location: `.claude/hooks.conf` (deployed by claude plugin)
- Used by: Git hooks (commit-msg, pre-push) and Claude hook (post-tool-format.py)
- Standard git hook config locations: `.git/hooks/config`, `.githooks/`, root of repo

**What's unclear:**
- Would moving to `.git/hooks/hooks.conf` improve discoverability?
- Would it break the pattern where Claude plugin also reads it (RUFF_ENABLED)?
- Is keeping under `.claude/` acceptable if ownership moves to git plugin?

**Recommendation:**
- Move hooks.conf templates to git plugin (ownership)
- Keep location as `.claude/hooks.conf` (deployed location)
- Rationale: Config controls both git hooks and Claude hooks, so .claude/ is acceptable neutral ground
- Alternative: Create `.hooks/` directory at project root, deploy hooks.conf there

**Decision needed:** Clarify with user where config should live long-term.

### Question 2: Should BRANCH_PROTECTION and GIT_HOOK_PREPUSH_PROTECTION merge?

**What we know:**
- hooks.conf has BRANCH_PROTECTION variable (block/warn/off)
- .env has GIT_HOOK_PREPUSH_PROTECTION variable (block/warn/off)
- pre-push hook reads GIT_HOOK_PREPUSH_PROTECTION from env first, then can be overridden by hooks.conf

**What's unclear:**
- Are these meant to be the same setting with different names?
- Should one be removed to avoid confusion?
- Should .env provide the default and hooks.conf override it?

**Recommendation:**
- Keep both but clarify: GIT_HOOK_PREPUSH_PROTECTION in .env is global default
- BRANCH_PROTECTION in hooks.conf is per-project override
- If hooks.conf doesn't exist, fall back to .env value
- If neither exists, default to "warn"

### Question 3: Add /merge-branch command as alternative to /squash-merge?

**What we know:**
- Current workflow uses squash merge (clean history, branch deleted)
- User concerned about git not tracking merged branches
- Merge commits preserve tracking but add noise

**What's unclear:**
- Does user want merge commit option as alternative?
- Would two commands (/squash-merge and /merge-branch) confuse users?
- Should workflow be per-project configured or per-operation chosen?

**Recommendation:**
- Don't add /merge-branch in Phase 8
- Document squash merge tradeoff clearly in /squash-merge command
- If user specifically requests merge commit workflow, add in future phase

## Sources

### Primary (HIGH confidence)
- Codebase audit: plugins/git/hooks/, plugins/claude/hooks/, plugins/*/project.sh
- Git hooks documentation: [git-scm.com/docs/githooks](https://git-scm.com/docs/githooks)
- Claude Code hooks documentation: [code.claude.com/docs](https://code.claude.com/docs)

### Secondary (MEDIUM confidence)
- [Plugin Architecture - Intuit Hooks Wiki](https://intuit.github.io/hooks/wiki/plugin-architecture/)
- [Mastering Git Hooks - Kinsta](https://kinsta.com/blog/git-hooks/)
- [Git Hooks Tutorial - Atlassian](https://www.atlassian.com/git/tutorials/git-hooks)
- [pre-commit framework](https://pre-commit.com/)
- [Git core.hooksPath vs per-project - DataCamp](https://www.datacamp.com/tutorial/git-hooks-complete-guide)
- [Githooks - GitHub repo](https://github.com/gabyx/Githooks)
- [Two Ways to Share Git Hooks - Viget](https://www.viget.com/articles/two-ways-to-share-git-hooks-with-your-team)

### Squash Merge vs Merge Commit (MEDIUM confidence)
- [Merge vs. Rebase vs. Squash - Mitchell Hashimoto GitHub Gist](https://gist.github.com/mitchellh/319019b1b8aac9110fcfb1862e0c97fb)
- [Should You Squash Merge or Merge Commit? - Lloyd Atkinson](https://www.lloydatkinson.net/posts/2022/should-you-squash-merge-or-merge-commit/)
- [Git Merge: To Squash Or Fast-Forward? - DEV Community](https://dev.to/trpricesoftware/git-merge-to-squash-or-fast-forward-3791)
- [Merge Commit vs Squash - Mergify](https://articles.mergify.com/what-is-the-difference-between-a-merge-commit-a-squash/)
- [Squash and Merge Guide - Kluster.ai](https://www.kluster.ai/blog/squash-and-merge)
- [Standard Merge Commit or Squash Merge? - Atomic Object](https://spin.atomicobject.com/squash-merge/)
- [Merge strategies - Azure DevOps](https://learn.microsoft.com/en-us/azure/devops/repos/git/merging-with-squash?view=azure-devops)

### Conventional Commits (MEDIUM confidence)
- [Conventional Commits Specification](https://www.conventionalcommits.org/en/about/)
- [Conventional Commits Cheatsheet - GitHub Gist](https://gist.github.com/qoomon/5dfcdf8eec66a051ecd85625518cfd13)
- [Enforcing Conventional Commits - Satellytes](https://www.satellytes.com/blog/post/writing-and-enforcing-conventional-commit-messages-and-pull-request-titles/)
- [Cocogitto - Conventional Commits toolbox](https://github.com/cocogitto/cocogitto)

### Claude Code & Explore Agent (MEDIUM confidence)
- [Claude Code Subagents Documentation](https://code.claude.com/docs/en/sub-agents)
- [Model Configuration Guide - Eesel](https://www.eesel.ai/blog/model-configuration-claude-code)
- [Claude Code 2.0 Guide - Sankalp's Blog](https://sankalp.bearblog.dev/my-experience-with-claude-code-20-and-how-to-get-better-at-using-coding-agents/)
- [Claude Code Multiple Agent Systems - Eesel](https://www.eesel.ai/blog/claude-code-multiple-agent-systems-complete-2026-guide)
- [Claude Sonnet 4.5 Features - IntuitionLabs](https://intuitionlabs.ai/articles/claude-sonnet-4-5-code-2-0-features)
- [Claude Code Hooks Mastery - GitHub](https://github.com/disler/claude-code-hooks-mastery)

## Metadata

**Confidence breakdown:**
- Current state audit: HIGH - direct codebase inspection
- Plugin architecture patterns: HIGH - well-documented industry standards
- Squash merge vs merge commit: MEDIUM - industry opinions vary, context-dependent
- Explore agent hook: MEDIUM - Claude Code hook API capabilities not fully documented
- Configuration hierarchy: HIGH - git documentation is authoritative

**Research date:** 2026-02-08
**Valid until:** 60 days (hook patterns are stable, but Claude Code hook API may evolve)

**Key assumptions:**
- Bash 3.2 compatibility requirement remains (macOS support)
- Solo developer / small team use case (not enterprise)
- Git workflow emphasis on clean main branch history
- Simplicity over feature maximalism

**Research scope:**
This research focused on EXISTING mechanisms and their placement. It did not explore:
- Adding new hook types (pre-commit, prepare-commit-msg)
- Implementing hook chaining or hook frameworks
- Multi-level hook configuration (global + project + repo)
- Hook testing infrastructure
