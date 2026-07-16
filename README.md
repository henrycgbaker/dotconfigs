# dotconfigs

My personal registry for dev configurations - **deployable across machines** and **configurable globally or per-project**.

It's a small, plugin-based config manager: plugin **manifests** are the catalogue of everything available, a per-instance **deploy.json** is the toggle board for what's on here, and `dotconfigs` links each selected item to its place (mostly symlinks) on any machine. `dots` is an alias for `dotconfigs`.

## 60-second start

```bash
git clone git@github.com:henrycgbaker/dotconfigs.git ~/Repositories/dotconfigs
cd ~/Repositories/dotconfigs
make install                # put dotconfigs + dots on PATH (./bin/dotconfigs setup)
dotconfigs init             # seed ~/.dotconfigs/deploy.json from the catalogue defaults
dotconfigs deploy           # deploy the selection (preview first with --dry-run)
```

Per-project hooks/skills, from inside a repo: `dotconfigs init . && dotconfigs deploy .`

**Requirements:** bash 3.2+ (macOS/Linux), [jq](https://jqlang.github.io/jq/). Full walkthrough → **[Getting started](docs/getting-started.md)**.

## Documentation

- [Getting started](docs/getting-started.md) - install → first global deploy → first project, end to end.

**Reference**
- [Commands](docs/commands.md) - every command, its flags, and examples.
- [Plugins](docs/plugins.md) - what each plugin (claude, git, shell) deploys and where.
- [Manifest format](docs/manifest.md) - the manifest schema and the four deploy methods.
- [ROSTER](docs/ROSTER.md) - generated index of all hooks, skills, and their event wiring.

**Explanation** 
- [Architecture](docs/architecture.md) - the single-source-of-truth dataflow and symlink ownership model.
- [Deploy methods](docs/deploy-methods.md) - symlink vs append vs managed vs merge, and **why** each is used.


## Plugins at a glance

| Plugin | Deploys |
|--------|---------|
| **claude** | Claude Code hooks (per-pattern safety guards + lifecycle hooks), skills (`/commit`, `/squash-merge`, `/preflight-merge`, `/check-resolution`, `/rebase-stacked-prs`, `/branch-cleanup`, `/pr-create`, `/fix-pr-feedback`, `/diagnose-missing-work`), `settings.json` (its hooks block synthesised from the selected hooks), the `concise-execution` output style, and the global `CLAUDE.md` |
| **git** | `~/.gitconfig` (incl. `init.templateDir` so new repos auto-seed hooks), global excludes (`~/.config/git/ignore`), 9 branch-aware hooks (pre-commit, pre-push, commit-msg, …) installed per-repo into `.git/hooks/`, and per-project `.git/info/exclude` + `.gitignore` |
| **shell** | shell-agnostic `init.sh` (starship, zoxide, fzf, thefuck, conda, zsh-autosuggestions/syntax-highlighting) + `aliases.sh` (eza, bat, …), auto-wired into `~/.zshrc`/`~/.bashrc` (bash + zsh, with a bash→zsh handoff when zsh is present) |

See [Plugins](docs/plugins.md) for what each plugin deploys, and each plugin's own page (linked there) for concrete detail on every hook/tool.

## Install the claude plugin via Claude Code

The claude plugin is also published as a native Claude Code plugin named **`dots`**, for use without the full dotconfigs deploy. From inside Claude Code:

```
/plugin marketplace add henrycgbaker/dotconfigs
/plugin install dots
```

It ships the same hooks, skills, output style, and (hook-free) `settings.json`, generated from `plugins/claude/` into the committed `claude-plugin/` artifact by `scripts/build-claude-plugin.sh`. Installed this way the skills are namespaced - `/dots:commit`, `/dots:squash-merge`, etc. (the dotconfigs deploy installs them un-namespaced). Re-run the build script after editing the source to refresh the artifact.

## How it works (in one breath)

Plugin **manifests** (`plugins/*/manifest.json`) are the single source of truth: a nested `category → item` catalogue. `init` seeds a **deploy.json** toggle board from each item's `default` — the machine one at `~/.dotconfigs/deploy.json`, a project's at `<repo>/.dotconfigs/deploy.json` — and `deploy` links each enabled item to its target (and tears down anything you've switched off). Deploy only touches files it owns and never clobbers foreign files without asking. Full picture → [Architecture](docs/architecture.md).
