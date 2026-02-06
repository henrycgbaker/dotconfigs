# Technology Stack

**Analysis Date:** 2026-02-06

## Languages

**Primary:**
- Bash - Shell scripting for deployment, setup, and CLI operations
- Markdown - Core format for agent definitions, commands, rules, and documentation
- Python 3 - Hook implementations for pre/post-commit automation and security

**Secondary:**
- JSON - Configuration files and settings

## Runtime

**Environment:**
- Bash shell (Unix-like systems: macOS, Linux)
- Python 3.x (for hook scripts)

**Package Manager:**
- pip (Python packages)
- No lockfile required (minimal dependencies)

## Frameworks

**Claude Integration:**
- Claude Code (via Claude Opus 4.6 or later models)
- Claude API integration through MCP (Model Context Protocol)

**Core Architecture:**
- Custom agent system (agents/ directory)
- Agent spawning and orchestration via Claude Code commands
- MCP context integration for external data fetching

## Key Dependencies

**Critical (Python):**
- `ruff` - Python formatting and linting (auto-installed via setup)
- Standard library only: `json`, `subprocess`, `sys`, `pathlib`, `re`

**Infrastructure:**
- Git (version control, hooks)
- SSH (remote deployment)
- rsync (remote synchronization)
- Docker/Docker Compose (optional - for container inspection)
- nvidia-smi (optional - GPU monitoring)

## Configuration

**Environment:**
- Shell initialization for `~/.claude/` directory
- `settings.json` - Claude Code configuration (copied, not symlinked, allows local overrides)
- `.claude/settings.local.json` - Local overrides for settings

**Key Configs:**
- `settings.json`: Permission policies, hook configuration, environment variables, sandbox settings
- `CLAUDE.md`: Root personal policies and decision framework
- `rules/`: Always-loaded behavioral standards (git commits, code style, security)
- `.claude/agents/`: Agent definitions (loaded per project)
- `.claude/commands/`: User-invoked commands
- `.claude/skills/`: Model-invoked capabilities
- `.claude/hooks/`: Pre/post tool-use automation

**Build:**
- No build system required
- Installation via symlinks (setup.sh)

## Platform Requirements

**Development:**
- Bash shell (zsh or bash)
- Python 3.x
- Git
- SSH client (for remote deployment)
- Text editor with Markdown support
- Claude Code IDE with MCP support

**Production (Remote Deployment):**
- Unix-like OS (macOS, Linux)
- Bash shell
- Git (for clone method)
- SSH access and rsync (for sync method)
- Home directory with write permissions (~/)

## Tool Permissions

**Allowed Operations:**
```
Bash: nvidia-smi, docker, docker-compose, git, ruff, pytest, pip, python
Read: /proc/meminfo, /proc/cpuinfo
```

**Denied Operations:**
```
Read: .env files, *_key, *_secret, .ssh/
Bash: rm -rf /, mkfs, dd
```

**Ask Before:**
```
Bash: systemctl, kill, pkill, reboot, shutdown
```

## Sandbox Configuration

**Status:** Enabled

**Excluded Commands:** `docker`, `docker-compose`, `nvidia-smi`, `git` (run outside sandbox)

**Environment Variables:**
- `PYTHONDONTWRITEBYTECODE=1` - Prevent .pyc file creation
- `PYTHONUNBUFFERED=1` - Unbuffered output for real-time logs

## Code Quality Tools

**Python Formatting/Linting:**
- `ruff format` - Code formatting (100 char line length)
- `ruff check --fix` - Linting and auto-fix

**Automation:**
- Pre-commit hooks: Run `ruff format` and `ruff check --fix` on staged Python files
- Post-tool-use hooks: Auto-format Python after Write/Edit operations

**Type Checking:**
- MyPy (available as skill, not enforced in hooks)

## System Capabilities

**Monitoring:**
- GPU status via nvidia-smi
- Docker container inspection
- Git operations and status

**Documentation Generation:**
- Agent system capable of creating README files
- Changelog generation from git logs

---

*Stack analysis: 2026-02-06*
