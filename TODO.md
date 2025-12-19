# TODO

## Extensibility Features

### Completed

- [x] **Hooks** - Event automation in `hooks/`
  - [x] `block-sensitive.py` - Block access to sensitive files
  - [x] `post-tool-format.py` - Auto-format Python with Ruff

- [x] **Rules** - Coding standards in `rules/`
  - [x] `python-standards.md` - Python conventions
  - [x] `git-commits.md` - Commit conventions
  - [x] `docker-practices.md` - Container best practices
  - [x] `security.md` - Security practices
  - [x] `research-code.md` - Reproducibility standards

- [x] **Skills** - Model-invoked capabilities in `skills/`
  - [x] `python-fixer/` - Auto-fix Python linting
  - [x] `type-checker/` - MyPy integration
  - [x] `test-runner/` - Pytest helper
  - [x] `container-inspector/` - Docker debugging
  - [x] `dependency-auditor/` - Security scanning

- [x] **Commands** - Custom slash commands in `commands/`
  - [x] `gpu-status.md` - GPU monitoring
  - [x] `docker-status.md` - Container status
  - [x] `pr-review.md` - PR review workflow
  - [x] `commit.md` - Commit helper

- [x] **Project Agents** - Reusable agents in `project-agents/`
  - [x] `infra-architect/` - Infrastructure design
  - [x] `research-pm/` - Research product management
  - [x] `research-scientist/` - Research scientist

- [x] **Git Hooks** - Git identity enforcement
  - [x] `pre-commit` - Enforce git user identity
  - [x] `commit-msg` - Block AI attribution

### Pending

- [ ] **MCP Servers** - External integrations
  - [ ] GitHub integration
  - [ ] Database connections (use env vars for credentials)
  - [ ] GPU monitoring server (custom)

- [ ] **Convert project-agents to templates** - Once agents stabilize, convert from symlinks to template copies for project customization

## Research

- [ ] **Scope Precedence** - Investigate how system-wide `~/.claude/` interacts with project-level `.claude/`
  - Which takes precedence when both exist?
  - Do they merge or override?
  - How do rules, agents, commands, skills layer?

- [x] **Git Identity Enforcement** - Ensure commits use correct user/email
  - Implemented as `pre-commit` hook in `githooks/`
  - Enforces: `henrycgbaker` / `henry.c.g.baker@gmail.com`
