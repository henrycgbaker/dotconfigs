---
name: pr-create
description: Open a GitHub PR for the current branch with a derived title, a stack banner for stacked PRs, and a structured Summary / Doc audit body. Use when the user says "open a PR", "draft a PR", or after a feature branch is ready for review but not yet merged.
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

Body sections, in order: Summary, then Doc audit. **No Test plan section** (CI on
the PR is the gate) and **no Stack prose section** (the banner below replaces it).

For a **stacked PR** (base is a feature branch, not `main`), the first line of the
body is a **stack banner**: the full PR chain, base->top, short-form and
space-`>` separated, e.g. `#123 > #124 > #125`. Use the same banner on every PR in
the stack, and list the whole lineage including already-merged lower PRs. Derive
the chain by walking base refs (`gh pr list --state all --json number,headRefName,baseRefName`)
or by copying a sibling PR's existing banner. Omit the banner entirely on a
main-based PR.

```bash
body=$(cat <<'EOF'
#123 > #124 > #125

## Summary

<1-3 bullets describing what the change does and why. No phase numbers, no
milestone IDs, no plan references. Substantive content only.>

## Doc audit

<One of:>
- No user-visible surface or contract change -> no doc update needed.
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
- The PR opens against `main` by default. For a stacked PR the user specifies
  `--base <other-branch>`; the body then leads with a stack banner (step 4). The
  skill doesn't auto-detect the base, but it adds the banner once told it's stacked.
- Use `gh pr edit <num> --body "$(cat <<'EOF' ... EOF)"` to revise after open.

## Related

- `/squash-merge` - drives an existing PR through preflight + CI watch + merge
  + cleanup. Run this after `/pr-create` once review and CI are green.
- `/commit` - on-branch commits; run before opening the PR.
- `/fix-pr-feedback` - address review comments on an open PR.
