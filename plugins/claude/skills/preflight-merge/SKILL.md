---
name: preflight-merge
description: Pre-merge gate Claude runs before completing any squash merge to main - simulates the merge and flags silent auto-merge regressions that would reintroduce code the base already fixed
allowed-tools: Bash
argument-hint: [PR number]
---

# Preflight Merge

The safety gate Claude runs **before completing any squash merge to main** -
notably as a step inside `/squash-merge`. It simulates the merge and flags
**silent auto-merge regressions**: branch content that would resurrect code the
base has since fixed, which neither a plain `gh pr merge` nor a conflict prompt
ever surfaces.

This is part of Claude's own merge workflow, not a manual pre-click check.
Claude should invoke it on the PR it is about to merge and refuse to merge on a
DO-NOT-MERGE verdict.

## When to invoke

- **Automatically inside `/squash-merge`**, after the PR exists and before
  `gh pr merge --squash` - the standard gate on every squash merge to main.
- Before completing any merge of a branch that has diverged from its base,
  especially a long-running or stacked PR with overlap on files the base
  changed since the branch diverged.
- Whenever the branch carries commits whose content has *already landed on
  main* via a squash merge of an intermediate PR (the classic silent-regression
  trap).

## Why it matters

A squash/auto-merge silently takes one side on lines that 3-way merge math
deems "unchanged by base". If the base's diff against the merge-base happens to
be empty on certain lines (e.g. an intermediate PR squash compressed a change
and its revert into one net-zero commit), git concludes "base didn't change
these lines" and takes the branch's competing version - silently resurrecting
content the base has visibly fixed. No conflict marker is produced, so nothing
flags it: not `gh pr merge`, not a local pre-commit hook (it can't fire on a
server-side merge), and not GitHub's "Resolve conflicts" UI (which lists only
files with textual conflicts). The only way to catch it is to simulate the
merge first - which is what this gate does.

## Process

Takes one argument: a PR number (e.g. `/preflight-merge 219`).

```bash
PR="$1"
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')

BASE=$(gh pr view "$PR" --json baseRefName --jq '.baseRefName')
HEAD_OID=$(gh pr view "$PR" --json headRefOid --jq '.headRefOid')

# Throwaway clone to avoid touching the user's working tree
TMP=$(mktemp -d)
git clone -q "https://github.com/$REPO.git" "$TMP/repo"
cd "$TMP/repo"

git checkout -B preflight "$HEAD_OID"
git fetch origin "$BASE":"$BASE" 2>&1 | tail -1

LOG=$(mktemp)
git merge "$BASE" --no-commit --no-ff > "$LOG" 2>&1 || true
cat "$LOG"

AUTO=$(grep '^Auto-merging' "$LOG" | sed 's/^Auto-merging //')
CONFLICT=$(grep '^CONFLICT' "$LOG" | sed -E 's/.*Merge conflict in //')

echo
echo "== Files git silently auto-merged =="
echo "$AUTO" | sed 's/^/  /' | sed 's/^  $//'
echo
echo "== Files with conflict markers (a normal merge would surface these) =="
echo "$CONFLICT" | sed 's/^/  /' | sed 's/^  $//'

MERGE_BASE=$(git merge-base HEAD "$BASE")
REGRESSED=()
for f in $AUTO; do
    [ -z "$f" ] && continue
    # base did something to this file since merge-base?
    if git diff --quiet "$MERGE_BASE".."$BASE" -- "$f" 2>/dev/null; then
        continue
    fi
    # merged result vs base: any net diff means branch's overlay won on lines
    # base also touched (or branch added lines base didn't)
    if ! git diff --quiet "$BASE" -- "$f" 2>/dev/null; then
        REGRESSED+=("$f")
        echo
        echo "⚠ SILENT REGRESSION RISK: $f"
        echo "  base changed this file since merge-base"
        echo "  merge result differs from base"
        echo "  inspect: cd $TMP/repo && git diff $BASE -- '$f'"
    fi
done

echo
if [ ${#REGRESSED[@]} -eq 0 ] && [ -z "$CONFLICT" ]; then
    echo "✓ SAFE: no conflicts, no silent regressions. OK to complete the merge."
elif [ ${#REGRESSED[@]} -eq 0 ]; then
    echo "✓ CONFLICTS ONLY: a normal merge surfaces them. No silent regressions detected."
    echo "  Resolve them (locally with /check-resolution, then re-run this gate)."
else
    echo "✗ DO NOT MERGE: ${#REGRESSED[@]} silent regression(s) detected."
    echo "  A plain merge would hide these. Resolve at the source instead - usually"
    echo "  by dropping a duplicate commit:"
    echo "    git fetch origin"
    echo "    git checkout <branch>"
    echo "    git rebase --onto origin/$BASE <duplicate-commit>"
    echo "    git push --force-with-lease"
fi

echo
echo "Working dir: $TMP/repo (throwaway, not the user's repo)"
```

## Output

Three lists:
1. Files git silently auto-merged (no marker - the dangerous set).
2. Files with conflict markers (a normal merge would surface these).
3. Files in (1) whose merge result diverged from the base - the silent
   regressions.

Plus a verdict line: SAFE / CONFLICTS ONLY / DO NOT MERGE. Claude should not
complete the squash merge on a DO-NOT-MERGE verdict.

## When silent regressions appear

The fix is almost always upstream: a commit on the branch carries content
the base now owns through a different commit ID (typically because an
intermediate PR squash-merged). Drop the duplicate via interactive rebase
(or `/rebase-stacked-prs`) and force-push the clean branch, rather than
completing the merge.

## Limitations

- Requires `gh` CLI authenticated to the repo.
- Throwaway clone makes this slow on large repos (a few seconds).
- Detects net divergence from base, not the *cause*. Some divergences are
  legitimate additions the branch makes that base hasn't touched - those
  are not regressions. The script flags them anyway; human eyeballs the
  diff if in doubt.
- Doesn't analyse the merge commit itself, just the working-tree state
  post `git merge --no-commit`.

## Related

- `/squash-merge` - invokes this gate before `gh pr merge --squash`. This is
  the primary caller; every squash merge to main runs through here.
- `/check-resolution` - same diagnostic, but for files you are resolving
  locally mid-merge/rebase (after `git add`, before `--continue` / commit).
  Use that while resolving by hand; this gate runs at merge time.
- `/rebase-stacked-prs` - the fix when this flags a silent regression on a
  stacked PR: replay only the new commits onto main instead of merging.
- Memory: `feedback_silent_merge_regression.md` records the principle and
  the silent-merge trap.
- A pre-commit hook gated on `.git/MERGE_HEAD` / `.git/rebase-merge/` runs an
  abbreviated version during local merge/rebase commits, but cannot fire on a
  server-side `gh pr merge` - that gap is why this gate exists.
