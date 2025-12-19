# Claude Code Configuration Guide

Comprehensive guide to configuring Claude Code with agents, rules, commands, skills, hooks, and settings.

## Table of Contents

1. [Configuration Types Overview](#configuration-types-overview)
2. [Loading & Token Impact](#loading--token-impact)
3. [CLAUDE.md Memory System](#claudemd-memory-system)
4. [Rules](#rules)
5. [Agents](#agents)
6. [Skills](#skills)
7. [Commands](#commands)
8. [Hooks](#hooks)
9. [Settings](#settings)
10. [Decision Workflows](#decision-workflows)
11. [Best Practices](#best-practices)
12. [Token Efficiency](#token-efficiency)
13. [User Flows](#user-flows)

---

## Configuration Types Overview

| Type | Loaded | Token Cost | Invocation | Priority |
|------|--------|------------|------------|----------|
| **CLAUDE.md** | Startup | YES (all content) | Always active | Instructions |
| **Rules** | Startup | YES (all content) | Always active | Standards |
| **Settings** | Startup | NO | Always active | Config |
| **Agents** | On-demand | NO (until invoked) | Claude decides or user requests | Delegation |
| **Skills** | On-demand | NO (until invoked) | Claude auto-discovers | Capability |
| **Commands** | On-demand | NO (until invoked) | User types `/command` | Explicit |
| **Hooks** | Startup (config) | NO | Tool events trigger | Automation |

### Hard vs Soft Constraints

| Type | Enforcement | Can Override? |
|------|-------------|---------------|
| **CLAUDE.md** | Soft | Claude can deviate with reason |
| **Rules** | Soft | Claude should follow, not forced |
| **Settings permissions.deny** | Hard | Blocked entirely |
| **Settings permissions.allow** | Soft | Permitted without asking |
| **Hooks exit code 2** | Hard | Blocks operation |
| **Agent tools** | Hard | Agent can't use unlisted tools |
| **Managed settings** | Hard | Enterprise can't override |

---

## Loading & Token Impact

### Startup Sequence

```
1. Load managed settings (Enterprise)
2. Load command-line args
3. Load .claude/settings.local.json
4. Load .claude/settings.json
5. Load ~/.claude/settings.json
6. Apply permission rules
7. Discover & load CLAUDE.md files (all levels)
8. Discover & load rules (all .md in rules/)
9. Index agent metadata (not full content)
10. Index skill metadata (not full content)
11. Index MCP tools
12. Snapshot hook configuration
→ Ready for session
```

### What Counts Toward Tokens

| Source | Startup Cost | Runtime Cost |
|--------|--------------|--------------|
| CLAUDE.md | **500-2000 tokens** | - |
| Rules | **500-5000 tokens** | - |
| Settings | 0 | - |
| Agent metadata | ~10 tokens each | **500-3000 on invoke** |
| Skill metadata | ~10 tokens each | **300-2000 on activate** |
| Hooks | 0 | 0 (external process) |
| MCP tools | ~5 tokens each | varies by response |

### Typical Token Overhead

```
Minimal setup:    ~500 tokens
Standard setup:   ~1500 tokens
Comprehensive:    ~5000 tokens
```

---

## CLAUDE.md Memory System

### Purpose
Long-term memory and instructions Claude follows throughout the session.

### Location Precedence (highest to lowest)

```
1. Enterprise:     /Library/Application Support/ClaudeCode/CLAUDE.md
2. Project:        ./.claude/CLAUDE.md or ./CLAUDE.md
3. Project rules:  ./.claude/rules/*.md
4. User:           ~/.claude/CLAUDE.md
5. User rules:     ~/.claude/rules/*.md
6. Project local:  ./.claude/CLAUDE.local.md (gitignored)
```

### When to Use

| Use CLAUDE.md For | Don't Use For |
|-------------------|---------------|
| Project overview | Implementation details |
| Architecture decisions | Step-by-step tutorials |
| Team conventions | Information in code |
| Common commands | One-time instructions |

### Optimal Structure

```markdown
# Project Name

Brief description (1-2 sentences).

## Architecture
[High-level component overview]

## Key Conventions
- Convention 1
- Convention 2

## Common Tasks
[Frequently used commands]

## See Also
- `rules/testing.md` for test conventions
```

### Import Syntax

```markdown
Read additional context from:
@./docs/architecture.md
```

Max import depth: 5 levels.

---

## Rules

### Purpose
Always-loaded standards organized by topic. Better than monolithic CLAUDE.md for maintainability.

### Location

```
.claude/rules/     # Project rules (shared)
~/.claude/rules/   # User rules (personal)
```

### When to Use Rules vs CLAUDE.md

| Use Rules For | Use CLAUDE.md For |
|---------------|-------------------|
| Code style standards | Project overview |
| Language-specific conventions | Architecture context |
| Security requirements | Team workflow |
| Testing patterns | Quick reference |
| Modular, maintainable guidelines | Single source of truth |

### Structure

```markdown
# Python Standards

> Applied when working with Python files.

## Formatting
- Ruff as formatter (100 char line length)
- Run `ruff format` before committing

## Type Hints
- Required for public functions
- Use `list[str]` not `List[str]`
```

### Organization Pattern

```
.claude/rules/
├── code-style.md      # Language formatting
├── testing.md         # Test conventions
├── security.md        # Security requirements
├── api.md             # API design standards
└── git.md             # Git conventions
```

---

## Agents

### Purpose
Specialized AI personas that run in **separate context windows**. Use for complex tasks requiring domain expertise.

### Location

```
.claude/agents/      # Project agents
~/.claude/agents/    # User agents (global)
```

### When Claude Uses Agents

1. **Task matches agent description** - primary trigger
2. **User explicitly requests** - "Use the code-reviewer agent"
3. **Agent has relevant tools** for the task

### Agent Definition

```yaml
---
name: code-reviewer
description: Expert code reviewer for quality, security, and maintainability.
             Use after writing or modifying code.
tools: Bash, Grep, Glob, Read, Edit, Write
model: opus
permissionMode: acceptEdits
---

# Code Reviewer

You are an expert code reviewer...

[System prompt content]
```

### Key Properties

| Property | Effect |
|----------|--------|
| `name` | Identifier for invocation |
| `description` | **Critical** - determines when Claude uses agent |
| `tools` | Hard limit - agent can only use listed tools |
| `model` | Which Claude model (haiku, sonnet, opus) |
| `permissionMode` | How agent handles permissions |

### Permission Modes

| Mode | Behavior |
|------|----------|
| `default` | Ask for each tool use |
| `acceptEdits` | Auto-approve Read/Edit/Write |
| `bypassPermissions` | Skip all permission prompts |
| `plan` | Read-only, advisory mode |

### Token Impact

- **Startup**: ~10 tokens (metadata only)
- **On invoke**: 500-3000 tokens (full system prompt)
- Runs in **separate context** - doesn't consume main conversation tokens

### When to Create vs Direct Approach

| Create Agent When | Use Direct Approach When |
|-------------------|--------------------------|
| Complex domain expertise needed | Simple, one-off task |
| Long multi-step workflow | Task fits current context |
| Different tool set required | Shares same tools |
| Want to preserve main context | Context isn't constrained |

---

## Skills

### Purpose
Reusable capabilities Claude **automatically discovers** and invokes when relevant.

### Location

```
.claude/skills/skill-name/SKILL.md    # Project skills
~/.claude/skills/skill-name/SKILL.md  # User skills
```

### When Claude Uses Skills

- **Autonomous** - Claude decides based on description matching request
- **NOT user-invoked** - unlike `/commands`
- Keywords in description trigger activation

### Skill Definition

```yaml
---
name: pdf-processor
description: Extract text from PDFs, fill forms, merge documents.
             Use when working with PDF files or document extraction.
allowed-tools: Read, Bash
---

# PDF Processor

Instructions for processing PDFs...

## Supported Operations
- Text extraction: `pdftotext`
- Form filling: `pdftk`
- Merging: `pdfunite`
```

### Token Impact

- **Startup**: ~10 tokens (metadata only)
- **On activation**: 300-2000 tokens (SKILL.md content)

### Skill vs Agent vs Command

| Use Skill When | Use Agent When | Use Command When |
|----------------|----------------|------------------|
| Task-specific capability | Domain expertise needed | User wants explicit control |
| Auto-discovery desired | Separate context needed | Parameters required |
| Single-purpose utility | Long workflow | One-time action |

### Writing Effective Descriptions

```yaml
# Good - specific triggers
description: Generate database migrations, schema changes, and model updates.
             Use when working with Django ORM, SQLAlchemy, or database schemas.

# Bad - too vague
description: Help with database stuff.
```

Include both **what** it does and **when** to use it.

---

## Commands

### Purpose
User-invoked actions via `/command-name`. Explicit control over execution.

### Location

```
.claude/commands/command-name.md    # Project commands
~/.claude/commands/command-name.md  # User commands
```

### Built-in Commands

| Command | Purpose |
|---------|---------|
| `/help` | Show help |
| `/config` | View configuration |
| `/memory` | View loaded memory |
| `/agents` | List available agents |
| `/hooks` | List configured hooks |
| `/clear` | Clear conversation |

### Custom Command Definition

```markdown
---
name: deploy
description: Deploy the application to staging environment
---

Deploy the current branch to staging:

1. Run tests: `pytest`
2. Build: `docker build -t app:staging .`
3. Push: `docker push app:staging`
4. Deploy: `kubectl apply -f k8s/staging/`

Report deployment status when complete.
```

### Parameters

Commands receive arguments:
- `$ARGUMENTS` - full argument string
- `$1`, `$2`, etc. - individual arguments

```markdown
---
name: search
description: Search codebase for pattern
---

Search for "$1" in the codebase using grep.
Show files and line numbers.
```

Usage: `/search "TODO"`

---

## Hooks

### Purpose
Automate actions on tool events. Run **outside Claude's context** (zero token cost).

### Location

Configured in `settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [...],
    "PostToolUse": [...],
    "UserPromptSubmit": [...],
    ...
  }
}
```

### Hook Events

| Event | When | Use Case |
|-------|------|----------|
| `PreToolUse` | Before tool executes | Validate, block, modify |
| `PostToolUse` | After tool completes | Auto-format, lint, notify |
| `UserPromptSubmit` | User sends message | Pre-process input |
| `PermissionRequest` | Permission dialog shown | Custom permission logic |
| `SessionStart` | Session begins | Setup environment |
| `Stop` | Claude stops | Cleanup, logging |

### Hook Configuration

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "python ~/.claude/hooks/format.py"
          }
        ]
      }
    ]
  }
}
```

### Matcher Patterns

| Pattern | Matches |
|---------|---------|
| `Write` | Only Write tool |
| `Edit\|Write` | Edit OR Write |
| `Bash` | Only Bash tool |
| `mcp__server__.*` | All tools from MCP server |

### Exit Codes

| Code | Effect |
|------|--------|
| 0 | Success - continue |
| 2 | **Block** - stop operation |
| Other | Warning - continue |

### Hook Input/Output

**Input (JSON on stdin):**
```json
{
  "hook_event_name": "PostToolUse",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/src/index.ts",
    "content": "..."
  }
}
```

**Output (JSON on stdout, optional):**
```json
{
  "continue": true,
  "systemMessage": "Formatted with prettier"
}
```

### Token Impact

**Zero** - hooks run as external processes, not in Claude's context.

---

## Settings

### Purpose
Configuration for permissions, environment, hooks, and behavior.

### Location Precedence

```
1. Managed (Enterprise)     # Cannot override
2. Command-line args
3. .claude/settings.local.json   # Personal, gitignored
4. .claude/settings.json         # Project shared
5. ~/.claude/settings.json       # User defaults
```

### Key Settings

```json
{
  "permissions": {
    "allow": ["Bash(npm:*)", "Bash(git:*)"],
    "ask": ["Bash(docker:*)"],
    "deny": ["Read(.env)", "Read(**/.ssh/*)"]
  },
  "env": {
    "PYTHONDONTWRITEBYTECODE": "1"
  },
  "hooks": { ... },
  "sandbox": {
    "enabled": true,
    "excludedCommands": ["docker", "nvidia-smi"]
  }
}
```

### Permission Rules

| Rule | Effect |
|------|--------|
| `allow` | Auto-approve without asking |
| `ask` | Always ask user (even if normally allowed) |
| `deny` | **Hard block** - cannot access |

### Pattern Syntax

```
Read(.env)           # Specific file
Read(**/.ssh/*)      # Glob pattern
Bash(npm:*)          # Command prefix
Bash(rm -rf /)       # Specific command
```

---

## Decision Workflows

### How Claude Decides: Agent vs Direct

```
User Request
    ↓
Does task match an agent description?
    ↓ YES                    ↓ NO
Invoke agent          Execute directly
(new context)         (current context)
```

**Agent triggered when:**
1. Task keywords match agent `description`
2. Agent has tools needed for task
3. User explicitly requests agent

### How Claude Decides: Skill Activation

```
User Request
    ↓
Does request match skill description?
    ↓ YES                    ↓ NO
Load skill content    Continue without
into context          skill
```

**Skill activated when:**
1. Keywords match skill description
2. File types suggest skill relevance
3. Task context aligns with skill purpose

### Hook Execution Flow

```
Tool Request (e.g., Edit)
    ↓
PreToolUse hooks (matcher: Edit)
    ↓ Exit 2 = BLOCK
    ↓ Exit 0 = Continue
Execute Tool
    ↓
PostToolUse hooks (matcher: Edit)
    ↓
Continue
```

### Permission Flow

```
Tool Request
    ↓
Check deny rules → BLOCKED
    ↓ Not denied
Check allow rules → APPROVED
    ↓ Not allowed
Check ask rules → ASK USER
    ↓ Not in ask
Default behavior → ASK or APPROVE
```

---

## Best Practices

### CLAUDE.md

| Do | Don't |
|----|-------|
| Keep under 200 lines | Write tutorials |
| Focus on architecture | Duplicate code comments |
| Link to rules for details | Include implementation details |
| Update when architecture changes | Add one-time instructions |

### Rules

| Do | Don't |
|----|-------|
| One topic per file | One giant rules file |
| 20-100 lines each | Duplicate CLAUDE.md content |
| Clear, actionable standards | Vague suggestions |
| Update when standards change | Let rules go stale |

### Agents

| Do | Don't |
|----|-------|
| Specific description with triggers | Vague "helps with X" |
| 2-5 agents per project | Agent for every task |
| Clear single responsibility | Overlapping agents |
| Test agent manually first | Deploy untested agents |

### Skills

| Do | Don't |
|----|-------|
| Include "when to use" in description | Just describe what it does |
| Specific trigger keywords | Generic descriptions |
| Supporting files in skill dir | Everything in SKILL.md |

### Hooks

| Do | Don't |
|----|-------|
| Test scripts manually first | Deploy untested hooks |
| Exit 0 on success | Forget exit codes |
| Handle errors gracefully | Let hooks crash |
| Log for debugging | Silent failures |

### Settings

| Do | Don't |
|----|-------|
| Minimal permissions in deny | Over-permissive allow |
| Team settings in .claude/settings.json | Personal prefs in shared |
| Personal overrides in .local.json | Commit .local.json |

---

## Token Efficiency

### Checklist

- [ ] CLAUDE.md under 200 lines
- [ ] Rules organized by topic (not monolithic)
- [ ] Imports limited to 2-3 deep
- [ ] Unused agents removed
- [ ] Skill descriptions specific (reduce false activations)
- [ ] No duplicate content between CLAUDE.md and rules

### Typical Impact

| Configuration | Token Overhead |
|---------------|----------------|
| Minimal (CLAUDE.md only) | ~200 tokens |
| Standard (CLAUDE.md + 5 rules) | ~1500 tokens |
| Comprehensive (full setup) | ~3000-5000 tokens |

### Reduction Strategies

1. **Move details to rules** - split by topic
2. **Use imports sparingly** - only essential context
3. **Keep agent prompts focused** - don't copy CLAUDE.md
4. **Make skill descriptions specific** - reduce false activations

---

## User Flows

### Adding a New Rule

```
1. Create .claude/rules/topic.md
2. Add standards in markdown format
3. Rule auto-loads on next session
4. No restart needed for new files
```

### Creating a Project Agent

```
1. Create .claude/agents/agent-name/agent-name.md
2. Add frontmatter (name, description, tools, model)
3. Write system prompt
4. Test: "Use the agent-name agent to..."
5. Refine description for better auto-triggering
```

### Adding a Hook

```
1. Create hook script in ~/.claude/hooks/
2. Make executable: chmod +x script.py
3. Add to settings.json hooks section
4. Restart Claude Code
5. Test by triggering the tool event
```

### Debugging Hook Issues

```
1. Run hook manually: echo '{"tool_name":"Write"}' | ./hook.py
2. Check exit code: echo $?
3. View Claude debug logs: /debug
4. Check hook is listed: /hooks
```

### Syncing Config Across Machines

```bash
# On primary machine
cd ~/Repositories/dotclaude
git add . && git commit -m "Update config"
git push

# On other machine
cd ~/Repositories/dotclaude
git pull
# Symlinks auto-update
```
