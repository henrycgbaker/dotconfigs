# Deploy methods

[← docs](../README.md#documentation) · Explanation

Every module in a manifest declares a `method` that controls how its source reaches the target. The method is chosen by **who owns the target file** - dotconfigs alone, or dotconfigs *plus* the user or an application that writes into it.

## The four methods

| Method | What it does | Target owned by | Used for |
|--------|--------------|-----------------|----------|
| `symlink` | Links target → source. Edits to the source are live immediately; nothing to re-deploy. | dotconfigs only | Most files: hooks, skills, `gitconfig`, `CLAUDE.md` |
| `append` | Appends source content to the target if not already present (idempotent). Leaves existing content intact. | dotconfigs **+ user/project** | Files you also hand-edit: `.gitignore`, `.git/info/exclude` |
| `copy` | Overwrites the target with a standalone copy. Independent of source afterwards. | dotconfigs only | Structured files that can't be appended and shouldn't be symlinked |
| `merge` | Deep-merges the managed base into the live target, preserving local entries; writes a regular file (never a symlink). | dotconfigs **+ an application** | `~/.claude/settings.json` |

## Why not just symlink everything?

Symlinks are the default and the best fit for files dotconfigs solely owns: zero drift, edit-in-place, no re-deploy step. But a symlink is wrong the moment something *other than dotconfigs writes to the file*:

- If the **user** maintains part of the file (e.g. you add lines to `.gitignore`), a symlink would replace your file with a pointer to the repo's version - your edits vanish, and committing the repo would force your lines on every machine. `append` instead adds the managed lines and leaves yours alone.
- If an **application** writes to the file, a symlink means those writes land *inside the repo*. That's the `settings.json` story below.

## The `settings.json` case (why `merge` exists)

Claude Code's `~/.claude/settings.json` is **co-owned**: the user/app appends permission grants over time (the `permissions.allow` array). Both naive methods fail it:

- **symlink** → Claude writes your machine's grants *through the symlink into the dotconfigs repo*, polluting it and leaking machine-local state across machines.
- **copy** → every `dotconfigs deploy` overwrites the file, **wiping all accumulated grants**.

`merge` resolves it. On deploy it deep-merges the repo's managed base into the live file:

- **base wins** on managed keys (`hooks`, `env`, `sandbox`, `statusLine`) - so config you version stays authoritative;
- `permissions.allow` / `deny` / `ask` arrays are **unioned** - so locally-approved grants always survive;
- keys that exist only locally are preserved;
- the result is a **regular file**, never a symlink, so the app can keep writing to it.

It's idempotent: re-deploying merges the same base again with no change. First deploy (or a stale symlink left by an older version) just drops the base in as a fresh regular file.

This mirrors how Claude Code itself layers settings - user-global is the lowest-priority layer and permission arrays merge across layers, with new grants now written to project-local `.claude/settings.local.json`. So the version-controlled base and machine-local grants never need to fight over one file.

## Picking a method for a new module

1. Does dotconfigs solely own the target? → **`symlink`** (default).
2. Do you also hand-edit it (line-oriented)? → **`append`**.
3. Does an application write structured (JSON) state into it? → **`merge`**.
4. None of the above, but it can't be symlinked? → **`copy`**.

## Related

- [Manifest format](manifest.md) - where `method` is declared per module.
- [Architecture](architecture.md#symlink-ownership) - the per-file ownership model these methods rest on.
- [Commands](commands.md) - `global-deploy` / `project-deploy` apply the methods.
