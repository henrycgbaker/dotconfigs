---
name: fix-pr-feedback
description: Walk through unresolved review comments on a PR and address each one as a discrete commit on the branch. Use when a reviewer has left comments / requested changes and the user says "address the feedback", "fix the comments", or "respond to the review".
allowed-tools: Bash, Read, Edit, Write
argument-hint: [PR-number]
---

# Fix PR Feedback

Fetch the unresolved review comments on a PR, work through each one as a
small, separately-committed change, and push the result back to the branch.
Addressing feedback in code (one commit per comment) is the default; posting
a reply on GitHub is not - the diff IS the response.

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

### 2. Fetch comments and reviews
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

### 3. Triage
Print the unresolved set with file + line + comment snippet. For each:
- **Code change needed**: address in the working tree (Edit / Write).
- **Question / clarification**: flag for the user; do not silently skip.
- **Nit / preference disagreement**: surface for the user to call.

If anything is ambiguous, stop and ask before editing.

### 4. Address each comment as a discrete commit
One commit per comment (or per tight cluster of related comments). This
keeps each fix visible to the reviewer and easy to revert in isolation.

```bash
# For each comment:
# - Edit the affected file(s)
# - Stage just those files
# - Commit with a message that references what the comment asked for
git add <files>
git commit -m "fix: <short description of what the review asked for>"
```

Conventional-commit types apply (`fix`, `refactor`, `docs`, etc.). Subject
under 72 chars, imperative mood, no AI attribution.

If the project has pre-commit hooks (Ruff format/lint, secrets scan), they
run as normal - resolve any hook failures with a new commit, not `--amend`.

### 5. Push
```bash
git push origin HEAD
```

Force-push is rarely needed here; review-feedback commits are accretive
on the branch. Only use `--force-with-lease` if the user explicitly asks
to squash or rewrite.

### 6. Report
Print, per comment: file:line, reviewer, what was asked, and the commit
SHA(s) that addressed it. The reviewer will see the new commits in the PR
and can resolve threads themselves.

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
- If a comment asks for something the user disagrees with, surface it for
  the user to decide. Do not silently skip or silently comply.

## Related

- `/code-review` - reviews the LOCAL diff for bugs / simplifications. Run
  before pushing, to catch the obvious before a human reviewer does.
  `/fix-pr-feedback` is the inverse: address comments humans already left.
- `/commit` - the underlying commit step for each fix.
- `/squash-merge` - drive the now-feedback-addressed PR to merge.
