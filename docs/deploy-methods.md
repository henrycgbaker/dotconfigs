# Deploy methods

[← docs](../README.md#documentation) · Explanation

Every module in a manifest declares a `method` that controls how its source reaches the target. The method is chosen by **who owns the target file** - dotconfigs alone, or dotconfigs *plus* the user or an application that writes into it.

## The five methods

| Method | What it does | Target owned by | Used for |
|--------|--------------|-----------------|----------|
| `symlink` | Links target → source. Edits to the source are live immediately; nothing to re-deploy. | dotconfigs only | Most files: hooks, skills, `gitconfig`, `CLAUDE.md` |
| `append` | Appends source content once if not already present (idempotent). Never rewrites the file. | dotconfigs **+ a tracked/team file** | Seed for committed files: `.gitignore`, the `~/.gitconfig` `[include]` stub |
| `managed` | Writes a sentinel-delimited block; **updates it in place** on re-deploy and **removes it** on undeploy. Leaves the user's other lines alone. | dotconfigs **+ user (untracked)** | Untracked machine-local files dotconfigs keeps current: `.git/info/exclude` |
| `copy` | Overwrites the target with a standalone copy (atomic). Independent of source afterwards. | dotconfigs only | Structured files that can't be appended and shouldn't be symlinked |
| `merge` | Deep-merges the managed base into the live target, preserving local entries; writes a regular file (never a symlink). | dotconfigs **+ an application** | `~/.claude/settings.json` |

## Why not just symlink everything?

Symlinks are the default and the best fit for files dotconfigs solely owns: zero drift, edit-in-place, no re-deploy step. But a symlink is wrong the moment something *other than dotconfigs writes to the file*:

- If the **user** maintains part of the file (e.g. you add lines to `.gitignore`), a symlink would replace your file with a pointer to the repo's version - your edits vanish, and committing the repo would force your lines on every machine. `append`/`managed` instead add the managed lines and leave yours alone.
- If an **application** writes to the file, a symlink means those writes land *inside the repo*. That's the `settings.json` story below.

## `append` vs `managed` (both are line-oriented)

Both place managed lines into a file the user also touches. The deciding question is **may dotconfigs rewrite its region on every deploy without harming anyone?**

- **`append` is seed-once.** It adds the lines if absent and then never touches them again. The cost is that it can't *update* (a changed source just appends the new lines, leaving the old) and can't be reversed by `undeploy` - which is exactly right when you must not rewrite the file. Use it when **either**:
  - the file is **tracked / team-shared** (e.g. `.gitignore`) - it's committed and owned by the project, so a rewrite on every deploy would churn a shared file's history and impose dotconfigs' markers on collaborators; **or**
  - the managed content is a **stable stub** that never needs updating (e.g. the `~/.gitconfig` `[include]` line, whose real config lives in the symlinked `gitconfig-base`).
- **`managed` owns a region.** It wraps its content in sentinel markers (`# >>> dotconfigs:<source> >>>` … `# <<< dotconfigs:<source> <<<`) so it can **replace that block in place** when the source changes and **delete it** on `undeploy`, all while leaving the user's other lines untouched. Use it when the file is **untracked / machine-local** (e.g. `.git/info/exclude`) **and** its content **evolves** - rewriting has no blast radius (nobody else sees it, it's never in git history) and you genuinely want it kept current. The block is written atomically (temp + rename) and is idempotent. Markers are `#` comments, inert in git config / exclude / ignore syntax.

Rule of thumb: **may a rewrite leak into shared history or others' machines? → `append` (seed). Is it private and evolving? → `managed`.**

Two behaviour notes:

- **Reversibility.** `undeploy` strips a `managed` block (and any stray markers), so the dotconfigs-managed lines are removed while the user's other lines stay. `append` and `merge` are *not* reversed (their lines can't be told apart from the user's). That means undeploying a project removes dotconfigs' `.git/info/exclude` patterns - intended, but re-run the deploy to restore them.
- **Migration from `append`.** A target that was previously `append`-deployed has the old lines *unmarked*. The first `managed` deploy can't recognise them, so it adds a fresh marked block alongside - leaving the legacy copy as plain user lines. For a machine-local file like `.git/info/exclude` the duplicate ignore patterns are harmless; delete the file and redeploy if you want a clean single block.

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
2. Does an application write structured (JSON) state into it? → **`merge`**.
3. Is it a line-oriented file you also hand-edit?
   - Tracked / committed (shared with collaborators)? → **`append`** (seed once, never rewrite).
   - Untracked / machine-local (dotconfigs keeps it current)? → **`managed`** (updatable + reversible).
4. None of the above, but it can't be symlinked? → **`copy`**.

## Related

- [Manifest format](manifest.md) - where `method` is declared per module.
- [Architecture](architecture.md#symlink-ownership) - the per-file ownership model these methods rest on.
- [Commands](commands.md) - `global-deploy` / `project-deploy` apply the methods.
