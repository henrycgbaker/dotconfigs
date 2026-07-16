# Plugins

[← docs](../README.md#documentation) · Reference

Each plugin is a self-contained directory under `plugins/` with a `manifest.json` cataloguing its
items. This page is an index - each plugin's concrete detail (what it deploys, what every hook/tool
actually does) lives in its own page:

| Plugin | Deploys |
|--------|---------|
| [**claude**](plugins/claude.md) | Claude Code hooks (safety guards + lifecycle hooks), skills (`/commit`, `/squash-merge`, …), `settings.json`, the `concise-execution` output style, and the global `CLAUDE.md` |
| [**git**](plugins/git.md) | `~/.gitconfig`, global excludes, 9 branch-aware hooks, and per-project `.git/info/exclude` + `.gitignore` |
| [**shell**](plugins/shell.md) | shell-agnostic `init.sh` + `aliases.sh` (starship, zoxide, fzf, thefuck, conda, eza, bat, …), auto-wired into `~/.zshrc`/`~/.bashrc` (bash + zsh) |

Generated index of every hook/skill with its Event/Matcher wiring: [ROSTER.md](ROSTER.md).

## How it works (in one breath)

Plugin **manifests** (`plugins/*/manifest.json`) are the single source of truth: a nested
`category → item` catalogue. `init` seeds a **deploy.json** toggle board from each item's
`default` - the machine one at `~/.dotconfigs/deploy.json`, a project's at
`<repo>/.dotconfigs/deploy.json` - and `deploy` links each enabled item to its target (and tears
down anything you've switched off). Deploy only touches files it owns and never clobbers foreign
files without asking. Full picture → [Architecture](architecture.md).

## Related

- [Manifest format](manifest.md) - how each item in a plugin page is declared.
- [Deploy methods](deploy-methods.md) - what `symlink` / `append` / `managed` / `merge` mean.
- [ROSTER.md](ROSTER.md) - generated hook/skill/config reference.
