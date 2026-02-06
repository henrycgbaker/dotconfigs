# Codebase Structure

**Analysis Date:** 2026-02-06

## Directory Layout

```
dotclaude/
├── CLAUDE.md                    # Personal Claude policies (symlinked to ~/.claude/CLAUDE.md)
├── settings.json                # Claude Code settings (copied to ~/.claude/settings.json)
├── agents/                      # System-wide reusable agents
│   ├── gsd-*.md                 # GSD orchestration + execution agents
│   └── [other agents]
├── commands/                    # User-invoked /commands
│   └── gsd/                     # GSD command suite (plan-phase, execute-phase, etc.)
├── rules/                       # Always-loaded behavioral standards
│   ├── git-commits.md
│   ├── python-standards.md
│   ├── git-workflow.md
│   ├── simplicity-first.md
│   └── [other rules]
├── hooks/                       # Pre/post tool-use automation
│   ├── block-sensitive.py       # PreToolUse: blocks .env, keys, credentials
│   ├── post-tool-format.py      # PostToolUse: auto-formats Python
│   ├── gsd-statusline.js        # Status monitoring hook
│   └── gsd-check-update.js      # Update checking hook
├── skills/                      # Model-invoked capabilities (currently empty)
├── githooks/                    # Git hook templates (copied to .git/hooks/ by setup.sh)
├── project-agents/              # Version-controlled record of project-specific agents
│   ├── llm-efficiency-measurement-tool/
│   │   ├── research-pm.md
│   │   └── research-scientist.md
│   ├── ds01-infra/
│   │   ├── admin-docs-writer.md
│   │   ├── cli-ux-designer.md
│   │   ├── systems-architect.md
│   │   └── [domain-specific agents]
│   └── [other projects]
├── .planning/                   # (Created during setup, not tracked)
│   ├── codebase/                # Codebase analysis documents
│   │   ├── ARCHITECTURE.md      # This file's home
│   │   ├── STRUCTURE.md         # This file
│   │   ├── CONVENTIONS.md       # (if run with quality focus)
│   │   └── [other analysis docs]
│   └── ...
├── docs/                        # User documentation
│   └── usage-guide.md
├── .claude/                     # Claude Code local state (git-ignored)
├── .vscode/                     # VSCode settings
├── .git/                        # Git repository
├── _archive/                    # Historical agents/configs
└── README.md
```

## Directory Purposes

**agents/**
- Purpose: Reusable Claude agent definitions for system-wide use (git, testing, refactoring, domain research)
- Contains: YAML frontmatter + markdown role definitions for GSD orchestrators and specialized agents
- Key files: `gsd-planner.md`, `gsd-executor.md`, `gsd-project-researcher.md`, `gsd-plan-checker.md`, `gsd-verifier.md`
- Symlinked to: `~/.claude/agents/` during setup

**commands/gsd/**
- Purpose: User-facing command orchestrators that parse arguments, validate state, spawn subagents
- Contains: Multi-step procedures (Bash-style process flows) with state management and conditional branching
- Key files: `plan-phase.md` (planning orchestrator), `execute-phase.md` (execution orchestrator), `new-project.md` (project initialization), `verify-work.md` (goal verification)
- Invoked: User types `/gsd:command-name` in Claude Code chat

**rules/**
- Purpose: Always-loaded behavioral standards that apply to all Claude instances on this machine
- Contains: Coding conventions, git standards, security policies, documentation principles
- Key files: `git-commits.md` (conventional commits), `python-standards.md` (type hints, Ruff), `simplicity-first.md` (Occam's razor), `git-workflow.md` (feature branches)
- Loaded: Globally via `~/.claude/rules/` symlink

**hooks/**
- Purpose: Cross-cutting concerns automated via tool-use hooks
- Contains: Python scripts for PreToolUse and PostToolUse events, JavaScript hooks for status monitoring
- Key files: `block-sensitive.py` (blocks .env/keys access), `post-tool-format.py` (auto-formats Python code)
- Loaded: Specified in `settings.json` hooks section

**project-agents/{project-name}/**
- Purpose: Version-controlled archive of project-specific agent variants
- Contains: Domain-specialized agents per project (research-scientist for research projects, systems-architect for infrastructure)
- Used: Projects copy these agents to their `.claude/agents/` during onboarding
- Pattern: One directory per project, organized by project name

**docs/**
- Purpose: User documentation and guides
- Contains: Setup instructions, usage patterns, command reference
- Key files: `usage-guide.md` (comprehensive getting started guide)

**githooks/**
- Purpose: Git hook templates applied to project repositories
- Contains: pre-commit (identity validation, agent sync), commit-msg (blocks AI attribution)
- Copied to: `.git/hooks/` in any project using dotclaude via setup.sh or deploy-remote.sh

## Key File Locations

**Entry Points:**
- `commands/gsd/new-project.md`: Initialize a new GSD project (creates .planning/, runs research, generates ROADMAP.md)
- `commands/gsd/plan-phase.md`: Create execution plan for a phase (spawns researcher → planner → checker)
- `commands/gsd/execute-phase.md`: Execute all plans in a phase (spawns executors in waves, verifies results)
- `commands/gsd/help.md`: Display available GSD commands and usage

**Configuration:**
- `CLAUDE.md`: Personal policies, communication style, autonomy, documentation guidelines
- `settings.json`: Claude Code permissions (allow/deny/ask), hooks configuration, sandbox settings
- `rules/*.md`: All behavior standards (loaded globally)

**Core Logic:**
- `agents/gsd-planner.md`: Plan creation logic with task decomposition, dependency analysis, goal-backward verification
- `agents/gsd-executor.md`: Plan execution with atomic commits, checkpoint handling, state management
- `agents/gsd-verifier.md`: Goal verification by checking actual codebase, not SUMMARY claims
- `agents/gsd-project-researcher.md`: Domain ecosystem research before roadmap creation

**Project State (in .planning/ - created during /gsd:new-project):**
- `.planning/STATE.md`: Current execution position, accumulated decisions, blockers
- `.planning/ROADMAP.md`: Master phase breakdown (all phases, descriptions, must-haves)
- `.planning/config.json`: Model profile (quality/balanced/budget), workflow settings (research enabled, verifier enabled)
- `.planning/codebase/ARCHITECTURE.md`: Codebase architecture analysis
- `.planning/codebase/STRUCTURE.md`: Codebase file structure and naming conventions
- `.planning/phases/{PHASE}/*.md`: Phase-specific files (CONTEXT, PLAN, SUMMARY, VERIFICATION)

## Naming Conventions

**Files:**

- **Agents:** `gsd-{purpose}.md` (e.g., `gsd-planner.md`, `gsd-project-researcher.md`) or `{role}-{context}.md` in project-agents
- **Commands:** `{command-name}.md` (e.g., `plan-phase.md`, `execute-phase.md`)
- **Rules:** `{concern}.md` (e.g., `git-commits.md`, `python-standards.md`)
- **Hooks:** `{trigger}-{purpose}.py` (e.g., `block-sensitive.py`, `post-tool-format.py`)
- **Analysis docs:** `{CONCERN}.md` in UPPERCASE (e.g., `ARCHITECTURE.md`, `STRUCTURE.md`, `CONVENTIONS.md`)
- **Project state:** `STATE.md`, `ROADMAP.md`, `CONTEXT.md` (root); `{PHASE}-*.md` in phase directories

**Directories:**

- **Agents:** lowercase with dashes (`gsd-planner`, `project-agents/llm-efficiency-measurement-tool`)
- **Commands:** logical grouping by system (`gsd/`, `other-commands/`)
- **Rules:** standalone files in `rules/` root
- **Project agents:** `project-agents/{project-slug}/` where slug uses hyphens and lowercase
- **Phases:** `.planning/phases/{PHASE}-{slug}` where PHASE is zero-padded (`01-setup`, `02-core-features`, `02.1-subphase`)

## Where to Add New Code

**New GSD Agent:**
- Primary code: `agents/gsd-{purpose}.md` (e.g., `agents/gsd-integration-checker.md`)
- Pattern: YAML frontmatter with name/description/tools, then <role>, <execution_flow>, return structured results
- Reference: See `agents/gsd-executor.md` or `agents/gsd-planner.md` for full examples

**New GSD Command:**
- Primary code: `commands/gsd/{command-name}.md` (e.g., `commands/gsd/debug-phase.md`)
- Pattern: YAML frontmatter with argument-hint and agent assignment, then <objective>, <context>, <process> with numbered steps
- Reference: See `commands/gsd/plan-phase.md` for orchestration pattern

**New Behavior Rule:**
- Primary code: `rules/{concern}.md` (e.g., `rules/docker-practices.md`)
- Pattern: Markdown with clear guidelines, examples (code blocks), decision tables
- Load: Add symlink in `~/.claude/rules/` during manual setup, or run setup.sh to symlink entire rules/ directory

**New Project-Specific Agent:**
- Primary code: `project-agents/{project-slug}/{agent-role}.md`
- Pattern: Same as GSD agents, but domain-specialized for the project
- Usage: Projects copy to their `.claude/agents/` during onboarding; updated via sync-project-agents.sh

**New Hook:**
- Primary code: `hooks/{trigger}-{purpose}.{py|js}` (e.g., `hooks/pre-tool-analyze.py`)
- Pattern: Takes stdin JSON, exits with 0 (allow) or 2 (block), writes to stderr on block
- Registration: Add to `settings.json` hooks section under PreToolUse or PostToolUse

## Special Directories

**_archive/**
- Purpose: Historical agents and configs (no longer in use but kept for reference)
- Generated: No
- Committed: Yes (preserved history)

**.planning/ (created during /gsd:new-project)**
- Purpose: Project planning artifacts (state, roadmap, phase files, analysis)
- Generated: Yes (created by orchestrators)
- Committed: Usually yes (tracked in project's git)
- Config: Determined by `.planning/config.json` `commit_docs` field or git's `check-ignore .planning`

**.git/info/exclude (local, not committed)**
- Purpose: Local-only exclusions (CLAUDE.md, personal notes)
- Generated: No (manually edited per project)
- Committed: No (local-only)
- Pattern: Add `CLAUDE.md` and `claude_*.md` entries here per rules/git-exclude.md

**.ruff_cache/**
- Purpose: Ruff formatter cache
- Generated: Yes (auto-created on first run)
- Committed: No (.gitignore)

**.claude/ (symlinked during setup)**
- Purpose: Claude Code local state
- Generated: Yes (Claude Code creates runtime state)
- Committed: No (.gitignore)

## Frontmatter Patterns

**Agent Frontmatter:**
```yaml
---
name: gsd-{purpose}
description: One-line description of agent purpose
tools: Read, Write, Bash, Grep, Glob, Task, WebFetch  # Tools agent is allowed to use
color: cyan  # Color for orchestrator display
---
```

**Command Frontmatter:**
```yaml
---
name: gsd:command-name
description: One-line description of command
argument-hint: "[phase] [--flag]"  # Usage hint
agent: gsd-{subagent}  # Which agent handles this command
allowed-tools: [Read, Write, Bash, Task]  # Tools available in orchestrator
---
```

**Plan Frontmatter (created by planner):**
```yaml
---
phase: 02
plan: 01
type: feature|refactor|bugfix|docs|testing
autonomous: true|false  # Whether executor can proceed without checkpoints
wave: 1  # Execution wave (all wave 1 tasks run in parallel)
depends_on: []  # Other plans that must complete first
---
```

---

*Structure analysis: 2026-02-06*
