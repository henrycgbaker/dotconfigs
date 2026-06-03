# dotconfigs

My personal registry for dev configurations - hooks, skills, git/shell/editor setup - **deployable across machines** and **configurable globally or per-project**. No secrets, just the setup I want everywhere.

It's a small, plugin-based config manager: plugin **manifests** declare what's available, and `dotconfigs` deploys it (mostly symlinks) to the right places on any machine. `dots` is an alias for `dotconfigs`.

## 60-second start

```bash
git clone git@github.com:henrycgbaker/dotconfigs.git ~/Repositories/dotconfigs
cd ~/Repositories/dotconfigs
./dotconfigs setup          # put dotconfigs + dots on PATH
dotconfigs global-init      # scaffold .dotconfigs/global.json from the manifests
dotconfigs global-deploy    # deploy everything (preview first with --dry-run)
```

Per-project hooks/skills, from inside a repo: `dotconfigs project-init . && dotconfigs project-deploy .`

**Requirements:** bash 3.2+ (macOS/Linux), [jq](https://jqlang.github.io/jq/). Full walkthrough → **[Getting started](docs/getting-started.md)**.

## Documentation

Start with the tutorial, reach for how-tos when you have a task, references when you need exact detail, and explanations when you want to understand why.

**Tutorial**
- [Getting started](docs/getting-started.md) - install → first global deploy → first project, end to end.

**Reference** (look things up)
- [Commands](docs/commands.md) - every command, its flags, and examples.
- [Plugins](docs/plugins.md) - what each plugin (claude, git, shell, vscode) deploys and where.
- [Manifest format](docs/manifest.md) - the manifest schema and the four deploy methods.
- [ROSTER](docs/ROSTER.md) - generated index of all hooks, skills, and their config keys.

**Explanation** (understand how it works)
- [Architecture](docs/architecture.md) - the single-source-of-truth dataflow and symlink ownership model.
- [Deploy methods](docs/deploy-methods.md) - symlink vs copy vs append vs merge, and **why** each is used.
- [Git hooks strategy](docs/git-hooks-strategy.md) - the rationale behind the branch-aware hook setup.
- [Claude Code concepts](docs/claude-code-concepts.md) - background on agents, skills, hooks, and token impact.

## Plugins at a glance

| Plugin | Deploys |
|--------|---------|
| **claude** | Claude Code hooks, skills (`/commit`, `/squash-merge`, `/preflight-merge`, `/check-resolution`, `/rebase-stacked-prs`), `settings.json`, global `CLAUDE.md` |
| **git** | `~/.gitconfig`, global excludes, and 8 branch-aware hooks (pre-commit, pre-push, commit-msg, …) |
| **shell** | zsh `init.zsh` + `aliases.zsh` (source them from `.zshrc`) |
| **vscode** | VS Code `settings.json` (macOS) |

See [Plugins](docs/plugins.md) for the full module tables.

## How it works (in one breath)

Plugin **manifests** (`plugins/*/manifest.json`) are the single source of truth. `global-init`/`project-init` assemble them into `.dotconfigs/global.json` / `.dotconfigs/project.json` (your editable include/exclude lists), and `global-deploy`/`project-deploy` link each module to its target. Deploy only touches files it owns and never clobbers foreign files without asking. Full picture → [Architecture](docs/architecture.md).
