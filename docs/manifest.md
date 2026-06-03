# Manifest format

[← docs](../README.md#documentation) · Reference

Each plugin has a `manifest.json` - the single source of truth for what that plugin can deploy. Manifests declare *what exists*; `.dotconfigs/global.json` and `.dotconfigs/project.json` (assembled from manifests by `global-init`/`project-init`) control what's *actually* deployed via include/exclude lists. See [Architecture](architecture.md) for the full dataflow.

## Schema

```json
{
  "global": {
    "module-name": {
      "source": "plugins/name/file-or-dir",
      "target": "~/deploy/target",
      "method": "symlink",
      "include": ["file1", "file2"]
    }
  },
  "project": {
    "module-name": {
      "source": "plugins/name/file-or-dir",
      "target": ".relative/target",
      "method": "symlink",
      "include": ["file1", "file2"],
      "exclude": []
    }
  }
}
```

| Field | Meaning |
|-------|---------|
| `source` | Path within the repo (file or directory) |
| `target` | Where it deploys. Global targets are `~`-relative; project targets are repo-relative |
| `method` | `symlink` · `copy` · `append` · `merge` - see [Deploy methods](deploy-methods.md) |
| `include` | Whitelist of files to deploy from a directory source |
| `exclude` | Project-only, user-editable blacklist (empty by default) |

A module is listed under `global`, `project`, or both. The `project` section is the only place `exclude` applies - edit it in `.dotconfigs/project.json` to skip specific hooks/skills per repo.

## Deploy methods

`method` picks how a source reaches its target, based on who owns the target file. Full rationale and decision guide: **[Deploy methods](deploy-methods.md)**.

- `symlink` - link target → source (default; live edits, dotconfigs-owned files).
- `append` - idempotently add managed lines, preserving user content (`.gitignore`, `.git/info/exclude`).
- `copy` - standalone overwrite for files that can't be symlinked.
- `merge` - deep-merge a managed base into a co-owned file, preserving local state (`~/.claude/settings.json`).

## Hook configuration

Some git hooks (`prepare-commit-msg`, `post-merge`, `post-checkout`, `post-rewrite`) read a config file. First found wins:

1. `.githooks/config`
2. `.claude/git-hooks.conf`
3. `.git/hooks/hooks.conf`
4. `.claude/hooks.conf`

Example `.claude/git-hooks.conf`:
```bash
GIT_HOOK_BRANCH_PREFIX=true
GIT_HOOK_DEPENDENCY_CHECK=true
GIT_HOOK_MIGRATION_REMINDER=true
GIT_HOOK_BRANCH_INFO=true
```

`pre-commit`, `commit-msg`, `pre-push`, and `pre-rebase` are self-contained (no config). **Precedence:** config file > environment variable > hardcoded default. Per-hook config keys are listed in [ROSTER.md](ROSTER.md).

## Regenerating after changes

After editing a manifest, re-scaffold and regenerate the reference:

```bash
dotconfigs global-init          # re-assemble .dotconfigs/global.json
scripts/generate-roster.sh      # regenerate docs/ROSTER.md
```

## Related

- [Deploy methods](deploy-methods.md) - the `method` field in depth.
- [Plugins](plugins.md) - the concrete modules each manifest declares.
- [Architecture](architecture.md) - manifests → global.json/project.json → deploy.
