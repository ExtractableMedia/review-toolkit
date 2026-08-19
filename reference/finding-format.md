# Finding Format

The single source of truth for how review-toolkit findings are written, numbered, tracked, and
merged. `/local-review`, `/doc-review`, and `/triage` all read this file — keep it authoritative and
don't restate its rules elsewhere.

## Severity scale

**Actionable** — require attention:

| Icon | Label | Meaning |
|------|-------|---------|
| 🔴 | `Critical` | Must fix before merge. Security holes, data loss, breaking changes, instructions that lead readers astray. |
| 🟠 | `High Priority` | Should fix before merge. Bugs, missing tests, performance problems, inaccurate technical claims. |
| 🟡 | `Medium Priority` | Should address. Code quality, accessibility, consistency, unclear instructions, staleness. |
| 🟢 | `Low Priority / Nice-to-Have` | Can address later. Minor improvements, typos, style preferences, future enhancements. |

**Non-actionable** — no action required:

| Icon | Label | Meaning |
|------|-------|---------|
| ℹ️ | `Observation` | A good pattern, positive practice, or architectural note worth recording. |

Observations never appear in the checklist. Use them to give the review balance — a review that only
lists problems misrepresents the change.

## Heading format

```markdown
### F1 🟡 Medium Priority - Missing input validation
```

Three parts, in order: the ID, the icon plus its exact label from the table above, then ` - ` and a
short description.

- IDs are `F1`, `F2`, `F3`, … — a **single global sequence** across every reviewer and every
  category, in the order findings appear in the document.
- Use `F1`, not `#1`. On GitHub, `#1` auto-links to an unrelated issue or pull request.
- Use the labels verbatim. `High Priority`, not `High`.

## Finding body

```markdown
### F1 🟡 Medium Priority - Missing input validation

**File:** `app/controllers/users_controller.rb` (line 45)
**Issue:** The `update` action accepts arbitrary parameters without validation.
**Suggestion:** Add strong parameters and validate expected input types.
```

For documents, use `**Location:**` — a section heading or line reference — in place of `**File:**`.

Every finding needs:

- **A location** precise enough to jump to: file and line, or section name.
- **An issue** that explains *why* it is a problem, not merely what is there.
- **A suggestion** that shows the fix. Include a code snippet when the fix is not obvious from prose
  — don't describe a solution you could simply write.

## Status markers

When an actionable finding is resolved, strike through **everything after the ID** and append the
status icon. Never delete a finding: the document records what was reviewed, and a deleted finding
reads identically to one that was never raised. Observations carry no status.

| Icon | Label | Meaning |
|------|-------|---------|
| ✅ | `Fixed` | Resolved in code. |
| ⏸️ | `Deferred` | Real, but scheduled for later. |
| 🚫 | `Ignored` | Won't fix. |

Add a `**Status:**` line to the body giving the reason or the commit:

```markdown
### F1 ~~🟡 Medium Priority - Missing input validation~~ ✅ Fixed

**Status:** Fixed in commit `abc123`
**File:** `app/controllers/users_controller.rb` (line 45)
**Issue:** The `update` action accepts arbitrary parameters without validation.
**Suggestion:** Add strong parameters and validate expected input types.
```

`Ignored` and `Deferred` are only useful with a reason. `**Status:** Ignored` tells a future reader
nothing; `**Status:** Ignored — single call site, the abstraction costs more than the duplication`
tells them the decision was considered.

## Consolidated summary

Close the document with a table covering every finding:

```markdown
| Finding | Priority | Category | Description | File | Status |
|---------|----------|----------|-------------|------|--------|
| F1 | 🔴 Critical | Security | SQL injection | `search_controller.rb` | |
| F2 | 🟡 Medium | Code Quality | Missing validation | `users_controller.rb` | ✅ |
| F3 | 🟢 Low | Code Quality | Extract helper | `user.rb` | 🚫 |
| F4 | ℹ️ Observation | Testing | Good edge-case coverage | `user_spec.rb` | — |
```

Category is free-form but should stay consistent within a document: Security, Performance, Code
Quality, Testing, UI/UX, Consistency, Accuracy, Clarity. Leave Status blank while a finding is
unresolved; observations take `—`, since no status will ever apply to them.

## Checklist

Then a checklist of **actionable findings only**. Skip observations. Skip generic entries such as
"run the tests" or "run the linter" — those aren't findings.

```markdown
- [ ] F1 - Fix SQL injection in search controller
- [x] F2 - Add input validation (fixed) ✅
- [x] F3 - Extract helper method (ignored — single call site) 🚫
```

Check the box once a finding is off the pre-merge path — fixed, deferred, and ignored all qualify —
and follow the description with a short parenthetical reason. Leave it unchecked while the finding
is still open.

## Re-running a review

Review files are updated in place, never regenerated. When the file already exists:

1. **Read it first.** Everything below depends on knowing what is already there.
2. **Keep existing IDs.** Never renumber. F3 must mean the same thing in tomorrow's review that it
   means today, because people cite these numbers in commit messages and pull request threads.
3. **Keep status markers** and their `**Status:**` lines intact.
4. **Number new findings from the next free ID.** If F1–F7 exist, the next new finding is F8, even
   if F2 and F5 are already resolved.
5. **Strike through findings that no longer apply** — the code or section was deleted or rewritten
   past recognition — with a one-line explanation of why. Don't remove them.
6. **Update the review history.**

## Review history

The file opens with a **Review History** section, one entry per run, newest last:

```markdown
## Review History

- **Initial review:** 2026-03-14
- **Re-review:** 2026-04-02 (findings F1, F3 fixed; F8–F9 added)
```

## Posting to a pull request

Wrap the review in a collapsible block so it doesn't dominate the thread. Write the body to a file
and post it with `--body-file` — heredocs mangle the backticks and emoji.

```bash
{
  echo "## Local Review — 24 findings, all actionable items resolved"
  echo ""
  echo "**24 findings — 16 fixed, 8 observations**"
  echo ""
  echo "<details>"
  echo "<summary>Click to expand full review details</summary>"
  echo ""
  cat local-review.md
  echo ""
  echo "</details>"
} > /tmp/pr-comment.md
gh pr comment --body-file /tmp/pr-comment.md
```

The summary line carries the state at a glance: `24 findings — 14 fixed, 2 ignored, 8 observations`.
When every actionable finding is resolved, lead with that: `24 findings — 16 fixed, 8 observations —
all clear`.
