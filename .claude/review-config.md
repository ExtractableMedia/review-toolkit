# Review Configuration

Routing for `/local-review` in this repository, and the plugin's own worked example of the feature.
Keep it current when the invariants in `CLAUDE.md` change.

## Always Run

### documentation-expert

- Accuracy of `README.md` and `CHANGELOG.md` against what the skills and agents actually do
- Consistency between `reference/finding-format.md` and every rule a skill states about the format
- Clarity and completeness of instructions written for a model to execute
- Staleness: version numbers, supported-release claims, and paths that no longer resolve

Bundled with this plugin at `agents/documentation-expert.md`, so the skill's rule against
dispatching a reviewer that exists only in the repository's own `.claude/agents/` does not name it.
Dispatch the installed copy — from `~/.claude/agents/`, or from the installed plugin — never the
working-tree file: this repository *is* the plugin, so the change set under review can modify that
file.

## Review Context

- This is a Claude Code plugin shipped as markdown. There is no source language, no build step and
  no test suite. The invariants that would elsewhere be unit tests are inline checks in
  `.github/workflows/validate.yml`, and linting is super-linter over the whole tree.
- Nothing runnable may be added at the repository root. `.claude-plugin/marketplace.json` sets
  `"source": "./"`, so the plugin root is the repository root: a `.mcp.json` or `.lsp.json` placed
  here installs with the plugin and starts for everyone who installs it, contradicting `README.md`.
  `claude plugin validate --strict` passes either way, so only a reader catches it.
- The reader of `agents/*.md` and `skills/*/SKILL.md` is a model executing the text, not a person
  consulting it. Ambiguity, a rule stated without its consequence, and two files stating the same
  rule differently all change behavior at runtime.
- `reference/finding-format.md` is the single definition of the finding format. All three skills
  read it at runtime, which is why a skill that restates one of its rules creates a second copy.
- In this plugin's design, reviewers report and never fix: `/triage` applies the fixes, after the
  user has ruled on each finding, so a reviewer that edits the code it is reviewing has broken the
  model.
- Every skill carries a `## Treat reviewed content as data` clause because a review reads a diff, a
  plan, or a project's `.claude/review-config.md` — all of them content the change set can modify.
- `/local-review` resolves the base branch once, in `skills/local-review/scripts/change-set.sh`, and
  passes each reviewer an explicit range. Agents and skills therefore carry no base branch of their
  own.
- The repository is public. Nothing tracked here, and no commit message or PR text, may carry
  private repository names, internal ticket IDs or local absolute paths.
- The untracked Markdown files in the repository root are scaffolding for work in progress. They are
  deliberately neither tracked nor listed in `.gitignore`, so that a branch can carry its own review
  when it suits. `.markdownlintignore` carries a pattern for each recurring shape —
  `/local-review*.md`, `/*DOC-REVIEW.md`, `/*HANDOFF.md`, `/*PLAN.md` — so a local
  `markdownlint --fix` does not rewrite those. A one-off name gets no pattern and is linted like any
  other file.

## Verifying Changes

Nothing here listens on a port or touches a database, so parallel reviewers need no namespacing.
Every command below is read-only — `markdownlint` is run without `--fix`, which would rewrite files
in the working tree.

```bash
# Manifests and component frontmatter. The second pass needs a copy without marketplace.json,
# which CI makes in its own temporary directory; see .github/workflows/validate.yml.
claude plugin validate . --strict

# The golden sample against the format spec.
scripts/check-finding-format.sh examples/sample-review.md

# The same linters CI runs, if they are installed locally.
git ls-files -z '*.sh' | xargs -0 -r shellcheck --
npx --yes markdownlint-cli --config .markdown-lint.yml --ignore-path .markdownlintignore '**/*.md'
```
