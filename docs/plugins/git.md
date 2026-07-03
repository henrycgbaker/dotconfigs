# git

[← docs](../../README.md#documentation) · [Plugins](../plugins.md) · Reference

Manages git config, global excludes, and hooks. Categories - `hooks`, `config`, `excludes`.

| Category | Item(s) | Target(s) | Method |
|----------|---------|-----------|--------|
| hooks | 9 hooks (`pre-commit`, `commit-msg`, …) | `~/.dotconfigs/git-template/hooks/<name>` (seeds new repos) + `.git/hooks/<name>` (per-repo) | symlink |
| config | `gitconfig-base` | `~/.dotconfigs/gitconfig-base` | symlink |
| config | `gitconfig-include` | `~/.gitconfig` (`[include]` stanza) | append |
| excludes | `global-excludes` | `~/.config/git/ignore` | symlink |
| excludes | `project-excludes` | `.git/info/exclude` (managed block) | managed |
| excludes | `gitignore` | `.gitignore` | append |

`~/.gitconfig` itself is never symlinked: `gitconfig-base` is symlinked to
`~/.dotconfigs/gitconfig-base`, and an `[include]` stanza is appended to `~/.gitconfig` pointing at
it - so your hand-written `~/.gitconfig` lines survive.

## What each hook actually does

| Hook | What it does |
|------|-------------|
| `pre-commit` | Identity check, secrets scan (gitleaks or regex fallback), blocks direct commits to main/master, blocks staging `.planning/`, Ruff format+lint on staged Python files, advisory resurrection-check after a merge/rebase |
| `commit-msg` | Blocks AI attribution patterns (`Co-Authored-By: Claude`, etc.) |
| `pre-push` | Blocks force-push to main/master, fast lint/format check |
| `pre-rebase` | Blocks rebasing main/master; warns about already-pushed commits |
| `prepare-commit-msg` | Auto-prefixes the commit message from the branch name (`feature/*` → `feat:`) |
| `post-checkout` | Prints branch information after checkout |
| `post-merge` | Dependency-change detection + migration reminders |
| `post-rewrite` | Dependency-change detection for rebase/amend workflows |
| `check-facade-consumers` | Verifies every facade `__all__` entry has an external consumer |

Each git hook is a self-contained script, but the **checks** inside it are individually toggleable.
To skip a whole hook in a given repo, set its item `false` in that repo's `.dotconfigs/deploy.json`.
To turn off just one check, nest it under the hook:

```jsonc
"git": { "hooks": { "pre-commit": { "enabled": true, "checks": { "block-main": false } } } }
```

A machine `deploy` materialises these toggles into git config (`dotconfigs.<hook>.<check>`), which
the hooks read at run time - a missing key means on, so default behaviour is preserved everywhere.
Flip one ad-hoc with `git config --global dotconfigs.pre-commit.block-main false`. Each hook's
checks are listed in [ROSTER](../ROSTER.md).

## What the excludes/config items actually do

| Item | What it does |
|------|-------------|
| `gitconfig-base` | Identity, `core`, pull/fetch/push defaults, and a set of git aliases, included from `~/.gitconfig` |
| `global-excludes` | OS (`.DS_Store`, …), editor, language, Claude, and Python patterns applied to every repo via `~/.config/git/ignore` |
| `project-excludes` | Per-repo, machine-local excludes seeded into `.git/info/exclude` - `.dotconfigs/`, `.claude/`, `CLAUDE.md`, `.idea/`/`.vscode/`, `.env*`, `.planning/`, and a handful of Claude Code sandbox artefact paths |
| `gitignore` | Seeds default patterns (the same kind as global-excludes) into a repo's own tracked `.gitignore` |

## How git hooks reach a repo (scope model)

Git only runs hooks from a repo's own `.git/hooks/`. There is no machine-wide hook directory it
consults by default - so a hook is **only** enforced in repos where it physically lives. dotconfigs
therefore gives each git hook a dual target:

- **machine target** (`~/.dotconfigs/git-template/hooks/<name>`) - the git **template dir**. A
  machine `deploy` populates it and reconciles `init.templateDir` in `~/.gitconfig` (set while any
  git hook is selected, unset when none are). Every subsequent `git init` / `git clone` copies the
  hooks (symlinks preserved, so they auto-update) into the new repo's `.git/hooks/`. This seeds new
  repos; it does **not** enforce hooks in already-existing ones.
- **project target** (`.git/hooks/<name>`) - installs/refreshes the hooks in an **existing** repo.
  Run `dotconfigs deploy <repo>` once per pre-existing repo (new ones are covered by the template
  dir).
- **`dotconfigs status`** audits every project-deployed repo (tracked in
  `~/.dotconfigs/projects.list`) and flags any whose hooks have gone missing or dangling - e.g.
  after a re-clone or a `.git` wipe.

Hooks live in `.git/hooks/`, which git never tracks, so they stay personal and uncommitted. (Other
project-deployed artefacts - `.claude/` skills - are kept untracked via the managed
`.git/info/exclude` block.)

## Related

- [Plugins overview](../plugins.md)
- [Manifest format](../manifest.md)
- [Deploy methods](../deploy-methods.md)
- [ROSTER.md](../ROSTER.md) - generated hook/skill reference
