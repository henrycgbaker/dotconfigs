# Feature Landscape: Plugin-Based CLI and Git Configuration Manager

**Domain:** Extensible CLI configuration management tools
**Researched:** 2026-02-07
**Project:** dotconfigs v2.0 (plugin architecture milestone)
**Confidence:** HIGH

## Executive Summary

Plugin-based CLIs and git configuration managers share common patterns: discoverability through consistent commands, interactive setup with sensible defaults, declarative configuration storage, and automatic conflict resolution. Users expect "it just works" deployment with clear feedback.

**Key insight:** The dividing line between "dotfiles manager" and "configuration manager" is intentionality. Dotfiles managers are generic (chezmoi, yadm, GNU stow). Configuration managers are opinionated about what they manage and how (git hooks, identity switching, team settings).

**For dotconfigs v2:** The plugin architecture positions this as a *configuration manager*, not a dotfiles manager. Each plugin (claude, git) is opinionated about the configuration domain it owns, with shared infrastructure for common patterns (interactive wizards, .env persistence, deployment).

## Table Stakes

Features users expect. Missing any of these = product feels incomplete or unprofessional.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Plugin discovery** | CLI must know what plugins exist without hardcoding | Low | File system scan of `plugins/*/` directory |
| **List available plugins** | Users need to see what's installed | Low | `dotconfigs list` or `dotconfigs plugins` |
| **Per-plugin setup** | Each plugin has different config needs | Medium | `dotconfigs setup [plugin]` runs plugin-specific wizard |
| **Per-plugin deploy** | Deploy one plugin without affecting others | Medium | `dotconfigs deploy [plugin]` for targeted updates |
| **Status visibility** | Users need to see what's deployed where | Medium | `dotconfigs status [plugin]` shows current state |
| **Interactive wizard** | First-time setup can't require manual file editing | Medium | Already built in v1, needs per-plugin adaptation |
| **Pre-filled defaults** | Re-running wizard should remember previous values | Low | Already built (.env persistence), needs plugin namespacing |
| **Dry-run mode** | Users want to preview changes before applying | Low-Medium | `--dry-run` flag shows what would happen |
| **Conflict detection** | Deploying over existing files must be safe | Medium | Check for conflicts before writing/symlinking |
| **Conflict resolution** | When conflicts exist, offer clear options | Medium | Backup, overwrite, skip, or abort |
| **Idempotent operations** | Running deploy twice should be safe | Low | Check current state before acting |
| **Clear error messages** | When things fail, user needs to know why and how to fix | Low | Context-aware error reporting |
| **Version awareness** | User should know what version is deployed | Low | `--version` flag, version in status output |
| **Help per command** | Users need usage documentation | Low | `dotconfigs [command] --help` |

### Existing Features (From v1)

These are already built and just need plugin adaptation:

- **Interactive wizard with y/n prompts** — Core infrastructure exists
- **.env-based configuration persistence** — Core pattern works, needs namespacing
- **Symlink management** — Core utility exists in deploy.sh
- **Conflict handling** — Basic backup logic exists
- **Remote deployment via SSH** — Infrastructure works

## Differentiators

Features that make this better than manual configuration or generic dotfiles managers. Not expected, but highly valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Plugin isolation** | Plugins don't interfere with each other | Medium | Each plugin manages its own namespace, shared lib for common tasks |
| **Conditional git identity switching** | Automatically use work email for work repos | High | Git 2.36+ conditional includes based on directory/remote |
| **Hook management** | Git hooks tracked in repo, deployed safely | Low | v1 already does this, git plugin formalises it |
| **Branch protection** | Prevent force-push to main/master | Low | v1 hook already exists, git plugin owns it |
| **Commit message validation** | Enforce conventional commits automatically | Low | v1 hook exists, git plugin owns it |
| **Template scaffolding** | Generate project configs (settings.json, CLAUDE.md) | Low | v1 does this for Claude, extend to plugins |
| **Validation before deploy** | Check config files are valid before writing | Medium | Prevents broken configs from being deployed |
| **Rollback capability** | Undo a deployment if it breaks something | Medium | Keep backup of previous state, offer restore |
| **Plugin dependencies** | Git plugin can depend on shared lib | Low | Already designed in v2 architecture |
| **Cross-machine sync** | Same config on laptop, remote servers, CI | Low | Achieved by git clone + deploy pattern |
| **Workflow git aliases** | Install productivity aliases (git st, git co, etc.) | Low | Git plugin feature, deployed to .gitconfig |
| **SSH key management** | Configure per-identity SSH keys | Medium | Links to git identity switching feature |
| **Git config scopes** | Set global vs per-directory settings correctly | Medium | Use git conditional includes strategically |
| **Plugin status dashboard** | See all plugin states at a glance | Medium | `dotconfigs status` with no args shows all plugins |
| **Non-interactive mode** | Support scripted deployment (CI/CD) | Low | Read config, skip prompts, use defaults |

## Anti-Features

Features to deliberately NOT build. These are common mistakes in this domain.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **GUI or TUI interface** | Adds complexity, breaks scriptability, not needed for setup/deploy pattern | Stick to CLI with clear text output |
| **Plugin marketplace/registry** | Premature — this is personal config, not a framework | Just document how to add plugins (create dir structure) |
| **Cross-plugin dependencies** | Creates coupling, breaks isolation principle | Plugins only depend on shared lib, never each other |
| **Auto-update mechanism** | Dangerous for personal configs, git pull is sufficient | User controls updates via git operations |
| **Backup rotation** | Over-engineering — one backup level is enough | Keep .bak of previous state, that's it |
| **Plugin versioning** | Unnecessary complexity for personal config | Plugins live in same repo, version is git commit |
| **Configuration import from other tools** | Scope creep — chezmoi does this, we don't | Provide clear migration docs instead |
| **Full dotfiles management** | Out of scope — only dev-tool configs (Claude, git, maybe shell) | Don't try to manage vim, tmux, etc. |
| **Team/collaboration features** | Personal configuration tool, not team tool | Git sharing is the collaboration mechanism |
| **Cloud sync** | Git is the sync mechanism | Don't build Dropbox integration |
| **Plugin hot-reloading** | Not a daemon, runs and exits | No need for this complexity |
| **Configuration validation schema** | Over-engineering for bash scripts | Simple existence checks are sufficient |
| **Multi-language plugin support** | Bash-only keeps it simple | Plugins are bash scripts using shared lib |
| **Plugin configuration UI** | Wizard provides interactive setup | Don't build ncurses/TUI configuration editors |

## Feature Dependencies

```
Plugin Discovery
    ↓
List Plugins → Setup Plugin → Deploy Plugin → Status Check
                    ↓              ↓
                .env Config    Conflict Detection
                                   ↓
                              Conflict Resolution
                                   ↓
                              Symlink/Copy Files

Git Identity (conditional includes)
    ↓
SSH Key per Identity
```

**Critical path for v2.0:**
1. Plugin discovery (file system scan)
2. Per-plugin setup (interactive wizard)
3. Per-plugin deploy (read .env, execute deploy logic)
4. Status command (show current state)

**Post-MVP enhancements:**
- Dry-run mode
- Rollback capability
- Validation before deploy
- Advanced conflict resolution strategies

## MVP Feature Set (v2.0)

For v2.0 plugin architecture milestone, prioritise:

### Must Have (Blocks v2.0 launch)

1. **Plugin discovery** — CLI finds plugins by scanning `plugins/*/`
2. **Per-plugin setup** — `dotconfigs setup claude` runs claude plugin wizard
3. **Per-plugin deploy** — `dotconfigs deploy git` deploys git config
4. **Status command** — `dotconfigs status [plugin]` shows deployment state
5. **Config namespacing** — .env entries prefixed by plugin (CLAUDE_*, GIT_*)
6. **Git plugin: hooks** — Deploy commit-msg, branch protection hooks
7. **Git plugin: identity** — Configure user.name, user.email
8. **Git plugin: workflow settings** — Default branch, pull strategy, aliases
9. **Conflict detection** — Warn before overwriting existing files
10. **Idempotent deploy** — Running deploy twice is safe

### Should Have (Improves UX)

11. **List command** — `dotconfigs list` shows available plugins
12. **Help per plugin** — `dotconfigs setup claude --help` shows plugin-specific help
13. **Dry-run mode** — `dotconfigs deploy --dry-run` previews changes
14. **Backup on conflict** — Automatically backup existing files before overwriting
15. **Clear progress output** — Show what's happening during deploy

### Defer to Post-v2.0

16. **Rollback capability** — Undo a deployment
17. **Validation before deploy** — Check configs are valid before writing
18. **Conditional git identity switching** — Automatic identity per repo (complex)
19. **SSH key per identity** — Link SSH keys to git identities
20. **Plugin status dashboard** — Aggregated view across all plugins

## Git Plugin Feature Breakdown

The git plugin is the major new feature in v2.0. Here's what it should manage:

### Hooks (Already Built in v1, Move to Plugin)

- **commit-msg hook** — Enforce conventional commits, block AI attribution
- **pre-push hook** — Branch protection for main/master
- **Hook deployment** — Copy from `plugins/git/hooks/` to `.git/hooks/`

### Identity Management

- **Basic identity** — Set user.name and user.email globally
- **Project-specific identity** — Override identity per project/directory
- **Future: Conditional includes** — Automatic switching based on directory (defer to v2.1+)

### Workflow Settings

- **Default branch** — Set init.defaultBranch to main
- **Pull strategy** — Set pull.rebase true or false
- **Push strategy** — Set push.default simple
- **Aliases** — Install productivity aliases:
  - `git st` → `git status`
  - `git co` → `git checkout`
  - `git br` → `git branch`
  - `git ci` → `git commit`
  - `git unstage` → `git reset HEAD --`
  - `git last` → `git log -1 HEAD`

### Configuration Scopes

Git has three configuration scopes:
- **System** (`/etc/gitconfig`) — Don't touch
- **Global** (`~/.gitconfig`) — Primary target for workflow settings
- **Local** (`.git/config`) — Per-project overrides

dotconfigs git plugin should:
- Write workflow settings to global scope
- Provide wizard option for per-project identity
- Document how users can override per-project

## Claude Plugin Feature Breakdown

Existing v1 features migrated to plugin structure:

### Files Managed

- **Global CLAUDE.md** — Deploy to `~/.claude/CLAUDE.md`
- **Global settings.json** — Deploy to `~/.claude/settings.json`
- **Project templates** — Generate project-specific CLAUDE.md, settings.json

### Configuration Options (via wizard)

- User name
- British/American English preference
- Git workflow (feature branches, commit style)
- GSD installation (yes/no)
- Project scaffolding (yes/no)

## CLI Command Structure

Based on research into plugin-based CLI patterns, the command structure should be:

```bash
dotconfigs <command> [plugin] [options]

Commands:
  setup [plugin]      Run interactive setup wizard for plugin
  deploy [plugin]     Deploy plugin configuration
  status [plugin]     Show deployment status
  list                List available plugins
  version             Show version information
  help [command]      Show help for command

Options:
  --dry-run           Preview changes without applying
  --force             Skip conflict checks and overwrite
  --quiet             Minimal output
  --verbose           Detailed output

Examples:
  dotconfigs setup claude           # Run Claude plugin setup wizard
  dotconfigs deploy git             # Deploy git configuration
  dotconfigs status                 # Show status of all plugins
  dotconfigs deploy --dry-run git   # Preview git deployment
```

### Command Design Rationale

- **Subcommand over flags** — `setup claude` is clearer than `--setup --plugin=claude`
- **Plugin argument optional** — `status` with no arg shows all plugins
- **Consistent flag names** — `--dry-run`, `--force` work across all commands
- **Help everywhere** — `help setup`, `help deploy`, `help [plugin]` all work

## Complexity Assessment

| Feature Category | Overall Complexity | Risk Level | Dependencies |
|------------------|-------------------|------------|--------------|
| Plugin discovery | Low | Low | File system scan is straightforward |
| Plugin setup | Low-Medium | Low | Infrastructure exists, needs adaptation |
| Plugin deploy | Medium | Low | Core logic exists, needs generalisation |
| Status command | Low-Medium | Low | Read state, report status |
| Conflict handling | Medium | Medium | Many edge cases to consider |
| Git hooks | Low | Low | v1 already works |
| Git identity (basic) | Low | Low | Write to .gitconfig |
| Git identity (conditional) | High | High | Complex git feature, many scopes |
| Git workflow settings | Low | Low | Simple config writes |
| Dry-run mode | Low-Medium | Low | Check and report, don't write |
| Rollback | Medium | Medium | State tracking required |

**Highest complexity items:**
1. Conditional git identity switching (deferred to v2.1+)
2. Plugin state tracking for rollback
3. Sophisticated conflict resolution strategies

**Safest to implement first:**
1. Plugin discovery and list
2. Status command
3. Per-plugin setup adaptation
4. Git workflow settings and aliases

## Key Research Findings

### Plugin-Based CLIs

1. **Discovery mechanisms:** File system scan is standard — look for `plugins/*/setup.sh` pattern
2. **Interface consistency:** All plugins should implement same interface (setup, deploy, status functions)
3. **Federated architecture:** Each plugin is independently maintainable
4. **Entry points over hardcoding:** Don't hardcode plugin names in main CLI

### Git Configuration Management

1. **Conditional includes are powerful:** Git 2.36+ supports automatic identity switching by directory/remote
2. **Scope awareness matters:** Global vs local config must be set correctly
3. **Hook management is valuable:** Teams want standardised hooks without manual copying
4. **Identity pain point:** Developers with multiple git accounts need automatic switching
5. **Aliases improve workflow:** Common shortcuts (st, co, br) are widely adopted

### CLI UX Patterns

1. **Status visibility:** Every action needs clear feedback (spinners, progress, completion messages)
2. **Idempotency:** Running commands multiple times should be safe
3. **Consistency:** Flags and subcommands should work the same way across all plugins
4. **Discoverability:** `help` and `list` commands are essential for plugin ecosystems
5. **Gerund for ongoing, past tense for complete:** "Deploying..." → "Deployed successfully"

### Dotfiles Management

1. **Symlink vs copy:** Symlinks are preferred for configs that might be edited in place
2. **Conflict resolution:** Backup existing files, don't silently overwrite
3. **Dry-run essential:** Users want to preview changes before applying
4. **Idempotent operations:** Check if already deployed before acting

### Git Hooks Best Practices

1. **Central management:** Store hooks in repo, deploy to .git/hooks/
2. **Keep hooks fast:** Don't run full test suites, use CI for that
3. **Hook chaining:** Multiple checks in one hook (lint → test → format)
4. **Security:** Never hardcode secrets, validate inputs
5. **Team sharing:** Version-controlled hooks ensure team consistency

### Git Identity Management

1. **Multiple approaches exist:**
   - SSH config per account (custom host aliases)
   - Git conditional includes (directory or remote-based)
   - Dedicated tools (gitego, gitup, git-identity-manager)
2. **Conditional includes preferred:** Git 2.36+ native feature, no external tools
3. **Automatic switching is valuable:** Clone repo, identity auto-configured
4. **Path-based vs remote-based:** Directory location OR remote URL pattern

## Recommendations for v2.0 Roadmap

### Phase Structure

Based on dependencies and complexity:

1. **Phase 1: Core plugin infrastructure**
   - Plugin discovery mechanism
   - Shared lib extraction
   - CLI command structure
   - Status command foundation

2. **Phase 2: Per-plugin setup**
   - Adapt wizard to per-plugin pattern
   - Config namespacing (.env prefixes)
   - Setup command implementation

3. **Phase 3: Per-plugin deploy**
   - Deploy command generalisation
   - Conflict detection
   - Idempotent operations

4. **Phase 4: Git plugin (basic)**
   - Git identity (global)
   - Workflow settings and aliases
   - Hook deployment

5. **Phase 5: Integration and polish**
   - Dry-run mode
   - Help documentation
   - Error message improvements

### Future Enhancements (Post-v2.0)

- Conditional git identity switching
- SSH key management per identity
- Rollback capability
- Validation before deploy
- Shell plugin (aliases, environment variables)

## Open Questions for Implementation

1. **Plugin interface contract:** What functions must every plugin implement?
   - **Recommend:** `setup()`, `deploy()`, `status()`, `validate()` (optional)

2. **Config file format:** Stay with .env or move to structured format (JSON/YAML)?
   - **Recommend:** Stay with .env for simplicity, bash compatibility

3. **Plugin dependencies:** How do plugins declare dependencies on lib functions?
   - **Recommend:** Source from `lib/` by relative path

4. **Error handling:** What happens when plugin setup fails mid-wizard?
   - **Recommend:** Write partial .env, allow resume with `--continue`

5. **Deployment scope:** Should `dotconfigs deploy` with no arg deploy all plugins?
   - **Recommend:** Yes, but confirm with user first ("Deploy all plugins? [y/N]")

6. **Git identity scope:** Should basic git plugin set global or per-directory identity?
   - **Recommend:** Global by default, document per-directory overrides for later

## Confidence Assessment

| Area | Level | Rationale |
|------|-------|-----------|
| Plugin CLI patterns | HIGH | Well-documented patterns, multiple authoritative sources (plugin-discovery, pop-book) |
| Git configuration | HIGH | Official git documentation, clear standards |
| Git identity switching | MEDIUM | Conditional includes are powerful but complex, needs hands-on verification |
| CLI UX patterns | HIGH | Consistent patterns across major CLI tools (clig.dev, lucasfcosta) |
| Dotfiles management | MEDIUM | Multiple approaches exist, choice depends on use case |
| Hook management | HIGH | v1 already works, pattern is validated |
| Git aliases | HIGH | Standard git feature, well-documented |

## Sources

### Plugin Architecture
- [Plugin Oriented Programming Patterns](https://pop-book.readthedocs.io/en/latest/main/patterns.html)
- [How to Build Plugin Systems in Python](https://oneuptime.com/blog/post/2026-01-30-python-plugin-systems/view)
- [Designing Plugin Architecture for Extensible CLI Applications](https://peerdh.com/blogs/programming-insights/designing-a-plugin-architecture-for-extensible-cli-applications-3)
- [Plugin Discovery npm package](https://www.npmjs.com/package/plugin-discovery)

### Git Configuration
- [Git Configuration Official Documentation](https://git-scm.com/book/en/v2/Customizing-Git-Git-Configuration)
- [Managing Multiple Git Identities](https://medium.com/@leroyleowdev/one-machine-many-identities-adding-effortlessly-switch-between-multiple-git-profiles-fd56a20bc181)
- [Git Identity Management with Conditional Includes](https://ingo-richter.io/post/2025/manage-multiple-git-identities-with-conditional-includes/)
- [Git Aliases Official Documentation](https://git-scm.com/book/en/v2/Git-Basics-Git-Aliases)

### Git Hooks
- [Mastering Git Hooks: Advanced Techniques and Best Practices](https://kinsta.com/blog/git-hooks/)
- [Git Hooks Official Documentation](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks)
- [Git Hooks Tutorial: 10 Advanced Best Practices](https://xcloud.host/top-advanced-git-hooks-best-practices/)

### Dotfiles Management
- [chezmoi Comparison Table](https://www.chezmoi.io/comparison-table/)
- [General-purpose dotfiles utilities](https://dotfiles.github.io/utilities/)
- [awesome-dotfiles](https://github.com/webpro/awesome-dotfiles)
- [GNU Stow for Managing Dotfiles](https://systemcrafters.net/managing-your-dotfiles/using-gnu-stow/)

### CLI Design
- [UX patterns for CLI tools](https://lucasfcosta.com/2022/06/01/ux-patterns-cli-tools.html)
- [Command Line Interface Guidelines](https://clig.dev/)
- [CLI UX best practices: Progress Displays](https://evilmartians.com/chronicles/cli-ux-best-practices-3-patterns-for-improving-progress-displays)

### Configuration Management
- [Git-based Configuration Management](https://www.ideas2it.com/blogs/git-configuration-management)
- [Git Workflows Best Practices for GitOps](https://developers.redhat.com/articles/2022/07/20/git-workflows-best-practices-gitops-deployments)
- [config-file-validator](https://github.com/Boeing/config-file-validator)

---

*Research complete. Ready for roadmap creation and requirements definition.*
