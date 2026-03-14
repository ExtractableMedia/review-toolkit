# Local Review

## Change Set

The **change set** defines which changes the reviewers should analyze.

If the user provided additional context: `$ARGUMENTS`

- If `$ARGUMENTS` specifies a change set (e.g., a commit range, specific files,
  or a description of what to review), use that as the change set.
- Otherwise, the default change set is **the changes on this branch** (i.e., all
  commits on the current branch that are not on the base branch).

All reviewer instructions below refer to "the change set" — this always means
the change set determined above.

---

## Built-in Reviewers

These reviewers are always dispatched on every review.

### Code Best Practices

Instruct code-best-practices-reviewer to analyze the change set. This should
include:

- **Code organization** - Proper separation of concerns, single responsibility,
  appropriate abstraction levels
- **Naming and clarity** - Descriptive variable/method names, self-documenting
  code, clear intent
- **DRY violations** - Duplicated logic that should be extracted
- **Complexity** - Overly complex conditionals, deep nesting, methods that do
  too much
- **Error handling** - Appropriate exception handling, edge case coverage

### Security

Instruct security-reviewer to perform a security audit of the change set. This
should include:

- **Injection vulnerabilities** - SQL injection, XSS, command injection,
  unsafe interpolation
- **Authentication/authorization** - Proper access controls, session handling,
  permission checks
- **Data exposure** - Sensitive data in logs, responses, or error messages
- **Mass assignment** - Proper use of strong parameters, permitted attributes
- **CSRF/CORS** - Cross-site request forgery protection, appropriate CORS
  configuration

### Test Coverage

Instruct test-suite-architect to analyze the change set and provide
recommendations for test coverage. This should include:

- **Missing tests** - New code paths, edge cases, or functionality that lack
  test coverage
- **Tests to update** - Existing tests that may need modification due to
  changed behavior
- **Tests to remove** - Obsolete tests for removed functionality or redundant
  coverage
- **Test quality concerns** - Brittle tests, improper mocking, or tests that
  don't actually verify behavior

---

## Project-Specific Reviewers

If `.claude/review-config.md` exists in the project, read it for additional
reviewer configuration. It defines two sections:

**Always Run** — agents dispatched on every review in addition to the built-in
reviewers above.

**Conditional** — agents dispatched only when the change set includes files
matching the specified trigger patterns.

Dispatch each configured reviewer with the review focus areas listed under
their heading. These agents must be available in the project's
`.claude/agents/` directory or the user's `~/.claude/agents/`.

---

## Collation and Assembly

After all specialist reviewers have completed their analyses, forward their
individual review results to the **documentation-expert** agent for collation
and assembly into the final `local-review.md` document.

The documentation-expert is responsible for:

1. **Receiving all individual reviews** - Collect the full output from each
   specialist reviewer (built-in reviewers and any project-specific reviewers)
1. **Assigning finding numbers** - Apply a single global numbering scheme
   (F1, F2, F3, ...) across all reviewers in the order findings appear
1. **Assembling the document** - Combine all findings into a unified document
   following the Documentation Format conventions below
1. **Merging with existing findings** - If `local-review.md` already exists in
   the repository root, read it first and merge new findings with existing
   ones (see Merging with Existing Findings below)
1. **Building the consolidated summary** - Create the summary table and
   pre-merge checklist from all findings
1. **Writing the file** - Save the assembled document to `local-review.md` in
   the repository root

## Documentation Format

When documenting the local review, follow these conventions:

### Severity Indicators

Use emoji indicators for quick visual scanning of issue severity:

**Actionable findings** (require attention):

- 🔴 **Critical** - Must fix before merge (security vulnerabilities, data
  loss, breaking changes)
- 🟠 **High Priority** - Should fix before merge (bugs, missing tests,
  performance issues)
- 🟡 **Medium Priority** - Should address (code quality, accessibility,
  consistency)
- 🟢 **Low Priority / Nice-to-Have** - Can address later (minor improvements,
  future enhancements)

**Non-actionable findings** (no action required):

- ℹ️  **Observation** - Documents a good pattern, positive practice, or
  architectural note worth highlighting. These do **not** appear in the
  pre-merge checklist.

### Numbered Findings

**All findings must be numbered sequentially** for easy reference in discussions:

- Use a single global numbering scheme across all reviewers (e.g., F1, F2, F3)
- Number findings in the order they appear, starting with the first reviewer
- Reference findings by number in the consolidated summary table
- Use the format: `### F1 🟡 Medium Priority - Description`

**Important:** Use `F1`, `F2`, etc. instead of `#1`, `#2` to avoid GitHub
auto-linking finding numbers to unrelated issues/PRs.

Example:

```markdown
### F1 🟡 Medium Priority - Missing input validation

**File:** `app/controllers/users_controller.rb` (line 45)
...

### F2 🟢 Low Priority - Consider extracting method

**File:** `app/models/user.rb` (line 120)
...

### F3 ℹ️ Observation - Clean use of service objects

**File:** `app/services/payment_processor.rb`
...
```

### Actionable Feedback

- Include **code snippets with fixes** - don't just describe the problem, show
  the solution
- Reference specific file paths and line numbers
- Explain *why* something is an issue, not just *what* is wrong

### Consolidated Summary

At the end of the review, provide a **summarized list across all reviewers** with:

- **Finding number** (e.g., F1, F2) for cross-referencing
- Item description
- Priority level (Critical/High/Medium/Low)
- Category (Security, Performance, Code Quality, UI/UX, Testing, etc.)

Example table format:

```markdown
| Finding | Priority | Category | Description | File |
|---------|----------|----------|-------------|------|
| F1 | 🟡 Medium | Code Quality | Missing validation | `users_controller.rb` |
| F2 | 🟢 Low | Performance | Consider caching | `api_client.rb` |
| F3 | ℹ️ Observation | Code Quality | Clean service objects | `payment_processor.rb` |
```

### Pre-Merge Checklist

Convert **actionable findings only** (🔴🟠🟡🟢) into a concrete checklist.
Do **not** include Observation findings in the checklist. Do **not** include
generic "run tests" or "run linting" items.

```markdown
- [ ] Fix critical issue X
- [ ] Address high priority issue Y
```

### Positive Feedback

Use **Observation** findings to highlight what the PR does well — good
patterns, clean architecture, or thoughtful design decisions. These numbered
observations provide balance and reinforce good practices while remaining easy
to reference in discussions.

## Output Requirements

### Tracking Finding Status

When **actionable** findings have been addressed, mark them visually to show
progress while preserving the original content of each finding for reference.
Observation findings do not require status tracking.

**Status indicators:**

- ✅ **Fixed** - The issue has been resolved in code
- 🚫 **Ignored** - Explicitly decided not to address (include reason)
- ⏸️ **Deferred** - Will address in a future PR or later

**How to mark fixed findings:**

Apply strikethrough to the finding heading (excluding the finding number) and
add the status icon to the right. Do **not** delete the finding content —
preserve it for reference.

```markdown
### F1 ~~🟡 Medium Priority - Missing input validation~~ ✅ Fixed

**File:** `app/controllers/users_controller.rb` (line 45)
**Status:** Fixed in commit `abc123`
...original finding content preserved...
```

In the pre-merge checklist, **check the box** for fixed findings and include
a brief explanation:

```markdown
- [x] F1 - Fix input validation (fixed) ✅
```

**How to mark ignored, skipped, or deferred findings:**

Apply strikethrough to the finding heading (excluding the finding number) and
add the appropriate status icon to the right. Do **not** delete the finding
content — preserve it for reference.

```markdown
### F2 ~~🟢 Low Priority - Consider extracting method~~ 🚫

**File:** `app/models/user.rb` (line 120)
**Status:** Ignored — complexity not warranted for a single call site
...original finding content preserved...
```

In the consolidated summary table, add a Status column:

```markdown
| Finding | Priority | Category | Description | File | Status |
|---------|----------|----------|-------------|------|--------|
| F1 | 🟡 Medium | Code Quality | Missing validation | `users_controller.rb` | ✅ |
| F2 | 🟢 Low | Code Quality | Extract method | `user.rb` | 🚫 |
| F3 | ℹ️ Observation | Code Quality | Clean service objects | `payment_processor.rb` | — |
```

### File Output

Save the complete review findings to `local-review.md` in the repository root.
The **documentation-expert** agent is responsible for creating and updating
this file.

- **Create** the file if it doesn't exist
- **Merge** with existing findings if the file already exists (see below)
- Include all sections: individual reviewer findings, consolidated summary,
  pre-merge checklist, and positive feedback

### Merging with Existing Findings

When `local-review.md` already exists, the **documentation-expert** must:

1. **Read the existing file first** to understand current findings and their
   status
1. **Preserve existing finding numbers** — don't renumber resolved findings
1. **Preserve status markers** — keep Fixed, Ignored, Deferred markers
   and their associated content intact
1. **Add new findings** with the next sequential number (e.g., if F1–F4 exist,
   new findings start at F5)
1. **Update findings** if re-review shows they're now resolved or still present
1. **Strike through findings** that are no longer applicable (e.g., the code
   they referenced has been deleted or completely rewritten) — do **not**
   remove them; apply strikethrough and add a brief explanation of why
1. **Update the review date** at the top of the document

### Session Output

After saving the file, output the **complete review findings** in the Claude
session. This should include:

1. **All individual reviewer findings** - Full details from each specialist
   reviewer
1. **Consolidated summary table** - All issues with priority and category
1. **Pre-merge checklist** - Actionable items organized by priority
1. **Positive feedback** - What the PR does well

The session output should mirror the content saved to `local-review.md` so the
developer can review findings directly in the terminal without opening the file.

**Important:** Use the same finding numbers (F1, F2, etc.) in both the file and
session output. This enables easy reference like "let's fix F3 first" or
"commit message: addresses local review F1 and F2".

### PR Comment Format

When posting review findings as a PR comment (e.g., when explicitly asked), use
the collapsible `<details><summary>` format. Build a temporary file with a
collapsible `<details><summary>` wrapper and post it with `--body-file` to
avoid heredoc quoting issues.

The comment should have this structure:

- **Heading**: `## Local Review — [status summary]`
- **Stats line**: `**[N findings — X actionable, Y observations]**`
- **Body**: Full review content inside a `<details>` block

### Interactive Finding Selection

After displaying all review output, present the list of **actionable findings
only** (🔴🟠🟡🟢 — not Observations), formatted as:

```text
F1 🔴 Critical - Description (file.rb)
F3 🟡 Medium - Description (file.rb)
F5 🟢 Low - Description (file.rb)
```

Ask the user which findings to fix. Accept finding numbers (e.g., "F1, F3"),
"all", or "skip". If the user selects one or more findings, begin fixing them
in order.
