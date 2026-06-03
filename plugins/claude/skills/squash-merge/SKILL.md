---
name: squash-merge
description: Squash merge current branch to main via GitHub PR
allowed-tools: Bash, Read
argument-hint: [optional commit message]
---

# Squash Merge via PR

Complete a feature branch by squash merging to main through a GitHub PR with CI gate.

## Process

### 0. Simplify Review

Before merging, run `/simplify` on all changed files. Fix any issues found, commit fixes, then continue.

**Subagent split (revised 2026-04-29):** subagents cannot invoke `/simplify`. The clean split is: subagent gets PR to draft + CI-green and stops; orchestrator (main thread) runs `/simplify` against the draft and merges from there. No manual checklist proxy in the subagent; no round-trip handshake. Brief tells the subagent: "Open draft PR, wait for CI green, report back. Do NOT merge. Orchestrator handles simplify + merge."

### 0.5 Documentation Audit

Architecture-changing PRs must update relevant docs in the same branch - follow-up doc PRs slip in practice (`feedback_docs_arch_sync.md`).

**Grep is cheap — use it.** The expensive part of an audit is reading whole files; finding which docs *might* need attention via targeted greps is sub-second and produces output proportional to match count. Look at what the diff touches and grep for the affected tokens:

```bash
# Identify user-visible strings the diff renamed/removed:
git diff origin/main...HEAD -- src/ | grep -E '^[-].*"' | head

# For each interesting old string, grep docs:
grep -rn "<old-string>" docs/ README.md src/<area>/README.md
```

Concrete signals:

- Renamed/removed a CLI flag, install command, or user-visible string → grep `docs/` + `README.md` for the old token. Hits are doc bugs to fix in this PR.
- Changed an architecture/contract/dataflow described in a `docs/<area>.md` → re-read just that file's relevant section, update if it now lies.
- Pure internal refactor, no user-visible surface, no contract change → no audit needed.

If a doc gap is found, fold the update into the same PR. If the gap is too large to fold in cleanly, file an issue tracking it AND record the trade-off in the PR body explicitly - never let the gap land silently.

Record audit outcome in the PR body, even if it's "no doc update needed (internal refactor only)". This makes the audit visible to reviewers + future maintainers.

### 1. Pre-flight Checks
```bash
# Verify not on main
git branch --show-current

# Check for uncommitted changes
git status

# Show commits that will be squashed
git log main..HEAD --oneline

# Show diff stat
git diff main...HEAD --stat
```

If on main, abort — nothing to squash merge.
If there are uncommitted changes, commit or stash first.

### 2. Ensure Remote is Up to Date
```bash
# Push current branch (set upstream if needed)
git push -u origin <branch>

# Fetch latest main
git fetch origin main
```

### 2.5 Verify merge safety (detect silent code reintroduction)

Before merging, confirm the squash will not reintroduce old code from
commits that landed on main after this branch was created. This matters
whenever the branch and main have both moved since their common ancestor
and touch any of the same files.

```bash
# The 3-dot diff shows what the squash will actually include (merge-base aware):
git diff origin/main...HEAD --stat

# Simulate the merge in memory to catch conflicts or reversals:
git merge-tree $(git merge-base origin/main HEAD) origin/main HEAD > /tmp/merge-check
grep -c '^<<<<<<<' /tmp/merge-check  # must be 0
```

**Hard rule:** never use `git diff origin/main..HEAD` (two-dot) to validate
merge safety. Two-dot compares tree tips and treats intermediate commits on
main as reversals — it will either fabricate conflicts or hide real ones.
Always use `...` (three-dot) or `merge-tree` for pre-merge verification.

If `merge-tree` reports conflicts, run `/check-resolution` to inspect each
overlap file with the three-diff view (intended vs main vs net) before
deciding whether to rebase or abort.

If `merge-tree` reports conflicts or the 3-dot diff contains files the
branch never intentionally modified, do not squash-merge. Either rebase
on main (resolving conflicts) and re-run CI, or abort and investigate.

### 3. Detect Workflow

Check if this repo has a GitHub remote:
```bash
gh repo view --json url 2>/dev/null
```

- **If GitHub remote exists:** continue with PR workflow (step 4)
- **If no GitHub remote:** fall back to local merge workflow (step 7)

### 4. Create PR

- if PR exists already, skip step 5.

- if no PR:
Craft a conventional commit title: `type(scope): description`
- Types: feat, fix, docs, refactor, test
- Subject under 72 chars, imperative mood
- **Substantive content only.** Title + body describe what the change DOES, not its position in any plan. Never include: phase numbers ("Phase 50"), plan PR-N markers ("PR-1 of 9"), milestone IDs ("M3", "M4"), GSD references, internal sequencing ("step 1 of foundation work"), or pointers to plan/design docs as the framing. If reviewers need design context, link a design doc in the body — but the title and lead paragraph should read as a self-contained description of the change.
- Generate summary body from commit log — but rewrite to focus on the substantive scope, not the chronological commit order.

```bash
gh pr create --base main --title "type(scope): description" --body "..."
```

### 5. Wait for CI
```bash
gh pr checks <pr-number> --watch
```

If CI fails, fix issues and push again. Re-run checks.

### 5.5 PR body sanity check

GitHub's squash-merge defaults can be set to use the PR body as the commit
message body (`squash_merge_commit_message: PR_BODY`). If so, a malformed
body becomes a malformed permanent commit on main. Catch it before merge.

```bash
# Preview first 5 + last 5 lines for a quick eyeball:
gh pr view <pr-number> --json body --jq .body | head -5
echo "..."
gh pr view <pr-number> --json body --jq .body | tail -5

# Sanity grep: scan for markers that indicate a botched edit.
body=$(gh pr view <pr-number> --json body --jq .body)
echo "$body" | grep -nE '\$\{[^}]+\}|\$\([^)]+\)' && echo "WARN: orphan shell substitution literals"
[[ $(echo "$body" | grep -c '^## Summary$') -gt 1 ]] && echo "WARN: multiple ## Summary sections"
[[ $(echo "$body" | grep -c '^## Test plan$') -gt 1 ]] && echo "WARN: multiple ## Test plan sections"
echo "$body" | grep -nE '<<EOF|^EOF$|\bcat <<' && echo "WARN: leftover heredoc markers"
[[ $(echo "$body" | grep -cE '^- \[[ x]\] CI passes') -gt 1 ]] && echo "WARN: duplicate CI-passes checkboxes"
```

If any WARN fires, stop and fix the body with a clean rewrite
(`gh pr edit <pr-number> --body "$(cat <<'EOF' ... EOF)"`) before merging.
Never patch with `${var//old/new}` substitution - that is what causes most
mangling in practice (shell expansion + pattern overlap with replacement
content).

### 5.7 Preflight the merge (detect silent auto-merge regressions)

Step 2.5 caught conflicts and reversals as the branch stood when the PR was
opened. This step re-checks against the CURRENT base, right before merge,
in the same way GitHub will do it server-side. Catches the case where main
moved during the PR's review and an intermediate squash merge has
invisibly changed the merge-base-vs-base delta.

```bash
/preflight-merge <pr-number>
```

The skill:
- Fetches both sides into a throwaway clone.
- Simulates `git merge` against the PR's base.
- Lists files git auto-merged silently (invisible in GH UI) AND files with
  textual conflicts.
- For each auto-merged file, checks whether the merge result diverges from
  the current base - i.e., whether the branch's stale overlay won on lines
  the base has since fixed.
- Verdict: `SAFE`, `CONFLICTS ONLY` (safe to resolve in UI), or
  `DO NOT MERGE` (silent regressions detected).

If `DO NOT MERGE`, the fix is upstream: usually a commit on the branch
carries content the base now owns through a different commit ID (typical
of stacked PRs where an intermediate PR squash-merged). Drop the duplicate
via interactive rebase:

```bash
git fetch origin
git checkout <branch>
git rebase --onto origin/main <duplicate-commit>
git push --force-with-lease
```

Then re-run `/preflight-merge <pr-number>` and continue only when the
verdict is `SAFE`.

### 6. Squash Merge via GitHub
```bash
gh pr merge <pr-number> --squash --subject "type(scope): description"
```

If the repo has `squash_merge_commit_message: PR_BODY` configured, drop the
`--subject` flag and let GitHub default to the (now-sanity-checked) PR title
+ body. Check with:
```bash
gh api repos/{owner}/{repo} --jq '.squash_merge_commit_title, .squash_merge_commit_message'
```

**Stacked-PR exception:** If this PR has child PRs whose base is THIS branch (a stacked-PR cascade), do NOT pass `--delete-branch`. The branch deletion races GitHub's auto-retarget and auto-closes the child PRs (which then cannot be reopened — base ref is gone). Skip the flag, manually retarget each child to `main` after this merge (`gh pr edit <child> --base main`), and sweep all branches in one pass after the entire cascade completes.

Skip to step 8 (cleanup).

### 7. Local Merge Fallback (no GitHub remote)
```bash
git checkout main
git pull
git merge --squash <branch-name>
git commit -m "type(scope): description"
git push
```

### 8. Cleanup
```bash
git checkout main && git pull
git branch -d <branch>
```

Remote branch is auto-deleted by GitHub. If not: `git push origin --delete <branch>`

## Notes
- If $ARGUMENTS provided, use as commit message hint
- See CLAUDE.md Git section for commit conventions
- Use `git branch -D` if branch wasn't fully merged (force delete)
