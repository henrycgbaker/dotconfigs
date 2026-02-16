---
created: 2026-02-16T16:14:55.912Z
title: Add deploy toggle field to config schema
area: tooling
files:
  - .dotconfigs/global.json
  - lib/deploy.sh
  - plugins/*/manifest.json
---

## Problem

When deploying on a different platform (e.g. cloning a Mac-oriented repo onto a Linux server), platform-specific entries like VS Code (`~/Library/Application Support/...`) create dangling symlinks and empty directory trees. Currently the only way to skip these is to delete the entry from global.json entirely, losing the config declaration.

Similarly for project.json — some entries may not apply to every project but you want to keep them declared for other contexts.

## Solution

Add an optional `"deploy": false` field to each entry in global.json and project.json. The deploy logic in `lib/deploy.sh` (`deploy_module`) should check this field and skip entries where `deploy` is explicitly `false`. Default behaviour (field absent or `true`) deploys as normal.

Example in global.json:
```json
"vscode": {
  "settings": {
    "source": "plugins/vscode/settings.json",
    "target": "~/Library/Application Support/Code/User/settings.json",
    "method": "symlink",
    "deploy": false
  }
}
```

Consider also supporting this at the group level (e.g. `"vscode": { "deploy": false, ... }`) to disable an entire plugin's global deployment in one toggle.
