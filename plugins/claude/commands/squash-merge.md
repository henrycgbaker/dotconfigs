---
description: Squash merge current branch to main via GitHub PR
allowed-tools: Bash, Read
argument-hint: [optional commit message]
---

# Squash Merge via PR

Complete a feature branch by squash merging to main through a GitHub PR with CI gate.

## Process

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

If main has diverged, rebase first: `git rebase origin/main`

### 3. Detect Workflow

Check if this repo has a GitHub remote:
```bash
gh repo view --json url 2>/dev/null
```

- **If GitHub remote exists:** continue with PR workflow (step 4)
- **If no GitHub remote:** fall back to local merge workflow (step 7)

### 4. Create PR
Craft a conventional commit title: `type(scope): description`
- Types: feat, fix, docs, refactor, test
- Subject under 72 chars, imperative mood
- Never include phase numbers, milestone IDs, or GSD references
- Generate summary body from commit log

```bash
gh pr create --base main --title "type(scope): description" --body "..."
```

### 5. Wait for CI
```bash
gh pr checks <pr-number> --watch
```

If CI fails, fix issues and push again. Re-run checks.

### 6. Squash Merge via GitHub
```bash
gh pr merge <pr-number> --squash --subject "type(scope): description"
```

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
