# Architecture

**Analysis Date:** 2026-02-06

## Pattern Overview

**Overall:** Multi-tier command orchestration system for Claude-based project automation (GSD - "Get Shit Done")

**Key Characteristics:**
- Hierarchical agent spawning with fresh context per subagent
- Command-driven orchestration layer decoupled from execution agents
- Declarative configuration (YAML frontmatter + markdown) for agent/command definition
- Hook-based cross-cutting concerns (security, formatting, git operations)
- Token budget management via context percentages and wave-based parallelization

## Layers

**Command/Orchestration Layer:**
- Purpose: User-facing interface that parses arguments, validates state, orchestrates subagent spawning
- Location: `commands/gsd/*.md` (e.g., `plan-phase.md`, `execute-phase.md`, `new-project.md`)
- Contains: Multi-step procedures with conditional branching, state management, wave-based dependency resolution
- Depends on: Agent specifications, project state files (`.planning/STATE.md`, `.planning/ROADMAP.md`, `.planning/config.json`)
- Used by: User invokes via `/gsd:command-name`, orchestrators delegate to subagents

**Agent Layer:**
- Purpose: Specialized, context-fresh workers spawned by orchestrators to handle specific domains
- Location: `agents/*.md` (GSD agents like `gsd-planner.md`, `gsd-executor.md`, `gsd-project-researcher.md`)
- Contains: Agent role definition, execution flow steps, decision trees, output specifications
- Depends on: Project state files, CONTEXT.md files (phase-specific constraints), external data
- Used by: Orchestrators spawn agents via Task with model-specific overrides

**Rules & Conventions Layer:**
- Purpose: Always-loaded behavioral standards that constrain all Claude instances
- Location: `rules/*.md` (e.g., `git-commits.md`, `python-standards.md`, `simplicity-first.md`)
- Contains: Coding standards, git workflow, security policies, documentation principles
- Depends on: None (loaded globally)
- Used by: All agents and commands via system-level configuration

**Hooks & Enforcement Layer:**
- Purpose: Pre/post tool-use automation for security, formatting, and git operations
- Location: `hooks/*.py` (PreToolUse and PostToolUse hooks)
- Contains: File-level access control, automatic formatting, git pre-commit validation
- Depends on: Tool invocation events, tool input inspection
- Used by: Claude Code runtime automatically triggers hooks

**Project-Specific Layer:**
- Purpose: Version-controlled record of domain-specific agents per project
- Location: `project-agents/{project-name}/*.md`
- Contains: Project-specialized agent variants (e.g., research-scientist.md for research projects)
- Depends on: Base agent patterns, project domain requirements
- Used by: Projects source these agents via `.claude/agents/` directory during setup

## Data Flow

**Phase Planning Flow:**

1. User invokes `/gsd:plan-phase 02`
2. **Orchestrator** (in `commands/gsd/plan-phase.md`) validates phase exists, loads CONTEXT.md (user decisions)
3. **Researcher agent** (if enabled) produces research files in `.planning/research/`
4. **Planner agent** (`gsd-planner.md`) reads CONTEXT.md + research, produces PLAN.md with task breakdown
5. **Checker agent** (`gsd-plan-checker.md`) verifies PLAN.md against goal, returns VERIFICATION.md
6. **Orchestrator** iterates planner → checker until plans pass or max iterations reached
7. User sees full flow: research → planning → verification

**Phase Execution Flow:**

1. User invokes `/gsd:execute-phase 02`
2. **Orchestrator** discovers all PLAN.md files, groups by `wave` field (dependency graph)
3. **For each wave in sequence:**
   - Orchestrator spawns `gsd-executor` agents in parallel (one per plan)
   - Each executor loads fresh context, executes all tasks, creates SUMMARY.md
   - Executor creates atomic commits per task
4. **Verification step** (if enabled):
   - Orchestrator spawns `gsd-verifier` with fresh context
   - Verifier reads actual codebase (not SUMMARY claims), validates must-haves
   - Verifier produces VERIFICATION.md with `passed` or `gaps_found` status
5. **If gaps found:** User offered `/gsd:plan-phase 02 --gaps` to create fix plans

**State Management:**

```
.planning/
├── STATE.md              # Current execution position, accumulated decisions, status
├── ROADMAP.md            # Master phase breakdown with descriptions and must-haves
├── config.json           # Workflow settings (model_profile, verifier enabled, etc.)
├── CONTEXT.md            # (optional) Phase-level user decisions
├── research/
│   └── *.md              # Research findings consumed during planning
├── phases/
│   ├── 01-setup/
│   │   ├── 01-CONTEXT.md        # User decisions (locked, deferred, discretion areas)
│   │   ├── 01-PLAN.md           # Planner output
│   │   ├── 01-SUMMARY.md        # Executor output
│   │   └── 01-VERIFICATION.md   # Verifier output
│   └── ...
└── codebase/             # Analysis documents (ARCHITECTURE.md, STRUCTURE.md, etc.)
```

## Key Abstractions

**Phase:**
- Purpose: Logical grouping of work with a single goal and must-haves
- Examples: `01-setup`, `02-core-features`, `02.1-bug-fixes` (subphase)
- Pattern: Phase has CONTEXT.md (user decisions) → PLAN.md (task breakdown) → SUMMARY.md (results) → VERIFICATION.md (goal check)

**Plan:**
- Purpose: Executable prompt that breaks a phase into 2-3 parallel-optimized tasks
- Examples: `01-database-schema.md`, `01-auth-service.md`
- Pattern: Frontmatter (phase, plan, type, wave, depends_on) + objective + tasks + verification/success criteria

**Task:**
- Purpose: Atomic unit of work with clear inputs, outputs, and verification
- Pattern: Type indicates execution (feature, refactor, fix, test, docs, checkpoint), has clear action description
- Verification: Checker verifies task feasibility; executor creates per-task commits

**Wave:**
- Purpose: Dependency group for parallel execution (all tasks in wave can run in parallel)
- Pattern: Plans specify `wave: 1`, `wave: 2`, etc. Orchestrator executes waves sequentially
- Benefit: Full context use with parallel speedup (wave 1 tasks → commit → wave 2 tasks in fresh context)

**Agent:**
- Purpose: Specialized Claude instance spawned with fresh context for focused domain work
- Pattern: YAML frontmatter (name, description, tools allowed, color) + role + responsibility sections
- Lifecycle: Orchestrator spawns via Task, agent runs to completion, returns structured result

## Entry Points

**User Commands:**
- Location: `/gsd:{command}` (e.g., `/gsd:plan-phase`, `/gsd:execute-phase`, `/gsd:new-project`)
- Triggers: User types command in Claude Code chat
- Responsibilities: Parse arguments, validate state, orchestrate subagent spawning, present results to user

**Project Initialization:**
- Location: `commands/gsd/new-project.md` (orchestrator)
- Triggers: User creates new GSD project
- Responsibilities: Create .planning/ directory, generate ROADMAP.md from domain research, set up initial STATE.md

**Sync Operations:**
- Location: `sync-project-agents.sh` and `deploy-remote.sh` scripts
- Triggers: Manual user invocation
- Responsibilities: Sync project-agents between dotclaude and individual projects, remote deployment

## Error Handling

**Strategy:** Explicit error propagation with user remediation guidance

**Patterns:**

- **State Validation:** Orchestrators verify `.planning/` structure exists before proceeding. If missing, error with instruction to run `/gsd:new-project`
- **Phase Resolution:** Orchestrators normalize phase numbers (`8` → `08`, `2.1` → `02.1`) and verify phase exists in ROADMAP.md
- **Model Profile:** Orchestrators resolve model profile from `config.json` (quality/balanced/budget) and look up correct model for each agent
- **Dependency Analysis:** Executors read `wave` and `depends_on` fields to detect circular dependencies or missing dependencies (error with suggestions)
- **Context Fidelity:** Planners verify locked decisions from CONTEXT.md are honored; deferred ideas are excluded; checkers validate this fidelity
- **Tool Permissions:** `settings.json` declares allow/deny/ask tool patterns; hooks enforce at runtime (PreToolUse block-sensitive.py prevents secrets access)
- **Git Hooks:** Pre-commit hook blocks AI attribution patterns; commit-msg hook validates conventional commits

## Cross-Cutting Concerns

**Logging:**
- Approach: Each agent step is logged in agent output (e.g., "Step 1: Load project state" produces visible checkpoint)
- Critical actions logged to `.planning/` as markdown files (RESEARCH.md, PLAN.md, SUMMARY.md, VERIFICATION.md)

**Validation:**
- Entry points: CONTEXT.md (user decisions), ROADMAP.md phase structure, plan frontmatter fields
- Tool level: Hook validates sensitive file access (block-sensitive.py), prevents .env reads
- Agent level: Planner validates plans respect CONTEXT.md locked decisions; verifier validates goal must-haves

**Authentication & Access Control:**
- Settings.json permissions layer: Declare allow (git, ruff, pytest), deny (rm -rf, .env), ask (systemctl, kill, reboot)
- Hook layer: block-sensitive.py pattern-matches files and blocks at PreToolUse time
- Git hooks: Enforce committer identity, block AI attribution, validate conventional commits

**Git Integration:**
- Settings.json sandbox excludes docker, git, nvidia-smi from sandboxing (allow real system access)
- Executor creates atomic commits per task (each task → one commit with per-task message)
- Orchestrator handles commit batching between waves (stage modified files, create orchestrator-level commits)
- Git hooks auto-run on every commit (pre-commit validates identity, commit-msg blocks attribution)

**Context Management:**
- Orchestrator uses ~15% context for discovery and spawning
- Each subagent gets fresh ~100% context for focused work
- Wave-based execution allows commit between waves, resetting context for next wave
- Token pressure monitoring: Quality degradation expected at 70%+ context usage

---

*Architecture analysis: 2026-02-06*
