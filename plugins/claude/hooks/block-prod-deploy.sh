#!/bin/bash

# === METADATA ===
# NAME: block-prod-deploy
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: PreToolUse hook blocking a by-hand production release (ds01-deploy) so prod is only moved through the tag-triggered pipeline. Read-only subcommands are allowed; override with DS01_DEPLOY_OK=1.
# ================
#
# Why: ds01-infra releases to prod through a pipeline, not a shell. Pushing a
# vX.Y.Z tag fires release.yml (cuts the Release) and deploy.yml, which runs
# ds01-deploy on the self-hosted runner: staging build, smoke test, rsync to
# /opt/ds01-infra, health gate, auto-rollback, and a line in history.log. That
# route pauses on the `production` environment for a human, and every release is
# a tag someone can point at afterwards.
#
# Running `sudo ds01-deploy` by hand does the same work while skipping the parts
# that make it accountable: no tag, no approval gate, no Release, and a prod SHA
# that corresponds to nothing anyone can name. That is how ds01-infra ended up
# with prod sitting on a bare main commit for seven months while VERSION and the
# v1.x tags drifted somewhere else entirely.
#
# The grep is on the whole command string rather than a command prefix on
# purpose: the realistic way this gets run is wrapped, `ssh dsl 'sudo -n
# ds01-deploy'`, which a Bash(sudo *) permission rule never sees.
#
# NOT blocked: --list / --help (reads), and ds01-apply, which only reapplies
# side-effects to code already on disk and moves no release.

# shellcheck source=_hook-common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_hook-common.sh"

hook_require_cmd jq

stdin_data=$(cat)
{
    IFS= read -r hook_event
    IFS= read -r tool_name
    IFS= read -r command
} < <(echo "$stdin_data" | jq -r '.hook_event_name // "", .tool_name // "", .tool_input.command // ""')

[[ "$hook_event" == "PreToolUse" ]] || exit 0
[[ "$tool_name" == "Bash" ]] || exit 0
[[ -n "$command" ]] || exit 0

# Cheap reject first: this hook has no `if` filter (it must see ssh-wrapped
# commands too), so every Bash call reaches it.
#
# Anchored on `sudo` rather than the bare program name, for two reasons: a real
# release is always sudo (the script itself dies "must run as root"), and the
# bare name appears constantly as a plain string - in greps, in docs, in this
# very file - which a looser match would block. Optional flags (-n) and an
# absolute path (/usr/local/bin/) sit between the two words.
echo "$command" | grep -qE 'sudo\s+(-[A-Za-z]+\s+)*(/[^[:space:]]*/)?ds01-deploy' || exit 0

# Writing or reading the string is not running it. A command whose real verb is a
# text tool is handling `sudo ds01-deploy` as prose - documenting this rule, or
# grepping for callers - and must not be blocked for saying the words. Leading
# `cd <path> &&` is stripped first because that is how most such commands arrive.
verb=$(echo "$command" | sed -E 's/^[[:space:]]*cd[[:space:]]+[^&;|]+(&&|;)[[:space:]]*//' |
    grep -oE '^[[:space:]]*[A-Za-z0-9_./-]+' | tr -d '[:space:]')
case "${verb##*/}" in
    printf | echo | cat | grep | rg | sed | awk | jq | head | tail | tee | diff | less | git)
        exit 0
        ;;
esac

# Explicit bypass, same shape as block-gh-comment's.
if echo "$command" | grep -qE '(^|[^A-Z_])DS01_DEPLOY_OK=1(\s|$)'; then
    exit 0
fi

# Read-only subcommands: release history, current SHA, usage. The trailing
# class carries a quote because the realistic caller is ssh-wrapped, where the
# flag is the last thing before the closing quote rather than end-of-string.
if echo "$command" | grep -qE -- "--(list|help)([[:space:]]|['\"]|\$)"; then
    exit 0
fi

hook_deny "Blocked by-hand production release: ds01-deploy moves /opt/ds01-infra without a tag, without the production approval gate, and without a GitHub Release - the prod SHA then corresponds to nothing anyone can name. Release by bumping VERSION, tagging vX.Y.Z and pushing the tag; deploy.yml runs ds01-deploy on the runner with smoke test, health gate and auto-rollback. For a genuine emergency (Actions down, rollback needed now) prefix the command: DS01_DEPLOY_OK=1 <command>"

exit 0
