# mcp-review-triage

An [MCP](https://modelcontextprotocol.io/) server that provides interactive
triage of code review findings using
[MCP elicitation](https://modelcontextprotocol.io/specification/2025-11-25/client/elicitation).

Instead of reviewing all findings at once and typing "fix F1, F3, ignore F7",
this server presents each finding one at a time with a structured action menu —
similar to `git add --patch` for code reviews.

**Partially addresses:**
[anthropics/claude-code#32724](https://github.com/anthropics/claude-code/issues/32724)
(Interactive review loops for slash commands)

## Requirements

- **Claude Code v2.1.76+** (for MCP elicitation support)
- **Node.js 20+**

## Install

```bash
# Clone and build
git clone https://github.com/cirm-github/mcp-review-triage.git
cd mcp-review-triage
npm install
npm run build

# Register with Claude Code (user-scoped, available in all projects)
claude mcp add --scope user mcp-review-triage -- node /path/to/mcp-review-triage/dist/index.js
```

## Usage

### With the `/triage` slash command

Copy `examples/triage.md` to `~/.claude/commands/triage.md`, then:

```
/triage local-review.md
/triage my-doc-DOC-REVIEW.md
```

### Direct tool call

The server exposes a single tool: `triage_findings`

**Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `file_path` | string | (required) | Absolute path to the review file |
| `severity_filter` | string[] | all | Filter: `critical`, `high`, `medium`, `low` |
| `update_file` | boolean | `true` | Update file with status markers |

### Interaction flow

For each unresolved finding, you'll see an elicitation dialog:

```
── Finding 1 of 5 ──────────────────────────
F1 🔴 Critical — SQL injection in search controller

**File:** `app/controllers/search_controller.rb` (line 23)
**Issue:** User input is interpolated directly into a SQL query...

Action: [Fix | Fix with guidance | Accept | Defer | Ignore | Skip]
```

**Actions:**
- **Fix** → Claude resolves the finding after triage completes
- **Fix with guidance** → Opens a second dialog for instructions, then Claude
  resolves with that context
- **Accept** → Marks as acceptable in the review file (✅)
- **Defer** → Marks as deferred (⏸️)
- **Ignore** → Marks as ignored (🚫)
- **Skip** → Moves to next finding without recording a decision

## Compatible review formats

The server parses the heading format produced by common Claude Code review
commands:

```markdown
### F1 🟡 Medium Priority - Finding title

**File:** `path/to/file.rb` (line 42)
**Issue:** Description of the problem
**Suggestion:** How to fix it
```

Already-resolved findings (with `~~strikethrough~~` and status icons) are
automatically skipped.

## Hooks (v2.1.76+)

Claude Code's `Elicitation` and `ElicitationResult` hooks can customize triage
behavior. See `examples/hooks/` for:

### Auto-skip low-priority findings

`examples/hooks/auto-skip-low-priority.sh` — Automatically skips 🟢 Low
Priority findings so you only see Critical/High/Medium in the interactive
triage.

### Log triage decisions

`examples/hooks/log-triage-decisions.sh` — Appends every triage decision to
`~/.claude/triage-log.jsonl` for auditing.

### Configuration

Add hooks to your `.claude/settings.json`:

```json
{
  "hooks": {
    "Elicitation": [
      {
        "matcher": "mcp-review-triage",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/auto-skip-low-priority.sh"
          }
        ]
      }
    ]
  }
}
```

## How it works

```
/local-review  →  produces local-review.md
                       ↓
/triage  →  calls MCP tool "triage_findings"
                       ↓
              MCP server reads file, loops:
                ┌─ elicitation/create (finding + action menu)
                │     ↓  Elicitation hook (auto-skip?)
                │  user picks action
                │     ↓  ElicitationResult hook (log?)
                │  if "fix with guidance" → 2nd elicitation
                │  update file markers
                └─ repeat
                       ↓
              returns structured triage results
                       ↓
              Claude fixes findings marked "fix"
```

## Limitations

This is a partial solution for
[#32724](https://github.com/anthropics/claude-code/issues/32724). What's **not**
covered:

- **Frontmatter-driven configuration** — The issue proposes declarative
  `review:` blocks in slash command frontmatter. This requires Claude Code core
  changes.
- **In-loop agent dispatch** — Fix agents run _after_ the triage loop
  completes, not during each item.
- **Native slash command integration** — Requires manually calling `/triage`
  after a review command finishes.

## License

MIT
