# Local Review

## Change Set

The **change set** defines which changes the reviewers should analyze.

If the user provided additional context: `$ARGUMENTS`

- If `$ARGUMENTS` specifies a change set (e.g., a commit range, specific files, or a description of
  what to review), use that as the change set.
- Otherwise, the default change set is **the changes on this branch** (i.e., all commits on the
  current branch that are not on the base branch).

All reviewer instructions below refer to "the change set" — this always means the change set
determined above.

---

## Built-in Reviewers

These reviewers are always dispatched on every review.

### Code Best Practices

Instruct code-best-practices-reviewer to analyze the change set. This should include:

- **Code organization** - Proper separation of concerns, single responsibility, appropriate
  abstraction levels
- **Naming and clarity** - Descriptive variable/method names, self-documenting code, clear intent
- **DRY violations** - Duplicated logic that should be extracted
- **Complexity** - Overly complex conditionals, deep nesting, methods that do too much
- **Error handling** - Appropriate exception handling, edge case coverage

### Security

Instruct security-reviewer to perform a security audit of the change set. This should include:

- **Injection vulnerabilities** - SQL injection, XSS, command injection, unsafe interpolation
- **Authentication/authorization** - Proper access controls, session handling, permission checks
- **Data exposure** - Sensitive data in logs, responses, or error messages
- **Mass assignment** - Proper use of strong parameters, permitted attributes
- **CSRF/CORS** - Cross-site request forgery protection, appropriate CORS configuration

### Test Coverage

Instruct test-suite-architect to analyze the change set and provide recommendations for test
coverage. This should include:

- **Missing tests** - New code paths, edge cases, or functionality that lack test coverage
- **Tests to update** - Existing tests that may need modification due to changed behavior
- **Tests to remove** - Obsolete tests for removed functionality or redundant coverage
- **Test quality concerns** - Brittle tests, improper mocking, or tests that don't actually verify
  behavior

---

## Project-Specific Reviewers

If `.claude/review-config.md` exists in the project, read it for additional reviewer configuration.
It defines two sections:

**Always Run** — agents dispatched on every review in addition to the built-in reviewers above.

**Conditional** — agents dispatched only when the change set includes files matching the specified
trigger patterns.

Dispatch each configured reviewer with the review focus areas listed under their heading. These
agents must be available in the project's `.claude/agents/` directory or the user's
`~/.claude/agents/`.

---

## Collation and Assembly

After all specialist reviewers have completed their analyses, forward their individual review
results to the **documentation-expert** agent for collation and assembly into the final
`local-review.md` document.

The documentation-expert is responsible for:

1. **Receiving all individual reviews** - Collect the full output from each specialist reviewer
   (built-in reviewers and any project-specific reviewers)
1. **Assigning finding numbers** - Apply a single global numbering scheme (F1, F2, F3, ...) across
   all reviewers in the order findings appear
1. **Assembling the document** - Combine all findings into a unified document following the finding
   format referenced below
1. **Merging with existing findings** - If `local-review.md` already exists in the repository root,
   read it first and merge new findings with existing ones, following the re-review rules in the
   finding format
1. **Building the consolidated summary** - Create the summary table and pre-merge checklist from all
   findings
1. **Writing the file** - Save the assembled document to `local-review.md` in the repository root

## Documentation Format

Follow `${CLAUDE_PLUGIN_ROOT}/reference/finding-format.md`. It defines the severity scale, the
heading and body format, numbering, status markers, the consolidated summary table, the checklist,
the merge rules for a re-review, and the pull request comment format. Read it rather than relying on
memory — it is the authoritative copy, and `/doc-review` and `/triage` follow the same rules.

Two conventions are specific to this command:

- Number findings in the order they appear, starting with the first reviewer, so the sequence runs
  across every reviewer rather than restarting per section.
- Use **Observation** findings to record what the change does well. They provide balance and stay
  easy to cite in discussion.

## Output Requirements

### File Output

Save the complete review findings to `local-review.md` in the repository root. The
**documentation-expert** agent is responsible for creating and updating this file.

- **Create** the file if it doesn't exist
- **Merge** with existing findings if the file already exists, per the re-review rules in the
  finding format
- Include all sections: individual reviewer findings, consolidated summary, pre-merge checklist, and
  positive feedback

### Session Output

After saving the file, output the **complete review findings** in the Claude session. This should
include:

1. **All individual reviewer findings** - Full details from each specialist reviewer
1. **Consolidated summary table** - All issues with priority and category
1. **Pre-merge checklist** - Actionable items organized by priority
1. **Positive feedback** - What the PR does well

The session output should mirror the content saved to `local-review.md` so the developer can review
findings directly in the terminal without opening the file.

**Important:** Use the same finding numbers (F1, F2, etc.) in both the file and session output. This
enables easy reference like "let's fix F3 first" or "commit message: addresses local review F1 and
F2".

### Interactive Finding Selection

After displaying all review output, present the list of **actionable findings only** (🔴🟠🟡🟢 — not
Observations), formatted as:

```text
F1 🔴 Critical - Description (file.rb)
F3 🟡 Medium - Description (file.rb)
F5 🟢 Low - Description (file.rb)
```

Ask the user which findings to fix. Accept finding numbers (e.g., "F1, F3"), "all", or "skip". If
the user selects one or more findings, begin fixing them in order.
