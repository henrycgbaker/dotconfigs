# Quickstart

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

This symlinks plugin files (hooks, settings, skills, gitconfig, etc.) to their global targets (`~/.claude/`, `~/.gitconfig`, `~/Library/...`).

## Deploy per-project config

From inside a git repo:

```bash
dotconfigs project-init .       # Scaffold .dotconfigs/project.json
dotconfigs project-deploy .     # Deploy hooks + skills into this repo
```

To skip specific hooks or skills per-project, edit `.dotconfigs/project.json` exclude lists before deploying.

## Deploy methods

Each module in a manifest declares a `method` controlling how source files reach their target:

| Method | Behaviour | Use when |
|--------|-----------|----------|
| `symlink` | Creates a symlink from target to source. Updates live when source changes. | Default for most files — hooks, skills, gitconfig |
| `append` | Appends source content to target (idempotent — skips if already present). Preserves existing content. | Target may have user/project content — `.gitignore`, `.git/info/exclude` |
| `copy` | Overwrites target with source. Target is independent of source after deploy. | Structured files that can't be appended (JSON) |

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

See [README.md](../README.md) for full architecture and plugin reference.
