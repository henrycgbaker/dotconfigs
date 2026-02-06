# Codebase Concerns

**Analysis Date:** 2026-02-06

## Architecture & Design Issues

### 1. Fragile Remote Agent Sync System

**Issue:** The `sync-project-agents.sh` script has brittle remote synchronization logic that can fail silently or create inconsistent states.

**Files:** `sync-project-agents.sh`

**Problems:**
- SSH operations in pipes can fail silently with bash's `pipefail` set to `e` but subshell context lost in `while` loops (line 37, 159, 213)
- No verification that remote files were fully transferred (uses `cat > file` which can truncate on connection loss)
- Bidirectional sync attempts (pull vs push) can create conflicts if both sources diverge
- `sync_status` compares file content with SSH subshells; network failures during diff silently mark files as "out of sync"
- Remote path hardcoding (`ds01-infra` in line 20) assumes specific SSH host aliases exist

**Impact:**
- Project agents in different repos could diverge without warning
- Failed syncs leave inconsistent state with no rollback
- No transaction semantics or atomic operations

**Fix approach:**
- Add explicit success verification for SSH file transfers (checksum comparison post-transfer)
- Implement atomic operations using temporary files + rename pattern
- Add dry-run mode (`--dry-run` flag) to preview changes before execution
- Wrap remote SSH operations in error handlers with clear failure messages
- Document required SSH host aliases and configuration


### 2. Complex Orchestrator Context Flow with No Validation

**Issue:** The execute-phase orchestrator passes context between multiple agents (planner, checker, executor, verifier) with minimal validation of state consistency.

**Files:**
- `commands/gsd/execute-phase.md` (execute orchestrator)
- `agents/gsd-executor.md` (executor)
- `agents/gsd-plan-checker.md` (plan validator)
- `agents/gsd-verifier.md` (goal verifier)

**Problems:**
- No checksum or validation that PLAN.md hasn't been modified between checker and executor
- STATE.md can become stale if executor crashes mid-task; no recovery mechanism defined
- Frontmatter parsing (wave numbers, dependencies) relies on grep patterns; malformed YAML goes undetected
- `@-references` in plans (context files) are not validated to exist before execution starts
- Model profile resolution (line 44-57 in execute-phase.md) uses fragile grep patterns for JSON parsing instead of proper JSON parsing

**Impact:**
- State drift between planning and execution phases could cause silent failures
- Missing context files discovered mid-execution with no graceful fallback
- Invalid plan frontmatter could cause agents to misinterpret execution order

**Fix approach:**
- Add PLAN.md validation step at start of execute-phase: checksum verification and frontmatter schema validation
- Implement state checkpointing: each executor writes checkpoint before task execution
- Parse JSON config with proper JSON tools, not grep
- Validate all `@-references` exist and are readable before agent spawning
- Add recovery protocol: executor can detect and resume from checkpoint


### 3. Git Hook Configuration Drift

**Issue:** Git hooks are installed to `.git/hooks/` (local, untracked) but the source template is in `githooks/` (tracked). Configuration divergence can occur.

**Files:**
- `githooks/pre-commit` (template)
- `setup.sh` (installation script)
- `.git/hooks/pre-commit` (local copy)

**Problems:**
- No automatic sync of updated hook templates to existing installations
- Setup.sh copies hooks once; updates to `githooks/` don't propagate unless setup.sh is re-run
- Agent auto-sync disabled (line 80 in pre-commit); this was over-engineered but leaving it out means agent changes aren't caught
- Identity enforcement is hardcoded (`henrycgbaker` / `henry.c.g.baker@gmail.com`); can't be configured per-project

**Impact:**
- Long-lived repos could have stale hooks that don't enforce current standards
- New policy enforcements (e.g., additional secret patterns) won't apply to existing repos
- Identity check prevents contribution from other team members

**Fix approach:**
- Add `--update-hooks` flag to setup.sh to refresh existing installations
- Store hook version in `.git/hooks/.hook-version`; warn if older than source
- Make identity check configurable via `.git/config` hook.identity-user/email
- Document hook update procedure in setup documentation


### 4. Weak Error Handling in Security Hooks

**Issue:** The `block-sensitive.py` security hook has permissive failure modes that could leak secrets.

**Files:** `hooks/block-sensitive.py`

**Problems:**
- Line 76: `return 0  # Allow on parse error (fail open)` — malformed JSON in stdin bypasses all checks
- Pattern matching is case-insensitive (line 54) but `.env` patterns are commented out (lines 22-24); `.env` files NOT actually blocked
- `get_file_path_from_input()` tries only 3 parameter names; custom tools with different parameter names bypass protection
- No logging of blocked attempts; security violations are silent except to stderr

**Impact:**
- Malformed Claude context causes hook to silently allow blocked files
- `.env` files are NOT actually blocked despite rule in settings.json line 20
- Logging failures (missing `>>` in error handling) means sensitive access isn't recorded

**Fix approach:**
- Change fail-open behavior: return 2 (block) on parse error, log to syslog
- Uncomment and enable `.env` protection patterns
- Parse tool input more robustly (iterate through all values, not just 3 keys)
- Add audit logging to dedicated security log file
- Add integration test that verifies common secret file patterns are actually blocked


## Testing & Verification Gaps

### 5. No Tests for Agent Instructions

**Issue:** Agent definitions (.md files) have no validation that their instructions are syntactically correct or internally consistent.

**Files:** `agents/*.md` (all agent definitions)

**Problems:**
- No linting of frontmatter (YAML schema validation missing)
- No validation that `@-references` in agent instructions point to valid files
- No check that role descriptions match actual capabilities (tools listed may not match what the role assumes)
- Circular role dependencies not detected (agent A spawns agent B which spawns agent A)
- Context size calculations are manual estimates with no automated validation

**Impact:**
- Agent definitions can have broken references without discovery until runtime
- Bloated agents exceeding context budgets aren't caught before spawning
- Role inconsistencies cause executor confusion mid-task

**Fix approach:**
- Create `validate-agents.sh` script that:
  - Validates frontmatter YAML syntax
  - Checks all `@-references` exist
  - Validates declared tools are actually used
  - Estimates token count and warns if >50% budget
  - Detects circular spawn dependencies
- Run as pre-commit hook (optional but recommended)
- Document in setup instructions


## Scaling & Performance Issues

### 6. Plan Dependency Resolution Is O(n²)

**Issue:** Wave-based execution in execute-phase orchestrator doesn't scale well with many plans.

**Files:** `commands/gsd/execute-phase.md` (step 3-5)

**Problems:**
- No dependency graph structure; just reads frontmatter `depends_on` field and re-scans for each plan
- Wave calculation logic is described but not implemented; actual implementation would be sequential scan
- No topological sort; if circular dependencies exist, they're not detected until runtime
- Context for tracking plan dependencies is lost between orchestrator and subagent spawning

**Impact:**
- Projects with 50+ plans per phase become slow to execute (O(n²) dependency checks)
- Circular dependencies cause infinite wait or deadlock
- Large plan sets exceed context budget for orchestrator (15% budget allocation)

**Fix approach:**
- Build dependency graph once at start of phase execution, not per-plan
- Implement topological sort with cycle detection; fail fast if circular
- Cache wave assignments in a `.planning/phase-X-waves.json` file
- Validate all dependencies exist before starting execution


### 7. State Reconstruction After Failures

**Issue:** When executor crashes mid-execution, there's no automated state recovery mechanism.

**Files:** `agents/gsd-executor.md` (step load_project_state)

**Problems:**
- STATE.md can be hours old if a plan fails partway through
- Executor checkpoints aren't persisted; only git commits are (which may be paused at checkpoints)
- Recovery requires manual "continue from task X" — no automated detection of partial completion
- If subagent crashes, orchestrator doesn't know which task failed and must be re-run

**Impact:**
- Large phases that fail partway through lose work and context
- Manual recovery is error-prone (risk of re-running completed tasks)
- No audit trail of what succeeded/failed

**Fix approach:**
- Executor writes `.planning/phase-X-task-checkpoints.json` after each task:
  ```json
  {
    "plan_id": "16-01",
    "task": 3,
    "commit_hash": "abc123...",
    "timestamp": "2026-02-06T10:30:00Z",
    "status": "completed"
  }
  ```
- Orchestrator reads checkpoints and resumes from last completed task
- Add `--recover-from=16-01:task-3` flag to execute-phase
- Document recovery in usage guide


## Security Concerns

### 8. Credential Configuration Management

**Issue:** Settings for remote SSH hosts and credentials are hardcoded or poorly isolated.

**Files:**
- `sync-project-agents.sh` (line 20: hardcoded `ds01-infra|dsl:...`)
- `deploy-remote.sh` (SSH credentials in command line)
- `settings.json` (no credential isolation)

**Problems:**
- SSH host aliases are hardcoded in script; deploying to new hosts requires editing source
- No `.env` file support for host configuration (appears intentional but limits flexibility)
- Deploy script passes `--rsync` credentials via command line (visible in process list)
- No IP whitelist or host key verification enforcement

**Impact:**
- Deploying to production servers requires modifying checked-in scripts
- SSH credentials could be visible in process listings
- No validation of remote host identity

**Fix approach:**
- Move host configuration to `~/.config/dotclaude/remotes.json` or `.git/config`:
  ```
  [dotclaude "remote-ds01"]
    host = dsl
    path = /opt/ds01-infra/.claude/agents
    method = ssh
  ```
- Use SSH config (`~/.ssh/config`) for credential management
- Add `StrictHostKeyChecking=accept-new` to SSH options
- Document security best practices for remote deployment


## Technical Debt & Over-Engineering

### 9. Over-Engineered Agent Sync (Disabled)

**Issue:** The `sync-project-agents.sh` script is complex but disabled in pre-commit hooks.

**Files:**
- `githooks/pre-commit` (line 80: agent sync disabled)
- `sync-project-agents.sh` (400+ lines)

**Problems:**
- Agent sync attempted in line 48 of TODO.md but disabled as "over-engineering"
- Script supports both local and remote sources but adds complexity
- Status checking uses SSH + diff which is slow and fragile
- Pull/push semantics are ambiguous when both sources are stale

**Impact:**
- Agents in different repos can diverge without warning
- No automated way to keep project agents in sync
- The script exists but is rarely used due to complexity

**Fix approach:**
- Decide: either commit to agent sync or remove the script entirely
- If keeping: simplify to one-way push from dotclaude to projects
- If removing: document manual sync process in CLAUDE.md
- Current choice (disabled) leaves confusing code in repo


### 10. Unclear Verification Flow

**Issue:** Three agents verify different things (plan-checker, verifier, executor verification) with overlapping responsibilities.

**Files:**
- `agents/gsd-plan-checker.md` (verifies plans before execution)
- `agents/gsd-verifier.md` (verifies goals after execution)
- `agents/gsd-executor.md` (has internal verification steps)

**Problems:**
- Plan-checker validates that plans WILL achieve goal (predictive)
- Verifier validates that plans DID achieve goal (confirmatory)
- Executor has internal verification but output isn't formally structured
- Relationship between these three isn't documented; unclear what happens when they disagree

**Impact:**
- Phase failures could be due to plan flaws or execution flaws; ambiguous where to look
- Redundant verification work across multiple agents
- No unified verification report

**Fix approach:**
- Document verification philosophy: design → predictive → execution → confirmatory
- Clarify: plan-checker is gate (blocks execution), verifier is audit (can restart)
- Executor verification is internal only; doesn't block phase
- Create VERIFICATION.md template with structured output format


## Missing Critical Features

### 11. No Partial Phase Execution Mode

**Issue:** Cannot execute a subset of tasks within a phase; must execute entire phase or nothing.

**Files:** `commands/gsd/execute-phase.md`

**Problems:**
- No `--tasks=16-01:1,16-01:3` filtering
- No way to re-run specific failed tasks without re-running entire plan
- Large phases must all-or-nothing execute
- Cannot interleave manual work with automated tasks

**Impact:**
- Cannot iterate on single task while keeping rest stable
- Large changes must be all-in or all-out
- Difficult to debug single task failures

**Fix approach:**
- Add `--tasks=PLAN:TASK,PLAN:TASK` parameter to execute-phase
- Allow comma-separated task lists and ranges (`16-01:1-3,16-02:5`)
- Still enforce wave dependencies (can't run task X if depends_on Y not complete)


## Performance Concerns

### 12. Context Budget Tracking Is Manual

**Issue:** No automated enforcement of context budgets for agents and plans.

**Files:**
- `agents/gsd-planner.md` (line 85-95: manual quality degradation curve)
- Various agent files declare context but don't measure against budget

**Problems:**
- Plans are sized by manual estimation ("2-3 tasks max")
- No automated warning if plan context exceeds budget
- Orchestrator can spawn agents that exceed 50% context immediately
- Quality degradation isn't validated; agents may still be over-budget

**Impact:**
- Large phases with many interdependent plans exceed context budget silently
- Quality degrades without warning
- No way to optimize agent context usage

**Fix approach:**
- Add context budgeter utility that:
  - Calculates actual token count for PLAN.md files
  - Sums context for referenced @-files
  - Warns if plan context > 20% of agent budget
  - Estimates orchestrator context usage and phases that exceed capacity
- Run as lint step in verify-work flow


---

*Concerns audit: 2026-02-06*
