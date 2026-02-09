---
created: 2026-02-09T22:35
title: Test project-init on brownfield project and ds01 server
area: testing
files:
  - plugins/claude/project.sh
  - plugins/git/project.sh
  - dotconfigs
---

## Problem

Project-init wizard has been tested in greenfield temp directories only. Need to validate it works correctly in:

1. **Brownfield project** — existing `.claude/` dir, existing CLAUDE.md, existing settings. Does the overwrite/skip flow work? Does it detect brownfield correctly? Does merging hooks into existing settings.json break anything?
2. **ds01 server** — different environment (likely Linux, not macOS). Checks: `sed -i` compat (no `''` arg on Linux), `jq` availability, hook permissions, `.git/info/exclude` behaviour, CLAUDE.md section assembly.

## Solution

Manual UAT:
- Pick a real brownfield project (existing Claude config) and run `dotconfigs project-init .`
- Verify each step handles existing artifacts gracefully
- SSH to ds01, clone dotconfigs, run setup + project-init
- Check for macOS-isms that break on Linux (sed -i is the known one)
