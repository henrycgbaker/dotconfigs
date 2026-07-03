# Plugins

[← docs](../README.md#documentation) · Reference

Each plugin is a self-contained directory under `plugins/` with a `manifest.json` cataloguing its items. Generated index of every hook/skill with its Event/Matcher wiring: [ROSTER.md](ROSTER.md).

## claude

Manages Claude Code configuration. Catalogued under three categories - `hooks`, `skills`, `config`.

| Category | Items | Target(s) | Method |
|----------|-------|-----------|--------|
| hooks | `_hook-common` + 14 event hooks | `~/.claude/hooks/<name>.sh` | symlink |
| skills | `commit`, `squash-merge`, … (9) | `~/.claude/skills/<name>` + `.claude/skills/<name>` | symlink |
| config | `settings` | `~/.claude/settings.json` | [merge](deploy-methods.md#the-settingsjson-case-why-merge-exists) |
| config | `claude-md` | `~/.claude/CLAUDE.md` | symlink |
| config | `output-style` | `~/.claude/output-styles/concise-execution.md` | symlink |

- **Hooks:** per-pattern Bash guards (`block-rm-rf-root`, `block-force-push`, `block-hard-reset`, `block-git-clean`, `block-drop-table`, `block-chmod-777`), a Write/Edit guard (`block-sensitive-write`), attribution/comment guards (`block-ai-pr-attribution`, `block-gh-comment`), the facade check (`facade-check`), and lifecycle hooks (`inject-context`, `session-start-env`, `session-end-log`, `pre-compact-snapshot`, `notify`). `_hook-common` is a sourced helper library, not an event hook (no `wiring`). Full table with descriptions and Event/Matcher: [ROSTER](ROSTER.md).
- **Skills:** `/commit`, `/squash-merge`, `/check-resolution`, `/preflight-merge`, `/rebase-stacked-prs`, `/branch-cleanup`, `/pr-create`, `/fix-pr-feedback`, `/diagnose-missing-work` (each a `skills/<name>/SKILL.md`). Their dual target deploys them globally **and** lets them be installed per-repo.
- **Output style:** `concise-execution` (default execution-mode style; carries the communication/language rules).

`settings.json` uses `merge` (not symlink) because Claude Code writes permission grants into it - see [Deploy methods](deploy-methods.md). There is no `claude-hooks.conf`: a hook is on when its item is `true` in `deploy.json`; to disable one, set it `false`.

### Hook wiring and scope (claude)

Unlike git, Claude Code **does** read a machine-wide config: a hook is *activated* by a `hooks` block in `~/.claude/settings.json`, which fires in **every** directory. A hook **script** in `~/.claude/hooks/` does nothing on its own - only a `settings.json` entry pointing at it makes it run.

That entry is **not hand-maintained**. Each event hook's manifest entry carries a `wiring` field (`{ event, matcher?, if?, timeout? }`, or an array of them). On every machine `deploy`, dotconfigs synthesises the `settings.json` `hooks` block from the `wiring` of exactly the hooks selected in `deploy.json`:

> **Single toggle, no dangling refs.** Selecting a hook symlinks its script *and* wires it; deselecting it (setting the item `false` in `deploy.json`) removes both. There is no separate wiring step, no static `hooks` block in `plugins/claude/settings.json`, and no way for a wired command to point at a script that isn't deployed.

All Claude hooks are wired at machine scope, so the guards protect even non-repo directories from a single source of truth.

## git

Manages git config, global excludes, and hooks. Categories - `hooks`, `config`, `excludes`.

| Category | Item(s) | Target(s) | Method |
|----------|---------|-----------|--------|
| hooks | 9 hooks (`pre-commit`, `commit-msg`, …) | `~/.dotconfigs/git-template/hooks/<name>` (seeds new repos) + `.git/hooks/<name>` (per-repo) | symlink |
| config | `gitconfig-base` | `~/.dotconfigs/gitconfig-base` | symlink |
| config | `gitconfig-include` | `~/.gitconfig` (`[include]` stanza) | append |
| excludes | `global-excludes` | `~/.config/git/ignore` | symlink |
| excludes | `project-excludes` | `.git/info/exclude` (managed block) | managed |
| excludes | `gitignore` | `.gitignore` | append |

`~/.gitconfig` itself is never symlinked: `gitconfig-base` is symlinked to `~/.dotconfigs/gitconfig-base`, and an `[include]` stanza is appended to `~/.gitconfig` pointing at it - so your hand-written `~/.gitconfig` lines survive.

**Hooks:**

| Hook | What it does |
|------|-------------|
| `pre-commit` | Identity check, secrets scan, block main commits, Ruff format+lint on staged files |
| `commit-msg` | Blocks AI attribution patterns |
| `pre-push` | Force-push protection + fast lint/format check |
| `pre-rebase` | Blocks rebasing main/master; warns about pushed commits |
| `prepare-commit-msg` | Auto-prefix from branch name (`feature/*` → `feat:`) |
| `post-checkout` | Branch info on checkout |
| `post-merge` | Dependency-change detection + migration reminders |
| `post-rewrite` | Dependency detection for rebase workflows |
| `check-facade-consumers` | Verify every facade `__all__` entry has an external consumer |

Each git hook is a self-contained script, but the **checks** inside it are individually toggleable. To skip a whole hook in a given repo, set its item `false` in that repo's `.dotconfigs/deploy.json`. To turn off just one check, nest it under the hook:

```jsonc
"git": { "hooks": { "pre-commit": { "enabled": true, "checks": { "block-main": false } } } }
```

A machine `deploy` materialises these toggles into git config (`dotconfigs.<hook>.<check>`), which the hooks read at run time - a missing key means on, so default behaviour is preserved everywhere. Flip one ad-hoc with `git config --global dotconfigs.pre-commit.block-main false`. Each hook's checks are listed in [ROSTER](ROSTER.md).

### How git hooks reach a repo (scope model)

Git only runs hooks from a repo's own `.git/hooks/`. There is no machine-wide hook directory it consults by default - so a hook is **only** enforced in repos where it physically lives. dotconfigs therefore gives each git hook a dual target:

- **machine target** (`~/.dotconfigs/git-template/hooks/<name>`) - the git **template dir**. A machine `deploy` populates it and reconciles `init.templateDir` in `~/.gitconfig` (set while any git hook is selected, unset when none are). Every subsequent `git init` / `git clone` copies the hooks (symlinks preserved, so they auto-update) into the new repo's `.git/hooks/`. This seeds new repos; it does **not** enforce hooks in already-existing ones.
- **project target** (`.git/hooks/<name>`) - installs/refreshes the hooks in an **existing** repo. Run `dotconfigs deploy <repo>` once per pre-existing repo (new ones are covered by the template dir).
- **`dotconfigs status`** audits every project-deployed repo (tracked in `~/.dotconfigs/projects.list`) and flags any whose hooks have gone missing or dangling - e.g. after a re-clone or a `.git` wipe.

Hooks live in `.git/hooks/`, which git never tracks, so they stay personal and uncommitted. (Other project-deployed artefacts - `.claude/` skills - are kept untracked via the managed `.git/info/exclude` block.)

## shell

zsh initialisation. Machine scope only - auto-wired into `~/.zshrc` via a managed block, so there's nothing to source by hand.

| Item | Source | Target |
|------|--------|--------|
| `init` | `plugins/shell/init.zsh` | `~/.dotconfigs/shell/init.zsh` |
| `aliases` | `plugins/shell/aliases.zsh` | `~/.dotconfigs/shell/aliases.zsh` |
| `zshrc-wiring` | `plugins/shell/templates/zshrc-managed-block` | `~/.zshrc` (managed block) |

### Requirements

This plugin wires up, but does not install, these tools - each `eval`/`source` in `init.zsh` is guarded and no-ops if the tool is missing. On macOS:

```bash
brew install starship zoxide fzf thefuck eza bat zsh-autosuggestions zsh-syntax-highlighting displayplacer
```

On Debian/Ubuntu, `starship`, `zoxide`, and `eza` aren't in the default apt repos (install via their own installer scripts or a PPA); the rest are:

```bash
sudo apt install fzf thefuck bat zsh-autosuggestions zsh-syntax-highlighting
```

`zsh-autosuggestions`/`zsh-syntax-highlighting` are found either way - `init.zsh` checks Homebrew's prefix (mac, or Linuxbrew) first, then falls back to apt's `/usr/share`. miniconda is installed via its own installer, not brew/apt.

## Related

- [Manifest format](manifest.md) - how each item above is declared.
- [Deploy methods](deploy-methods.md) - what `symlink` / `merge` etc. mean.
- [ROSTER.md](ROSTER.md) - generated hook/skill/config reference.
