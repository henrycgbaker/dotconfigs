---
description: Safely rebase a stacked PR onto main, dropping already-merged stacked-below work without reintroducing legacy code
allowed-tools: Bash, Read, Edit, Write
argument-hint: [PR number]
---

# Rebase a Stacked PR onto main

Rebase a PR that was stacked on one or more lower PRs, where those lower PRs have
since merged to main - often **modified during review**. A naive `git rebase --onto`
replays every stacked-below commit and forces you to resolve conflicts against code
that main has deliberately changed, risking silent reintroduction of the old (legacy)
versions.

This skill instead extracts **only the commits genuinely new to this PR** and replays
them on a fresh branch off `origin/main`, then **proves** by audit that the result
contains exactly the new work and no legacy. The original PR branch is never touched
until you explicitly repoint it.

PR number: `$ARGUMENTS` (ask if not supplied).

## Core principle

> Build a new branch from `origin/main`, cherry-pick only the new commits, and audit
> that `git diff origin/main..new-branch` carries **exactly the new feature's added
> lines** - nothing more. In a conflict, preserve what the new commit *actually changes*
> (its delta, reapplied onto main) and discard only the divergence that comes from
> superseded stacked-below work - never reflexively keep one side.

## Process

### 1. Map the topology
```bash
git fetch origin
gh pr view <PR> --json number,title,headRefName,baseRefName,body,mergeable,commits
git merge-base origin/<headRef> origin/main          # how stale the base is
git log --oneline origin/main..origin/<headRef>      # ALL commits not on main
```
Most of those commits belong to stacked-below PRs that already landed on main. Read the
PR body ("Stacked on #NNN") and the commit messages to separate them from the genuinely
new ones. The new commits are usually the **last few**, on top of the stacked-below run.

### 2. Isolate the new commits and their net diff
Let `NEW_FIRST..NEW_LAST` be the contiguous run of genuinely-new commits.
```bash
git diff --stat NEW_FIRST^..NEW_LAST     # which files the feature really touches
git diff NEW_FIRST^..NEW_LAST            # the isolated feature diff - this is the contract
```
Confirm the feature is not already partially on main:
```bash
git grep -n "<a-new-symbol>" origin/main -- 'src/**' 'tests/**' || echo "not on main yet"
```

### 3. Verify the new work's dependencies exist on current main
For each thing the new code calls into (API signatures, helpers, test anchors), confirm
it is present on `origin/main` in a compatible form:
```bash
git show origin/main:path/to/file.py        # inspect the real current state
git grep -n "def <dependency>" origin/main
```
If a dependency the feature needs is missing or changed shape on main, **stop and ask** -
the feature may have depended on stacked-below work that did not land as-is.

### 4. Build the rebased branch in an isolated worktree (non-destructive)
```bash
git worktree add -b <headRef>-rebased ../<slug>-rebase origin/main
cd ../<slug>-rebase
git cherry-pick NEW_FIRST [.. NEW_LAST]      # one or a short list
```
Expect conflicts only where main diverged from the PR's stale base.

### 5. Resolve conflicts: preserve the commit's intent, drop only stacked-below noise
A conflict means the commit's change landed on lines main also changed. Don't reflexively
pick a side - classify each conflicting hunk against the commit's **own** patch first:
```bash
git show <newcommit> -- <path>   # exactly what THIS commit changes, vs its parent
```
- **Incidental divergence** - the conflicting lines are *not* in the commit's patch; they
  differ only because stacked-below work (now on main in a different form) touched them.
  -> **take main (HEAD)**; the PR side is superseded legacy. This is the common case in a
  stale stack, but never assume it.
- **Feature intent** - the conflicting lines *are* in the commit's patch; changing them is
  the point of the commit. -> **apply the commit's change, expressed against main's current
  version** (keep main's untouched neighbours, layer the commit's delta on top). Keeping
  main here would silently drop the feature.
- **True clash** - both the commit *and* main genuinely changed the same logic for
  different reasons. -> real merge judgement; reconcile the two intents, and if the right
  answer isn't clear, **stop and ask**.

A single hunk can mix cases (e.g. an import line where main dropped a stacked-below symbol
*and* the commit adds a new one), so resolve line by line, not side by side. Only keep a
symbol/import the new code **actually uses**. Step 6's added-line audit is the backstop: a
feature line you wrongly resolved to main shows up as "missing on the left".

Resolve with Edit, then:
```bash
git add -A && git cherry-pick --continue
```

### 6. Audit - the proof step (do not skip)
```bash
# a) Only the expected files changed, matching the isolated feature stat
git diff --stat origin/main..HEAD

# b) Added-line equivalence: the set of '+' lines must equal the isolated feature diff.
#    Empty both ways == provably the same new content (context-line differences are fine
#    and expected, since main's base lines differ from the PR's stale base).
diff <(git diff origin/main..HEAD | grep '^+' | sort) \
     <(git diff NEW_FIRST^..NEW_LAST | grep '^+' | sort)

# c) Legacy-absence spot checks: confirm main's version of each diverged item survived,
#    and the PR's superseded version did NOT leak in. Grep for legacy-only strings:
git grep -n "<legacy-only-string>" -- src tests && echo "LEAK" || echo "clean"

# d) No leftover conflict markers
grep -rn '^<<<<<<<\|^=======\|^>>>>>>>' src tests && echo "MARKERS" || echo "clean"
```
If (b) shows added lines missing on the left, you dropped feature content. If it shows
extras on the left, you carried legacy in. Either way, fix before proceeding.

### 7. Build + test + lint
Run the project's tests for the touched area and the linter. In a `src/`-layout repo
whose venv has an editable install pointing at the **main** checkout, shadow it so tests
exercise the worktree, e.g.:
```bash
PYTHONPATH=src <venv>/bin/python -m pytest <touched test modules> -q
<venv>/bin/ruff check <changed files> && <venv>/bin/ruff format --check <changed files>
```
A live smoke test of the entry point is worth it for CLI/API changes (invoke the real
console-script callable, not `python -m module`, unless the module has a `__main__`).

### 8. Repoint the PR (only after the audit passes)
GitHub cannot change a PR's head branch, so "repoint" means one of two things. **Default
to option A** (update in place, keep the PR number) unless the user asks to replace it.

- **A - Update PR in place (DEFAULT, keeps the PR number):** force-push the rebased
  commits onto the original head branch.
  ```bash
  git push --force-with-lease origin <headRef>-rebased:<headRef>
  ```
- **B - Replace:** push the new branch, open a fresh PR, close the old one.
  ```bash
  git push -u origin <headRef>-rebased
  gh pr create --base main --head <headRef>-rebased --title "..." --body "..."
  gh pr close <PR> --comment "Superseded by #<new> (clean rebase onto main)."
  ```

**Execution constraint:** the force-push rewrites history on a shared remote branch - a
destructive, outward-facing action. Present the exact command for the user to run rather
than running it unprompted; everything up to step 7 (branch build, audit, tests) is safe
to do automatically, only the final push is handed over. (A user who wants it automated
can allow-list `git push --force-with-lease:*` in their settings.)

### 9. Clean up the worktree when done
```bash
git worktree remove ../<slug>-rebase   # add --force if it still has the branch checked out
```

## Notes
- The new branch is disposable scaffolding for validation; the original PR branch stays
  as an untouched reference the whole time. That is what makes this safe.
- Cherry-pick (not hand-applied edits) preserves the original authorship, dates, and
  commit messages - keep the feature's commits intact; the eventual squash-merge collapses
  them.
- If the "new" run is not contiguous (new commits interleaved with stacked-below ones),
  cherry-pick the specific new SHAs individually rather than a range.
