# Commands

[← docs](../README.md#documentation) · Reference

`dotconfigs <command> [args]` (or the `dots` alias). Run `dotconfigs help <command>` for inline help.

The command surface is **path-presence driven**: no path ⇒ machine scope (`~/...` targets, selection at `~/.dotconfigs/deploy.json`); a path ⇒ that project repo (relative targets, selection at `<repo>/.dotconfigs/deploy.json`).

| Command | Purpose |
|---------|---------|
| `setup` | One-time: put `dotconfigs`/`dots` on PATH |
| `init [path]` | Seed a selection (`deploy.json`) from the manifests |
| `deploy [path]` | Deploy the selection (machine, or a project repo) |
| `undeploy [path]` | Remove deployed artefacts (inverse of deploy) |
| `cleanup [path]` | Remove stale/broken symlinks dotconfigs owns |
| `status [plugin]` | Show deployment status / drift |
| `validate [--strict]` | Lint manifests + scan deployed JSON for dangling references |
| `list` | List plugins and their deployment status |
| `help [command]` | Detailed help |

## setup

```bash
dotconfigs setup          # run once after cloning
```
Creates PATH symlinks for `dotconfigs` and the `dots` alias. Run `init` next.

## init `[path]` `[--force]`

```bash
dotconfigs init           # seed the machine selection: ~/.dotconfigs/deploy.json
dotconfigs init .         # seed a per-project selection: <repo>/.dotconfigs/deploy.json
```
Seeds a **selection** (the toggle board) from the plugin manifests. Every catalogued item with a target in that scope is listed with its `default` on/off value. With a path it requires a git repo and adds `.dotconfigs/` to that repo's `.git/info/exclude`. Edit the file to toggle items, then run `deploy [path]`. `--force` overwrites an existing selection without prompting (the old one is backed up to a timestamped `.bak`).

## deploy `[path]` `[--dry-run]` `[--force]`

```bash
dotconfigs deploy             # deploy the machine selection
dotconfigs deploy .           # deploy the project selection into this repo
dotconfigs deploy --dry-run   # preview, no changes
dotconfigs deploy --force     # overwrite conflicting foreign files
```
Deploys from `deploy.json` to the filesystem. **Enabled items are deployed; items toggled off are torn down in the same pass** - so flipping an item to `false` and re-running `deploy` removes its artefact. Each item is applied by its [deploy method](deploy-methods.md). A machine deploy also reconciles the git `init.templateDir` (set when any git hook is selected, unset when none are) and ensures `dotconfigs`/`dots` are on PATH. If a target exists and isn't dotconfigs-owned you're prompted to overwrite/skip (ownership is tracked per file, so dotconfigs coexists with other tools in shared dirs like `~/.claude/`); `--force` skips the prompt.

## undeploy `[path]` `[--apply]` `[--dry-run]`

```bash
dotconfigs undeploy           # preview removing the machine artefacts (dry-run)
dotconfigs undeploy . --apply # remove this repo's deployed artefacts
```
Inverse of deploy. Removes dotconfigs-owned symlinks (foreign files preserved) and `managed` blocks (the sentinel-delimited region only). `merge` and `append` targets are left alone - they can't be reversed without losing local content. Default is dry-run; pass `--apply` to remove.

## cleanup `[path]` `[--apply]` `[--dry-run]`

```bash
dotconfigs cleanup            # preview stale/broken machine symlinks (dry-run)
dotconfigs cleanup --apply    # actually remove them
dotconfigs cleanup . --apply  # clean a project's deployed symlinks
```
Removes **only stale and broken symlinks** that dotconfigs owns - links no longer in the selection (e.g. you toggled an item to `false`) or broken ones pointing back into the repo. It does **not** touch merged-JSON or appended files, and never removes foreign files or foreign symlinks. Default is dry-run; pass `--apply` to remove. A clean, in-sync deployment correctly reports `Removed: 0` (a normal `deploy` already prunes stale symlinks as it runs).

## Removing deployed config

What it takes depends on the item's deploy method:

- **symlink** (hooks, skills, output-styles, `CLAUDE.md`): set the item `false` in `deploy.json`, then `deploy` (it tears it down) - or `cleanup --apply`.
- **merge** (`settings.json`): set the item `false` and re-`deploy`; for a key inside the merged file, remove it by hand (the merge never deletes keys).

To stop deploying something on *this instance*, edit its `deploy.json` (your selection). To remove a capability *everywhere*, edit the plugin manifest (the catalogue) and re-run `init`.

## status `[plugin]`

```bash
dotconfigs status
dotconfigs status claude
```
Shows per-item state for the machine selection: **✓ deployed** (symlink correct), **△ drift** (broken/foreign/wrong target), **✗ not deployed**.

Also runs a **project git-hook audit**: every repo that has been project-deployed is recorded in `~/.dotconfigs/projects.list`, and `status` (or `status git`) walks that list and flags any whose git hooks have gone missing or dangling - the per-repo failure mode that lets AI attribution slip through a `commit-msg` hook that isn't actually installed. The fix it suggests is `dotconfigs deploy <repo>`.

## validate `[--strict]`

```bash
dotconfigs validate            # lint manifests + scan deployed config
dotconfigs validate --strict   # treat dangling-reference warnings as failures
```
Lints every plugin manifest (valid JSON, methods ∈ `symlink`/`merge`/`append`/`managed`, item keys ∈ the whitelist, sources exist) and scans deployed merge targets (e.g. `~/.claude/settings.json`) for dangling command references - a hook `command` or `statusLine.command` pointing at a script that isn't actually deployed. Exits non-zero on any error; `--strict` also fails on dangling-reference warnings. Runs without deploying or mutating anything.

## list

```bash
dotconfigs list
```
Lists available plugins and their deployment status (deployed / partially deployed / drifted / not deployed).

## help `[command]`

```bash
dotconfigs help
dotconfigs help deploy
```

## Related

- [Getting started](getting-started.md) - these commands in a guided sequence.
- [Manifest format](manifest.md) / [Deploy methods](deploy-methods.md) - what deploy acts on and how.
- [Plugins](plugins.md) - what each deploy actually places.
