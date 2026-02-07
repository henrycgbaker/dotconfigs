# Project Research Summary

**Project:** dotclaude - Portable Claude Code Configuration
**Domain:** Developer tooling, dotfiles management, Claude Code configuration
**Researched:** 2026-02-06
**Confidence:** HIGH

## Executive Summary

dotclaude is a git-based portable configuration system for Claude Code that deploys across macOS, SSH servers, Docker, and CI/CD environments. Research reveals this is fundamentally a **dotfiles management problem** with Claude-specific configuration layering. Experts solve this with modular templates, symlink-based deployment, and environment-specific profiles.

The recommended approach is to **simplify aggressively** and **remove over-engineering**. The current 94-file repository has accumulated significant complexity through duplicated GSD framework components (8,685 lines), over-engineered sync systems (300 lines, disabled), and verbose rules consuming ~2,000 tokens baseline. Research indicates most of this can be deleted: use GSD framework directly (don't duplicate), eliminate dead code, replace complex hooks with settings.json deny rules, and focus on the core value proposition—portable personal preferences and deterministic enforcement.

Key risks are **context bloat** (rules consuming Claude's working memory), **maintenance burden** (hooks and scripts become technical debt), and **portability failures** (hardcoded values, platform assumptions). Mitigation requires ruthless simplification, modular documentation (<100 lines per CLAUDE.md), and deployment-time configuration instead of hardcoded values.

## Key Findings

### Recommended Stack

**Core insight:** This is not a new software project—it's configuration distribution. The "stack" is bash scripts for deployment, symlinks for live updates, and Claude Code's native configuration system.

**Core technologies:**
- **Bash 3.2+ scripts** (cross-platform, macOS/Linux compatible) — deployment automation
- **Symlinks for live config** (CLAUDE.md, rules/, hooks/, agents/) — auto-update when repo changes
- **Copies for machine-specific** (settings.json, git hooks) — allow local overrides
- **Git as distribution** (clone/rsync for remotes) — version control, not custom sync
- **settings.json deny rules** (NOT Python hooks) — 94% less code, framework-maintained
- **Ruff for Python** (deterministic formatting) — zero-token enforcement via PostToolUse hook

**Critical findings:**
- Settings.json deny rules currently BROKEN (bug #6699, #8961) — must keep PreToolUse hook as workaround until fixed
- Claude Code settings hierarchy: Managed > CLI flags > Local project > Shared project > User global
- Symlinks require absolute paths and fail if repo moves
- GSD framework provides its own 11 agents + 30 commands — duplication is waste

### Expected Features

**Must have (table stakes):**
- **Global CLAUDE.md** — personal communication style, autonomy preferences (currently 100 lines, good)
- **settings.json** — permissions model (allow/deny/ask), hooks configuration
- **Git hooks** — pre-commit (formatting, branch protection), commit-msg (block AI attribution)
- **Deploy script** — automated setup via symlinks/copies
- **README** — quick start, architecture overview

**Should have (differentiators):**
- **Deterministic hooks** — auto-format Python (Ruff), block sensitive files (currently ~100 lines Python, should be 8 lines settings.json)
- **Configurable deployment** — selective components (--minimal, --no-gsd), environment profiles (dev/prod/CI), target directory override
- **Portable skills** — /commit, /squash-merge, /pr-review (git workflows)
- **Modular rules** — separate files for git, Python, simplicity principles
- **Remote deployment** — SSH via git clone or rsync

**Defer (v2+ or remove entirely):**
- **Project agent registry** — sync disabled, over-engineered, GSD handles distribution better
- **Docker templates** — user note says "not a priority for current workflow"
- **GitHub Actions templates** — no team use case yet
- **Complex sync systems** — bidirectional sync never needed, manual copy sufficient
- **Archived agents** — delete, use git history if needed

**Anti-features (deliberately avoid):**
- **GSD agent/command duplication** — framework ships these, don't copy
- **Verbose rules** (>100 lines) — use tools, not prose
- **Comprehensive usage guides** (750 lines) — unmaintained bloat
- **Specialist agents** (docker-expert, security-auditor) — too specific, use docs/tools

### Architecture Approach

**Pattern:** Layered configuration with clear boundaries (dotclaude core → GSD framework → project-specific → local overrides). Template in repo (githooks/, core/), deploy via setup.sh with symlinks for live-updated content and copies for machine-specific overrides.

**Major components:**
1. **Core config** (~/.claude/) — symlinked CLAUDE.md, rules/, hooks/, agents/; copied settings.json
2. **Git hooks** (.git/hooks/) — copied templates, enforce standards outside Claude context
3. **Deployment scripts** (deploy/) — setup.sh (local), remote.sh (SSH), profiles for selective install
4. **GSD framework integration** — optional, invoked not duplicated, 11 agents + 30 commands
5. **Environment profiles** (config/profiles.json) — minimal/standard/full/no-gsd presets

**Key architectural decisions:**
- **Symlink for code** (auto-updates), **copy for config** (local overrides)
- **User-level deployment** (~/.claude/) — projects override as needed
- **Fail-closed for security** (sensitive files, AI attribution), **fail-open for convenience** (formatting)
- **Settings-first** — use framework deny rules before writing hooks
- **Three-instance rule** — only generalize after third similar use case

### Critical Pitfalls

1. **Context bloat death spiral** — Large CLAUDE.md (>200 lines) consumes context → Claude forgets rules → add more rules → worse performance. **Prevention:** Modular docs, infer over instruct, <100 lines per file, quarterly audits.

2. **Duplicating GSD framework** — 8,685 lines of agents/commands copied from framework → drift from upstream → no bug fixes/improvements → maintenance burden. **Prevention:** Delete all GSD copies, use framework directly via `/gsd:*` commands.

3. **Complex hooks vs simple settings.json** — 102-line Python hook for functionality achievable in 8 lines of settings.json → slower, harder to debug, more bugs. **Prevention:** Settings-first rule, use built-in permissions, hooks only for gaps. **Current blocker:** Settings deny rules broken (bug #6699), must keep hook until fixed.

4. **Hardcoded personal values** — Git identity "henrycgbaker" hardcoded in pre-commit → only works for one person → can't share. **Prevention:** Deploy-time config, read from git config, cross-platform testing.

5. **Dead code accumulation** — Commented blocks, disabled features, "just in case" code → maintenance burden, confusion about what's active. **Prevention:** Delete don't disable, quarterly pruning, trust git history.

**Additional pitfalls from research:**
- **Pre-commit vs commit-msg timing** — COMMIT_EDITMSG is stale in pre-commit (previous commit), causes wrong validation
- **Fail-open vs fail-closed** — Security hooks must fail-closed (block on error), convenience can fail-open
- **Symlink vs copy confusion** — Wrong choice causes update failures or broken links
- **Over-engineering for hypothetical futures** — Agent sync (300 lines, never used), remote deployment complexity

## Implications for Roadmap

Based on research, this is a **cleanup and simplification project**, not a build-from-scratch project. Most work is **deletion** and **refactoring** existing over-engineering.

### Phase 1: Remove Over-Engineering (Foundation Cleanup)
**Rationale:** Research shows 80% of current code is waste. Delete first to establish clean foundation.

**Delivers:**
- Delete 8,685 lines of GSD agent/command duplicates
- Delete 300-line sync-project-agents.sh (disabled, unused)
- Delete _archive/ directory (use git history)
- Delete commented code blocks (environment patterns in block-sensitive.py, agent sync in pre-commit)
- Delete or condense 750-line usage guide (split into topic docs)

**Addresses features:**
- Anti-feature: GSD duplication (FEATURES.md line 745)
- Anti-feature: Complex sync systems (FEATURES.md line 765)
- Anti-feature: Archived dead code (FEATURES.md line 873)

**Avoids pitfalls:**
- Pitfall: Duplicating framework functionality (PITFALLS.md §3.3)
- Pitfall: Dead code accumulation (PITFALLS.md §3.4)
- Pitfall: Over-engineering config (PITFALLS.md §3.1)

**Research flags:** Standard cleanup, no research needed.

---

### Phase 2: Fix Core Architecture Issues
**Rationale:** Research identified broken deny rules and timing bugs in hooks. Fix before building new features.

**Delivers:**
- Fix pre-commit timing bug (COMMIT_EDITMSG read is stale)
- Move commit message validation to commit-msg hook (correct timing)
- Fix hardcoded identity (use git config or deploy-time config)
- Monitor Claude Code for deny rules bug fix (#6699), migrate from hook to settings.json when fixed
- Document settings.json precedence (hierarchy, merge behaviour)

**Uses stack:**
- Settings.json deny rules (when bug fixed)
- Commit-msg hook (for correct validation timing)

**Addresses features:**
- Must-have: Git hooks (FEATURES.md line 74)
- Differentiator: Deterministic hooks (FEATURES.md line 206)

**Avoids pitfalls:**
- Pitfall: Pre-commit vs commit-msg timing (PITFALLS.md §2.1)
- Pitfall: Hardcoding identity (PITFALLS.md §5.3)
- Pitfall: Complex hooks vs settings.json (PITFALLS.md §2.3)

**Research flags:** Monitor Claude Code issue tracker for bug fix, test settings.json deny rules before migration.

---

### Phase 3: Deployment Configurability
**Rationale:** Research shows need for selective component install and environment profiles (CI, Docker, minimal).

**Delivers:**
- Modularise deployment scripts (deploy/lib/common.sh, symlink.sh, validate.sh)
- Create deployment profiles (config/profiles.json: minimal, standard, full, no-gsd)
- Add setup.sh flags (--target, --profile, --no-gsd, --dry-run)
- Implement component selection (--components rules,commands)
- Create validation tool (tools/validate-config.sh)

**Implements architecture:**
- Environment profiles (ARCHITECTURE.md line 230)
- Deployment script architecture (ARCHITECTURE.md line 256)
- Cross-platform symlink handling (ARCHITECTURE.md line 303)

**Addresses features:**
- Differentiator: Configurable deployment (FEATURES.md line 267)

**Avoids pitfalls:**
- Pitfall: Settings precedence surprises (PITFALLS.md §4.3)
- Pitfall: Cross-platform path issues (PITFALLS.md §4.2)

**Research flags:** Test on both macOS and Linux, verify profile behaviour in Docker/CI.

---

### Phase 4: Context Optimisation
**Rationale:** Research shows ~2,000 tokens baseline from rules. Reduce to <500 tokens through modularisation.

**Delivers:**
- Condense CLAUDE.md to <100 lines (reference modular rules instead of repeating)
- Move language-specific rules to project-level (python-standards.md only for Python projects)
- Split git-workflow.md into on-demand docs (not always-loaded)
- Remove redundant instructions (things Claude already does)
- Quarterly audit process (documented)

**Addresses features:**
- Differentiator: Context-efficient design (FEATURES.md line 602)

**Avoids pitfalls:**
- Pitfall: Bloated CLAUDE.md (PITFALLS.md §1.1)
- Pitfall: Rules files eating baseline context (PITFALLS.md §1.2)

**Research flags:** Standard refactoring, no research needed.

---

### Phase 5: Remote & Docker Deployment
**Rationale:** Research shows need for SSH and CI/CD deployment, but avoid over-engineering.

**Delivers:**
- Remote deployment script (deploy/remote.sh: git clone vs rsync methods)
- Docker deployment script (deploy/docker.sh for volume mounts)
- CI deployment script (deploy/ci.sh: non-interactive, minimal profile)
- Dockerfile templates (dev container, baked-in production)
- .gitattributes for line endings (shell scripts always LF)

**Implements architecture:**
- SSH deployment (ARCHITECTURE.md line 360)
- Docker deployment (ARCHITECTURE.md line 416)
- CI/CD deployment (ARCHITECTURE.md line 520)

**Addresses features:**
- Should-have: Remote deployment (FEATURES.md line 379)

**Avoids pitfalls:**
- Pitfall: Remote deployment complexity (PITFALLS.md §4.4)
- Pitfall: Cross-platform path issues (PITFALLS.md §4.2)

**Research flags:** Test rsync vs git clone on actual remote servers, verify Docker volume behaviour.

---

### Phase 6: Project Templates & Documentation
**Rationale:** Research shows 750-line usage guide is too long. Replace with focused templates and concise docs.

**Delivers:**
- Project CLAUDE.md template (templates/project/CLAUDE.md.template)
- settings.json templates (templates/project/settings-{dev,prod,ci}.json)
- Agent template (templates/agent/agent-template.md)
- Condense usage guide (split into FAQ, troubleshooting, architecture)
- README to <200 lines (quick start only)

**Addresses features:**
- Should-have: CLAUDE.md starter template (FEATURES.md line 491)
- Must-have: README (FEATURES.md line 171)

**Avoids pitfalls:**
- Anti-feature: 750-line usage guides (PITFALLS.md §18)

**Research flags:** Standard documentation, no research needed.

### Phase Ordering Rationale

**Phase 1 first:** Delete waste before building new features. Establishes clean foundation, reduces cognitive load, prevents building on top of over-engineering.

**Phase 2 second:** Fix broken core functionality (deny rules bug, hook timing) before adding configurability. Ensures stable base.

**Phase 3 third:** Configurability enables Phases 5-6 (selective install for CI/Docker). Profiles support different deployment scenarios.

**Phase 4 parallel with 5-6:** Context optimisation can proceed independently while deployment features are built.

**Phase 6 last:** Documentation after features stable. Templates use final deployment approach.

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 2:** Monitor Claude Code issue tracker for deny rules bug fix (#6699, #8961). Research alternative if not fixed by phase start.
- **Phase 5:** Test remote deployment on actual SSH servers (not just localhost). Verify Docker volume mount behaviour with symlinks.

**Phases with standard patterns (skip research-phase):**
- **Phase 1:** Deletion and cleanup, no uncertainty.
- **Phase 3:** Standard bash scripting patterns, well-documented.
- **Phase 4:** Context management, clear from research.
- **Phase 6:** Documentation and templates, no research needed.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | **HIGH** | Official docs, multiple sources confirm Claude Code configuration system, bash portability well-understood |
| Features | **HIGH** | Real repository analysis shows what's used vs unused, dotfiles patterns established |
| Architecture | **HIGH** | Symlink vs copy tradeoffs documented, deployment patterns proven, layered config clear |
| Pitfalls | **VERY HIGH** | Identified from actual code analysis (94 files), real bugs found (COMMIT_EDITMSG timing, deny rules broken) |

**Overall confidence:** **HIGH**

Research is based on:
- Official Claude Code documentation (settings, hooks, skills)
- Real codebase analysis (current dotclaude repo)
- Established dotfiles management patterns (symlinks, templates, deployment)
- Known bugs (GitHub issues #6699, #8961 for deny rules)
- Cross-platform compatibility research (macOS/Linux/Docker)

### Gaps to Address

1. **Settings.json deny rules bug** — Currently broken in Claude Code (reported issues). Must track upstream fix, plan migration from Python hook to settings.json when resolved. **Handling:** Keep PreToolUse hook as workaround, monitor releases, test deny rules before removing hook.

2. **GSD framework version pinning** — Research doesn't specify which GSD version to recommend. **Handling:** Use latest stable, document version in setup.sh, provide upgrade path.

3. **Symlink reliability in git worktrees** — GitHub issue #764 reports symlink problems. **Handling:** Document limitation, provide --copy-all flag for environments where symlinks fail.

4. **Windows compatibility** — Research focused on macOS/Linux. **Handling:** Document as macOS/Linux only for now, or test WSL if Windows support needed.

5. **Settings.json merge semantics** — Research shows some fields merge, others override, but exact behaviour not fully documented. **Handling:** Test empirically, document findings for users.

## Sources

### Primary (HIGH confidence)
- [Claude Code Settings Documentation](https://code.claude.com/docs/en/settings) — Settings hierarchy, precedence
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks) — Hook system, timing, events
- [Ruff Documentation](https://docs.astral.sh/ruff/) — Formatting/linting capabilities
- [Git Hooks Documentation](https://git-scm.com/docs/githooks) — Hook types, execution order
- **Codebase analysis** — dotclaude repo (94 files, 8,685 lines GSD duplicates)
- [GitHub Issues #6699, #8961](https://github.com/anthropics/claude-code/issues) — Deny rules bug reports

### Secondary (MEDIUM confidence)
- [Skills System Merge Announcement](https://medium.com/@joe.njenga/claude-code-merges-slash-commands-into-skills) — Skills/commands unification
- [Docker Sandboxes Announcement](https://www.docker.com/blog/docker-sandboxes-run-claude-code-and-other-coding-agents-unsupervised-but-safely/) — Docker integration
- [GSD Framework Repository](https://github.com/glittercowboy/get-shit-done) — Framework structure, agent count
- Community dotfiles patterns — github.com/rhysd/dotfiles, paulirish/dotfiles (symlink patterns)

### Tertiary (LOW confidence)
- Cross-platform symlink issues (GitHub #764) — Reported but not extensively tested
- Windows compatibility — Inferred, not verified
- Settings merge semantics — Partially documented, needs empirical validation

---
*Research completed: 2026-02-06*
*Ready for roadmap: yes*
