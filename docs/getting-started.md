# Getting started

[← docs](../README.md#documentation) · Tutorial

Install dotconfigs, deploy your global config, then wire up a project - end to end.

## Requirements

- bash 3.2+ (macOS or Linux)
- [jq](https://jqlang.github.io/jq/)

## Install

```bash
git clone git@github.com:henrycgbaker/dotconfigs.git ~/Repositories/dotconfigs
cd ~/Repositories/dotconfigs
./dotconfigs setup
```

`setup` adds `dotconfigs` (and alias `dots`) to your PATH.

## Scaffold and deploy global config

```bash
dotconfigs global-init          # Scaffold .dotconfigs/global.json from manifests
dotconfigs global-deploy        # Deploy all plugins
dotconfigs global-deploy git    # Deploy one plugin
dotconfigs global-deploy --dry-run  # Preview first
```

This symlinks plugin files (hooks, settings, skills, gitconfig, etc.) to their global targets (`~/.claude/`, `~/.gitconfig`, `~/Library/...`). For git it also installs `init.templateDir`, so **every git repo you create or clone from now on auto-installs the git hooks** into its own `.git/hooks/`. (Claude hooks fire machine-wide from `~/.claude/settings.json`; git hooks are inherently per-repo - see [Architecture](architecture.md#hook-activation-two-different-models).)

## Deploy per-project config

New repos are already covered by `init.templateDir` above. For a repo that **existed before** you ran `global-deploy`, install the hooks into it once:

```bash
dotconfigs project-init .       # Scaffold .dotconfigs/project.json
dotconfigs project-deploy .     # Deploy hooks + skills into this repo
```

`project-deploy` records the repo so `dotconfigs status` can later flag it if its git hooks go missing (e.g. after a re-clone). To skip specific hooks or skills per-project, edit `.dotconfigs/project.json` exclude lists before deploying.

### Turn off automatic git-hook seeding

If you'd rather *not* have every new repo auto-install the git hooks, remove the git `hooks` module from your selection and re-deploy:

```bash
# edit .dotconfigs/global.json → delete the "hooks" entry under "git"
dotconfigs global-deploy        # unsets init.templateDir for you
dotconfigs cleanup --apply      # removes the now-unused ~/.dotconfigs/git-template/hooks/
```

`init.templateDir` is coupled to that module, so excluding it makes `global-deploy` unset the templateDir automatically - no leftover config, and existing repos keep whatever hooks they already have. (Re-add the module and deploy to turn it back on.)

## Deploy methods

Each module declares a `method` (`symlink` · `append` · `copy` · `merge`) controlling how its source reaches the target - the default is `symlink`. You rarely touch this, but it's worth knowing why `~/.claude/settings.json` is merged rather than symlinked: see [Deploy methods](deploy-methods.md).

## Customise

Edit `.dotconfigs/global.json` to change which modules are deployed globally (add/remove entries in include/exclude lists). Edit `.dotconfigs/project.json` for per-repo overrides.

To re-scaffold after adding a plugin or changing manifests:

```bash
dotconfigs global-init           # Re-assemble .dotconfigs/global.json from manifests
```

## Common tasks

| Task | Command |
|------|---------|
| Re-scaffold global config | `dotconfigs global-init` |
| Preview changes | `dotconfigs global-deploy --dry-run` |
| Force overwrite conflicts | `dotconfigs global-deploy --force` |
| Check deployment status | `dotconfigs status` |
| List available plugins | `dotconfigs list` |
| Detailed help | `dotconfigs help <command>` |

## Next

- [Commands](commands.md) - every command and flag.
- [Plugins](plugins.md) - what each plugin deploys.
- [Architecture](architecture.md) - how the manifest → deploy flow works.
- [Deploy methods](deploy-methods.md) - symlink vs copy vs append vs merge, and why.
