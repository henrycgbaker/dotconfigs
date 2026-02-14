# Plugin Architecture

Plugins live in `plugins/<name>/`. The manifest is the only required file -- everything else depends on whether the plugin needs interactive config or just deploys static files.

## Required

- **`manifest.json`** -- SSOT for all deployable modules. Declares `"global"` and/or `"project"` sections, each containing modules with `source`, `target`, `method` (`symlink`|`copy`), and optional `include`/`exclude` lists.

## Full Plugins (interactive config + deployment logic)

Plugins that need wizards, status checks, or custom deployment logic also provide:

- **`setup.sh`** -- Interactive configuration wizard. Must export `plugin_<name>_setup()`. Called via `dotconfigs global-configs <name>`. Writes config to `.env`.
- **`deploy.sh`** -- Deployment logic and status. Must export `plugin_<name>_status()`. Called via `dotconfigs status <name>`.
- **`project.sh`** *(optional)* -- Project-level logic. Exports `plugin_<name>_project()`.
- **`DESCRIPTION`** -- One-line summary shown in `dotconfigs list`.

Current full plugins: `claude`, `git`.

## Data-Only Plugins (manifest + files)

Plugins that just symlink/copy files need only a manifest and the source files it references. No `.sh` files required.

Current data-only plugins: `shell`, `vscode`.

## Conventions

- **Function naming**: `plugin_<name>_<action>()` for public, `_<name>_<helper>()` for internal.
- **Self-locating**: `.sh` files resolve their own path via `PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`.
- **No cross-plugin imports** -- plugins are self-contained.
- **No shebangs** -- all `.sh` files are sourced, not executed directly.
- **Hook METADATA** -- hooks use `# === METADATA ===` blocks for `generate-roster.sh` to discover descriptions and config variables.
- **Bash 3.2 compat** -- no namerefs, associative arrays, or `${var,,}`.
