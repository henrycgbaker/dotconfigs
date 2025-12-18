# Modular CLAUDE.md Documentation

Use a hierarchical network of CLAUDE.md files for efficient, modular documentation.

## Structure
*NB: repo structure will vary by project, but this is an example of how CLAUDE.mds will be distributed.*

```
project/
├── CLAUDE.md                    # Root: concise index + architecture overview
├── .claude/
│   ├── architecture.md          # Detailed system design, component relationships
│   └── workflows.md             # Common tasks, processes, how-to guides
├── src/
│   ├── CLAUDE.md                # src-level overview, links to subdirs
│   ├── core/
│   │   └── CLAUDE.md            # Core module: purpose, key files, usage
│   ├── metrics/
│   │   └── CLAUDE.md            # Metrics module docs
│   └── ...
└── tests/
    └── CLAUDE.md                # Testing strategy, fixtures, how to run
```

## Principles

1. **Each CLAUDE.md is concise** - Describe local functionality only
2. **Link to related docs** - Reference other CLAUDE.md files for context / to direct claude or reader appropriately onwards if needed
3. **Root is an index** - Quick architecture overview + pointers to detailed docs
4. **Token efficient** - Read only relevant parts, not one massive file

## Root CLAUDE.md Template

```markdown
# Project Name

Brief description (1-2 sentences).

## Architecture Overview
[High-level component diagram and description]

## Key Directories
- `src/core/` - [purpose] → see src/core/CLAUDE.md
- `src/metrics/` - [purpose] → see src/metrics/CLAUDE.md
- ...

## Detailed Docs
- `.claude/architecture.md` - System design
- `.claude/workflows.md` - Common tasks
```

## Directory CLAUDE.md Template

```markdown
# [Directory Name]

Purpose of this module/directory.

## Key Files
- `file.py` - [what it does]

## Usage
[Brief usage example if relevant]

## Related
- See `../CLAUDE.md` for parent context
- See `../other/CLAUDE.md` for related module
```

## When to Create/Update

- **Create**: When asked, or when a directory has significant standalone functionality
- **Update**: When docs become stale or changes affect the documented functionality
- **Split**: When any CLAUDE.md gets too long (>100 lines), break into subdirectory docs
