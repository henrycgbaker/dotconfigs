---
name: fix-pr-feedback
description: Sync a PR branch, triage its unresolved review comments, let the user pick which to address (mechanical via checklist, judgement-calls via options), fix each as a discrete commit, then audit and offer to push. Use when a reviewer has left comments / requested changes and the user says "address the feedback", "fix the comments", or "respond to the review".
allowed-tools: Bash, Read, Edit, Write, Task, AskUserQuestion
argument-hint: [PR-number]
---

# Fix PR Feedback

Sync the branch, fetch the unresolved review comments on a PR, let the user
choose what to address, work through each chosen item as a small
separately-committed change, audit the result, and push only on the user's
say-so. Addressing feedback in code (one commit per comment) is the default;
posting a reply on GitHub is not - the diff IS the response.

**On posting replies:** the gh-comment hook blocks every `gh pr comment`,
`gh issue comment`, `gh pr review`, and `gh api` comment-write unless the
command is prefixed with `GH_COMMENT_OK=1`. This skill never posts replies
automatically. If the user explicitly asks to reply to a specific comment,
prefix the single command, e.g.:
`GH_COMMENT_OK=1 gh api repos/OWNER/REPO/pulls/NUMBER/comments/CID/replies -f body='done'`

## When to invoke

- Reviewer has left comments or requested changes on an open PR.
- User says "address the feedback", "fix the review comments", "respond to
  the review", or "do what the reviewer asked".
- Not for the user's own self-review notes mid-development; that's just
  normal commits.

## Process

### 1. Identify the PR
PR number from `$ARGUMENTS`. If empty, infer from current branch:
```bash
PR="$ARGUMENTS"
[ -z "$PR" ] && PR=$(gh pr view --json number --jq .number)
[ -z "$PR" ] && { echo "No PR for current branch - pass a PR number"; exit 1; }
```

### 2. Sync the branch before touching anything
Never address feedback on a stale branch - fixes built on an old base waste a
review round. Fetch, check out the PR branch, and measure divergence from its
base:
```bash
git fetch origin
gh pr checkout "$PR"                       # checks out the PR's head branch
BASE=$(gh pr view "$PR" --json baseRefName --jq .baseRefName)   # usually main
git log --oneline "HEAD..origin/$BASE"     # commits on base not on branch
git log --oneline "origin/$BASE..HEAD"     # commits on branch not on base
```
Decide and act:
- **Up to date** (base has nothing new): proceed.
- **Behind / simply diverged**: rebase onto the base. If the working tree is
  dirty, stash first. `git rebase "origin/$BASE"`.
- **Stacked PR, or diverged by more than a handful of merges**: do **not**
  hand-rebase. Invoke **`/rebase-stacked-prs`** - it cherry-picks only the
  branch's genuinely-new commits and drops work already merged (in possibly
  modified form) on the base. Per the repo's rebasing policy, duplicate
  commits must be explicitly dropped, not conflict-resolved.

If a rebase conflicts and the resolution is non-trivial, run
**`/check-resolution`** afterwards to confirm nothing was silently resurrected
or reverted. Stop and surface to the user if the rebase can't complete cleanly.

### 3. Fetch comments and reviews
```bash
gh pr view "$PR" --json comments,reviews,reviewThreads > /tmp/pr-feedback.json
```

The three sources are different:
- `comments`: top-level conversation comments on the PR.
- `reviews`: review submissions (approve / request-changes / comment), each
  with a body and a state.
- `reviewThreads`: inline code comments grouped into threads, each with an
  `isResolved` flag. **This is the primary source** - filter to unresolved.

```bash
jq '.reviewThreads[] | select(.isResolved == false) | {
    path: .path,
    line: .line,
    body: (.comments[0].body),
    author: (.comments[0].author.login)
}' /tmp/pr-feedback.json
```

Also surface any `reviews[].body` whose `state` is `CHANGES_REQUESTED` -
the top-level review summary often says things the inline threads don't.

### 4. Triage and classify
Build one row per unresolved item and present the whole set to the user as a
table **before** changing anything. Each row:

| # | file:line | reviewer | what's asked | recommended fix | class |
|---|-----------|----------|--------------|-----------------|-------|

Classify every row as exactly one of:
- **mechanical** - a clear, deterministic code change with no real decision
  (rename, typo, extract helper, add guard the reviewer spelled out). The
  recommended fix is unambiguous.
- **input-required** - needs a human call: a question to answer, a
  preference/nit you might decline, a suggestion with more than one reasonable
  response, or anything ambiguous.

When in doubt, classify as input-required. Never silently skip or silently
comply with a contested comment.

### 5. Mechanical fixes - user picks via checklist
Present the mechanical rows through `AskUserQuestion` with `multiSelect: true`
so the user ticks which to apply. `AskUserQuestion` allows at most 4 options
per question, so **batch in groups of ≤4** (several questions if needed) -
never truncate the list to fit. Each option label = the fix; description =
the file:line and what changes. Unticked items are left for the user to
revisit; note them in the final report rather than dropping them.

### 6. Input-required fixes - user picks an option per comment
For each input-required row, present a single-select `AskUserQuestion` with
2-4 concrete options - typically: apply the reviewer's suggestion / keep the
current approach (optionally with a reply drafted for the user to post) / a
named alternative. Use the user's choice as the instruction for that fix. If
the user picks "keep current approach", that comment gets no commit; record it
for the report.

### 7. Implement - one commit per chosen fix
Work through the selected fixes. One commit per comment (or per tight cluster
of related comments) keeps each fix visible to the reviewer and revertible in
isolation.
```bash
# For each selected fix:
# - Edit the affected file(s)
# - Stage just those files
git add <files>
git commit -m "fix: <short description of what the review asked for>"
```
Conventional-commit types apply (`fix`, `refactor`, `docs`, …). Subject under
72 chars, imperative mood, no AI attribution. Use **`/commit`** if you want the
standard commit flow per fix. If pre-commit hooks (Ruff, secrets scan) fail,
fix forward with a new commit - never `--amend`.

### 8. Audit with a Sonnet subagent
Before reporting done, spawn a quick **Sonnet** subagent (Task tool,
`model: sonnet`) to independently verify coverage. Give it: the original
unresolved comments (from step 3) and the commits just made
(`git log --oneline "origin/$BASE..HEAD"` plus diffs). It returns a table:

| # | file:line | comment | addressed? | commit / note |
|---|-----------|---------|:---------:|---------------|

with a ✓ / ✗ in *addressed?* for every original comment - ✓ for a fix or a
deliberate user "keep" decision, ✗ for anything left open. Show the table to
the user. If the auditor marks something ✗ that should have been fixed, loop
back to step 7.

### 9. Ask before pushing
Do not push automatically. After the audit, ask the user via `AskUserQuestion`
whether to push the feedback commits:
```bash
git push origin HEAD
```
Force-push is rarely needed - review-feedback commits are accretive. Only use
`--force-with-lease`, and only if the user explicitly asked to squash or
rewrite. On "don't push", leave the commits local and tell the user the branch
is ready to push when they are.

## Posting replies on GitHub

**Default: do not.** The diff is the response. Reviewers see the new
commits and resolve the threads they're satisfied with.

If the user **explicitly** asks to reply to a comment (rare - usually for
a question that needs a text answer, not a code change), the `gh-comment`
hook blocks `gh pr comment` / `gh api ... pulls/comments` by default. The
user can unblock a single call by prefixing the env var:

```bash
GH_COMMENT_OK=1 gh pr comment "$PR" --body "..."
GH_COMMENT_OK=1 gh api repos/{owner}/{repo}/pulls/$PR/comments/<id>/replies \
    -f body="..."
```

The user must opt in per call - never set this in a hook or commit it
to the repo. Per project policy: "Do NOT comment directly on GitHub,
unless requested to explicitly".

## Notes

- **Don't amend**, don't squash mid-review. Each new commit is a visible
  unit of response to a specific comment. The eventual squash-merge
  collapses them all.
- Resolving threads on GitHub is the reviewer's call, not Claude's. Even
  with `GH_COMMENT_OK=1`, don't mark threads resolved.
- A comment the user chose to decline (step 6) is a legitimate outcome -
  the audit marks it ✓ as a deliberate decision, not an open item.

## Related

- `/rebase-stacked-prs` - the safe rebase invoked in step 2 for stacked or
  badly-diverged branches.
- `/check-resolution` - audit a non-trivial rebase/merge resolution.
- `/commit` - the underlying commit step for each fix.
- `/code-review` - reviews the LOCAL diff for bugs / simplifications. Run
  before pushing, to catch the obvious before a human reviewer does.
  `/fix-pr-feedback` is the inverse: address comments humans already left.
- `/squash-merge` - drive the now-feedback-addressed PR to merge.
