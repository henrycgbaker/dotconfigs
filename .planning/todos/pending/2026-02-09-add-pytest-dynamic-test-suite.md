---
created: 2026-02-09T21:50
title: Add pytest dynamic test suite
area: testing
files:
  - tests/
  - plugins/claude/deploy.sh
  - plugins/claude/project.sh
  - plugins/git/deploy.sh
  - dotconfigs
---

## Problem

Current tests/ directory has hardcoded values (paths, usernames) that only work on one machine. No proper test framework — validation scripts aren't portable or maintainable. Need a real test suite that:

1. Uses pytest as the test runner
2. Is dynamic — no hardcoded paths, user-specific values, or machine-dependent assumptions
3. Covers the key CLI flows: setup, global-configs, deploy, project-configs, status, list
4. Can run on any machine with the repo cloned

## Solution

TBD — likely approach:
- pytest with subprocess calls to dotconfigs CLI
- Temp directories for deploy targets (pytest tmp_path fixture)
- Mock .env generation for wizard outputs
- Parameterised tests for both plugins (claude, git)
- CI-friendly (no TTY dependency for non-interactive paths)
