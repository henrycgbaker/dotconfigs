# Codebase Structure

**Analysis Date:** 2026-02-10

## Directory Layout

```
dotconfigs/
├── dotconfigs                      # CLI entry point (primary, executable)
├── dots                            # Convenience symlink → dotconfigs
├── .env                            # Configuration store (gitignored, wizard-managed)
├── .env.example                    # Configuration reference (complete key list)
├── lib/                            # Shared bash libraries (sourced, no shebangs)
│   ├── colours.sh                  # TTY-aware colour output, status symbols
│   ├── config.sh                   # Configuration SSOT, hierarchy documentation
│   ├── discovery.sh                # Plugin/hook/skill/section discovery
│   ├── symlinks.sh                 # Symlink management, ownership detection
│   ├── validation.sh               # Git repo validation helpers
│   └── wizard.sh                   # Interactive prompts, .env management
├── plugins/
│   ├── claude/
│   │   ├── setup.sh                # Claude setup wizard
│   │   ├── deploy.sh               # Claude deployment logic (symlinks, assembly)
│   │   ├── project.sh              # Per-repo scaffolding
│   │   ├── DESCRIPTION             # Plugin metadata
│   │   ├── settings.json           # Assembled settings (generated, gitignored)
│   │   ├── CLAUDE.md               # Assembled CLAUDE.md (generated, gitignored)
│   │   ├── hooks/
│   │   │   ├── block-destructive.sh   # PreToolUse guard
│   │   │   └── post-tool-format.py    # PostToolUse Ruff formatter
│   │   ├── commands/               # Skills (/commit, /squash-merge, /pr-review, /simplicity-check)
│   │   │   ├── commit.md
│   │   │   ├── pr-review.md
│   │   │   ├── simplicity-check.md
│   │   │   └── squash-merge.md
│   │   └── templates/
│   │       ├── claude-md/          # CLAUDE.md section templates (01-communication.md, etc.)
│   │       ├── settings/           # settings.json templates (base.json, python.json, node.json, etc.)
│   │       └── claude-hooks.conf   # Hook configuration template
│   └── git/
│       ├── setup.sh                # Git setup wizard
│       ├── deploy.sh               # Git deployment logic
│       ├── project.sh              # Per-repo hooks + identity
│       ├── DESCRIPTION             # Plugin metadata
│       ├── hooks/                  # Git hooks (commit-msg, pre-commit, pre-push, etc.)
│       │   ├── commit-msg          # AI attribution blocking, conventional commits
│       │   ├── post-checkout
│       │   ├── post-merge
│       │   ├── post-rewrite
│       │   ├── pre-commit
│       │   ├── pre-push
│       │   └── prepare-commit-msg
│       └── templates/
│           └── git-hooks.conf      # Per-project hook config template
├── scripts/                        # Utility scripts
│   ├── generate-roster.sh          # Auto-generates docs/ROSTER.md from hook metadata
│   └── registry-scan.sh            # Registry scanning utility
├── tests/                          # Test validation
│   └── test-project-configs.sh     # Comprehensive scaffold validation
├── docs/                           # User documentation
│   ├── ROSTER.md                   # Complete hook/command/config reference (generated)
│   └── usage-guide.md              # Claude Code configuration guide
├── project-agents/                 # Project-specific agent variants
│   ├── deep_learning_lab_teaching_2025/
│   ├── ds01-infra/
│   └── llm-efficiency-measurement-tool/
├── .planning/                      # GSD planning (created during setup)
│   ├── codebase/                   # Analysis documents
│   │   ├── ARCHITECTURE.md         # This file's companion
│   │   ├── STRUCTURE.md            # This file
│   │   ├── CONVENTIONS.md
│   │   ├── CONCERNS.md
│   │   ├── TESTING.md
│   │   ├── STACK.md
│   │   └── INTEGRATIONS.md
│   └── ...
└── README.md                       # Project overview, quick start
```

## Directory Purposes

**lib/**
- Purpose: Shared bash libraries sourced by entry point and all plugins
- Contains: Reusable abstractions (wizards, symlinks, discovery, colours, validation)
- Key files: `wizard.sh` (interactive prompts), `symlinks.sh` (deployment), `discovery.sh` (plugin scanning)

**plugins/claude/**
- Purpose: Claude Code configuration management
- Contains: Setup wizard, deployment logic, per-repo scaffolding, hooks, skills, templates
- Key files: `setup.sh` (interacts with user), `deploy.sh` (applies to ~/.claude/), `project.sh` (per-repo setup)

**plugins/git/**
- Purpose: Git configuration management
- Contains: Setup wizard, deployment logic, per-repo hooks, git config application
- Key files: `setup.sh` (wizard), `deploy.sh` (git config writes), `project.sh` (copies hooks)

**plugins/*/templates/**
- Purpose: Template sources for assembly or copying
- Claude: CLAUDE.md sections (markdown), settings.json bases (JSON), hook config (conf)
- Git: Hook configuration template (conf)

**plugins/*/hooks/**
- Purpose: Event-triggered automation
- Claude: PreToolUse guard (block-destructive.sh), PostToolUse formatter (post-tool-format.py)
- Git: 7 git hooks for validation, protection, and automation

**plugins/*/commands/**
- Purpose: Claude Code skills (user-invoked commands)
- Contains: Markdown-based skill definitions (commit.md, squash-merge.md, etc.)

**scripts/**
- Purpose: Utility and build scripts
- generate-roster.sh: Auto-generates docs/ROSTER.md from hook/command metadata
- registry-scan.sh: Registry introspection utility

**docs/**
- Purpose: User documentation
- ROSTER.md: Complete reference of all hooks, commands, and configuration options (generated)
- usage-guide.md: Guide to Claude Code configuration types and usage patterns

**project-agents/**
- Purpose: Version-controlled record of project-specific agent variants
- Contains: Specialized agents per project domain (research-scientist, systems-architect, etc.)

**.planning/codebase/**
- Purpose: Analysis documents consumed by GSD planning/execution
- ARCHITECTURE.md: System pattern, layers, data flow, abstractions
- STRUCTURE.md: This file - directory layout, naming, where to add code
- CONVENTIONS.md: Coding style, naming patterns, import organization
- TESTING.md: Test framework, structure, common patterns
- CONCERNS.md: Technical debt, known issues, scalability limits

## Key File Locations

**Entry Points:**
- `dotconfigs`: Main CLI script, routes to command handlers
- `plugins/claude/setup.sh`: Claude wizard entry (sourced by dotconfigs)
- `plugins/git/setup.sh`: Git wizard entry (sourced by dotconfigs)

**Configuration:**
- `.env`: Single source of truth for all user preferences (gitignored)
- `.env.example`: Reference of all available configuration keys
- `lib/config.sh`: Documents configuration hierarchy and variable naming

**Global Deployment:**
- `plugins/claude/deploy.sh`: Claude global deployment (symlinks to ~/.claude/)
- `plugins/git/deploy.sh`: Git deployment (git config --global writes)

**Per-Project Setup:**
- `plugins/claude/project.sh`: Scaffolds .claude/ in projects
- `plugins/git/project.sh`: Copies hooks and optional identity to projects

**Hooks:**
- `plugins/claude/hooks/block-destructive.sh`: PreToolUse guard
- `plugins/claude/hooks/post-tool-format.py`: PostToolUse Ruff formatter
- `plugins/git/hooks/commit-msg`: Conventional commit validation
- `plugins/git/hooks/pre-push`: Branch protection (main/master)

**Templates:**
- `plugins/claude/templates/claude-md/`: CLAUDE.md sections (01-communication.md, etc.)
- `plugins/claude/templates/settings/`: settings.json templates (base.json, python.json, etc.)
- `plugins/git/templates/git-hooks.conf`: Hook configuration template

## Naming Conventions

**Files:**

- **Plugin scripts:** `{command}.sh` (setup.sh, deploy.sh, project.sh)
- **Hooks:** `{trigger}[-purpose]` (block-destructive.sh, post-tool-format.py, commit-msg)
- **Skills/Commands:** `{skill-name}.md` (commit.md, squash-merge.md)
- **Templates:** `{number}-{name}.md` for sections (01-communication.md), `base.json` or `{lang}.json` for settings
- **Lib files:** `{concern}.sh` (wizard.sh, symlinks.sh, discovery.sh)
- **Config:** `.env` (gitignored), `.env.example` (reference)

**Directories:**

- **Plugins:** `plugins/{plugin-name}/` (claude, git)
- **Plugin subdirs:** `setup.sh` + `deploy.sh` + `project.sh` (no dirs)
- **Templates:** `templates/{type}/` (claude-md/, settings/)
- **Hooks:** `hooks/` (flat directory)
- **Commands:** `commands/` (flat directory)
- **Shared libs:** `lib/` with individual `{concern}.sh` files

## Where to Add New Code

**New Plugin:**
- Primary code: `plugins/{plugin-name}/setup.sh`, `deploy.sh`, `project.sh`
- Plugin discovery: Entry point scans `plugins/*/` for both files
- Pattern: Functions named `plugin_{plugin_name}_{command}()` (e.g., `plugin_myapp_setup()`)
- Reference: See `plugins/claude/setup.sh` and `plugins/git/setup.sh` for patterns

**New Claude Hook:**
- Primary code: `plugins/claude/hooks/{trigger}-{purpose}.{sh|py}`
- Registration: Add to wizard option in `plugins/claude/setup.sh` and list in DESCRIPTION
- Pattern: Hooks are copied/symlinked to ~/.claude/hooks/ by deploy
- Example: `block-destructive.sh` (PreToolUse), `post-tool-format.py` (PostToolUse)

**New Claude Skill/Command:**
- Primary code: `plugins/claude/commands/{skill-name}.md`
- Registration: Add to wizard and hooks config template
- Pattern: Markdown files defining /command capabilities for Claude Code
- Example: `commit.md`, `squash-merge.md`, `pr-review.md`

**New Claude CLAUDE.md Section:**
- Primary code: `plugins/claude/templates/claude-md/{number}-{section-name}.md`
- Numbering: Continue existing sequence (01-communication, 02-simplicity, etc.)
- Registration: Discovered automatically via `discover_claude_sections()`
- Pattern: User toggles in wizard, sections assembled in order

**New Git Hook:**
- Primary code: `plugins/git/hooks/{hook-name}` (no extension)
- Hook types: commit-msg, pre-commit, pre-push, prepare-commit-msg, post-merge, post-checkout, post-rewrite
- Pattern: Executables copied to .git/hooks/ by project setup
- Reference: See existing hooks for config file discovery pattern

**New Settings.json Template:**
- Primary code: `plugins/claude/templates/settings/{type}.json` (e.g., rust.json, go.json)
- Base: All extend `settings-template.json`
- Pattern: Language-specific permission/hook overrides
- Examples: `base.json`, `python.json`, `node.json`

**New Lib Function:**
- Primary code: `lib/{concern}.sh`
- Sourced by: Entry point (eager load of all lib/*.sh) and all plugins
- Pattern: Functions, no shebangs, designed for bash 3.2 compatibility
- Examples: `wizard_prompt()`, `backup_and_link()`, `discover_plugins()`

**New Test:**
- Primary code: `tests/{test-purpose}.sh`
- Pattern: Bash script that validates deployments and configuration
- Example: `test-project-configs.sh` validates scaffold creation

## Special Directories

**.env (gitignored)**
- Purpose: Runtime configuration store (user preferences)
- Generated: Yes (created by setup wizard)
- Committed: No (per-machine, gitignored)
- Sourced by: All plugins to read configuration

**.planning/ (created during setup, may be committed)**
- Purpose: GSD framework artifacts (planning, execution, analysis)
- Generated: Yes (created by GSD framework)
- Committed: Usually yes (tracked in project's git)
- Contents: STATE.md, ROADMAP.md, phases/, codebase/ analysis

**plugins/*/settings.json (gitignored)**
- Purpose: Generated Claude Code settings (assembled from templates)
- Generated: Yes (assembled by deploy)
- Committed: No (gitignored, user-edited after generation)
- Use: Copy to ~/.claude/settings.json via symlink

**plugins/*/CLAUDE.md (gitignored)**
- Purpose: Generated Claude Code instructions (assembled from section templates)
- Generated: Yes (assembled from enabled sections)
- Committed: No (gitignored, user-edited after generation)
- Use: Symlinked to ~/.claude/CLAUDE.md

## Conventions for Plugin Development

**Function Naming:**
- Plugin functions: `plugin_{name}_{command}()` (e.g., `plugin_claude_setup()`, `plugin_git_deploy()`)
- Internal functions: `_{name}_{function}()` (e.g., `_claude_load_config()`, `_git_detect_drift()`)
- Shared lib functions: `{verb}_{noun}()` (e.g., `wizard_prompt()`, `backup_and_link()`)

**Variable Naming:**
- Plugin config: `{PLUGIN_UPPERCASE}_*` (e.g., `CLAUDE_DEPLOY_TARGET`, `GIT_USER_NAME`)
- Internal vars: `lowercase_with_underscores`
- Constants: `UPPERCASE_WITH_UNDERSCORES`

**Error Handling:**
- Exit code 1 on failure
- Error messages to stderr with `>&2`
- Use validation functions: `plugin_exists()`, `validate_git_repo()` before proceeding

**Bash Compatibility:**
- Bash 3.2 compatible (macOS requirement)
- Avoid bash 4+ features like nameref variables (`local -n`)
- Use `perl` fallback for `readlink -f` on macOS

## Bash 3.2 Compatibility Notes

**Incompatible constructs to avoid:**
- `local -n` (namerefs) - bash 4+
- `declare -n` (namerefs) - bash 4+
- `${var/pattern/replace}` (pattern expansion edge cases) - use `sed` instead
- Arithmetic via bash `$(())` works but use with caution

**Working alternatives:**
- Nameref workaround: `eval "var=\$((\$$var + 1))"` for counter increment
- Use `sed` or `tr` for string manipulation
- Use `perl` for path resolution (readlink -f fallback)

---

*Structure analysis: 2026-02-10*
