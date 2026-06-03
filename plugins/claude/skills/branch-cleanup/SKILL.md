---
name: branch-cleanup
description: Delete local branches already merged into main and prune stale remote-tracking refs. Use after squash-merging a PR, when local `git branch` is cluttered with leftovers, or when the user says "clean up branches".
allowed-tools: Bash
argument-hint: [--dry-run]
---

# Branch Cleanup

Remove local branches whose work has already landed on `main`, and prune
remote-tracking refs whose upstream branches no longer exist. Safe by default:
shows the candidate list and asks before deleting unless `--dry-run` is passed.

## When to invoke

- Right after a `/squash-merge` completes, to sweep the just-merged branch and
  any siblings that landed during the same cycle.
- Periodically when `git branch` lists branches the user no longer recognises.
- When the user explicitly asks to prune / clean up / tidy local branches.

## Process

### 1. Fetch and prune remote-tracking refs
```bash
git fetch --prune origin
git remote prune origin
```
This drops `origin/<gone>` refs whose upstream branches were deleted (e.g. by
GitHub's auto-delete-on-merge).

### 2. Identify local branches merged into main
```bash
git checkout main
git pull --ff-only origin main

# Branches whose tip is reachable from main - i.e. fully merged.
# Exclude main itself and HEAD.
git branch --merged main | grep -vE '^\*| main$| HEAD$' | sed 's/^[[:space:]]*//'
```

In a squash-merge workflow `--merged` will MISS squash-merged branches (the
squash commit on main has a different SHA than the branch tip). Catch those
too via `gh`:
```bash
# Local branches whose corresponding PR has been merged on GitHub.
for b in $(git branch --format='%(refname:short)' | grep -v '^main$'); do
    state=$(gh pr list --head "$b" --state merged --json number --jq 'length' 2>/dev/null)
    [ "$state" -gt 0 ] && echo "$b"
done
```

Union the two lists. This is the candidate set.

### 3. Show the candidate set
```bash
echo "Candidates for deletion:"
printf '  %s\n' "${CANDIDATES[@]}"
```

If `$ARGUMENTS` contains `--dry-run`, stop here. Otherwise prompt:
"Delete these N branches? [y/N]" and proceed only on `y`.

### 4. Delete
```bash
for b in "${CANDIDATES[@]}"; do
    # Use -d for --merged matches (git refuses if not merged).
    # Use -D for squash-merged matches (git can't see the squash equivalence).
    git branch -d "$b" 2>/dev/null || git branch -D "$b"
done
```

### 5. Report
Print the final list of branches deleted, and the count of remote-tracking
refs pruned in step 1 (extract from `git remote prune origin` output).

## Notes

- Never delete the currently-checked-out branch. If a candidate is HEAD,
  `git checkout main` first.
- Never touch `main` or any protected branch.
- Force-delete (`-D`) is only used for branches whose PR is `merged` on
  GitHub - i.e. work demonstrably integrated, just not visible to local git
  through tip-reachability.
- If `gh` is unauthenticated, skip the squash-merge detection and fall back
  to `--merged` only. Warn the user.
