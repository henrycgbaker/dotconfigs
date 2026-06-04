# Commands

[← docs](../README.md#documentation) · Reference

`dotconfigs <command> [args]` (or the `dots` alias). Run `dotconfigs help <command>` for inline help.

| Command | Aliases | Purpose |
|---------|---------|---------|
| `setup` | | One-time: put `dotconfigs`/`dots` on PATH |
| `global-init` | | Scaffold `.dotconfigs/global.json` from manifests |
| `global-deploy [group]` | `deploy` | Deploy global config |
| `project-init [path]` | | Scaffold `.dotconfigs/project.json` for a repo |
| `project-deploy [path]` | `project` | Deploy per-project config |
| `cleanup [--project P]` | | Remove stale/broken symlinks dotconfigs owns |
| `undeploy [group]` | | Remove deployed artefacts (inverse of deploy) |
| `status [plugin]` | | Show deployment status / drift |
| `validate [--strict]` | | Lint manifests + scan deployed JSON for dangling references |
| `list` | | List plugins and whether they're configured |
| `help [command]` | | Detailed help |

## setup

```bash
dotconfigs setup          # run once after cloning
```
Creates PATH symlinks for `dotconfigs` and `dots`. Run `global-init` next.

## global-init

```bash
dotconfigs global-init    # re-run anytime after adding a plugin or editing manifests
```
Assembles `.dotconfigs/global.json` from every manifest's `.global` section, with pre-populated include lists. Edit that file to control what deploys.

## global-deploy `[group]` `[--dry-run]` `[--force]`

```bash
dotconfigs global-deploy              # all groups
dotconfigs global-deploy claude       # one plugin only
dotconfigs global-deploy --dry-run    # preview, no changes
dotconfigs global-deploy --force      # skip conflict prompts
```
Deploys from `global.json` to the filesystem and ensures `dotconfigs`/`dots` are on PATH. Each module is applied by its [deploy method](deploy-methods.md). **Conflict resolution:** if a target exists and isn't dotconfigs-owned, you're prompted to overwrite / skip / backup / diff (ownership is tracked per file, so it coexists with other tools in shared dirs like `~/.claude/`). Alias: `deploy`.

## project-init `[path]`

```bash
dotconfigs project-init .             # current repo
dotconfigs project-init ~/myrepo
```
Assembles `.dotconfigs/project.json` from manifests' `.project` sections and seeds `.git/info/exclude`. Defaults to the current directory; requires a git repo. The generated file has empty exclude lists - edit them to skip specific hooks/skills per repo.

## project-deploy `[path]` `[--dry-run]` `[--force]`

```bash
dotconfigs project-deploy .                  # deploy into current repo
dotconfigs project-deploy ~/myrepo --force
dotconfigs project-deploy . --dry-run
```
Deploys per-project config from `project.json` (hooks, skills, …), respecting include/exclude. Requires `project-init` first. Alias: `project`.

## cleanup `[--apply]` `[--project <path>]`

```bash
dotconfigs cleanup                      # preview stale/broken global symlinks (dry-run)
dotconfigs cleanup --apply              # actually remove them
dotconfigs cleanup --project . --apply  # clean a project's deployed symlinks
```
Removes **only stale and broken symlinks** that dotconfigs owns - links no longer in the deploy set (e.g. you dropped a file from an `include` list) or dangling ones. It does **not** remove copied files or merged-JSON entries, and never touches foreign files. Default is dry-run; pass `--apply` to remove. The target is chosen with `--project <path>` - a bare path argument is ignored. A clean, in-sync deployment correctly reports `Removed: 0` (a normal `deploy` already prunes stale symlinks as it runs).

## undeploy `[group]` `[--apply]` `[--project <path>]`

```bash
dotconfigs undeploy                 # preview removing all deployed artefacts (dry-run)
dotconfigs undeploy claude --apply  # remove the claude group's artefacts
```
Inverse of deploy. Removes symlink modules (foreign files preserved) and copy modules **only if byte-identical to source** (so your edits survive). Merge and append modules are skipped - they can't be reversed without losing local content. Default is dry-run.

## Removing deployed config

What it takes depends on the module's deploy method:

- **symlink** (hooks, skills, output-styles, `CLAUDE.md`): drop the file from that module's `include` list in `.dotconfigs/global.json` (or add it to `exclude` in `project.json`), then `cleanup --apply` - a re-`deploy` prunes it too.
- **copy** (`claude-hooks.conf`): `undeploy <group> --apply`, or just delete the file. `cleanup` does not touch copies.
- **merge** (`settings.json`): neither command edits a merged file - remove the key by hand.

To stop deploying something on *this machine*, edit `.dotconfigs/global.json` (your selection). To remove a capability *everywhere*, edit the plugin manifest (the catalogue) and re-run `global-init`.

## status `[plugin]`

```bash
dotconfigs status
dotconfigs status claude
```
Shows per-file state: **✓ deployed** (symlink correct), **△ drifted** (broken/foreign/wrong target), **✗ not deployed**. Merge-managed files like `settings.json` are reported by deploy, not here.

## validate `[--strict]`

```bash
dotconfigs validate            # lint manifests + scan deployed config
dotconfigs validate --strict   # treat warnings as failures too
```
Lints every plugin manifest (valid JSON, known `method`, whitelisted keys, source exists) and scans deployed merge-managed JSON (e.g. `~/.claude/settings.json`) for dangling command references - a `statusLine.command` or hook `command` pointing at a script that isn't actually deployed. Exits non-zero on any error; `--strict` also fails on warnings. Runs without deploying.

## list

```bash
dotconfigs list
```
Lists available plugins and whether each is configured.

## help `[command]`

```bash
dotconfigs help
dotconfigs help global-deploy
```

## Related

- [Getting started](getting-started.md) - these commands in a guided sequence.
- [Manifest format](manifest.md) / [Deploy methods](deploy-methods.md) - what deploy acts on and how.
- [Plugins](plugins.md) - what each deploy actually places.
