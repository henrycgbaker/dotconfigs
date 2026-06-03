---
name: pr-create
description: Open a GitHub PR for the current branch with a derived title and a structured Summary / Test plan / Doc audit body. Use when the user says "open a PR", "draft a PR", or after a feature branch is ready for review but not yet merged.
allowed-tools: Bash, Read
argument-hint: [optional title]
---

# Create a Pull Request

Open a GitHub PR targeting `main` from the current feature branch. Derives a
sensible title from the branch and last commit subject, drafts a body with the
project's standard sections, and surfaces any linked issues.

This skill opens the PR and stops. To drive a PR through CI and merge, use
`/squash-merge`.

## When to invoke

- The user asks to open / draft / create a PR.
- A feature branch has had its first meaningful commit and is ready for review
  (CI on PR is the gate before merge).
- Not when a PR already exists for this branch (check with `gh pr view`).

## Process

### 1. Pre-flight
```bash
# Confirm not on main
branch=$(git branch --show-current)
[ "$branch" = "main" ] && { echo "On main - need a feature branch"; exit 1; }

# Confirm no PR already exists
gh pr view --json number 2>/dev/null && { echo "PR already exists - use /squash-merge to drive it to merge"; exit 0; }

# Confirm branch is pushed (or push it)
if ! git rev-parse --verify "@{upstream}" >/dev/null 2>&1; then
    git push -u origin "$branch"
fi
```

### 2. Derive title
If `$ARGUMENTS` is non-empty, use it as the title. Otherwise:
```bash
# Start from the last commit subject
title=$(git log -1 --pretty=%s)

# If the branch name encodes a conventional-commit type, prefer that:
# feature/foo-bar -> feat: ..., fix/baz -> fix: ..., refactor/x -> refactor: ...
case "$branch" in
    feature/*) prefix="feat" ;;
    fix/*)     prefix="fix" ;;
    refactor/*) prefix="refactor" ;;
    docs/*)    prefix="docs" ;;
    test/*)    prefix="test" ;;
    *)         prefix="" ;;
esac

# Combine if title doesn't already start with a conventional-commit type
if [ -n "$prefix" ] && ! echo "$title" | grep -qE '^(feat|fix|docs|refactor|test|chore)(\(|:)'; then
    title="$prefix: $title"
fi
```

Subject under 72 chars, imperative mood, no AI attribution.

### 3. Detect linked issues
```bash
# From branch name (e.g. fix/123-broken-thing -> #123)
branch_issue=$(echo "$branch" | grep -oE '[0-9]+' | head -1)

# From commits on this branch since main
commit_issues=$(git log origin/main..HEAD --pretty=%B | grep -oE '#[0-9]+' | sort -u)
```

If any issue numbers are found, include them in the body's Summary as
"Closes #N" (only if confident the PR fully resolves the issue; otherwise
"Refs #N").

### 4. Draft the body

Match the project's existing PR body style (see `gh pr list --limit 3 --json body`):
three sections, in this order: Summary, Test plan, Doc audit.

```bash
body=$(cat <<'EOF'
## Summary

<1-3 bullets describing what the change does and why. No phase numbers, no
milestone IDs, no plan references. Substantive content only.>

## Test plan

- [ ] <local check 1>
- [ ] <local check 2>
- [ ] CI passes

## Doc audit

<One of:>
- No user-visible surface or contract change → no doc update needed.
- Updated `docs/<file>.md` to reflect <change>.
- <Doc gap identified and tracked in #N>.
EOF
)
```

Populate Summary from the commit log since `origin/main`:
```bash
git log origin/main..HEAD --pretty='- %s'
```
Rewrite to focus on substantive scope, not chronological commit order.

### 5. Open the PR
```bash
gh pr create --base main --title "$title" --body "$(cat <<EOF
$body
EOF
)"
```

Print the PR URL on success.

## Notes

- **No AI attribution** in title or body. The `block-ai-pr-attribution` hook
  rejects it anyway; this skill must not generate it in the first place.
- **No phase numbers / plan markers / milestone IDs.** Title and body describe
  what the change does, not its position in any plan.
- The PR opens against `main` by default. If the branch is stacked on another
  branch, the user must specify `--base <other-branch>` manually; this skill
  doesn't try to infer stacked-PR topology.
- Use `gh pr edit <num> --body "$(cat <<'EOF' ... EOF)"` to revise after open.

## Related

- `/squash-merge` - drives an existing PR through preflight + CI watch + merge
  + cleanup. Run this after `/pr-create` once review and CI are green.
- `/commit` - on-branch commits; run before opening the PR.
- `/fix-pr-feedback` - address review comments on an open PR.
