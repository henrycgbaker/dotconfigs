# dotconfigs

My personal registry for dev configurations - **deployable across machines** and **configurable globally or per-project**.

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

- [Getting started](docs/getting-started.md) - install → first global deploy → first project, end to end.

**Reference**
- [Commands](docs/commands.md) - every command, its flags, and examples.
- [Plugins](docs/plugins.md) - what each plugin (claude, git, shell) deploys and where.
- [Manifest format](docs/manifest.md) - the manifest schema and the four deploy methods.
- [ROSTER](docs/ROSTER.md) - generated index of all hooks, skills, and their config keys.

**Explanation** 
- [Architecture](docs/architecture.md) - the single-source-of-truth dataflow and symlink ownership model.
- [Deploy methods](docs/deploy-methods.md) - symlink vs copy vs append vs merge, and **why** each is used.


## Plugins at a glance

| Plugin | Deploys |
|--------|---------|
| **claude** | Claude Code hooks (per-pattern safety guards + lifecycle hooks), skills (`/commit`, `/squash-merge`, `/preflight-merge`, `/check-resolution`, `/rebase-stacked-prs`, `/branch-cleanup`, `/pr-create`, `/fix-pr-feedback`), `settings.json`, the `concise-execution` output style, global `CLAUDE.md`, and `claude-hooks.conf` |
| **git** | `~/.gitconfig`, global excludes (`~/.config/git/ignore`), 8 branch-aware hooks (pre-commit, pre-push, commit-msg, …), and per-project `.git/info/exclude` + `.gitignore` |
| **shell** | zsh `init.zsh` + `aliases.zsh` (source them from `.zshrc`) |

See [Plugins](docs/plugins.md) for the full module tables.

## Install the claude plugin via Claude Code

The claude plugin is also published as a native Claude Code plugin named **`dots`**, for use without the full dotconfigs deploy. From inside Claude Code:

```
/plugin marketplace add henrycgbaker/dotconfigs
/plugin install dots
```

It ships the same hooks, skills, output style, and (hook-free) `settings.json`, generated from `plugins/claude/` into the committed `claude-plugin/` artifact by `scripts/build-claude-plugin.sh`. Installed this way the skills are namespaced - `/dots:commit`, `/dots:squash-merge`, etc. (the dotconfigs deploy installs them un-namespaced). Re-run the build script after editing the source to refresh the artifact.

## How it works (in one breath)

Plugin **manifests** (`plugins/*/manifest.json`) are the single source of truth. `global-init`/`project-init` assemble them into `.dotconfigs/global.json` / `.dotconfigs/project.json` (your editable include/exclude lists), and `global-deploy`/`project-deploy` link each module to its target. Deploy only touches files it owns and never clobbers foreign files without asking. Full picture → [Architecture](docs/architecture.md).
