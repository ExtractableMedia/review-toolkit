#!/bin/bash
#
# Example ElicitationResult hook: Log all triage decisions
#
# This hook intercepts user responses to triage elicitations and
# appends each decision to a log file for auditing/tracking.
#
# Installation:
# Add to your .claude/settings.json (project or user level):
#
#   "hooks": {
#     "ElicitationResult": [
#       {
#         "matcher": "review-toolkit",
#         "hooks": [
#           {
#             "type": "command",
#             "command": "/path/to/log-triage-decisions.sh"
#           }
#         ]
#       }
#     ]
#   }
#
# Output:
# Appends timestamped decisions to ~/.claude/triage-log.jsonl
#

LOG_FILE="${HOME}/.claude/triage-log.jsonl"

# Read the elicitation result from stdin
input=$(cat)

# Extract relevant fields
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
action=$(echo "$input" | jq -r '.content.action // "unknown"')

# Build log entry
log_entry=$(jq -n \
  --arg ts "$timestamp" \
  --arg sid "$session_id" \
  --arg act "$action" \
  --argjson raw "$input" \
  '{timestamp: $ts, session_id: $sid, action: $act, raw: $raw}')

# Append to log file
echo "$log_entry" >> "$LOG_FILE"

# Always exit 0 — we're just observing, not modifying
exit 0
