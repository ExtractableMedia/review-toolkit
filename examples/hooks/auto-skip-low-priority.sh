#!/bin/bash
#
# Example Elicitation hook: Auto-skip low-priority findings
#
# This hook intercepts MCP elicitation requests from the triage server
# and automatically selects "skip" for low-priority (🟢) findings,
# so you only see Critical/High/Medium findings in the interactive triage.
#
# Installation:
# Add to your .claude/settings.json (project or user level):
#
#   "hooks": {
#     "Elicitation": [
#       {
#         "matcher": "review-toolkit",
#         "hooks": [
#           {
#             "type": "command",
#             "command": "/path/to/auto-skip-low-priority.sh"
#           }
#         ]
#       }
#     ]
#   }
#
# How it works:
# - The hook receives the elicitation request as JSON on stdin
# - If the message contains "🟢" (low priority), it outputs a JSON
#   response that auto-selects "skip", bypassing the dialog
# - For all other findings, it exits 0 with no output (passthrough)
#

# Read the elicitation request from stdin
input=$(cat)

# Check if this is from the triage server and contains a low-priority finding
message=$(echo "$input" | jq -r '.message // empty')

if echo "$message" | grep -q '🟢'; then
  # Auto-respond with "skip" action — this bypasses the UI dialog
  echo '{"action": "accept", "content": {"action": "skip"}}'
  exit 0
fi

# For all other findings, pass through to normal dialog
exit 0
