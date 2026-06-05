# Plugin Architecture

Plugins live in `plugins/<name>/`. A plugin is any directory containing a `manifest.json` -- everything else is optional.

## Required

- **`manifest.json`** -- the catalogue (SSOT) of everything the plugin can deploy. A nested `category → item` map; each item has `source`, `method` (`symlink` | `merge` | `append` | `managed`), `target` (a string or an array of targets), an optional `wiring` (Claude event hooks), a `default` on/off value, and an optional `description`.

`init` seeds a per-instance `deploy.json` toggle board from each item's `default`; `deploy` resolves each enabled item from the manifest and links/merges it to its target; `status` checks each item's on-disk state against its source. See [docs/manifest.md](../docs/manifest.md) for the schema.

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
