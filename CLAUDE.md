## Project: dotconfigs

Generic config deployer with plugin architecture. Manages Claude Code, Git, VS Code, and shell configs via JSON manifests and symlinks.

## Architecture

- Entry point: `dotconfigs` (no extension)
- Plugins: `plugins/{claude,git,shell,vscode}/` with `manifest.json` each
- Shared libs: `lib/` (sourced, not executed -- no shebangs)

### SSOT Dataflow

Plugin manifests are the upstream SSOT. Everything derives downstream:

- **Manifests** (`plugins/*/manifest.json`) -- declare all available functionality
- **`.dotconfigs/global.json`** / **`.dotconfigs/project.json`** -- assembled from manifests, control what's deployed (include/exclude)
- **Hook METADATA** (`# CONFIG:` lines in hook files) -- SSOT for hook descriptions and config variables
- **`generate-roster.sh`** -- reads manifests + hook METADATA -> produces `docs/ROSTER.md`

Deploy flow: manifests -> `global-init` -> `.dotconfigs/global.json` -> `deploy`
Project flow: manifests -> `project-init` -> `.dotconfigs/project.json` -> `project`

## Constraints

- **Bash 3.2 compat** (macOS) -- no `local -n`, `declare -n`, associative arrays, `${var,,}`
- **jq required** for JSON parsing
- No cross-plugin imports -- plugins self-contained
- No shebangs in `lib/` files (sourced only)

## Commands

- `dotconfigs setup` -- one-time PATH setup
- `dotconfigs global-init` -- assemble global.json from manifests
- `dotconfigs deploy` -- deploy global config (~/.claude/, ~/.gitconfig, etc.)
- `dotconfigs project-init [path]` -- scaffold project.json for a repo
- `dotconfigs project [path]` -- deploy project config (.git/hooks/, .claude/, etc.)
- `dotconfigs status` -- check deployment status
- `dotconfigs list` -- list available plugins

## Testing

```bash
pytest tests/ -v
```

Tests use pytest with bash subprocess calls and temp directory fixtures.
