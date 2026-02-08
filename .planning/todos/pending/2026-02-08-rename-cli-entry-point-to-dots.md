---
created: 2026-02-08T17:51
title: Rename CLI entry point to dots
area: tooling
files:
  - dotconfigs
---

## Problem

The CLI entry point `dotconfigs` is verbose for frequent use. A shorter name like `dots` would be more ergonomic for daily use while keeping the repo name as `dotconfigs`.

## Solution

TBD — future phase. Options:
- Rename entry point script from `dotconfigs` to `dots`
- Or keep `dotconfigs` and add `dots` as a symlink/alias
- Update PATH symlink, help text, README, all references
