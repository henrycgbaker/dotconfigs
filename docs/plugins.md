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
| output-styles | `plugins/claude/output-styles/` | `~/.claude/output-styles/` | symlink |
| CLAUDE.md | `plugins/claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | symlink |
| hooks-conf | `plugins/claude/templates/claude-hooks.conf` | `~/.claude/claude-hooks.conf` | copy |

- **Hooks:** per-pattern Bash guards (`block-rm-rf-root`, `block-force-push`, `block-hard-reset`, `block-git-clean`, `block-drop-table`, `block-chmod-777`), a Write/Edit guard (`block-sensitive-write`), attribution/comment guards, and lifecycle hooks (`inject-context`, `session-start-env`, `session-end-log`, `pre-compact-snapshot`, `notify`). Full table with descriptions and config keys: [ROSTER](ROSTER.md).
- **Skills:** `/commit`, `/squash-merge`, `/check-resolution`, `/preflight-merge`, `/rebase-stacked-prs`, `/branch-cleanup`, `/pr-create`, `/fix-pr-feedback` (each a `skills/<name>/SKILL.md`).
- **Output style:** `concise-execution` (default execution-mode style; carries the communication/language rules formerly inline in CLAUDE.md).

`settings.json` uses `merge` (not symlink/copy) because Claude Code writes permission grants into it - see [Deploy methods](deploy-methods.md). Project scope supports exclude lists to skip specific hooks/skills per repo.

### Hook activation and scope (claude)

Unlike git, Claude Code **does** read a machine-wide config: hooks are *activated* by a `hooks` block in a `settings.json`, and the user-scope `~/.claude/settings.json` fires in **every** directory. A hook **script** sitting in `~/.claude/hooks/` or a repo's `.claude/hooks/` does nothing on its own — only a `settings.json` entry pointing at it makes it run.

**Default: all hooks are wired at global scope only.** That gives machine-wide enforcement (the guards protect even non-repo directories) from a single source of truth.

dotconfigs *can* also wire hooks per-repo (point a project `.claude/settings.json` at `${CLAUDE_PROJECT_DIR}/.claude/hooks/<name>.sh`), and the project hook files + `exclude` list exist so you can. **But mind the footgun:**

> ⚠️ **Claude merges hooks additively across scopes — there is no dedup or override.** The same hook wired in *both* `~/.claude/settings.json` and a project `.claude/settings.json` for the same event runs **twice**. For idempotent PreToolUse guards that is merely wasted work; for context/lifecycle hooks (`inject-context` on `UserPromptSubmit`, `notify`) it double-injects context and **wastes tokens**. Wire a given hook in **one** scope only. `dotconfigs validate` and `project-deploy` warn when they detect a cross-scope duplicate (use `validate --strict` to make it an error).

## git

Manages git config, global excludes, and hooks.

| Module | Source | Target | Scope |
|--------|--------|--------|-------|
| hooks | `plugins/git/hooks/` | `~/.dotconfigs/git-template/hooks/` (global, seeds new repos), `.git/hooks/` (project) | both |
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

### How git hooks reach a repo (scope model)

Git only runs hooks from a repo's own `.git/hooks/` (or a `core.hooksPath`). There is no machine-wide hook directory it consults by default — so a hook is **only** enforced in repos where it physically lives. dotconfigs therefore treats git hooks as **per-repo**, with global-deploy seeding new repos rather than enforcing anything itself:

- **`global-deploy`** installs the hooks into the git **template dir** (`~/.dotconfigs/git-template/hooks/`) and sets `init.templateDir` in `~/.gitconfig`. Every subsequent `git init` / `git clone` copies them (symlinks preserved, so they auto-update) into the new repo's `.git/hooks/`. This is the *only* job of git global-deploy — it does not enforce hooks in already-existing repos.
- **`project-deploy`** installs/refreshes the hooks in an **existing** repo's `.git/hooks/`. Run it once per pre-existing repo (new ones are covered by the template dir).
- **`dotconfigs status`** audits every repo that has been project-deployed (tracked in `~/.dotconfigs/projects.list`) and flags any whose hooks have gone missing or dangling — e.g. after a re-clone or a `.git` wipe.

Hooks live in `.git/hooks/`, which git never tracks, so they stay personal and uncommitted. (Other project-deployed artifacts — `CLAUDE.md`, `.claude/` — are kept untracked via managed `.git/info/exclude` entries.)

> **Heads-up:** the earlier `~/.dotconfigs/git-hooks/` global target was inert — nothing pointed git at it, so those hooks never fired. Re-run `global-init && global-deploy` to migrate to the template dir, and `project-deploy` each existing repo.

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
