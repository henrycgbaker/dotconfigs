# Manifest format

[← docs](../README.md#documentation) · Reference

Each plugin has a `manifest.json` - the single source of truth for what that plugin can deploy. A manifest is a **catalogue**: it lists every item the plugin offers, fully specifying how and where each one deploys, plus its default on/off state. What actually deploys on a given machine or repo is the **selection** in `deploy.json` (`~/.dotconfigs/deploy.json` for the machine, `<repo>/.dotconfigs/deploy.json` per project), seeded from the catalogue by `init`. See [Architecture](architecture.md) for the full dataflow.

## Structure

A manifest is nested `category → item`. Categories are organisational only (no include/exclude lists); each item is a self-contained entry keyed by a name unique within its category.

```json
{
  "hooks": {
    "block-rm-rf-root": {
      "description": "Block rm -rf / or rm -rf ~ (full filesystem wipe)",
      "source": "plugins/claude/hooks/block-rm-rf-root.sh",
      "method": "symlink",
      "target": "~/.claude/hooks/block-rm-rf-root.sh",
      "wiring": { "event": "PreToolUse", "matcher": "Bash", "if": "Bash(rm *)", "timeout": 10 },
      "default": true
    }
  },
  "skills": {
    "commit": {
      "source": "plugins/claude/skills/commit",
      "method": "symlink",
      "target": ["~/.claude/skills/commit", ".claude/skills/commit"],
      "default": true
    }
  }
}
```

## Item fields

| Field | Required | Meaning |
|-------|----------|---------|
| `source` | yes | Path within the repo (file or directory), repo-relative |
| `method` | yes | `symlink` · `merge` · `append` · `managed` - see [Deploy methods](deploy-methods.md) |
| `target` | yes | Where it deploys: a string **or** an array of strings (see Scope below) |
| `default` | yes | Boolean - whether the item ships on (the value `init` seeds into `deploy.json`) |
| `description` | optional | Roster description. Omitted for skills, whose SSOT is their `SKILL.md` frontmatter |
| `wiring` | optional | Claude **event** hooks only - how the hook is wired into `settings.json` (see below). Absent ⇒ not an event hook |

`validate` enforces exactly this key whitelist (`description`, `source`, `method`, `target`, `wiring`, `default`); any other key is an error.

## Scope is implied by the target path

There are no `global`/`project` keys. An item's scope is read off its target:

- a `~`-relative or absolute target (`~/.claude/...`, `~/.gitconfig`) ⇒ **machine** scope;
- a repo-relative target (`.claude/skills/commit`, `.git/hooks/pre-commit`) ⇒ **project** scope.

`target` may be a single string or an **array**, and an item may list both a machine *and* a project target. Two real cases:

- git hooks - `["~/.dotconfigs/git-template/hooks/pre-commit", ".git/hooks/pre-commit"]`: the machine target seeds new repos via `init.templateDir`, the project target installs into an existing repo;
- claude skills - `["~/.claude/skills/commit", ".claude/skills/commit"]`: globally for every project, or per-repo.

`init` lists each item in whichever scope's `deploy.json` matches its target(s); a dual-target item appears in **both** files, and each `deploy` applies only the scope-matching target.

## The `wiring` field (Claude event hooks)

A Claude hook **script** sitting in `~/.claude/hooks/` does nothing until a `hooks` block in `settings.json` points an event at it. `wiring` is that block's source: one object, or an **array** of objects, each `{ event, matcher?, if?, timeout? }`.

```json
"wiring": [
  { "event": "PreToolUse", "matcher": "Bash", "if": "Bash(gh pr*)", "timeout": 10 },
  { "event": "PreToolUse", "matcher": "mcp__github__.*", "timeout": 10 }
]
```

At deploy time the `wiring` of every **enabled** Claude hook is collected, grouped by event and matcher, and **synthesised** into the merged `~/.claude/settings.json` - there is no static, hand-maintained hooks block in `plugins/claude/settings.json`. A hook is wired *iff* it is selected, so deselecting one in `deploy.json` removes both its symlink and its `settings.json` entry (no dangling reference). Items without `wiring` are not event hooks - the shared helper `_hook-common`, the `settings` fragment, and all git hooks have none.

## Deploy methods

`method` picks how a source reaches its target, based on who owns the target file. Full rationale and decision guide: **[Deploy methods](deploy-methods.md)**.

- `symlink` - link target → source (default; live edits, dotconfigs-owned files or directories).
- `append` - seed-once: idempotently add managed lines to a tracked/team file, never rewriting it (`.gitignore`, `~/.gitconfig` `[include]` stub).
- `managed` - own a sentinel-delimited block in an untracked file; updatable in place and reversible on undeploy (`.git/info/exclude`).
- `merge` - deep-merge a managed base into a co-owned file, preserving local state (`~/.claude/settings.json`).

## Regenerating after changes

After editing a manifest, re-seed your selection and regenerate the reference:

```bash
dotconfigs init                 # re-seed ~/.dotconfigs/deploy.json (backs up the old one)
scripts/generate-roster.sh      # regenerate docs/ROSTER.md from the manifests
```

`generate-roster.sh` reads the hook list, descriptions, and Event/Matcher straight from each manifest's `wiring`; skill descriptions come from each `SKILL.md` frontmatter.

## Related

- [Deploy methods](deploy-methods.md) - the `method` field in depth.
- [Plugins](plugins.md) - the concrete items each manifest declares.
- [Architecture](architecture.md) - manifests → deploy.json → deploy.
