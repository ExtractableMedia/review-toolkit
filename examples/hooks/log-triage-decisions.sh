#!/bin/bash
#
# Example PostToolUse hook: audit every triage decision
#
# /triage asks for decisions with the built-in AskUserQuestion tool, so a PostToolUse hook matched
# on that tool sees every question that was asked and every answer that came back. Each invocation
# is appended to a JSONL log.
#
# Installation: copy the hook entry from settings-snippet.json, in this directory, into
# .claude/settings.json (project or user level) and point its "command" at your copy of this script.
# Kept in one place deliberately — the two copies of this snippet had already disagreed about the
# command path.
#
# Note this fires for *every* AskUserQuestion, not only triage. The filter below keeps entries whose
# question text mentions a finding ID (F1, F2, ...); widen or drop it if you want to audit all
# questions.
#
# Output: ~/.claude/triage-log.jsonl
#
# What it retains: /triage puts the finding's location, issue, suggested fix, and any code snippet
# into the question text, and this log stores that verbatim alongside the working directory. The
# result is a durable record of source excerpts and security findings from every repository you
# triage, so it is created 0600 and its directory 0700. Point LOG_FILE at an encrypted volume if
# that retention is more than you want on a shared host.
#
# Requires: jq. If it is missing the hook says so on stderr and exits 0, rather than silently
# logging nothing.
#
# Concurrency: appends are serialized with flock where it exists. On systems without it (macOS ships
# none) two sessions triaging at the same instant can interleave a write, since a payload carrying a
# code snippet exceeds the 4 KiB PIPE_BUF that would otherwise make the append atomic.

set -euo pipefail

# Check the one dependency up front. Without this the jq calls below fail with exit 127, which is
# indistinguishable from "this question wasn't a triage decision" and leaves an audit log that is
# empty rather than obviously broken.
if ! command -v jq >/dev/null 2>&1; then
  echo "log-triage-decisions.sh: jq not found; triage decisions are not being logged" >&2
  exit 0
fi

# HOME is unset in cron-style and container environments, and expanding it under `set -u` aborts the
# script with exit 1 — which a PostToolUse hook surfaces to the user mid-triage, breaking the
# promise at the bottom of this file.
if [ -z "${HOME:-}" ]; then
  echo "log-triage-decisions.sh: HOME is unset; nowhere to write the triage log" >&2
  exit 0
fi

LOG_FILE="${HOME}/.claude/triage-log.jsonl"

# Create the directory and the file before anything writes to them, so the log never exists at the
# default 0644 even briefly. Every branch here reports and exits 0: this is an audit control, and a
# silent failure leaves an empty log that cannot be told apart from "no triage happened".
umask 077
mkdir -p "$(dirname "$LOG_FILE")" \
  || { echo "triage log directory unavailable: $(dirname "$LOG_FILE")" >&2; exit 0; }
if [ ! -e "$LOG_FILE" ]; then
  : > "$LOG_FILE" 2>/dev/null \
    || { echo "triage log not writable: $LOG_FILE" >&2; exit 0; }
fi
chmod 600 "$LOG_FILE" 2>/dev/null || true

input=$(cat)

# One jq pass does both jobs: `select` keeps only decisions that look like review findings (question
# text mentioning F1, F2, ...) and emits nothing otherwise, so a non-match produces no entry and
# still exits 0. Filtering in a separate earlier invocation meant two parses of the same payload
# that could diverge, and it hid real jq errors behind the same exit path as a non-match.
entry=$(printf '%s' "$input" | jq -c \
  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  'select([(.tool_input.questions[]? | .header, .question)] | join(" ") | test("\\bF[0-9]+\\b"))
   | {
       timestamp: $ts,
       session_id: .session_id,
       cwd: .cwd,
       questions: .tool_input.questions,
       answers: .tool_response
     }') || { echo "triage log filter failed" >&2; exit 0; }

# Not a triage decision, so there is nothing to record.
[ -n "$entry" ] || exit 0

if command -v flock >/dev/null 2>&1; then
  printf '%s\n' "$entry" | flock "$LOG_FILE" tee -a "$LOG_FILE" > /dev/null \
    || { echo "triage log write failed" >&2; exit 0; }
else
  printf '%s\n' "$entry" >> "$LOG_FILE" \
    || { echo "triage log write failed" >&2; exit 0; }
fi

# Always succeed — this hook observes, it never blocks.
exit 0
