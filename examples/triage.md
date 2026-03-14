# Triage Review Findings

Interactively triage the findings in a review file, presenting each finding
one at a time with an action menu.

## Input

**File:** `$ARGUMENTS`

If `$ARGUMENTS` is empty, look for a review file in the current project root:
1. `local-review.md` (from `/local-review`)
2. Any `*-DOC-REVIEW.md` file (from `/doc-review`)

If multiple review files exist and no argument was given, ask the user which
file to triage.

## Triage Process

Call the `mcp__mcp-review-triage__triage_findings` MCP tool with the resolved
file path. This will present each unresolved finding via an interactive
elicitation dialog where the user can choose:

- **Fix** — mark for agent-driven resolution
- **Fix with guidance** — mark for resolution with user-provided context
- **Accept** — mark as acceptable (no fix needed)
- **Defer** — address later
- **Ignore** — won't fix
- **Skip** — decide later

The tool automatically updates the review file with status markers for
accept/defer/ignore actions.

## Post-Triage

After the triage tool returns:

1. **Report results** — Show a summary of all decisions made
2. **Fix findings** — For any findings marked "Fix" or "Fix with guidance",
   fix them in order:
   - Read the full finding from the review file for context
   - Make the code changes to resolve the finding
   - If guidance was provided, follow that guidance
   - After fixing, update the review file to mark the finding as ✅ Fixed
3. **Skip if none to fix** — If no findings were marked for fixing, just
   report the triage summary and note that the review file has been updated
