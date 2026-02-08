---
description: Squash merge current branch to main
allowed-tools: Bash, Read
argument-hint: [optional commit message]
---

# Squash Merge Helper

Complete a feature branch by squash merging to main.

## Process

### 1. Pre-flight Checks
```bash
# Verify not on main
git branch --show-current

# Check for uncommitted changes
git status

# Show commits that will be squashed
git log main..HEAD --oneline
```

If on main, abort - nothing to squash merge.

### 2. Check Branch Up-to-Date with Main
```bash
# Fetch latest main
git fetch origin main

# Check if main has diverged
git log HEAD..origin/main --oneline
```

If main has new commits, recommend rebasing first:
```bash
git rebase origin/main
```

### 3. Review Changes
```bash
# Summary of what will be merged
git diff main...HEAD --stat
```

### 4. Switch to Main and Pull
```bash
git checkout main
git pull
```

### 5. Squash Merge
```bash
git merge --squash <branch-name>
```

### 6. Create Clean Commit
Help craft a conventional commit message summarising all the squashed changes:

```bash
git commit -m "type: description"
```

**Commit message guidance:**
- Use conventional commit format (feat/fix/docs/refactor/test)
- Subject under 72 characters, imperative mood
- Summarise the overall change, not individual commits

### 7. Cleanup
```bash
# Delete the merged branch locally
git branch -d <branch-name>

# Delete remote tracking branch (if exists)
git push origin --delete <branch-name>

# Push squashed commit to remote
git push
```

## Tradeoffs

Squash merge creates a clean linear history on main but comes with tradeoffs:

**Benefits:**
- Single atomic commit per feature on main
- Clean `git log` output
- Easy to revert entire features

**Tradeoffs:**
- Individual branch commits lost from main history
- Detailed development history only visible in PR/branch (if using GitHub)
- Branch refs are the ONLY way to find individual commits after squash

**Why this matters for solo dev:**
- Clean main history > preserving every WIP commit
- Feature branches capture detailed development journey
- `git reflog` can still recover branch commits for ~90 days after deletion

**Critical:** Delete the branch after squashing. Without branch refs, individual commits become unreachable in `git log` (though still in reflog temporarily).

## Notes
- If $ARGUMENTS provided, use as commit message hint
- See CLAUDE.md Git section for commit conventions
- Use `git branch -D` if branch wasn't fully merged (force delete)
