---
name: diagnose-missing-work
description: Diagnose a "I thought we did X" / "this got lost" report before concluding work is missing. Fetches first, distinguishes squash-merge dangling commits (normal) from genuine loss, and checks merged PRs and the reflog. Use when the user says work seems gone, a change isn't on main, or a branch "disappeared" - and BEFORE any destructive recovery or re-doing the work.
allowed-tools: Bash, Read
argument-hint: [what the user thinks is missing - a feature name, file, or PR]
---

# Diagnose Missing Work

A report that work has "got lost" is usually a stale-view or normal-post-merge artifact, not
real loss. The failure mode is concluding loss from stale local refs and then re-doing work
that is already on main, or worse, running destructive recovery. This skill is **read-only**:
it never restores, resets, or cleans. It establishes what is actually true before any action.

Subject of the report: `$ARGUMENTS` (ask what they expected to find if not supplied).

## Core principle

> Never reason about `main` from local refs. `git fetch origin` FIRST, then ask the loose
> object store, the merged-PR list, and the reflog - in that order - before believing
> anything is gone. In a squash-merge repo, a source-branch commit that is now "dangling"
> is the **expected** end state of a merge, not evidence of loss.

## Process

### 1. Refresh - never trust stale local refs
```bash
git fetch origin --prune
git status -sb
```
Everything downstream compares against `origin/*`, not local `main`. Skipping this is the
single most common cause of a false "it's gone" conclusion.

### 2. Is it already on main, under a different SHA?
A squash-merge lands the whole branch as ONE new commit on main with a new SHA and the PR
title as its subject. Search by content and by merged PR, not by the old commit SHA:
```bash
gh pr list --state merged --search "<keyword>" --limit 20 \
  --json number,title,mergedAt,mergeCommit
git log origin/main --oneline -20
git grep -n "<a-symbol-the-work-introduced>" origin/main || echo "not on main"
```
If a merged PR or the symbol is present, the work landed - report which PR and stop.

### 3. If not on main: find the work in the object store
The branch's original commits survive as loose/dangling objects after a squash-merge or a
deleted branch:
```bash
git reflog --date=iso | head -40                       # was it checked out / committed here?
git fsck --lost-found --no-reflogs --unreachable 2>/dev/null | grep commit
```
For each candidate dangling commit, inspect it - do NOT assume it is lost work:
```bash
git show --stat <dangling-sha>
git log --oneline -5 <dangling-sha>
```

### 4. Prove integrated-vs-lost by content, not by SHA
The decisive test: does the dangling commit's content already exist on main? In a squash-merge
repo it almost always does.
```bash
git diff <dangling-sha> origin/main -- <paths it touched>   # empty-ish => already integrated
```
- **Diff is empty / only trivial** -> the work is on main. NOT lost. Report the PR from step 2.
- **Diff shows the work's additions missing on main** -> genuinely not integrated. Proceed to
  step 5 to surface recovery options - but still do not act destructively.

### 5. Report - findings first, recovery as user-run commands
State plainly which case it is and the evidence. If genuinely unintegrated, the work exists at
`<dangling-sha>` and is recoverable; present (do not auto-run) the recovery options:
```bash
git branch recover/<slug> <dangling-sha>     # safest: park it on a branch, then inspect
git cherry-pick <dangling-sha>               # if it should layer onto current work
```
Recovery that rewrites or discards state (`reset --hard`, `restore`, `checkout -- <path>`,
`clean`) is destructive and outward of this skill's remit - hand those to the user, and only
after confirming there are no uncommitted edits that such a command would erase.

## Notes
- "Dangling" after a squash-merge is the normal, healthy end state - it is how git records that
  the branch's individual commits were collapsed into one. It is not a corruption signal.
- A deleted local branch whose commits are unreachable behaves the same way; the reflog and
  `fsck` still find them for ~90 days (default gc grace).
- Stop at the first definitive answer. If step 2 finds the merged PR, you are done - do not run
  `fsck` "to be sure".

## Related
- The destructive-git guardrail: when uncommitted edits are present, never run
  `git restore`/`reset --hard`/`clean` to "recover" - stash first; editor local history is the
  real recovery path. This skill stays read-only precisely to respect that.
- `/check-resolution` - if the work IS on main but looks wrong, audit whether a merge/rebase
  silently dropped part of it.
