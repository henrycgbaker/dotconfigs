---
created: 2026-02-06T15:20
title: Review squash-merge vs native git merge workflow
area: tooling
files:
  - ~/.claude/CLAUDE.md:33
  - .planning/ROADMAP.md:128-134
---

## Problem

Squash merge rewrites git history, which causes git to not recognise commits as merged — branches show as unmerged even after squashing. The original goal was clean commit histories (blocks of validated work rather than messy atomic commits), but squash merge may not be the best approach.

Key tensions:
- **Squash merge**: Clean linear history on main, but git loses merge tracking. Branch appears unmerged. Difficult to trace which branch delivered a feature.
- **Regular merge commit (`merge --no-ff`)**: Preserves merge tracking, git knows what's merged, but main history shows all branch commits.
- **Rebase + merge**: Linear history but also rewrites, similar issues.

The user wants: blocks of validated work, merged from feature branches, where git correctly tracks what's merged. Need to research industry standard approach.

## Solution

Research needed before Phase 6 (SKIL-02):

1. What is industry standard for solo dev / small team git workflow in 2026?
2. Is `git merge --no-ff` (merge commits) better than squash for this use case?
3. Could we use squash merge but with a different cleanup strategy (delete branch immediately, use tags)?
4. How do GitHub/GitLab handle "squash and merge" vs "create a merge commit"?
5. Update CLAUDE.md git workflow section and /squash-merge skill (or replace with /merge skill) based on findings

Affects: Phase 6 SKIL-02 (/squash-merge skill), CLAUDE.md ## Git section
