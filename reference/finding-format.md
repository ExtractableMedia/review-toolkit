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
| 💡 | `Optional` | Something reads correctly, but a small improvement below the 🟢 Low bar is available. State the action inline. It is noted so the option is visible, not to imply it should be taken. |

Observations never appear in the checklist and are never triaged. Use ℹ️ to give the review
balance — a review that only lists problems misrepresents the change — and keep genuine praise (ℹ️)
distinct from latent suggestions (💡), so neither drowns out the other.

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
**Recommendation:** Implement — unvalidated input reaches a database write, and
the fix is cheap.
```

For documents, use `**Location:**` (a section heading or line reference) instead of `**File:**`.

Every finding needs:

- **A location** precise enough to jump to — file and line, or section name.
- **An issue** that explains *why* it's a problem, not just what is there.
- **A suggestion** that shows the fix — actionable findings only. Include a code snippet when the
  fix isn't obvious from prose; don't describe a solution you could just write. Observations record
  something good and need nothing beyond the location and what was noticed.
- **A recommendation** — `Implement`, `Defer`, or `Skip`, plus a one-line rationale. This tells the
  reader whether the fix is worth making, not merely that it is possible. A reviewer that finds
  something real but not worth fixing should say so rather than leaving the reader to guess.

Recommendations are for actionable findings only. ℹ️ observations carry none; 💡 observations state
the optional action inline.

A recommendation never sets a status. See **Status records a decision, not a recommendation** below.

**Never quote a live secret.** When a finding is about a credential, give the location and the kind
of secret and nothing more — `AWS access key ID at line 12`, not the key. The review file is written
into the repository and pasted into pull requests, so a finding that reproduces the secret has
published it a second time. Say so in the suggestion: rotate first, then remove.

### Fencing a snippet that contains a fence

When a suggestion quotes Markdown that itself contains a fenced code block, open and close the outer
fence with **four** backticks:

`````markdown
````markdown
Here is the block to add:

```ruby
validate :expected_input_types
```
````
`````

CommonMark ends a fence at any run of backticks at least as long as the opener carrying no info
string, so a three-backtick outer fence is closed by the inner block's *closing* fence. Everything
after it — including the whole next finding — is swallowed into a code block until the next stray
fence rebalances it.

The damage lands on the findings *after* the one that caused it, so it reads as corruption in a
section that is actually fine and sends the reader looking in the wrong place. That's why the rule
is worth stating rather than leaving to taste.

## Status markers

Every actionable finding starts at ❓ Open and stays there until something moves it. When one is
resolved, strike through **everything after the ID** and append the status icon. Never delete a
finding — the document is a record of what was reviewed, and a deleted finding reads identically to
one that was never raised.

The Status column of the summary table carries the icon without its label, so `Fixed` and
`Accepted` need different icons there: "we changed the code" and "we looked and decided not to" are
different answers to whether the branch is ready.

| Icon | Label | Meaning |
|------|-------|---------|
| ❓ | `Open` | Undecided, or decided to fix and the fix isn't in yet. Where every actionable finding begins. |
| ✅ | `Fixed` | Resolved in code. |
| ☑️ | `Accepted` | Reviewed and judged acceptable as-is. |
| ⏸️ | `Deferred` | Real, but scheduled for later. |
| 🚫 | `Ignored` | Won't fix. |

❓ exists so that "nobody has ruled on this yet" is representable. Without it an undecided finding is
blank, and blank is what an observation looks like — the one row that needs a decision renders
identically to the rows that never will. Never write `—` for an undecided actionable finding; `—`
means "no status applies," which is true only of ℹ️ and 💡 observations.

### Status records a decision, not a recommendation

**Never derive a finding's status from its own recommendation.** A recommendation of Defer or Skip
is the reviewer's advice. It is not consent.

- ✅ `Fixed` is the one status that may be applied without asking. It asserts a fact about the code,
  verifiable by reading it.
- ☑️ `Accepted`, ⏸️ `Deferred`, and 🚫 `Ignored` assert that a decision was made, so they may only be
  written after the user confirms *that specific finding*. `/triage` is where that confirmation
  happens.
- Everything else stays ❓ Open — including a finding the user has decided to fix, until the fix
  actually lands.

Read together, the two columns say different things. **Skip** + ❓ is "the reviewer thinks this isn't
worth doing, and nobody has agreed yet." **Skip** + 🚫 is "that call has been made." Collapsing them
lets a review close its own findings before anyone has read them.

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
| Finding | Priority | Category | Description | File | Recommendation | Status |
|---------|----------|----------|-------------|------|----------------|--------|
| F1 | 🔴 Critical | Security | SQL injection | `search_controller.rb` | Implement | ❓ |
| F2 | 🟢 Low | Code Quality | Extract helper | `user.rb` | Skip | ❓ |
| F3 | 🟡 Medium | Performance | Add caching | `api_client.rb` | Defer | ⏸️ |
| F4 | 🟠 High | Security | Mask logged tokens | `webhook.rb` | Implement | ✅ |
| F5 | ℹ️ Observation | Testing | Good edge-case coverage | `user_spec.rb` | — | — |
```

Category is free-form but should stay consistent within a document: Security, Performance, Code
Quality, Testing, UI/UX, Consistency, Accuracy, Clarity.

**Recommendation** is what the reviewer advised; **Status** is what was decided. F2 shows the pair
that matters: a Skip recommendation nobody has accepted yet, which is why it reads `Skip | ❓` and
not `Skip | 🚫` — and why it stays unchecked in the checklist below. Observations get `—` in both
columns.

The two examples describe the same five findings and must agree. A reader who follows one against
the other is checking their understanding; a contradiction teaches the opposite of the rule.

## Checklist

Then a checklist of **actionable findings only**. Skip observations. Skip generic entries like "run
the tests" or "run the linter" — those aren't findings.

```markdown
- [ ] ❓ F1 - Fix SQL injection in search controller
- [ ] ❓ F2 - Extract helper method (Skip recommended, not yet accepted)
- [x] ⏸️ F3 - Add caching layer (deferred to follow-up PR)
- [x] ✅ F4 - Mask logged tokens (fixed)
```

- **Every item is a checkbox.** This is about rendering, not tidiness: Markdown lays out `- [ ]`
  items as a task list flush with the left margin, but a bare glyph bullet as an ordinary list item
  with an extra indent. Mixing the forms gives the list two ragged margins and destroys the column
  the glyphs exist to create.
- **The glyph goes immediately after the checkbox**, never at the end of the line. Trailing, it
  forces a read of the whole item to learn its state; leading, the glyphs line up in a column that
  answers "what's left?" in one vertical scan.
- **Check the box once the finding is off the pre-merge path** — fixed, accepted, deferred, and
  ignored all qualify, matching the four resolved statuses in the table above. A checked box means
  "not blocking," not specifically "fixed"; the glyph says which.
- **Leave it unchecked while the finding is still open**, whether undecided or decided-to-fix with
  the fix not yet in.
- Follow the description with a short parenthetical reason for anything fixed, accepted,
  deferred, or ignored.

New findings enter the checklist unchecked at ❓, whatever their recommendation.

## Re-running a review

Review files are updated in place, never regenerated. When the file already exists:

1. **Read it first.** Everything below depends on knowing what's already there.
2. **Keep existing IDs.** Never renumber. F3 must mean the same thing in tomorrow's review that it
   meant today, because people cite these numbers in commit messages and PR threads.
3. **Keep status markers** and their `**Status:**` lines intact.
4. **Re-locate every open finding before judging it.** Each location was written against an
   earlier revision and may have moved. Find it in the current code or document and correct it in
   place first; a location that no longer resolves is evidence the file changed, not that the
   finding was addressed.
5. **Number new findings from the next free ID.** If F1–F7 exist, the next new finding is F8 — even
   if F2 and F5 are resolved. Each enters at ❓ Open whatever its recommendation.
6. **Don't re-raise a resolved finding.** If it's marked Fixed and the problem is genuinely back,
   reopen the *existing* finding by removing the strikethrough and noting the regression; don't file
   a duplicate.
7. **Strike through findings that no longer apply** — the code was deleted or rewritten past
   recognition — as ✅ Fixed, with a one-line explanation of why. Strikethrough marks a finding
   decided, so it carries a status to stay countable, and ✅ is written only when the condition the
   finding describes is verifiably gone. A rewrite that merely moved the text is not evidence of a
   fix: that finding stays ❓ Open at its new location, with a note saying so.
8. **Append a review history entry** — see below.

## Review history

The file opens with a **Review History** section, one entry per run, newest last. Each entry records
the date, what the run changed, and the models that produced it.

```markdown
## Review History

### 2026-03-14 — Initial review

**Orchestration:** Opus 5 (`claude-opus-5[1m]`)

| Reviewer | Model |
|---|---|
| code-best-practices-reviewer | Opus 5 (`claude-opus-5`) |
| security-reviewer | Opus 5 (`claude-opus-5`) |
| test-suite-architect | Sonnet 5 (`claude-sonnet-5`) |

### 2026-04-02 — Re-review (F1, F3 fixed; F8–F9 added)

**Orchestration:** Opus 5 (`claude-opus-5[1m]`)

| Reviewer | Model |
|---|---|
| security-reviewer | Opus 5 (`claude-opus-5`) |
| test-suite-architect | Opus 5 (`claude-opus-5`) |
```

Why the models are recorded: a reader deciding how much weight a past review deserves needs to know
what produced it. The `model:` alias in an agent's frontmatter isn't evidence — `opus` resolves to a
different model as new ones ship, and can resolve downward at runtime when the preferred model is
unavailable. Only the resolved model identifies actual capability.

- **Give both the display name and the exact model ID.** The display name is what a reader scans;
  the ID is the durable part, pinning down snapshot and context-window variants the display name
  loses. Record it verbatim, including any suffix — `claude-opus-5[1m]`, not `claude-opus-5`.
- **Orchestration** is the session that resolved the change set, chose the reviewers, and wrote the
  file. There is no separate assembly entry: the invoking session assembles the document itself.
- **List only the reviewers that actually ran.** The table doubles as the record of which
  conditional reviewers the change set triggered.
- **Record each reviewer's model individually.** Reviewers resolve their models independently, so
  one can run on a weaker model than its siblings — which is exactly the variance that explains an
  unexpectedly thin section of a past review.
- **A reviewer that can't determine its own model reports `unknown`.** A wrong entry is worse than a
  missing one.
- **Never rewrite the model entries of earlier runs.** Each entry is a permanent record of the run
  that produced those findings.

A reconciliation pass records **Orchestration** only, with no reviewer table, because no reviewer
ran. Label it so it isn't mistaken for a review:

```markdown
### 2026-04-11 — Reconciliation (F1, F3, F5 marked fixed)

**Orchestration:** Opus 5 (`claude-opus-5[1m]`)
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

"All clear" is the strongest claim the document makes, so it is the one to guard. Write it only when
every actionable finding is ✅ Fixed or ☑️ Accepted. Deferred and ignored findings are off the
pre-merge path but not resolved, and open ones are neither, so none of them fold into the fixed
count — and never write it while a 🔴 Critical or 🟠 High sits at any other status. Name every
bucket separately instead.

### Scrub local paths before posting

A review is written by an agent reading a developer machine, and a finding that traces where an
agent or a command resolves from cites an absolute path under the home directory. Check at this
step rather than trusting the review stage, because this is the step that publishes:

```bash
find . -maxdepth 1 \( -name 'local-review*.md' -o -name '*-DOC-REVIEW.md' \) \
  -exec grep -nE '/Users/|/home/|/private/tmp/|/var/folders/' /dev/null {} + || true
```

`find` does the matching, so a pattern with no file behind it is an empty result rather than the
shell error an unmatched glob raises under zsh, which aborts the whole command before the
redirection applies. The `/dev/null` argument keeps `grep` printing the filename, and the `|| true`
keeps a clean run from reading as a failure — `grep` exits 1 when it matches nothing. No output
means nothing to scrub.

Rewrite each hit **in the review file** before building the comment: `~`-prefixed when the path
genuinely lies outside the repository, repo-relative when it does not. Editing the comment
afterwards does not undo the disclosure — GitHub keeps the pre-edit revision in the comment's edit
history, and the only complete remedy is to delete the comment and repost it under a new URL. A hit
that is a placeholder carrying no real username, `/Users/<name>/…` quoted from a rule, is already
redacted; leave it. And read what surrounds each hit: the patterns match paths, not secrets, so
anything credential-shaped on the same line means stop and tell the user before posting anything.
