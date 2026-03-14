# Document Review

Review the following document for quality, using the **documentation-expert**
agent:

**Document:** `$ARGUMENTS`

Instruct the documentation-expert to perform a thorough review covering:

## Formatting

- **Markdown syntax** — Correct use of headings, lists, code blocks, tables,
  and links
- **Heading hierarchy** — Logical nesting (no skipped levels, consistent style)
- **Whitespace and spacing** — Consistent blank lines, no trailing whitespace,
  proper list indentation
- **Code blocks** — Correct language tags, properly formatted inline code
- **Tables** — Aligned columns, correct syntax, consistent formatting

## Consistency

- **Terminology** — Same concepts use the same terms throughout (no mixing
  synonyms inconsistently)
- **Capitalization** — Consistent casing for product names, features, and
  section titles
- **Formatting patterns** — Consistent use of bold, italics, and code formatting
  for similar elements
- **Tone and voice** — Consistent level of formality and perspective (first vs
  third person)
- **List style** — Consistent use of ordered vs unordered lists, punctuation at
  end of items
- **Cross-section consistency** — Information stated in one section does not
  contradict or conflict with information in another section (e.g., a summary
  that doesn't match the details, or repeated instructions that diverge)

## Accuracy

- **File paths and references** — Verify referenced files, directories, and
  commands exist in the codebase where possible
- **Code examples** — Check that code snippets match the actual codebase
  patterns and conventions
- **Cross-references** — Internal links and section references are valid
- **Technical claims** — Flag any statements that appear incorrect or outdated

## Clarity and Structure

- **Organization** — Logical flow of information, appropriate use of sections
- **Completeness** — No obvious gaps or missing context for the intended audience
- **Conciseness** — Flag verbose or redundant sections
- **Audience alignment** — Language and detail level appropriate for the target
  reader
- **Actionability** — For instructional or how-to content: are steps followable
  in order? Are prerequisites stated? Are expected outcomes described so the
  reader knows if they succeeded?
- **Examples** — Flag complex concepts or procedures that lack concrete examples
  to illustrate usage

## Sensitive Information

- **Secrets and credentials** — Flag any API keys, tokens, passwords, or
  connection strings that appear to be real (not placeholders)
- **Internal URLs and IPs** — Flag internal hostnames, IP addresses, or URLs
  that should not be in documentation
- **PII** — Flag personally identifiable information (names, emails, phone
  numbers) that may have been included accidentally

## Spelling and Grammar

- **Typos and misspellings** — Flag spelling errors in prose (not code/commands)
- **Grammar** — Flag grammatical errors and awkward phrasing
- **Punctuation** — Inconsistent or missing punctuation in sentences and lists

## Staleness

- **Hardcoded dates** — Flag specific dates that may become outdated
- **Version numbers** — Flag pinned versions of tools, languages, or frameworks
  that may need updating
- **Deprecated references** — Flag mentions of tools, APIs, libraries, or
  practices that are known to be deprecated or superseded

## Output

### Review File

Write the review to a **Markdown file in the project root**. Derive the filename
from the document being reviewed: lowercase the name, convert spaces to dashes,
drop the original extension, and append `-DOC-REVIEW.md` (e.g.,
`Data Retention Policy.pdf` -> `data-retention-policy-DOC-REVIEW.md`).
This file is the working artifact for the review — update it in place as
findings are addressed during the conversation.

- **Create** the file if it doesn't exist
- **Merge** with existing findings if the file already exists (see below)

**IMPORTANT: Never delete findings.** Findings are a permanent record of what
was reviewed. When a finding is addressed, mark it with strikethrough and a
status icon (Fixed, Ignored, Deferred) — but preserve the original content.

### Merging with Existing Findings

When the review file already exists:

1. **Read the existing file first** to understand current findings and their
   status
1. **Preserve existing finding numbers** — don't renumber resolved findings
1. **Preserve status markers** — keep Fixed, Ignored, Deferred markers
   and their associated content intact
1. **Add new findings** with the next sequential number (e.g., if F1–F4 exist,
   new findings start at F5)
1. **Update findings** if re-review shows they're now resolved or still present
1. **Strike through findings** that are no longer applicable (e.g., the section
   they referenced has been deleted or rewritten) — do **not** remove them;
   apply strikethrough and add a brief explanation of why
1. **Update the review date** at the top of the document:
   ```markdown
   ## Review History
   - **Initial review:** YYYY-MM-DD
   - **Re-review:** YYYY-MM-DD (findings F1, F2 fixed; F5–F6 added)
   ```

### Severity Indicators

Use these severity conventions for quick visual scanning:

**Actionable findings** (require attention):

- 🔴 **Critical** — Must fix (sensitive information exposure, factual errors
  that could cause harm, broken instructions that lead readers astray)
- 🟠 **High Priority** — Should fix (inaccurate technical claims, missing
  critical context, cross-section contradictions)
- 🟡 **Medium Priority** — Should address (inconsistent terminology, formatting
  issues, unclear instructions, staleness)
- 🟢 **Low Priority / Nice-to-Have** — Can address later (minor typos, style
  preferences, missing examples)

**Non-actionable findings** (no action required):

- ℹ️  **Observation** — Highlights a well-written section, good pattern, or
  structural choice worth noting

### Numbered Findings

Number all findings sequentially (F1, F2, F3, ...) across all categories.
Present findings grouped by category (Formatting, Consistency, Accuracy,
Clarity, Sensitive Information, Spelling/Grammar, Staleness). Omit categories
with no findings.

Use the format: `### F1 🟡 Medium Priority - Description`

For each finding, include:

- **Location** — Section heading or line reference
- **Issue** — Clear description of the problem
- **Suggestion** — Concrete fix or improvement

### Tracking Finding Status

When a finding has been addressed (either by fixing, ignoring, or deferring),
mark it visually while preserving the original content for reference.
Observation findings do not require status tracking.

**Status indicators:**

- ✅ **Fixed** — The issue has been resolved
- 🚫 **Ignored** — Explicitly decided not to address (include reason)
- ⏸️ **Deferred** — Will address later

**How to mark findings:**

Apply strikethrough to the finding heading (excluding the finding number) and
add the status icon to the right. Do **not** delete the finding content —
preserve it for reference.

```markdown
### F1 ~~🟡 Medium Priority - Inconsistent terminology~~ ✅ Fixed

**Location:** Section "Getting Started"
**Status:** Fixed — standardized on "deploy" throughout
...original finding content preserved...
```

In the checklist, check the box for fixed findings:

```markdown
- [x] F1 - Standardize terminology (fixed) ✅
- [ ] F2 - Add missing example (deferred to next revision) ⏸️
```

### Consolidated Summary

At the end, provide:

1. **Summary table** of all findings:

| Finding | Priority | Category | Description | Location | Status |
|---------|----------|----------|-------------|----------|--------|
| F1 | 🟡 Medium | Consistency | Example description | Section name | |

1. **Overall assessment** - Brief summary of document quality

1. **Checklist** - Convert actionable findings (🔴🟠🟡🟢) into a checklist.
   Do not include Observation findings in the checklist.

```markdown
- [ ] F1 - Fix description
- [ ] F2 - Fix description
```

### PR Comment Format

When posting review findings as a PR comment (e.g., when explicitly asked),
build a temporary file with a collapsible `<details><summary>` wrapper and
post it with `--body-file` to avoid heredoc quoting issues:

```bash
{
  echo "## Document Review: [document name] — [status summary]"
  echo ""
  echo "**[N findings — X actionable, Y observations]**"
  echo ""
  echo "<details>"
  echo "<summary>Click to expand full review details</summary>"
  echo ""
  cat "$review_file"
  echo ""
  echo "</details>"
} > /tmp/pr-comment.md
gh pr comment --body-file /tmp/pr-comment.md
```

The `<summary>` line should include the total finding count and a breakdown
(e.g., "24 findings — 14 fixed, 2 ignored, 8 observations"). When all
actionable findings have been addressed, lead with that:
"24 findings — 16 fixed, 8 observations — all clear".

### Interactive Finding Selection

After displaying all review output, present the list of **actionable findings
only** (🔴🟠🟡🟢 — not Observations), formatted as:

```text
F1 🔴 Critical - Description (location)
F3 🟡 Medium - Description (location)
F5 🟢 Low - Description (location)
```

Ask the user which findings to fix. Accept finding numbers (e.g., "F1, F3"),
"all", or "skip". If the user selects one or more findings, edit the document
directly to resolve them in order.
