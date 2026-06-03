---
name: check-resolution
description: Audit a just-resolved merge or rebase locally to confirm the resolution didn't silently resurrect code the branch removed or revert a fix that landed on main. Use after `git add` of resolved files and before `git rebase --continue` / `git commit`.
allowed-tools: Bash
---

# Check Resolution

Verify a recent merge/rebase conflict resolution did not silently resurrect
old code from `origin/main` that the branch deliberately removed, or undo a
fix that landed on main while the branch was diverged.

## When to invoke

- **Mid-rebase**: after `git add` of resolved files, before `git rebase --continue`
- **Mid-merge**: after `git add` of resolved files, before `git commit`
- **Post-resolution**: after a merge/rebase completed, to retroactively verify

## Why it matters

Long-running branches diverge from main while main moves forward. Conflict
markers hide two unrelated things at once: the branch's intentional change
AND main's overlapping change. A line-by-line resolution can silently restore
content the branch deleted, or revert content main added.

The diff is invisible if you only look at "your intended" diff against the
merge-base. You also need the diff against current `origin/main`.

## Process

```bash
# 1. Identify the merge-base (common ancestor)
MERGE_BASE=$(git merge-base origin/main HEAD)
echo "Merge-base: $MERGE_BASE"

# 2. Files that BOTH the branch AND main have touched since the merge-base
#    (these are the candidate resurrection surfaces)
git diff --name-only "$MERGE_BASE"...HEAD > /tmp/branch-touched
git diff --name-only "$MERGE_BASE"...origin/main > /tmp/main-touched
comm -12 <(sort /tmp/branch-touched) <(sort /tmp/main-touched) > /tmp/overlap

echo "Overlap files (candidates for resurrection): $(wc -l < /tmp/overlap)"

# 3. For each overlap file, show three diffs side by side:
while read -r file; do
  [[ -z "$file" ]] && continue
  echo
  echo "============================================================"
  echo "FILE: $file"
  echo "============================================================"

  echo
  echo "--- 1. What this branch intended to change (vs merge-base) ---"
  git diff "$MERGE_BASE"..HEAD -- "$file"

  echo
  echo "--- 2. What main added since the merge-base ---"
  git diff "$MERGE_BASE"..origin/main -- "$file"

  echo
  echo "--- 3. Current branch state vs origin/main (the net merge effect) ---"
  git diff origin/main -- "$file"

  echo
  echo "RESURRECTION CHECK: does diff #3 contain hunks that REVERSE content"
  echo "added by main in diff #2? If yes, the resolution clobbered main's"
  echo "work. Fix by re-resolving with main's lines preserved."
done < /tmp/overlap
```

## Output

Print, for each overlap file:
- File path
- Three diffs (intended vs main vs net) for context
- A pointer at the resurrection question

End with a brief summary: total overlap files audited, suspicious files (if
any), recommended action (continue / re-resolve / abort).

## Warn, don't block

Some resurrections are intentional (revert PRs, deliberate deletions of code
main re-added). Always show the diff and let the user judge. Do not exit
non-zero. The point is to make the choice visible, not to gate it.

## Limitations

- Works against `origin/main` specifically. For PRs targeting a different
  base, adjust the references.
- Files only modified on one side (only branch, only main) are not candidates
  for resurrection; they are skipped from the overlap set.
- Binary files are reported but their diffs are noisy; spot-check manually.
- A "trivially safe" resolution (one side untouched the lines main edited)
  still appears in overlap if the FILE was touched both sides. False
  positive rate is acceptable in exchange for completeness.

## Related

- `/squash-merge` step 2.5 catches WHETHER conflicts exist before merging
  (via `git merge-tree`). This skill catches whether the RESOLUTION was
  correct after conflicts are resolved.
- `/rebase-stacked-prs` is the full workflow for rebasing a stacked PR onto
  main; its added-line audit is a specialised form of this skill's 3-way diff.
- `/preflight-merge` is the same resurrection check, but run as Claude's gate at
  squash-merge time rather than during a local hand-resolution.
- Memory: `feedback_conflict_resurrection.md` records the principle and
  the canonical command.
- Hook: a pre-commit hook gated on `.git/MERGE_HEAD` / `.git/rebase-merge/`
  runs an abbreviated version of this automatically during merge/rebase
  commits.
