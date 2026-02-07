---
description: Review code or architecture for unnecessary complexity
allowed-tools: Bash, Read, Grep, Glob
argument-hint: [file, directory, or description of concern]
---

# Simplicity Check

Review code or architecture against simplicity principles.

## Principles

1. **Solve only what was asked** — no premature abstractions (only generalise at 3+ similar implementations)
2. **No backwards-compatibility shims** — if code can just change, change it
3. **No hypothetical future requirements** — don't build "just in case" configurability
4. **Validate at system edges only** — trust internal code

## Process

### 1. Identify Scope

If $ARGUMENTS provided, use as target. Otherwise ask what to review.

### 2. Read and Analyse

Read the target code/files. For each file, check:

- [ ] Over-abstraction: Are there interfaces/abstractions with only one implementation?
- [ ] Premature generalisation: Are there config options nobody uses?
- [ ] Defensive overkill: Is there internal validation that duplicates edge validation?
- [ ] Speculative features: Is there code for requirements that don't exist yet?
- [ ] Layer bloat: Are there unnecessary indirection layers?

### 3. Report

For each issue found:
- **What**: Describe the unnecessary complexity
- **Where**: File and line range
- **Why it's unnecessary**: Which principle it violates
- **Suggested fix**: How to simplify (usually: delete it)

### 4. Summary

Rate overall simplicity: Simple / Acceptable / Over-engineered
List top 3 simplification opportunities if any exist.

## Notes

- This is an advisory review, not an automated fix
- Focus on structural complexity, not code style (Ruff handles style)
- "Could we delete this and nothing breaks?" is the key question
