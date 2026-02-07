# Portable Claude Code Configuration Architecture

Research document for architecting a git-based, portable Claude Code configuration system (dotclaude) that deploys across multiple environments: macOS workstations, SSH servers, Docker containers, and CI/CD pipelines.

## Table of Contents

1. [Directory Structure](#directory-structure)
2. [Deployment Architecture](#deployment-architecture)
3. [Configuration Hierarchy](#configuration-hierarchy)
4. [Data Flow](#data-flow)
5. [Component Boundaries](#component-boundaries)
6. [Build Order](#build-order)

---

## Directory Structure

### Current State Analysis

The existing dotclaude repo has this structure:

```
dotclaude/
├── CLAUDE.md                # User policies & preferences
├── settings.json            # Claude settings template
├── agents/                  # Global GSD agents (11 files)
├── rules/                   # Behavioural standards (6 files)
├── hooks/                   # Claude pre/post tool-use scripts (4 files)
├── commands/                # User-invoked /commands
│   ├── commit.md
│   ├── squash-merge.md
│   └── gsd/                 # GSD framework commands (27 files)
├── skills/                  # Model-invoked capabilities (empty currently)
├── project-agents/          # Version-controlled project agent registry
│   ├── llm-efficiency-measurement-tool/
│   ├── ds01-infra/
│   └── deep_learning_lab_teaching_2025/
├── githooks/                # Git hook templates for repos
│   ├── pre-commit
│   └── commit-msg
├── gitignore_global         # Global gitignore template
├── setup.sh                 # Local deployment script
├── deploy-remote.sh         # SSH deployment script
├── sync-project-agents.sh   # Project agent sync utility
└── docs/                    # Documentation
```

### Proposed Enhanced Structure

```
dotclaude/
├── README.md                         # Quick start, overview
├── CLAUDE.md                         # User global policies
│
├── core/                             # Core configuration (always deployed)
│   ├── settings.json                 # Base settings template
│   ├── rules/                        # Always-loaded standards
│   │   ├── git-commits.md
│   │   ├── python-standards.md
│   │   ├── simplicity-first.md
│   │   ├── git-exclude.md
│   │   ├── git-workflow.md
│   │   ├── modular-claude-docs.md
│   │   └── no-unnecessary-files.md
│   └── hooks/                        # Claude tool-use hooks
│       ├── post-tool-format.py
│       ├── block-sensitive.py
│       ├── gsd-statusline.js
│       └── gsd-check-update.js
│
├── agents/                           # Global reusable agents
│   ├── gsd-planner.md               # GSD framework agents
│   ├── gsd-executor.md
│   ├── gsd-codebase-mapper.md
│   └── [other GSD agents]
│
├── commands/                         # User-invoked slash commands
│   ├── commit.md
│   ├── squash-merge.md
│   ├── pr-review.md
│   └── gsd/                          # GSD framework commands
│       ├── new-project.md
│       ├── execute-phase.md
│       └── [other GSD commands]
│
├── skills/                           # Model-invoked capabilities
│   └── [reserved for future]
│
├── project-agents/                   # Project agent registry (VCS)
│   ├── {project-name}/
│   │   ├── agent-1.md
│   │   └── agent-2.md
│   └── README.md                     # Registry index
│
├── templates/                        # Starter templates
│   ├── project/                      # New project templates
│   │   ├── CLAUDE.md.template
│   │   ├── settings.json.template
│   │   └── .git-info-exclude.template
│   ├── agent/                        # Agent templates
│   │   └── agent-template.md
│   └── docker/                       # Docker deployment templates
│       ├── Dockerfile.template
│       └── docker-compose.yml.template
│
├── githooks/                         # Git hook templates
│   ├── pre-commit
│   └── commit-msg
│
├── gitignore_global                  # Global gitignore template
│
├── deploy/                           # Deployment scripts
│   ├── setup.sh                      # Local deployment (symlinks)
│   ├── remote.sh                     # SSH deployment
│   ├── docker.sh                     # Docker setup
│   ├── ci.sh                         # CI/CD setup
│   └── lib/                          # Shared deployment functions
│       ├── common.sh
│       ├── symlink.sh
│       └── validate.sh
│
├── tools/                            # Maintenance utilities
│   ├── sync-project-agents.sh        # Project agent sync
│   ├── validate-config.sh            # Config validation
│   └── generate-registry.sh          # Auto-generate registry
│
├── config/                           # Deployment profiles
│   ├── profiles.json                 # Environment profiles
│   └── defaults.json                 # Default settings
│
├── .planning/                        # Development planning
│   ├── research/
│   └── roadmap/
│
└── docs/                             # Documentation
    ├── usage-guide.md
    ├── deployment-guide.md
    └── development.md
```

### Rationale for Changes

1. **`core/` directory**: Groups essential config that always deploys (settings, rules, hooks). Makes selective deployment clearer.

2. **`templates/` directory**: Centralises all starter templates for projects, agents, Docker, etc. Separates templates from active config.

3. **`deploy/` directory**: All deployment scripts in one place. `lib/` subdirectory for shared functions promotes DRY.

4. **`tools/` directory**: Separates maintenance utilities from deployment scripts. Clearer purpose.

5. **`config/` directory**: External configuration for deployment profiles (local, remote, docker, CI). Avoids hardcoding in scripts.

### What Gets Symlinked vs Copied

| Source | Target | Method | Rationale |
|--------|--------|--------|-----------|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | **Symlink** | Single source of truth, git-tracked updates |
| `core/rules/` | `~/.claude/rules/` | **Symlink** | Always in sync with repo |
| `agents/` | `~/.claude/agents/` | **Symlink** | Central agent definitions |
| `core/hooks/` | `~/.claude/hooks/` | **Symlink** | Hook script updates auto-apply |
| `commands/` | `~/.claude/commands/` | **Symlink** | Command updates auto-apply |
| `skills/` | `~/.claude/skills/` | **Symlink** | Skills auto-update |
| `settings.json` | `~/.claude/settings.json` | **Copy** | Allows local machine-specific overrides |
| `gitignore_global` | `~/.gitignore_global` | **Copy** | User may have existing global gitignore |
| `githooks/*` | `.git/hooks/` | **Copy** | Git doesn't follow symlinks in `.git/` |
| `project-agents/` | - | **VCS only** | Registry, not deployed |
| `templates/` | - | **VCS only** | Used for new project creation |

**Key principle**: Symlink anything that should auto-update when repo changes. Copy anything requiring local customisation or where symlinks won't work (git internals).

### Project Agent Registry

The `project-agents/` directory is a version-controlled record of agents from active projects:

```
project-agents/
├── README.md                                    # Auto-generated index
├── llm-efficiency-measurement-tool/
│   ├── research-pm.md
│   └── research-scientist.md
├── ds01-infra/
│   ├── admin-docs-writer.md
│   ├── cli-ux-designer.md
│   ├── systems-architect.md
│   ├── technical-product-manager.md
│   └── user-docs-writer.md
└── deep_learning_lab_teaching_2025/
    └── [project agents]
```

**Purpose**:
- Version control for project-specific agents
- Reuse agents across projects
- Track agent evolution over time
- Share agents between machines

**Not deployed**: This is a registry only. Actual project agents live in each project's `.claude/agents/` directory (source of truth).

---

## Deployment Architecture

### Design Principles

1. **Idempotent**: Running deployment multiple times produces same result
2. **Non-destructive**: Backs up existing config before overwriting
3. **Selective**: Can deploy subsets (core only, no GSD, etc.)
4. **Validated**: Pre-flight checks before deployment
5. **Reversible**: Easy rollback mechanism

### Setup Script Design

The deployment scripts should be modular and composable:

```bash
# deploy/setup.sh - Local deployment
./setup.sh [OPTIONS]

Options:
  --target PATH         Target directory (default: ~/.claude)
  --profile PROFILE     Use deployment profile (local|minimal|full)
  --no-gsd              Skip GSD framework
  --no-backup           Skip backup of existing config
  --dry-run             Show what would be deployed
  --force               Overwrite without asking
```

#### Configuration Profiles

Defined in `config/profiles.json`:

```json
{
  "profiles": {
    "minimal": {
      "components": ["CLAUDE.md", "core/rules", "core/hooks"],
      "description": "Essential config only"
    },
    "standard": {
      "components": ["CLAUDE.md", "core", "commands", "agents"],
      "description": "Standard setup with GSD"
    },
    "full": {
      "components": ["*"],
      "description": "Everything including skills and templates"
    },
    "no-gsd": {
      "components": ["CLAUDE.md", "core"],
      "excludes": ["agents/gsd-*", "commands/gsd"],
      "description": "Config without GSD framework"
    }
  }
}
```

#### Deployment Script Architecture

```bash
#!/bin/bash
# deploy/setup.sh

set -e

# Source shared libraries
source "$(dirname "$0")/lib/common.sh"
source "$(dirname "$0")/lib/symlink.sh"
source "$(dirname "$0")/lib/validate.sh"

# Parse arguments
parse_args "$@"

# Pre-flight checks
validate_environment
check_dependencies

# Backup existing config
if [[ "$BACKUP" == "true" ]]; then
    backup_existing_config "$TARGET_DIR"
fi

# Deploy components based on profile
deploy_component "CLAUDE.md" "$REPO_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md" symlink
deploy_component "rules" "$REPO_DIR/core/rules" "$TARGET_DIR/rules" symlink
deploy_component "hooks" "$REPO_DIR/core/hooks" "$TARGET_DIR/hooks" symlink
deploy_component "agents" "$REPO_DIR/agents" "$TARGET_DIR/agents" symlink
deploy_component "commands" "$REPO_DIR/commands" "$TARGET_DIR/commands" symlink
deploy_component "settings.json" "$REPO_DIR/core/settings.json" "$TARGET_DIR/settings.json" copy

# Setup git hooks
setup_git_hooks "$REPO_DIR/.git"

# Setup global gitignore
setup_global_gitignore "$REPO_DIR/gitignore_global"

# Post-deployment validation
validate_deployment "$TARGET_DIR"

# Success
print_summary
```

### Cross-Platform Symlink Handling

#### macOS vs Linux Differences

Both macOS and Linux use the same `ln -s` syntax for symlinks, so cross-platform compatibility is straightforward. Key considerations:

| Concern | macOS | Linux | Solution |
|---------|-------|-------|----------|
| Symlink syntax | `ln -sfn` | `ln -sfn` | Identical |
| Path resolution | Absolute paths work | Absolute paths work | Use absolute paths |
| Permissions | Respects umask | Respects umask | Set explicitly if needed |
| Docker volumes | Follows symlinks | Follows symlinks | Works in both |

**Best practice**: Always use absolute paths for symlinks. Relative symlinks can break if the working directory changes.

```bash
# Good - absolute path
ln -sfn /Users/henry/Repositories/dotclaude/rules ~/.claude/rules

# Bad - relative path (breaks if pwd changes)
ln -sfn ../dotclaude/rules ~/.claude/rules
```

#### Symlink Validation

```bash
# deploy/lib/symlink.sh

create_symlink() {
    local src="$1"
    local dest="$2"

    # Validate source exists
    if [[ ! -e "$src" ]]; then
        log_error "Source does not exist: $src"
        return 1
    fi

    # Backup existing destination
    if [[ -e "$dest" ]] && [[ ! -L "$dest" ]]; then
        backup_file "$dest"
    fi

    # Create symlink (force, no-dereference)
    ln -sfn "$src" "$dest"

    # Validate symlink created correctly
    if [[ -L "$dest" ]] && [[ "$(readlink "$dest")" == "$src" ]]; then
        log_success "Symlinked: $dest → $src"
        return 0
    else
        log_error "Failed to create symlink: $dest"
        return 1
    fi
}
```

### Remote Deployment (SSH)

Flow for deploying to remote servers:

```bash
# deploy/remote.sh user@host [OPTIONS]

./deploy/remote.sh hbaker --profile minimal
./deploy/remote.sh dsl --method rsync
./deploy/remote.sh user@gpu-server --method git
```

#### Deployment Methods

| Method | How It Works | Use When |
|--------|--------------|----------|
| **Git clone** | Clone repo on remote, run setup.sh | Remote has git and GitHub access |
| **Rsync** | Sync local copy to remote | No git on remote, or behind firewall |
| **SCP + tar** | Tar locally, scp, untar, setup | Minimal dependencies on remote |

#### Remote Deployment Flow (Git method)

```bash
ssh user@host << 'REMOTE_SCRIPT'
    # Check if repo exists
    if [ -d ~/dotclaude ]; then
        cd ~/dotclaude
        git pull
    else
        git clone https://github.com/user/dotclaude.git ~/dotclaude
    fi

    # Run setup
    cd ~/dotclaude
    ./deploy/setup.sh --profile minimal
REMOTE_SCRIPT
```

#### Remote Deployment Flow (Rsync method)

```bash
# Rsync with filters
rsync -av --delete \
    --exclude='.git' \
    --exclude='.vscode' \
    --exclude='project-agents' \
    ~/Repositories/dotclaude/ \
    user@host:~/dotclaude/

# Run setup remotely
ssh user@host 'cd ~/dotclaude && ./deploy/setup.sh --profile minimal'
```

### Docker Deployment

Docker containers present unique challenges:
- Symlinks work but volumes must be mounted correctly
- Container filesystem is ephemeral
- Build-time vs runtime configuration

#### Approach 1: Volume Mount (Development)

For development containers where host filesystem is accessible:

```dockerfile
# Dockerfile.dev
FROM anthropic/claude-code:latest

# Mount dotclaude repo as volume
# docker run -v ~/Repositories/dotclaude:/dotclaude ...

# Setup script runs at container start
COPY deploy/docker.sh /usr/local/bin/setup-claude-config
RUN chmod +x /usr/local/bin/setup-claude-config

ENTRYPOINT ["/usr/local/bin/setup-claude-config"]
```

```bash
# deploy/docker.sh (runs inside container)
#!/bin/bash
set -e

DOTCLAUDE_SOURCE="${DOTCLAUDE_SOURCE:-/dotclaude}"
CLAUDE_DIR="${HOME}/.claude"

# Create symlinks from mounted volume
mkdir -p "$CLAUDE_DIR"

ln -sfn "$DOTCLAUDE_SOURCE/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
ln -sfn "$DOTCLAUDE_SOURCE/core/rules" "$CLAUDE_DIR/rules"
ln -sfn "$DOTCLAUDE_SOURCE/core/hooks" "$CLAUDE_DIR/hooks"
ln -sfn "$DOTCLAUDE_SOURCE/agents" "$CLAUDE_DIR/agents"
ln -sfn "$DOTCLAUDE_SOURCE/commands" "$CLAUDE_DIR/commands"

# Copy settings (container-specific)
cp "$DOTCLAUDE_SOURCE/core/settings.json" "$CLAUDE_DIR/settings.json"

# Start Claude Code
exec claude-code "$@"
```

Usage:
```bash
docker run -it --rm \
    -v ~/Repositories/dotclaude:/dotclaude \
    -v $(pwd):/workspace \
    dotclaude-dev
```

#### Approach 2: Baked-In (Production)

For production or CI containers where config should be baked in:

```dockerfile
# Dockerfile
FROM anthropic/claude-code:latest

# Copy dotclaude repo into image
COPY . /opt/dotclaude

# Run setup during build
RUN /opt/dotclaude/deploy/setup.sh \
    --target /root/.claude \
    --profile minimal \
    --no-backup

# Cleanup
RUN rm -rf /opt/dotclaude/.git

WORKDIR /workspace
ENTRYPOINT ["claude-code"]
```

Build:
```bash
docker build -t dotclaude:latest .
```

#### Docker Compose Setup

```yaml
# templates/docker/docker-compose.yml.template
version: '3.8'

services:
  claude-code:
    image: dotclaude:latest
    volumes:
      - ./project:/workspace
      - claude-cache:/root/.claude/cache
    environment:
      - CLAUDE_API_KEY=${CLAUDE_API_KEY}
    working_dir: /workspace

volumes:
  claude-cache:
```

### CI/CD Deployment

CI/CD environments need fast, reproducible setup without user interaction.

#### GitHub Actions Example

```yaml
# .github/workflows/claude-setup.yml
name: Setup Claude Code Config

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  setup:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout dotclaude
        uses: actions/checkout@v3
        with:
          repository: user/dotclaude
          path: dotclaude

      - name: Deploy minimal config
        run: |
          cd dotclaude
          ./deploy/ci.sh --profile minimal

      - name: Validate deployment
        run: |
          test -L ~/.claude/rules || exit 1
          test -f ~/.claude/settings.json || exit 1
```

#### CI Deployment Script

```bash
# deploy/ci.sh
#!/bin/bash
set -e

# CI-specific deployment (no interactive prompts, minimal logging)
export CI=true
export BACKUP=false
export TARGET_DIR="${HOME}/.claude"

# Run setup
./deploy/setup.sh --profile "${PROFILE:-minimal}" --no-backup --force

# Validate
./tools/validate-config.sh

echo "✓ Claude Code config deployed for CI"
```

---

## Configuration Hierarchy

### Claude Code's Native Hierarchy

According to [Claude Code documentation](https://code.claude.com/docs/en/settings) and [configuration guides](https://claudefa.st/blog/guide/settings-reference), Claude Code has a clear precedence hierarchy:

**Highest to Lowest Priority:**

1. **Managed Settings** (Enterprise policies)
   - Cannot be overridden by any user/project setting
   - Set by organisation admins
   - Used for security compliance

2. **Command-line Flags**
   - Temporary overrides for single session
   - `claude-code --setting value`

3. **Local Project Settings** (`.claude/settings.local.json`)
   - Personal preferences, not committed to git
   - Machine-specific overrides

4. **Shared Project Settings** (`.claude/settings.json`)
   - Team-wide settings, checked into version control
   - Applied to all project contributors

5. **Global User Settings** (`~/.claude/settings.json`)
   - Personal defaults across all projects
   - Lowest priority

### Settings Merge Behaviour

Settings don't simply replace—they **merge**:

- Arrays (like permissions) are **combined** from all levels
- For conflicting keys, **higher priority wins**
- Deny rules always win over allow rules (security-first)

Example:
```json
// ~/.claude/settings.json (user level)
{
  "permissions": {
    "allow": ["Bash(git:*)"]
  }
}

// .claude/settings.json (project level)
{
  "permissions": {
    "allow": ["Bash(npm:*)"]
  }
}

// Effective merged result:
{
  "permissions": {
    "allow": ["Bash(git:*)", "Bash(npm:*)"]
  }
}
```

### How Dotclaude Fits

**Dotclaude deploys at the User level** (`~/.claude/`):

```
Enterprise (managed)     # If applicable, set by org
    ↓ (overrides)
CLI arguments            # Session-specific
    ↓ (overrides)
Project .local.json      # Personal, machine-specific
    ↓ (overrides)
Project .json            # ← Projects configure here
    ↓ (overrides)
User ~/.claude/          # ← Dotclaude deploys here ✓
```

**Implications:**
- Dotclaude provides **default user-level config**
- Projects can override with their own `.claude/` settings
- Users can override with `.claude/settings.local.json` per machine
- Enterprise policies (if present) override everything

### Avoiding Conflicts with GSD Framework

GSD (Get Shit Done) framework lives in dotclaude and has its own agents/commands:

| Component | Location | Scope | Conflict Risk |
|-----------|----------|-------|---------------|
| **GSD agents** | `~/.claude/agents/gsd-*.md` | Global | Low - unique names |
| **GSD commands** | `~/.claude/commands/gsd/` | Global | Low - namespaced |
| **Project agents** | `.claude/agents/` | Project | Medium - can override GSD |
| **Project commands** | `.claude/commands/` | Project | Medium - can override |

**Conflict resolution:**

1. **Namespace GSD components**: Prefix all GSD agents/commands with `gsd-` to avoid collisions
2. **Project overrides**: If a project defines `gsd-planner.md`, it overrides the global one
3. **Explicit disable**: Projects can set `"disableGlobalAgents": true` in settings to ignore user-level agents

**Best practice**: GSD framework should be opt-in per project. Check for `.claude/gsd-enabled` marker file before loading GSD agents/commands.

### Global vs Project Config Decision Matrix

| Config Type | Global (~/.claude) | Project (.claude) |
|-------------|-------------------|-------------------|
| **CLAUDE.md** | Personal preferences, communication style | Project overview, architecture |
| **Rules** | Generic standards (Python, Git, etc.) | Project-specific standards |
| **Agents** | Reusable (git-manager, test-engineer) | Domain-specific (research-pm, systems-architect) |
| **Commands** | Generic utilities (/commit, /pr-review) | Project workflows (/deploy, /migrate) |
| **Skills** | General capabilities (pdf-processor) | Project tools (custom-api-client) |
| **Hooks** | General automation (format, lint) | Project-specific (validate schema, notify) |
| **Settings** | Personal defaults | Team/project requirements |

**Rule of thumb**: If it's reusable across projects → global. If it's project-specific → project.

---

## Data Flow

### Setup Flow: Initial Deployment

```
┌─────────────────────────────────────────────────────────────────┐
│ User runs: ./deploy/setup.sh --profile standard                 │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ 1. Parse arguments & load profile from config/profiles.json     │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. Pre-flight validation                                        │
│    - Check repo structure                                       │
│    - Check dependencies (git, ln, cp)                           │
│    - Check target directory writeable                           │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. Backup existing config                                       │
│    - ~/.claude/rules → ~/.claude/rules.backup                   │
│    - ~/.claude/CLAUDE.md → ~/.claude/CLAUDE.md.backup           │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. Create symlinks                                              │
│    - ln -sfn $REPO/CLAUDE.md → ~/.claude/CLAUDE.md              │
│    - ln -sfn $REPO/core/rules → ~/.claude/rules                 │
│    - ln -sfn $REPO/core/hooks → ~/.claude/hooks                 │
│    - ln -sfn $REPO/agents → ~/.claude/agents                    │
│    - ln -sfn $REPO/commands → ~/.claude/commands                │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ 5. Copy settings (allow local overrides)                        │
│    - cp $REPO/core/settings.json → ~/.claude/settings.json      │
│      (only if doesn't exist)                                    │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ 6. Setup git hooks                                              │
│    - cp $REPO/githooks/pre-commit → $REPO/.git/hooks/           │
│    - chmod +x $REPO/.git/hooks/pre-commit                       │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ 7. Setup global gitignore                                       │
│    - cp $REPO/gitignore_global → ~/.gitignore_global            │
│    - git config --global core.excludesfile ~/.gitignore_global  │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ 8. Post-deployment validation                                   │
│    - Verify all symlinks point to correct locations             │
│    - Verify settings.json is valid JSON                         │
│    - Run ./tools/validate-config.sh                             │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ 9. Print deployment summary                                     │
│    ✓ Symlinked: CLAUDE.md                                       │
│    ✓ Symlinked: rules/                                          │
│    ✓ Copied: settings.json                                      │
│    ✓ Installed: git hooks                                       │
└─────────────────────────────────────────────────────────────────┘
```

### Update Flow: Pulling Changes

```
┌─────────────────────────────────────────────────────────────────┐
│ User runs: cd ~/Repositories/dotclaude && git pull              │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ Git updates repo files:                                         │
│    - CLAUDE.md (updated)                                        │
│    - core/rules/python-standards.md (updated)                   │
│    - agents/gsd-planner.md (updated)                            │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ Symlinks automatically point to updated files:                  │
│    ~/.claude/CLAUDE.md → [updated content] ✓                    │
│    ~/.claude/rules/python-standards.md → [updated content] ✓    │
│    ~/.claude/agents/gsd-planner.md → [updated content] ✓        │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ Next Claude Code session:                                       │
│    - Loads updated config automatically                         │
│    - No manual intervention needed                              │
└─────────────────────────────────────────────────────────────────┘
```

**Key advantage of symlinks**: Updates are instant. No need to re-run deployment.

### Update Flow: Settings.json Changes

Settings.json is **copied**, not symlinked, to allow local overrides:

```
┌─────────────────────────────────────────────────────────────────┐
│ Repo update: core/settings.json (new hook added)                │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ User's ~/.claude/settings.json NOT automatically updated        │
│ (it's a copy, not a symlink)                                    │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ Options:                                                        │
│ 1. Manual merge: diff repo vs local, apply changes              │
│ 2. Overwrite: cp $REPO/core/settings.json ~/.claude/            │
│ 3. Use .local.json: Put local changes in settings.local.json    │
└─────────────────────────────────────────────────────────────────┘
```

**Best practice**: Keep machine-specific changes in `.claude/settings.local.json` (gitignored), so you can safely overwrite `settings.json` from the repo.

### Project Agent Registry Flow

Two-way sync between projects and dotclaude registry:

#### Pull: Projects → Dotclaude

```
┌─────────────────────────────────────────────────────────────────┐
│ User runs: ./tools/sync-project-agents.sh pull                  │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ For each project in config:                                     │
│    - llm-efficiency-tool: ~/Repos/project/.claude/agents        │
│    - ds01-infra: dsl:/opt/ds01-infra/.claude/agents            │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ Copy agents to registry:                                        │
│    Local: cp ~/Repos/project/.claude/agents/*.md \              │
│              → project-agents/llm-efficiency-tool/              │
│    Remote: scp dsl:/opt/ds01-infra/.claude/agents/*.md \        │
│               → project-agents/ds01-infra/                      │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ Commit to git:                                                  │
│    git add project-agents/                                      │
│    git commit -m "sync: pull project agents"                    │
└─────────────────────────────────────────────────────────────────┘
```

#### Push: Dotclaude → Projects

```
┌─────────────────────────────────────────────────────────────────┐
│ User runs: ./tools/sync-project-agents.sh push                  │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ For each project in registry:                                   │
│    project-agents/llm-efficiency-tool/*.md                      │
│    project-agents/ds01-infra/*.md                               │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ Copy to project locations:                                      │
│    Local: cp project-agents/llm-efficiency-tool/*.md \          │
│              → ~/Repos/project/.claude/agents/                  │
│    Remote: scp project-agents/ds01-infra/*.md \                 │
│               → dsl:/opt/ds01-infra/.claude/agents/             │
└─────────────────────────────────────────────────────────────────┘
```

**Source of truth**: Projects are the source of truth. Registry is a version-controlled backup.

#### Automatic Pull via Git Hook

For local projects, automatically pull agents on commit:

```bash
# githooks/pre-commit (excerpt)

# Sync project agents if in a project with .claude/agents/
if [[ -d .claude/agents ]]; then
    PROJECT_NAME=$(basename "$(pwd)")
    DOTCLAUDE="$HOME/Repositories/dotclaude"

    if [[ -d "$DOTCLAUDE" ]]; then
        mkdir -p "$DOTCLAUDE/project-agents/$PROJECT_NAME"
        cp .claude/agents/*.md "$DOTCLAUDE/project-agents/$PROJECT_NAME/" 2>/dev/null || true
    fi
fi
```

### New Project Flow: Using Templates

```
┌─────────────────────────────────────────────────────────────────┐
│ User: "Create a new Python project with Claude config"          │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ User or GSD command runs: /gsd new-project                      │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ 1. Copy project template:                                       │
│    cp ~/Repos/dotclaude/templates/project/CLAUDE.md.template \  │
│       → ./CLAUDE.md                                             │
│    cp ~/Repos/dotclaude/templates/project/settings.json \       │
│       → ./.claude/settings.json                                 │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. Customise template:                                          │
│    - Replace {{PROJECT_NAME}} with actual name                  │
│    - Replace {{PROJECT_DESCRIPTION}} with description           │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. Setup .git/info/exclude:                                     │
│    echo "CLAUDE.md" >> .git/info/exclude                        │
│    echo "claude_*.md" >> .git/info/exclude                      │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. Create initial directory structure:                          │
│    mkdir -p .claude/agents .claude/commands .claude/plans       │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│ Claude Code loads project config on next session                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Component Boundaries

Clear separation of concerns between dotclaude, GSD framework, and project-specific config.

### Layer Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Enterprise Policies (Managed)                 │
│                    [Optional - Organisation-wide]                │
└─────────────────────────────────────────────────────────────────┘
                               ↓ overrides
┌─────────────────────────────────────────────────────────────────┐
│                      Dotclaude Config (User)                     │
│  ┌──────────────────┬──────────────────┬────────────────────┐  │
│  │  Core Config     │   GSD Framework  │   Global Agents    │  │
│  │  - Rules         │   - Agents       │   - git-manager    │  │
│  │  - Hooks         │   - Commands     │   - test-engineer  │  │
│  │  - Settings      │   - Planning     │   - docs-writer    │  │
│  └──────────────────┴──────────────────┴────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                               ↓ overridden by
┌─────────────────────────────────────────────────────────────────┐
│                   Project-Specific Config                        │
│  ┌──────────────────┬──────────────────┬────────────────────┐  │
│  │  Project CLAUDE  │   Project Agents │  Project Settings  │  │
│  │  - Architecture  │   - domain-pm    │  - Team rules      │  │
│  │  - Conventions   │   - specialist   │  - Shared perms    │  │
│  │  - Workflows     │                  │                    │  │
│  └──────────────────┴──────────────────┴────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                               ↓ overridden by
┌─────────────────────────────────────────────────────────────────┐
│                   Local Overrides (Per-machine)                  │
│                   .claude/settings.local.json                    │
└─────────────────────────────────────────────────────────────────┘
```

### Dotclaude Core Config

**Purpose**: Universal configuration applicable to all projects.

**Scope**:
- Generic coding standards (Python, Git, simplicity principles)
- Tool-use automation (formatting, linting, security checks)
- Global preferences (communication style, autonomy level)
- Universal utilities (commit command, PR review)

**Location**: `~/Repositories/dotclaude/core/` → deployed to `~/.claude/`

**Characteristics**:
- Language-agnostic where possible
- No project-specific assumptions
- Stable, infrequently changing
- Minimal token overhead (<2000 tokens)

**Examples**:
- `rules/python-standards.md` - Ruff formatting, type hints
- `rules/git-commits.md` - Conventional commits
- `hooks/block-sensitive.py` - Block .env file access
- `CLAUDE.md` - Personal communication preferences

### GSD Framework

**Purpose**: Planning and execution framework for complex projects.

**Scope**:
- Multi-phase project planning
- Task decomposition and tracking
- Progress monitoring and verification
- Milestone management
- Codebase mapping

**Location**: `~/Repositories/dotclaude/agents/gsd-*.md` and `commands/gsd/` → deployed to `~/.claude/`

**Characteristics**:
- Specialised workflow system
- Heavy token usage (11 agents, 27 commands)
- Optional - not all projects need it
- Self-contained namespace (gsd-* prefix)

**Components**:
- **Agents**: gsd-planner, gsd-executor, gsd-verifier, gsd-codebase-mapper, etc.
- **Commands**: /gsd new-project, /gsd execute-phase, /gsd plan-phase, etc.
- **Planning files**: Stored in `~/.claude/plans/` or `.claude/plans/`

**Activation**:
- Opt-in per project (check for `.claude/gsd-enabled` marker)
- Or always available globally, but only used when invoked

**Interaction with Core**:
- Uses core rules (Git, Python standards)
- Uses core hooks (formatting, security)
- Adds planning/execution layer on top

### Project-Specific Config

**Purpose**: Project architecture, domain knowledge, team conventions.

**Scope**:
- Project overview and architecture
- Domain-specific agents (research-pm, systems-architect)
- Project workflows and commands
- Team-specific rules and standards
- Project-specific settings

**Location**: `./.claude/` (within each project)

**Characteristics**:
- Project context (architecture, components)
- Domain expertise (research, infrastructure, ML)
- Checked into project repo (shared with team)
- Overrides user-level config by name

**Examples**:
- `.claude/CLAUDE.md` - Project overview, architecture
- `.claude/agents/research-pm/` - Domain-specific agent
- `.claude/settings.json` - Team permissions, hooks
- `.claude/rules/api-standards.md` - Project-specific conventions

**Relationship to Dotclaude**:
- Inherits global rules (Python, Git) unless overridden
- Can use GSD framework commands if enabled
- Project agents can reference global agents
- Settings merge with user settings

### Git Hooks

**Purpose**: Pre-commit and commit-msg validation for repos.

**Scope**:
- Enforce git identity configuration
- Validate commit message format
- Block AI attribution in commits
- Trigger project agent sync
- Optional: run linters/formatters

**Location**:
- Templates: `~/Repositories/dotclaude/githooks/`
- Deployed: `.git/hooks/` (in each repo)

**Characteristics**:
- Repo-specific (copied, not symlinked)
- Not managed by Claude Code
- Runs outside Claude context
- Standard git hook behaviour

**Interaction with Dotclaude**:
- Can reference dotclaude scripts
- Can sync to project-agents/ registry
- Independent of Claude Code config

### Interaction Matrix

| From → To | Dotclaude Core | GSD Framework | Project Config | Git Hooks |
|-----------|----------------|---------------|----------------|-----------|
| **Dotclaude Core** | - | Uses core rules | Inherited by default | Can reference |
| **GSD Framework** | Uses | - | Optional usage | Triggered by commands |
| **Project Config** | Overrides by name | Can invoke | - | Triggers sync |
| **Git Hooks** | Independent | Independent | Independent | - |

### Dependency Graph

```
┌──────────────────┐
│   Git Hooks      │ (Independent)
└──────────────────┘

┌──────────────────┐
│ Dotclaude Core   │ ◄─── Foundation layer
└────────┬─────────┘
         │
         │ uses
         ↓
┌──────────────────┐
│  GSD Framework   │ ◄─── Optional layer
└────────┬─────────┘
         │
         │ available to
         ↓
┌──────────────────┐
│ Project Config   │ ◄─── Override layer
└──────────────────┘
         │
         │ overrides
         ↓
┌──────────────────┐
│ Local Overrides  │ ◄─── Machine-specific
└──────────────────┘
```

---

## Build Order

Suggested implementation phases with dependencies and priorities.

### Phase 0: Foundation (Week 1)

**Goal**: Establish core architecture and deployment mechanism.

**Tasks**:
1. **Restructure repo** according to proposed directory layout
   - Create `core/`, `deploy/`, `tools/`, `templates/` directories
   - Move files to new locations
   - Update documentation

2. **Modularise deployment scripts**
   - Create `deploy/lib/common.sh` with shared functions
   - Create `deploy/lib/symlink.sh` with symlink logic
   - Create `deploy/lib/validate.sh` with validation checks

3. **Implement local deployment** (`deploy/setup.sh`)
   - Argument parsing
   - Profile loading
   - Component deployment
   - Validation

4. **Create deployment profiles** (`config/profiles.json`)
   - minimal, standard, full, no-gsd profiles
   - Profile validation

**Deliverables**:
- Restructured repo
- Working `deploy/setup.sh` with profiles
- Deployment validation

**Dependencies**: None (foundation)

**Testing**:
```bash
# Test on clean machine
rm -rf ~/.claude
./deploy/setup.sh --profile minimal --dry-run
./deploy/setup.sh --profile minimal
./tools/validate-config.sh
```

### Phase 1: Remote Deployment (Week 2)

**Goal**: Deploy to SSH servers reliably.

**Tasks**:
1. **Implement remote deployment** (`deploy/remote.sh`)
   - Git clone method
   - Rsync method
   - SCP+tar method (optional)
   - Remote validation

2. **Add remote-specific profiles** (`config/profiles.json`)
   - Minimal remote profile (no GSD)
   - Server profile (Docker daemon access)

3. **Error handling and rollback**
   - Failed deployment detection
   - Automatic rollback on failure
   - Remote backup strategy

**Deliverables**:
- Working `deploy/remote.sh`
- Multiple deployment methods
- Rollback mechanism

**Dependencies**: Phase 0 (foundation)

**Testing**:
```bash
# Test SSH deployment
./deploy/remote.sh testserver --method git --profile minimal
ssh testserver 'test -L ~/.claude/rules && echo "✓"'

./deploy/remote.sh testserver --method rsync --profile minimal
```

### Phase 2: Docker Integration (Week 3)

**Goal**: Deploy config in Docker containers.

**Tasks**:
1. **Create Docker deployment script** (`deploy/docker.sh`)
   - Volume mount setup
   - Symlink creation inside container
   - Container-specific settings

2. **Create Dockerfile templates** (`templates/docker/`)
   - Development Dockerfile (volume mount)
   - Production Dockerfile (baked-in)
   - Docker Compose template

3. **Document Docker workflows**
   - Dev container usage
   - CI container usage
   - Volume mount caveats

**Deliverables**:
- Working Docker setup
- Dockerfile templates
- Docker deployment guide

**Dependencies**: Phase 0 (foundation)

**Testing**:
```bash
# Test Docker deployment
docker build -f templates/docker/Dockerfile.dev -t dotclaude:dev .
docker run -it --rm dotclaude:dev /bin/bash -c "test -L ~/.claude/rules && echo '✓'"
```

### Phase 3: Project Templates (Week 4)

**Goal**: Streamline new project setup.

**Tasks**:
1. **Create project templates** (`templates/project/`)
   - CLAUDE.md.template with placeholders
   - settings.json.template
   - .git/info/exclude template
   - Directory structure

2. **Create template generator script** (`tools/new-project.sh`)
   - Interactive prompts
   - Variable substitution
   - Directory creation

3. **Integrate with GSD /new-project command**
   - Automatically use templates
   - Customise for project type (Python, Node, etc.)

**Deliverables**:
- Project templates
- new-project.sh script
- GSD integration

**Dependencies**: Phase 0 (foundation)

**Testing**:
```bash
# Test project creation
./tools/new-project.sh \
    --name test-project \
    --type python \
    --dir /tmp/test-project

test -f /tmp/test-project/CLAUDE.md && echo "✓"
test -d /tmp/test-project/.claude && echo "✓"
```

### Phase 4: CI/CD Integration (Week 5)

**Goal**: Deploy config in CI/CD pipelines.

**Tasks**:
1. **Create CI deployment script** (`deploy/ci.sh`)
   - Non-interactive deployment
   - CI-specific validation
   - Fast setup (minimal profile)

2. **Create GitHub Actions workflows** (`.github/workflows/`)
   - Setup dotclaude action
   - Reusable workflow
   - Matrix testing (multiple profiles)

3. **Create GitLab CI/CD config** (`.gitlab-ci.yml`)
   - Dotclaude setup job
   - Cache strategy

4. **Document CI/CD usage**
   - GitHub Actions guide
   - GitLab CI guide
   - Environment variables

**Deliverables**:
- CI deployment script
- GitHub Actions workflows
- GitLab CI config
- CI/CD deployment guide

**Dependencies**: Phase 0 (foundation)

**Testing**:
```bash
# Test CI deployment
CI=true ./deploy/ci.sh --profile minimal
./tools/validate-config.sh
```

### Phase 5: Project Agent Registry Enhancement (Week 6)

**Goal**: Improve project agent sync and discoverability.

**Tasks**:
1. **Enhance sync script** (`tools/sync-project-agents.sh`)
   - Auto-detect projects
   - Conflict resolution
   - Selective sync (per-project)

2. **Add registry index generation** (`tools/generate-registry.sh`)
   - Auto-generate README with agent listing
   - Agent metadata extraction
   - Cross-project agent search

3. **Integrate with git hooks**
   - Auto-pull on commit (if project has .claude/agents)
   - Optional auto-commit to dotclaude repo

4. **Add agent validation**
   - Check frontmatter format
   - Validate tool references
   - Check for naming conflicts

**Deliverables**:
- Enhanced sync script
- Auto-generated registry index
- Git hook integration
- Agent validation

**Dependencies**: Phase 0 (foundation)

**Testing**:
```bash
# Test agent sync
./tools/sync-project-agents.sh pull
./tools/generate-registry.sh
git diff project-agents/README.md
```

### Phase 6: Configuration Validation & Tooling (Week 7)

**Goal**: Robust validation and maintenance tools.

**Tasks**:
1. **Create comprehensive validation** (`tools/validate-config.sh`)
   - Symlink integrity checks
   - JSON validation (settings)
   - YAML validation (agent frontmatter)
   - Hook executability
   - File permissions

2. **Create config diff tool** (`tools/diff-config.sh`)
   - Compare local vs repo settings
   - Highlight manual changes
   - Suggest migrations

3. **Create cleanup tool** (`tools/cleanup.sh`)
   - Remove broken symlinks
   - Clear backup files
   - Reset to clean state

4. **Add health check command**
   - `/health` command in Claude Code
   - Reports config status
   - Suggests fixes

**Deliverables**:
- Validation tooling
- Config diff tool
- Cleanup utilities
- Health check command

**Dependencies**: All previous phases

**Testing**:
```bash
# Test validation
./tools/validate-config.sh --strict
./tools/diff-config.sh
./tools/cleanup.sh --dry-run
```

### Phase 7: Documentation & Polish (Week 8)

**Goal**: Complete documentation and user experience polish.

**Tasks**:
1. **Write comprehensive documentation**
   - `docs/architecture.md` (this document)
   - `docs/deployment-guide.md` (step-by-step)
   - `docs/troubleshooting.md` (common issues)
   - `docs/development.md` (contributing)

2. **Create visual diagrams**
   - Architecture diagrams
   - Deployment flow diagrams
   - Configuration hierarchy

3. **Improve user experience**
   - Better error messages
   - Progress indicators
   - Coloured output
   - Interactive prompts

4. **Add examples and tutorials**
   - Example project setups
   - Common workflows
   - Migration guides

**Deliverables**:
- Complete documentation
- Visual diagrams
- Polished UX
- Examples and tutorials

**Dependencies**: All previous phases

**Testing**:
- User testing with fresh users
- Documentation review
- Example walkthrough

### Implementation Roadmap

```
Week 1: Phase 0 - Foundation
  ├─ Restructure repo
  ├─ Modular deployment scripts
  ├─ Local deployment
  └─ Deployment profiles

Week 2: Phase 1 - Remote Deployment
  ├─ SSH deployment methods
  ├─ Remote profiles
  └─ Rollback mechanism

Week 3: Phase 2 - Docker Integration
  ├─ Docker deployment script
  ├─ Dockerfile templates
  └─ Docker documentation

Week 4: Phase 3 - Project Templates
  ├─ Project templates
  ├─ Template generator
  └─ GSD integration

Week 5: Phase 4 - CI/CD Integration
  ├─ CI deployment script
  ├─ GitHub Actions workflows
  ├─ GitLab CI config
  └─ CI documentation

Week 6: Phase 5 - Registry Enhancement
  ├─ Enhanced sync script
  ├─ Registry index generation
  ├─ Git hook integration
  └─ Agent validation

Week 7: Phase 6 - Validation & Tooling
  ├─ Config validation
  ├─ Diff tool
  ├─ Cleanup utilities
  └─ Health check command

Week 8: Phase 7 - Documentation & Polish
  ├─ Complete documentation
  ├─ Visual diagrams
  ├─ UX polish
  └─ Examples and tutorials
```

### Critical Path

**Must-have (MVP)**:
- Phase 0: Foundation
- Phase 1: Remote deployment
- Phase 3: Project templates

**Should-have (First release)**:
- Phase 2: Docker integration
- Phase 6: Validation tooling
- Phase 7: Documentation

**Could-have (Future enhancements)**:
- Phase 4: CI/CD integration (can be added later)
- Phase 5: Registry enhancement (nice-to-have)

### Parallel Development

Some phases can be developed in parallel:

```
Phase 0 (Foundation)
    ├─→ Phase 1 (Remote)  ────┐
    ├─→ Phase 2 (Docker)  ────┼─→ Phase 6 (Validation)
    ├─→ Phase 3 (Templates) ──┤
    └─→ Phase 4 (CI/CD)  ─────┘
                              ↓
                         Phase 7 (Docs)
```

Phases 1-4 can be developed in parallel after Phase 0 is complete.

---

## References

### Claude Code Configuration

- [Claude Code Settings Documentation](https://code.claude.com/docs/en/settings) - Official settings reference
- [Claude Code Settings Reference Guide](https://claudefa.st/blog/guide/settings-reference) - Complete config guide
- [Claude Code Configuration Guide](https://claudelog.com/configuration/) - Configuration best practices
- [A Practical Guide to Claude Code Configuration (2025)](https://www.eesel.ai/blog/claude-code-configuration) - Practical setup guide
- [Memory and Configuration - FlorianBruniaux Guide](https://deepwiki.com/FlorianBruniaux/claude-code-ultimate-guide/4-memory-and-configuration) - Memory system
- [GitHub: claude-code-showcase](https://github.com/ChrisWiles/claude-code-showcase) - Example configurations
- [GitHub: my-claude-code-setup](https://github.com/centminmod/my-claude-code-setup) - Starter template
- [Configuration Management - anthropics/claude-code](https://deepwiki.com/anthropics/claude-code/2.2-configuration-management) - Config management
- [GitHub: claude-code-guide](https://github.com/zebbern/claude-code-guide) - Setup and workflows
- [Complete Guide to Global Instructions](https://naqeebali-shamsi.medium.com/the-complete-guide-to-setting-global-instructions-for-claude-code-cli-cec8407c99a0) - Global config guide

### Dotfiles Management

- [GitHub: rhysd/dotfiles](https://github.com/rhysd/dotfiles) - Dotfiles symlink management CLI
- [GitHub: mrjohannchang/dotfiles](https://github.com/mrjohannchang/dotfiles) - Cross-platform dotfiles
- [GitHub: i-dotfiles](https://github.com/idcrook/i-dotfiles) - GNU Stow managed dotfiles
- [Manage Your Dotfiles Like a Superhero](https://www.jakewiesler.com/blog/managing-dotfiles) - Dotfiles guide
- [Cross-platform Dotfile Management with Dotbot](https://brianschiller.com/blog/2024/08/05/cross-platform-dotbot/) - Dotbot tutorial
- [Dotfiles Inspiration](https://dotfiles.github.io/inspiration/) - Community examples
- [GitHub: jacobwgillespie/dotfiles](https://github.com/jacobwgillespie/dotfiles) - macOS/Linux dotfiles
- [Cross-Platform Dotfiles - Calvin Bui](https://calvin.me/cross-platform-dotfiles/) - Cross-platform strategies
- [Managing Dotfiles with Chezmoi](https://stoddart.github.io/2024/09/08/managing-dotfiles-with-chezmoi.html) - Chezmoi guide
- [paulirish/dotfiles symlink-setup.sh](https://github.com/paulirish/dotfiles/blob/main/symlink-setup.sh) - Setup script example

### Docker Deployment

- [How to Mount or Symlink a Single File in Docker](https://www.howtogeek.com/devops/how-to-mount-or-symlink-a-single-file-in-a-docker-container/) - Docker file mounting
- [GitHub: pmalmgren/dotfiles](https://github.com/pmalmgren/dotfiles) - Dotfiles with Docker
- [Docker Forum: Mounting Symbolic Links](https://forums.docker.com/t/mounting-symbolic-links-inside-directories/134919) - Symlink handling
- [Docker Dev Containers in VS Code](https://oneuptime.com/blog/post/2026-01-06-docker-dev-containers-vscode/view) - Dev container setup
- [Docker Forum: Volume Mount Follows Symbolic Links](https://forums.docker.com/t/volume-mount-follows-symbolic-links/91287) - Volume behaviour
- [Mounting Folders as Docker Volumes](https://blog.valerauko.net/2018/07/03/mounting-folders-as-docker-volumes/) - Volume mounting guide
- [How I Manage My Dotfiles](https://shibisuriya.github.io/blog/blog/how-i-manage-my-dotfiles) - Personal workflow
- [Automated Dotfile Deployment Using Ansible and Docker](https://bananamafia.dev/post/dotfile-deployment/) - Ansible automation
- [Docker: Mounting or Symlinking Files](https://copyprogramming.com/howto/how-to-mount-or-symlink-a-single-file-in-a-docker-container) - Technical guide
- [Docker Forum: Docker for Mac Symlinks](https://forums.docker.com/t/docker-for-mac-beta-does-not-handle-symlinks-when-mounting-volumes/10955) - macOS symlinks

---

## Appendices

### A. File Permissions

Recommended file permissions for dotclaude components:

| File Type | Permissions | Reason |
|-----------|-------------|--------|
| Scripts (.sh) | `755` (rwxr-xr-x) | Executable by all |
| Python hooks | `755` (rwxr-xr-x) | Executable by Claude |
| Config (.json) | `644` (rw-r--r--) | Readable by all |
| Markdown (.md) | `644` (rw-r--r--) | Readable by all |
| Git hooks | `755` (rwxr-xr-x) | Executable by git |

Set during deployment:
```bash
chmod 755 ~/.claude/hooks/*.py
chmod 644 ~/.claude/settings.json
```

### B. Symlink Debugging

Common symlink issues and solutions:

```bash
# Check if symlink exists
test -L ~/.claude/rules && echo "Is symlink" || echo "Not symlink"

# Check where symlink points
readlink ~/.claude/rules

# Check if target exists
test -e ~/.claude/rules && echo "Target exists" || echo "Broken symlink"

# List all symlinks in ~/.claude
find ~/.claude -type l -ls

# Find broken symlinks
find ~/.claude -type l ! -exec test -e {} \; -print
```

### C. Environment Variables

Environment variables used by deployment scripts:

| Variable | Default | Purpose |
|----------|---------|---------|
| `DOTCLAUDE_REPO` | `~/Repositories/dotclaude` | Repo location |
| `CLAUDE_DIR` | `~/.claude` | Target directory |
| `BACKUP` | `true` | Enable backups |
| `PROFILE` | `standard` | Deployment profile |
| `CI` | `false` | CI mode (non-interactive) |
| `DRY_RUN` | `false` | Show actions without executing |

Override during deployment:
```bash
PROFILE=minimal CLAUDE_DIR=/custom/path ./deploy/setup.sh
```

### D. Troubleshooting Checklist

**Deployment fails:**
- [ ] Check repo structure: `tree -L 2 ~/Repositories/dotclaude`
- [ ] Check dependencies: `which git ln cp`
- [ ] Check permissions: `ls -la ~/.claude`
- [ ] Check disk space: `df -h ~`
- [ ] Review error logs: `tail -n 50 /tmp/dotclaude-setup.log`

**Symlinks broken:**
- [ ] Verify source exists: `ls -la ~/Repositories/dotclaude/rules`
- [ ] Check symlink: `readlink ~/.claude/rules`
- [ ] Re-run setup: `./deploy/setup.sh --force`

**Settings not loading:**
- [ ] Validate JSON: `jq . ~/.claude/settings.json`
- [ ] Check precedence: Higher-level settings override user settings
- [ ] Review merged settings: `/config` command in Claude Code

**Git hooks not running:**
- [ ] Check executable: `ls -la .git/hooks/pre-commit`
- [ ] Set executable: `chmod +x .git/hooks/pre-commit`
- [ ] Test manually: `.git/hooks/pre-commit`
- [ ] Check git config: `git config --get core.hooksPath`

---

**End of Document**
