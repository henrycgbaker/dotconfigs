# Plugins

[← docs](../README.md#documentation) · Reference

Each plugin is a self-contained directory under `plugins/` with a `manifest.json` declaring its modules. Generated index of every hook/skill and its config keys: [ROSTER.md](ROSTER.md).

## claude

Manages Claude Code configuration.

| Module | Source | Target | Method |
|--------|--------|--------|--------|
| hooks | `plugins/claude/hooks/` | `~/.claude/hooks/` (global), `.claude/hooks/` (project) | symlink |
| skills | `plugins/claude/skills/` | `~/.claude/skills/` (global), `.claude/skills/` (project) | symlink |
| settings | `plugins/claude/settings.json` | `~/.claude/settings.json` | [merge](deploy-methods.md#the-settingsjson-case-why-merge-exists) |
| CLAUDE.md | `plugins/claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | symlink |

- **Hooks:** `block-destructive.sh`, `block-ai-pr-attribution.sh`, `block-gh-comment.sh`, `facade-check.sh` (PreToolUse guards).
- **Skills:** `/commit`, `/squash-merge`, `/check-resolution`, `/preflight-merge`, `/rebase-stacked-prs` (each a `skills/<name>/SKILL.md`).

`settings.json` uses `merge` (not symlink/copy) because Claude Code writes permission grants into it - see [Deploy methods](deploy-methods.md). Project scope supports exclude lists to skip specific hooks/skills per repo.

## git

Manages git config, global excludes, and hooks.

| Module | Source | Target | Scope |
|--------|--------|--------|-------|
| hooks | `plugins/git/hooks/` | `~/.dotconfigs/git-hooks/` (global), `.git/hooks/` (project) | both |
| config | `plugins/git/templates/gitconfig` | `~/.gitconfig` | global |
| global-excludes | `plugins/git/templates/global-excludes` | `~/.config/git/ignore` | global |
| exclude-patterns | `plugins/git/templates/project-excludes` | `.git/info/exclude` | project |
| gitignore | `plugins/git/templates/gitignore-default` | `.gitignore` | project |

**Hooks:**

| Hook | What it does |
|------|-------------|
| `pre-commit` | Identity check always; Ruff format on main only (branch-aware) |
| `commit-msg` | Blocks AI attribution |
| `pre-push` | Code-quality validation (pytest + ruff + mypy) + force-push protection |
| `pre-rebase` | Blocks rebasing main/master; warns about pushed commits |
| `prepare-commit-msg` | Auto-prefix from branch name (`feature/*` → `feat:`) |
| `post-merge` | Dependency-change detection + migration reminders |
| `post-checkout` | Branch info on switch |
| `post-rewrite` | Dependency detection for rebase |

`prepare-commit-msg`, `post-merge`, `post-checkout`, `post-rewrite` are configurable (see [Hook configuration](manifest.md#hook-configuration)).

## shell

zsh initialisation. Global scope only - source these from your `.zshrc`.

| Module | Source | Target |
|--------|--------|--------|
| init | `plugins/shell/init.zsh` | `~/.dotconfigs/shell/init.zsh` |
| aliases | `plugins/shell/aliases.zsh` | `~/.dotconfigs/shell/aliases.zsh` |

## Related

- [Manifest format](manifest.md) - how each module above is declared.
- [Deploy methods](deploy-methods.md) - what `symlink` / `merge` etc. mean.
- [ROSTER.md](ROSTER.md) - generated hook/skill/config reference.
