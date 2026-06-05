## Project: dotconfigs

Generic config deployer with a plugin architecture. Manages Claude Code, Git, and shell
configs via JSON catalogues and (mostly) symlinks.

## Architecture

- Engine: `src/dotconfigs` (entry point) + `src/lib/*.sh` (sourced libs, no shebangs)
- Plugins (the data registry): `plugins/{claude,git,shell}/manifest.json` + their sources
- Scripts: `scripts/` (`generate-roster.sh`, `build-claude-plugin.sh`)

### Two-tier model

- **manifest.json** (per plugin, in repo) -- the catalogue. Nested `category -> item`; each
  item carries `source`, `method`, `target` (string or array), optional `wiring` (Claude
  event hooks only), `default`, and an optional `description`. The upstream SSOT.
- **deploy.json** (per instance, outside the repo) -- the toggle board. Nested
  `plugin -> category -> item -> bool`, mirroring the catalogue, seeded from each item's
  `default`. The machine selection lives at `~/.dotconfigs/deploy.json`; a project's at
  `<repo>/.dotconfigs/deploy.json`. Flip an item true/false and re-run deploy. Scope is
  implied by the target path (`~`/absolute => machine, relative => project).

Deploy applies enabled items and tears down disabled ones in the same pass. The Claude
`settings.json` hooks block is synthesised at deploy time from the selected, wired hooks
(no hand-maintained wiring, no `.conf` layer). `generate-roster.sh` reads the manifests.

## Constraints

- **Bash 3.2 compat** (macOS) -- no `local -n`, `declare -n`, associative arrays, `${var,,}`
- **jq required** for JSON parsing
- No cross-plugin imports -- plugins self-contained
- No shebangs in `src/lib/` files (sourced only)

## Commands

(no path => machine scope; a path => that repo)

- `dotconfigs setup` -- one-time PATH setup
- `dotconfigs init [path]` -- seed a selection (deploy.json) from the catalogue defaults
- `dotconfigs deploy [path]` -- deploy the selection (enabled on, disabled torn down)
- `dotconfigs undeploy [path]` -- remove deployed artefacts
- `dotconfigs cleanup [path]` -- remove stale/broken symlinks
- `dotconfigs status [plugin]` -- check deployment status
- `dotconfigs validate [--strict]` -- lint catalogues + scan deployed JSON for dangling references
- `dotconfigs list` -- list available plugins

## Testing

```bash
pytest tests/ -v
```

Tests use pytest with bash subprocess calls and temp directory fixtures.
