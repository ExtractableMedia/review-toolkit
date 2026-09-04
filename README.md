# review-toolkit

A [Claude Code plugin](https://code.claude.com/docs/en/plugins) for multi-agent code and document
review, with durable findings and interactive triage.

**Includes:**

- `/local-review` — multi-agent code review of your branch changes
- `/doc-review` — document quality review
- `/triage` — batch through findings and decide each one (`git add --patch` for code reviews)
- 4 bundled reviewer agents (code quality, security, testing, documentation)

Pure markdown. No build step, no runtime dependencies, no MCP server.

## Requirements

Claude Code v2.1.145 or later — the first release that invokes a plugin skill as a slash
command. CI validates against that floor and against the latest release, so the claim is
exercised rather than asserted.

## Install

```bash
claude plugin marketplace add ExtractableMedia/review-toolkit
claude plugin install review-toolkit@extractable-media
```

Or from inside a session:

- `/plugin marketplace add ExtractableMedia/review-toolkit`
- `/plugin install review-toolkit@extractable-media`

### Try it without installing

```bash
git clone https://github.com/ExtractableMedia/review-toolkit.git
claude --plugin-dir ./review-toolkit
```

## What this is for

Claude Code already ships strong general review: `/code-review` finds correctness bugs in your diff,
`/security-review` checks it for vulnerabilities. Use those.

This plugin covers what they don't:

- **A durable artifact.** Findings land in a Markdown file in your repo, so they survive the
  session, get committed alongside the branch, and can be posted to the PR. Built-in review renders
  into the transcript and is gone when the session is.
- **Your reviewers.** Register project-specific specialists — a Rails expert, a Postgres migration
  reviewer, a domain expert — and dispatch them conditionally based on which files changed.
- **Triage as a step.** Findings get an explicit disposition, recorded in the file, before anything
  gets fixed. `Ignore` with a reason is a first-class outcome, not a finding you scrolled past.

## Commands

### `/local-review`

Dispatches reviewer agents in parallel against your branch changes, then writes numbered findings to
`local-review.md` in the repository root.

```text
/local-review
/local-review HEAD~3..HEAD
/local-review app/controllers/
```

The base branch is the first of the remote HEAD's target, `main`, `master`, `develop`, or `trunk`
that resolves to a ref this clone actually has. The remote-tracking ref wins over the local branch,
so the base is usually reported as `origin/main` rather than `main` — a local branch left unpulled
would otherwise drag already-merged upstream commits into the review. The remote is whichever one is
named `origin`, or the first configured if there is none, so a `--origin upstream` clone works too.
Uncommitted changes are included.

If the remote names a default branch that this clone has no ref for — routine in single-branch and
shallow clones — the base is reported as unresolved and `/local-review` stops and asks rather than
reviewing an empty diff.

**Bundled reviewers** — always dispatched:

| Agent | Focus |
|-------|-------|
| `code-best-practices-reviewer` | Separation of concerns, naming, DRY, complexity, error handling |
| `security-reviewer` | OWASP Top 10, injection, authn/authz, data exposure, dependencies |
| `test-suite-architect` | Coverage gaps, tests needing updates, brittle assertions |

**Project reviewers** come from `.claude/review-config.md` — see
[Project configuration](#project-configuration).

Two flags change what is reviewed:

```text
/local-review --plan
/local-review --reconcile
```

`--plan` reviews an implementation plan instead of a diff — `PLAN.md` if it exists, otherwise the
newest plan in `~/.claude/plans/` for this project. The same reviewers run, chosen by the paths the
plan says it will touch, and each reads the files the plan references so it can catch assumptions
the code doesn't support.

`--reconcile` re-reads `local-review.md`, checks whether each open finding has since been fixed, and
marks the ones that have. No reviewer runs and no finding is added, removed, or re-judged.

Every run appends a **Review History** entry recording the date and the model each reviewer actually
resolved to, so a review's weight can be judged later. Model aliases like `opus` drift as new models
ship and can resolve downward under load, which makes the alias useless as a record.

### `/doc-review`

Reviews a document for formatting, consistency, accuracy, clarity, leaked secrets, spelling, and
staleness. Writes a `*-DOC-REVIEW.md` file using the same finding format.

```text
/doc-review README.md
/doc-review docs/architecture.md
```

### `/triage`

Walks the unresolved findings in a review file, four at a time, recording a decision for each — then
fixes the ones you marked `Fix`.

```text
/triage
/triage local-review.md
/triage --severity critical,high
```

Each finding gets four options: **Fix**, **Accept**, **Defer**, **Ignore**. The free-text row takes
anything else — type `fix but use a lookup table` to add a constraint, or `skip` to leave it
undecided.

Decisions are written to the file **after every batch**, so an interrupted triage keeps everything
you already decided.

## Finding format

```markdown
### F1 🟡 Medium Priority - Missing input validation

**File:** `app/controllers/users_controller.rb` (line 45)
**Issue:** The `update` action accepts arbitrary parameters without validation.
**Suggestion:** Add strong parameters and validate expected input types.
**Recommendation:** Implement — unvalidated input reaches a database write.
```

| Severity | Meaning |
|----------|---------|
| 🔴 Critical | Must fix |
| 🟠 High Priority | Should fix before merge |
| 🟡 Medium Priority | Should address |
| 🟢 Low Priority | Can address later |
| ℹ️ Observation | Positive note, no action needed |

Resolved findings are struck through and marked, never deleted:

```markdown
### F1 ~~🟡 Medium Priority - Missing input validation~~ ✅ Fixed
### F2 ~~🟢 Low Priority - Consider extracting method~~ 🚫 Ignored
### F3 ~~🟠 High Priority - Missing CSRF check~~ ⏸️ Deferred
```

Every actionable finding starts at **❓ Open** and stays there until someone rules on it.
**Recommendation** is what the reviewer advised — Implement, Defer, or Skip; **Status** is what was
decided. A review never sets the second from the first: a Skip recommendation nobody has accepted
reads `Skip | ❓`, not `Skip | 🚫`. Only `/triage` writes ⏸️ and 🚫, because only you can decide them.
`✅ Fixed` is the exception — it states a fact about the code, so `--reconcile` can apply it without
asking.

The full specification — numbering, status markers, summary table, checklist, and the rules for
merging a re-review into an existing file — lives in
[`reference/finding-format.md`](reference/finding-format.md). All three commands read it, so it is
the one place to change the format.

See [`examples/sample-review.md`](examples/sample-review.md) for a complete review file.

## Project configuration

Create `.claude/review-config.md` in your project to add specialists beyond the bundled three.

```markdown
## Always Run

### ruby-on-rails-expert
- Rails conventions, Active Record patterns, controller design
- Efficient queries, scopes, avoiding N+1 queries

## Conditional

### postgresql-expert
**Trigger:** `db/migrate/**`, `db/schema.rb`
- Migration safety, index strategy, data type choices
```

**Always Run** reviewers are dispatched every time. **Conditional** reviewers are dispatched only
when the change set touches a file matching one of their trigger globs, so a CSS-only branch doesn't
wake the database reviewer.

Each named agent must exist in `~/.claude/agents/`, and is dispatched from there. The config routes
— it names which reviewer runs — but it never supplies that reviewer's instructions, because the
config ships inside the repository being reviewed and the change set can modify it. An agent that
exists only in the repository's own `.claude/agents/` is named in the review for you to approve
rather than dispatched, and a missing one is reported rather than aborting the run.

Two further sections, both optional, are passed verbatim to every reviewer — the bundled three
included:

````markdown
## Review Context

- We're migrating off Sidekiq onto Solid Queue. Flag new `perform_async` calls
  as 🟡 Medium — they aren't broken, but they're new debt.

## Verifying Changes

Reviewers run in parallel against one checkout, so namespace the test database:

```bash
SUFFIX=${PWD##*/}; SUFFIX=${SUFFIX//[^[:alnum:]]/_}
export TEST_DATABASE="myapp_test_${SUFFIX}"
bin/rails db:test:prepare
```
````

**Review Context** is prose a reviewer can't infer from the code — a migration in flight, an idiom
that would otherwise read as a mistake. **Verifying Changes** is how to run things here, for a
reviewer that wants to check a claim rather than reason about it. Both exist because subagents start
with an empty context and never see your config file.

Keep reviewer entries thin. Deep domain knowledge belongs in the agent's own definition in
`.claude/agents/`, where every session can use it; this file adds routing — which agent, and when.

See [`examples/review-config.md`](examples/review-config.md) for a fuller example.

## Reviewer agents

Reviewers report; they don't fix. Fixes happen in `/triage`, after you have approved them. All
four bundled agents declare `tools: Read, Grep, Glob, Bash`, so none has an `Edit` or `Write`
tool.

| Agent | Purpose |
|-------|---------|
| `code-best-practices-reviewer` | SOLID, DRY, naming, complexity, error handling |
| `security-reviewer` | OWASP Top 10, injection, authn/authz, secrets, dependencies |
| `test-suite-architect` | Coverage analysis, test quality, test strategy |
| `documentation-expert` | Document review: accuracy, consistency, clarity, staleness |

They're generic by design. Framework-specific reviewers belong in your project via
`review-config.md`.

To route a reviewer to a particular model, add `model:` to its frontmatter in your own copy — for
example `model: haiku` on the test reviewer to cut cost, or `model: opus` on security to raise
depth. Without it, reviewers inherit the session model.

## Auditing triage decisions

`/triage` collects decisions with the built-in `AskUserQuestion` tool, so a `PostToolUse` hook can
log every one. [`examples/hooks/log-triage-decisions.sh`](examples/hooks/log-triage-decisions.sh)
appends them to `~/.claude/triage-log.jsonl`; the settings entry to wire it up is in
[`examples/hooks/settings-snippet.json`](examples/hooks/settings-snippet.json).

To skip low-severity findings, you don't need a hook — pass `/triage --severity critical,high`.

## How it works

```text
/local-review
    ├── detects base branch, resolves the change set
    ├── dispatches reviewers in parallel ──┬── code-best-practices-reviewer
    │                                      ├── security-reviewer
    │                                      ├── test-suite-architect
    │                                      └── project reviewers (conditional)
    └── numbers findings F1..Fn, writes/merges local-review.md

/triage
    ├── reads the file, drops resolved findings and observations
    ├── asks up to 4 findings per prompt (Fix / Accept / Defer / Ignore)
    ├── writes status markers after every batch
    └── fixes the Fix findings, marking each ✅ as it lands
```

## Development

There is no build. Edit the markdown and reload.

```bash
claude --plugin-dir .                  # run against your working copy
claude plugin validate .               # validate the marketplace manifest
```

To validate the plugin manifest and component frontmatter, validate a copy without
`marketplace.json` present — `claude plugin validate` checks whichever manifest it finds first. The
CI workflow in [`.github/workflows/validate.yml`](.github/workflows/validate.yml) does both.

## License

MIT
