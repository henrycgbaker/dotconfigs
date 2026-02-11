---
created: 2026-02-11T17:03
title: Add deployment scan/status report command
area: tooling
files:
  - dotconfigs:420 (cmd_status — current status command, reads .env)
  - lib/deploy.sh (deploy engine, could be reused for scanning)
  - global.json (global deployment config)
  - scripts/registry-scan.sh (existing scan script, potential starting point)
---

## Problem

No way to see a unified view of what's deployed globally and per-project across all projects. Current `dotconfigs status` reads old .env config and only shows plugin-level status. Users need a markdown report showing:

- All globally deployed modules (from global.json) and their symlink status
- All projects with .dotconfigs/project.json and their deployed modules
- Which items are in `include` vs `exclude` per project
- Broken symlinks or missing sources

This would help verify deployment state after changes and give a birds-eye view of the entire dotconfigs ecosystem.

## Solution

- New command: `dotconfigs scan` or enhance `dotconfigs status` to work with JSON config
- Scan home directory for global symlinks (from global.json targets)
- Find all projects with `.dotconfigs/project.json` (could reuse project setup lib's directory scanning)
- Generate markdown report to stdout or file
- Consider: v4 scope (after v3 stabilises), include in docs phase
- Related: current `cmd_status` and `cmd_list` still read .env — Phase 12 CLI cleanup should migrate these to JSON config, this command builds on that
