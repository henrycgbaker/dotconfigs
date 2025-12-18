# TODO

## Extensibility Features to Add

- [ ] **Skills** - Model-invoked capabilities in `skills/`
  - [ ] code-review skill
  - [ ] pdf-processing skill

- [ ] **Commands** - Custom slash commands in `commands/`
  - [ ] pr-review.md
  - [ ] commit-helper.md

- [ ] **Hooks** - Event automation in `hooks.json`
  - [ ] Auto-format after edits
  - [ ] Block sensitive file edits

- [ ] **MCP Servers** - External integrations in `mcp-servers.json`
  - [ ] GitHub integration
  - [ ] Database connections (use env vars for credentials)

- [ ] **Output Styles** - Custom system prompts in `output-styles/` (optional)

## Research

- [ ] **Scope Precedence** - Investigate how system-wide `~/.claude/` interacts with project-level `.claude/`
  - Which takes precedence when both exist?
  - Do they merge or override?
  - How do rules, agents, commands, skills layer?

- [ ] **Git Identity Enforcement** - Ensure commits use correct user/email
  - User: `henrycgbaker`
  - Email: `henry.c.g.baker@...`
  - Options: pre-commit hook vs rule vs global git config
  - Should block commits with wrong identity or auto-fix?
