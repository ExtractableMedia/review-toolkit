# Document Review

Review the following document for quality, using the **documentation-expert** agent:

**Document:** `$ARGUMENTS`

Instruct the documentation-expert to perform a thorough review covering:

## Formatting

- **Markdown syntax** — Correct use of headings, lists, code blocks, tables, and links
- **Heading hierarchy** — Logical nesting (no skipped levels, consistent style)
- **Whitespace and spacing** — Consistent blank lines, no trailing whitespace, proper list
  indentation
- **Code blocks** — Correct language tags, properly formatted inline code
- **Tables** — Aligned columns, correct syntax, consistent formatting

## Consistency

- **Terminology** — Same concepts use the same terms throughout (no mixing synonyms inconsistently)
- **Capitalization** — Consistent casing for product names, features, and section titles
- **Formatting patterns** — Consistent use of bold, italics, and code formatting for similar
  elements
- **Tone and voice** — Consistent level of formality and perspective (first vs third person)
- **List style** — Consistent use of ordered vs unordered lists, punctuation at end of items
- **Cross-section consistency** — Information stated in one section does not contradict or conflict
  with information in another section (e.g., a summary that doesn't match the details, or repeated
  instructions that diverge)

## Accuracy

- **File paths and references** — Verify referenced files, directories, and commands exist in the
  codebase where possible
- **Code examples** — Check that code snippets match the actual codebase patterns and conventions
- **Cross-references** — Internal links and section references are valid
- **Technical claims** — Flag any statements that appear incorrect or outdated

## Clarity and Structure

- **Organization** — Logical flow of information, appropriate use of sections
- **Completeness** — No obvious gaps or missing context for the intended audience
- **Conciseness** — Flag verbose or redundant sections
- **Audience alignment** — Language and detail level appropriate for the target reader
- **Actionability** — For instructional or how-to content: are steps followable in order? Are
  prerequisites stated? Are expected outcomes described so the reader knows if they succeeded?
- **Examples** — Flag complex concepts or procedures that lack concrete examples to illustrate usage

## Sensitive Information

- **Secrets and credentials** — Flag any API keys, tokens, passwords, or connection strings that
  appear to be real (not placeholders)
- **Internal URLs and IPs** — Flag internal hostnames, IP addresses, or URLs that should not be in
  documentation
- **PII** — Flag personally identifiable information (names, emails, phone numbers) that may have
  been included accidentally

## Spelling and Grammar

- **Typos and misspellings** — Flag spelling errors in prose (not code/commands)
- **Grammar** — Flag grammatical errors and awkward phrasing
- **Punctuation** — Inconsistent or missing punctuation in sentences and lists

## Staleness

- **Hardcoded dates** — Flag specific dates that may become outdated
- **Version numbers** — Flag pinned versions of tools, languages, or frameworks that may need
  updating
- **Deprecated references** — Flag mentions of tools, APIs, libraries, or practices that are known
  to be deprecated or superseded

## Output

### Review File

Write the review to a **Markdown file in the project root**. Derive the filename from the document
being reviewed: lowercase the name, convert spaces to dashes, drop the original extension, and
append `-DOC-REVIEW.md` (e.g., `Data Retention Policy.pdf` ->
`data-retention-policy-DOC-REVIEW.md`). This file is the working artifact for the review — update it
in place as findings are addressed during the conversation.

- **Create** the file if it doesn't exist
- **Merge** with existing findings if the file already exists, per the re-review rules in the
  finding format

**IMPORTANT: Never delete findings.** Findings are a permanent record of what was reviewed. When a
finding is addressed, mark it with strikethrough and a status icon (Fixed, Ignored, Deferred) — but
preserve the original content.

### Finding Format

Follow `${CLAUDE_PLUGIN_ROOT}/reference/finding-format.md`. It defines the severity scale, the
heading and body format, numbering, status markers, the consolidated summary table, the checklist,
the merge rules for a re-review, the review history, and the pull request comment format. Read it
rather than relying on memory — it is the authoritative copy, and `/local-review` and `/triage`
follow the same rules.

Two conventions are specific to this command:

- Use `**Location:**` — a section heading or line reference — where the format shows `**File:**`.
- Group findings by category (Formatting, Consistency, Accuracy, Clarity, Sensitive Information,
  Spelling/Grammar, Staleness) while keeping the ID sequence global across all of them. Omit
  categories with no findings.

### Interactive Finding Selection

After displaying all review output, present the list of **actionable findings only** (🔴🟠🟡🟢 — not
Observations), formatted as:

```text
F1 🔴 Critical - Description (location)
F3 🟡 Medium - Description (location)
F5 🟢 Low - Description (location)
```

Ask the user which findings to fix. Accept finding numbers (e.g., "F1, F3"), "all", or "skip". If
the user selects one or more findings, edit the document directly to resolve them in order.
