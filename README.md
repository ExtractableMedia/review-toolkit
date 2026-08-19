# review-toolkit

A [Claude Code plugin](https://docs.anthropic.com/en/docs/claude-code/plugins) that provides
structured code review commands and interactive triage using [MCP
elicitation](https://modelcontextprotocol.io/specification/2025-11-25/client/elicitation).

**Includes:**

- `/local-review` — multi-agent code review with configurable reviewers
- `/doc-review` — document quality review
- `/triage` — interactive finding triage (`git add --patch` for code reviews)
- 4 bundled reviewer agents (code quality, security, testing, documentation)

## Requirements

- **Claude Code v2.1.76+** (for MCP elicitation support)
- **Node.js 20+**

## Install

```bash
claude plugin install ExtractableMedia/review-toolkit
```

### Manual install (development)

```bash
git clone https://github.com/ExtractableMedia/review-toolkit.git
cd review-toolkit
npm install
npm run build

# Test locally without installing
claude --plugin-dir /path/to/review-toolkit
```

## Commands

### `/local-review`

Dispatches multiple reviewer agents in parallel to analyze your branch changes, then collates
findings into a single `local-review.md` with numbered findings, severity indicators, and a
pre-merge checklist.

```text
/local-review
/local-review HEAD~3..HEAD
/local-review app/controllers/
```

**Built-in reviewers** (always dispatched):

| Agent | Focus |
|-------|-------|
| `code-best-practices-reviewer` | Code quality, SOLID, DRY, naming, complexity |
| `security-reviewer` | OWASP Top 10, injection, auth, data exposure |
| `test-suite-architect` | Test coverage gaps, test quality, strategy |
| `documentation-expert` | Collates all findings into the review document |

**Project-specific reviewers** are configured via `.claude/review-config.md` (see
[Configuration](#project-configuration) below).

### `/doc-review`

Reviews a document for formatting, consistency, accuracy, clarity, sensitive information,
spelling/grammar, and staleness.

```text
/doc-review README.md
/doc-review docs/architecture.md
```

Outputs a `*-DOC-REVIEW.md` file with numbered findings using the same format as `/local-review`.

### `/triage`

Interactively triage findings from a review file, presenting each finding one at a time with an
action menu via MCP elicitation.

```text
/triage
/triage local-review.md
/triage my-doc-DOC-REVIEW.md
```

**Actions per finding:**

- **Fix** — dispatch agent to resolve after triage
- **Fix with guidance** — add context for the fixing agent
- **Accept** — mark as acceptable (no fix needed)
- **Defer** — address later
- **Ignore** — won't fix
- **Skip** — decide later

The tool updates the review file in place with status markers for accept/defer/ignore decisions.

## Bundled Agents

The plugin ships 4 generic reviewer agents that work across any codebase:

| Agent | Purpose |
|-------|---------|
| `code-best-practices-reviewer` | Code organization, SOLID, DRY, naming, error handling |
| `security-reviewer` | OWASP Top 10, injection, auth, data exposure, dependencies |
| `test-suite-architect` | Test creation, coverage analysis, test strategy, refactoring |
| `documentation-expert` | Review collation, document formatting, merge logic |

Framework-specific agents (Rails, PostgreSQL, etc.) are **not bundled** — add them to your project
via `.claude/review-config.md`.

## Project Configuration

Create `.claude/review-config.md` in your project to add specialized reviewers beyond the 4 built-in
ones. The config supports two sections:

### Always Run

Agents dispatched on every review:

```markdown
## Always Run

### ruby-on-rails-expert
- Rails conventions, Active Record patterns, controller design
- Model responsibilities, performance considerations
```

### Conditional

Agents dispatched only when the change set includes files matching trigger patterns:

```markdown
## Conditional

### ui-ux-design-specialist
**Trigger:** `app/views/**`, `app/assets/stylesheets/**`,
`app/javascript/**`, `spec/system/**`
- Visual consistency, accessibility, responsive design
- User feedback, interaction patterns

### postgresql-expert
**Trigger:** `db/migrate/**`, `db/schema.rb`
- Migration safety, index strategy, data type choices
```

Configured agents must be available in the project's `.claude/agents/` directory or the user's
`~/.claude/agents/`.

See `examples/review-config.md` for a complete example.

## Finding Format

All review commands use the same output format:

```markdown
### F1 🟡 Medium Priority - Missing input validation

**File:** `app/controllers/users_controller.rb` (line 45)
**Issue:** Description of the problem
**Suggestion:** How to fix it
```

**Severity indicators:**

- 🔴 Critical — must fix
- 🟠 High Priority — should fix before merge
- 🟡 Medium Priority — should address
- 🟢 Low Priority — can address later
- ℹ️ Observation — positive note, no action needed

**Status markers** (applied when findings are resolved):

- `~~heading~~ ✅ Fixed`
- `~~heading~~ 🚫 Ignored`
- `~~heading~~ ⏸️ Deferred`

## Hooks

Claude Code's `Elicitation` and `ElicitationResult` hooks can customize triage behavior. See
`examples/hooks/` for:

### Auto-skip low-priority findings

`examples/hooks/auto-skip-low-priority.sh` — automatically skips 🟢 Low Priority findings so you only
see Critical/High/Medium in the interactive triage.

### Log triage decisions

`examples/hooks/log-triage-decisions.sh` — appends every triage decision to
`~/.claude/triage-log.jsonl` for auditing.

### Configuration

Add hooks to your `.claude/settings.json`:

```json
{
  "hooks": {
    "Elicitation": [
      {
        "matcher": "review-toolkit",
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

## How It Works

```text
/local-review  →  dispatches reviewer agents in parallel
                       ↓
               documentation-expert collates findings
                       ↓
               writes local-review.md
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

## Development

```bash
npm install
npm run build
```

## License

MIT
