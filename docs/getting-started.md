# Getting started

[← docs](../README.md#documentation) · Tutorial

Install dotconfigs, deploy your machine config, then wire up a project - end to end.

## Requirements

- bash 3.2+ (macOS or Linux)
- [jq](https://jqlang.github.io/jq/)

## Install

```bash
git clone git@github.com:henrycgbaker/dotconfigs.git ~/Repositories/dotconfigs
cd ~/Repositories/dotconfigs
./src/dotconfigs setup
```

`setup` adds `dotconfigs` (and the alias `dots`) to your PATH.

## Seed and deploy your machine config

```bash
dotconfigs init               # Seed ~/.dotconfigs/deploy.json from the manifests
dotconfigs deploy --dry-run   # Preview the changes
dotconfigs deploy             # Deploy the selection
```

`init` writes a **selection** (the toggle board): every catalogued item with a machine target, listed with its default on/off value. `deploy` then symlinks/merges each enabled item to its target (`~/.claude/`, `~/.gitconfig`, `~/.config/git/ignore`, `~/.dotconfigs/...`). For git it also reconciles `init.templateDir`, so **every git repo you create or clone from now on auto-installs the git hooks** into its own `.git/hooks/`. For Claude the `~/.claude/settings.json` `hooks` block is synthesised from the hooks you have enabled - no manual wiring. (Claude hooks fire machine-wide; git hooks are inherently per-repo - see [Architecture](architecture.md#hook-activation-claude-vs-git).)

## Per-machine settings (`.env`)

A machine `init` also seeds `~/.dotconfigs/.env` from the repo's `.env.example` (only if one doesn't exist yet). It holds the few values that vary per person/machine and is sourced by the engine at startup:

- `DOTCONFIGS_AUTHOR_NAME` / `DOTCONFIGS_AUTHOR_EMAIL` - baked into the `settings.json` attribution placeholders. Resolution is `git config --includes user.{name,email}` first, then these, then a built-in default - so if your git identity is set (directly or via an included config) you can leave them blank.
- `DOTCONFIGS_BIN_DIR` - where the `dotconfigs`/`dots` symlinks go (default: `~/.local/bin` if present, else `/usr/local/bin`).

It lives outside the repo, so it's never committed. Paths the host tools dictate (`~/.claude`, `~/.gitconfig`, `~/.config/git`) are deliberately **not** configurable here. Edit it, then re-run `deploy`.

## Toggle what deploys

`deploy.json` is the single place to control what's on for this instance. Open `~/.dotconfigs/deploy.json`, flip any item to `false`, and re-run `deploy` - the item's artefact is torn down in the same pass (its symlink removed, and for a Claude hook, its `settings.json` wiring too). Flip it back to `true` and re-`deploy` to restore it.

To re-seed after adding a plugin or editing a manifest:

```bash
dotconfigs init               # re-seeds ~/.dotconfigs/deploy.json (old one backed up to .bak)
```

## Deploy per-project config

New repos are already covered by `init.templateDir` above. For a repo that **existed before** you ran the machine deploy, seed and deploy its selection once:

```bash
dotconfigs init .       # Seed <repo>/.dotconfigs/deploy.json (also excludes it from git)
dotconfigs deploy .     # Deploy hooks + skills into this repo
```

`deploy .` records the repo so `dotconfigs status` can later flag it if its git hooks go missing (e.g. after a re-clone). To skip specific hooks or skills in this repo, set their items `false` in `.dotconfigs/deploy.json` before deploying.

### Turn off automatic git-hook seeding

`init.templateDir` is coupled to the git hooks. If you'd rather *not* have every new repo auto-install them, toggle the git hooks off and re-deploy:

```bash
# in ~/.dotconfigs/deploy.json, set the git hooks (pre-commit, commit-msg, …) to false
dotconfigs deploy           # tears the template-dir hooks down and unsets init.templateDir
```

No leftover config, and existing repos keep whatever hooks they already have. (Set them back to `true` and deploy to turn seeding on again.)

## Deploy methods

Each item declares a `method` (`symlink` · `append` · `managed` · `merge`) controlling how its source reaches the target - the default is `symlink`. You rarely touch this, but it's worth knowing why `~/.claude/settings.json` is merged rather than symlinked: see [Deploy methods](deploy-methods.md).

## Common tasks

| Task | Command |
|------|---------|
| Re-seed the machine selection | `dotconfigs init` |
| Preview changes | `dotconfigs deploy --dry-run` |
| Force overwrite conflicts | `dotconfigs deploy --force` |
| Toggle an item | edit `deploy.json` → `dotconfigs deploy` |
| Check deployment status | `dotconfigs status` |
| List available plugins | `dotconfigs list` |
| Detailed help | `dotconfigs help <command>` |

## Next

- [Commands](commands.md) - every command and flag.
- [Plugins](plugins.md) - what each plugin deploys.
- [Architecture](architecture.md) - how the catalogue → deploy.json → deploy flow works.
- [Deploy methods](deploy-methods.md) - symlink vs append vs managed vs merge, and why.
