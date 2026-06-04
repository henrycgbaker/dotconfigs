# Plugin Architecture

Plugins live in `plugins/<name>/`. A plugin is any directory containing a `manifest.json` -- everything else is optional.

## Required

- **`manifest.json`** -- SSOT for all deployable modules. Declares `"global"` and/or `"project"` sections, each containing modules with `source`, `target`, `method` (`symlink` | `copy` | `merge` | `append` | `managed`), and optional `include`/`exclude` lists.

The CLI walks manifests directly: `global-init` assembles `.dotconfigs/global.json` from the `.global` sections, `deploy` walks that file, and `status` checks each module's on-disk state against its source.

## Optional

- **`DESCRIPTION`** -- One-line summary.

All current plugins (`claude`, `git`, `shell`) are manifest-driven (manifest + files), with no interactive setup step.

## Conventions

- **Function naming**: `plugin_<name>_<action>()` for public, `_<name>_<helper>()` for internal.
- **Self-locating**: `.sh` files resolve their own path via `PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`.
- **No cross-plugin imports** -- plugins are self-contained.
- **No shebangs** -- all `.sh` files are sourced, not executed directly.
- **Hook METADATA** -- hooks use `# === METADATA ===` blocks for `generate-roster.sh` to discover descriptions and config variables.
- **Bash 3.2 compat** -- no namerefs, associative arrays, or `${var,,}`.
