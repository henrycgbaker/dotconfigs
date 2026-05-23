# Preflight Merge

Simulate a PR's merge into its base branch BEFORE clicking the GitHub UI's
merge button, surfacing silent auto-merge regressions that the UI hides.

## When to invoke

- Before approving "Resolve conflicts" + "Commit merge" on GitHub for any PR
  whose branch has diverged from its base.
- Before clicking "Merge pull request" on a long-running or stacked PR with
  overlap on files the base has changed since the branch diverged.
- Whenever the PR was opened against `main` but its branch carries commits
  whose content has *already landed on main* via a squash merge of an
  intermediate PR (the classic silent-regression trap).

## Why it matters

GitHub's web "Resolve conflicts" UI shows ONLY files with textual conflict
markers. Files git auto-merges silently never appear in the UI - even when
the auto-merge takes a stale branch version that resurrects content the base
has fixed. Local pre-commit hooks don't fire on GitHub-UI merges (the merge
runs server-side). The only way to catch silent regressions before clicking
merge is to simulate the merge locally first.

The trap relies on standard 3-way merge math: if the base's diff against the
merge-base happens to be empty on certain lines (e.g. because an intermediate
PR squash compressed a change and its revert into one net-zero commit), git
correctly concludes "base didn't change these lines" and takes the branch's
competing change - silently resurrecting content the base has visibly fixed.

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
echo "== Files with conflict markers (GH UI surfaces these) =="
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
    echo "✓ SAFE: no conflicts, no silent regressions. OK to merge in GH UI."
elif [ ${#REGRESSED[@]} -eq 0 ]; then
    echo "✓ CONFLICTS ONLY: GH UI will surface them. No silent regressions detected."
    echo "  Safe to resolve in the UI."
else
    echo "✗ DO NOT MERGE IN GH UI: ${#REGRESSED[@]} silent regression(s) detected."
    echo "  GH UI will hide these. Resolve at the source instead - usually"
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
1. Files git silently auto-merged (invisible in GH UI).
2. Files with conflict markers (GH UI surfaces these).
3. Files in (1) whose merge result diverged from the base - the silent
   regressions.

Plus a verdict line: SAFE / CONFLICTS ONLY / DO NOT MERGE.

## When silent regressions appear

The fix is almost always upstream: a commit on the branch carries content
the base now owns through a different commit ID (typically because an
intermediate PR squash-merged). Drop the duplicate via interactive rebase
and force-push the clean branch, rather than trying to resolve in GH UI.

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

- `/check-resolution` - same diagnostic, but for files mid-merge/rebase
  locally (after `git add`, before `git rebase --continue` / `git commit`).
  Use that when YOU are resolving conflicts locally; use `/preflight-merge`
  when GH UI is about to do the merge.
- Memory: `feedback_silent_merge_regression.md` records the principle and
  the GH UI trap.
- Pre-commit hook gated on `.git/MERGE_HEAD` / `.git/rebase-merge/` runs an
  abbreviated version during local merge/rebase commits (but cannot fire
  on GH UI merges - that's why this skill exists).
