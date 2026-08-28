# Finding Format

The single source of truth for how review-toolkit findings are written, numbered, tracked, and
merged. `/local-review`, `/doc-review`, and `/triage` all read this file — keep it authoritative and
don't restate its rules elsewhere.

## Severity scale

**Actionable** — require a decision:

| Icon | Label | Meaning |
|------|-------|---------|
| 🔴 | `Critical` | Must fix. Security holes, data loss, breaking changes, instructions that lead readers astray. |
| 🟠 | `High Priority` | Should fix before merge. Bugs, missing tests, performance problems, inaccurate technical claims. |
| 🟡 | `Medium Priority` | Should address. Code quality, accessibility, consistency, staleness. |
| 🟢 | `Low Priority` | Can address later. Minor improvements, style preferences, future enhancements. |

**Non-actionable** — no decision needed:

| Icon | Label | Meaning |
|------|-------|---------|
| ℹ️ | `Observation` | A good pattern, thoughtful design choice, or architectural note worth recording. |

Observations never appear in the checklist and are never triaged. Use them to give the review
balance — a review that only lists problems misrepresents the change.

## Heading format

```markdown
### F1 🟡 Medium Priority - Missing input validation
```

Three parts, in order: the ID, the icon plus its exact label from the table above, then ` - ` and a
short description.

- IDs are `F1`, `F2`, `F3`, … — a **single global sequence** across every reviewer, in the order
  findings appear in the document.
- Use `F1`, not `#1`. On GitHub, `#1` auto-links to an unrelated issue or PR.
- Use the labels verbatim in headings — `High Priority`, not `High`. The summary table is
  width-constrained; the short form (`🟠 High`) is fine there.

## Finding body

```markdown
### F1 🟡 Medium Priority - Missing input validation

**File:** `app/controllers/users_controller.rb` (line 45)
**Issue:** The `update` action accepts arbitrary parameters without validation.
**Suggestion:** Add strong parameters and validate expected input types.
```

For documents, use `**Location:**` (a section heading or line reference) instead of `**File:**`.

Every finding needs:

- **A location** precise enough to jump to — file and line, or section name.
- **An issue** that explains *why* it's a problem, not just what is there.
- **A suggestion** that shows the fix — actionable findings only. Include a code snippet when the
  fix isn't obvious from prose; don't describe a solution you could just write. Observations record
  something good and need nothing beyond the location and what was noticed.

**Never quote a live secret.** When a finding is about a credential, give the location and the kind
of secret and nothing more — `AWS access key ID at line 12`, not the key. The review file is written
into the repository and pasted into pull requests, so a finding that reproduces the secret has
published it a second time. Say so in the suggestion: rotate first, then remove.

## Status markers

When a finding is resolved, strike through **everything after the ID** and append the status icon.
Never delete a finding — the document is a record of what was reviewed, and a deleted finding reads
identically to one that was never raised.

The Status column of the summary table carries the icon without its label, so `Fixed` and
`Accepted` need different icons there: "we changed the code" and "we looked and decided not to" are
different answers to whether the branch is ready.

| Icon | Label | Meaning |
|------|-------|---------|
| ✅ | `Fixed` | Resolved in code. |
| ☑️ | `Accepted` | Reviewed and judged acceptable as-is. |
| ⏸️ | `Deferred` | Real, but scheduled for later. |
| 🚫 | `Ignored` | Won't fix. |

Add a `**Status:**` line as the first line of the body, giving the reason or the commit:

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
| F2 | 🟢 Low | Code Quality | Extract helper | `user.rb` | ✅ |
| F3 | ℹ️ Observation | Testing | Good edge-case coverage | `user_spec.rb` | — |
```

Category is free-form but should stay consistent within a document: Security, Performance, Code
Quality, Testing, UI/UX, Consistency, Accuracy, Clarity. Observations get `—` in the Status column.

## Checklist

Then a checklist of **actionable findings only**. Skip observations. Skip generic entries like "run
the tests" or "run the linter" — those aren't findings.

```markdown
- [ ] F1 - Fix SQL injection in search controller
- [x] F2 - Extract helper method (fixed) ✅
- [ ] F4 - Mask sensitive data in logs (deferred to next PR) ⏸️
```

Check the box for anything Fixed or Accepted. Leave Deferred and Ignored unchecked, with the
disposition noted inline.

## Re-running a review

Review files are updated in place, never regenerated. When the file already exists:

1. **Read it first.** Everything below depends on knowing what's already there.
2. **Keep existing IDs.** Never renumber. F3 must mean the same thing in tomorrow's review that it
   meant today, because people cite these numbers in commit messages and PR threads.
3. **Keep status markers** and their `**Status:**` lines intact.
4. **Number new findings from the next free ID.** If F1–F7 exist, the next new finding is F8 — even
   if F2 and F5 are resolved.
5. **Don't re-raise a resolved finding.** If it's marked Fixed and the problem is genuinely back,
   reopen the *existing* finding by removing the strikethrough and noting the regression; don't file
   a duplicate.
6. **Strike through findings that no longer apply** — the code was deleted or rewritten past
   recognition — with a one-line explanation of why.
7. **Update the review history** at the top:

```markdown
## Review History
- **Initial review:** 2026-03-14
- **Re-review:** 2026-04-02 (F1, F2 fixed; F8–F9 added)
```

## Posting to a pull request

Wrap the review in a collapsible block so it doesn't dominate the PR thread. Write the body to a
file and post with `--body-file` — heredocs mangle the backticks and emoji.

```bash
# mktemp, not a fixed /tmp path: on a shared host another account can pre-create
# a known path as a symlink and read the review — which may quote a secret — or
# redirect the write into a file you own.
comment_file=$(mktemp -t pr-comment)

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
} > "$comment_file"
gh pr comment --body-file "$comment_file"
```

The summary line carries the state at a glance: `24 findings — 14 fixed, 2 ignored, 8 observations`.
When every actionable finding is resolved, lead with that: `24 findings — 16 fixed, 8 observations —
all clear`.
