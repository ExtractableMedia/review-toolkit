# Changelog

## Unreleased — 1.0.0-beta.1

Rewritten as a pure-markdown plugin. No build step, no Node dependency, no MCP server.

### Breaking

- **The `review-toolkit` MCP server is gone**, along with `src/`, `package.json`, `tsconfig.json`,
  and `.mcp.json`. `/triage` now collects decisions with Claude Code's built-in `AskUserQuestion`
  tool, so there is nothing to build or install.
- **The `Elicitation` and `ElicitationResult` hooks no longer apply.** Decision auditing moved to a
  `PostToolUse` hook matched on `AskUserQuestion` — see `examples/hooks/log-triage-decisions.sh`.
  `/triage --severity critical,high` replaces the auto-skip-low-priority hook.
- **Commands moved from `commands/` to `skills/`.** Invocation is unchanged (`/local-review`,
  `/doc-review`, `/triage`), but all three now set `disable-model-invocation: true`, so Claude will
  not start a multi-agent review on its own.
- **`/local-review` assembles the review document itself** instead of routing every reviewer's
  output through `documentation-expert` to be renumbered.

### Fixed

- The plugin failed `claude plugin validate`: `plugin.json` declared `"agents": "./agents"` as a
  string where the schema requires an array. Both `agents/` and `skills/` are auto-discovered, so
  the keys are gone.
- Installing from git produced a broken plugin, because `.mcp.json` pointed at a `dist/index.js`
  that `.gitignore` excluded and nothing built.
- The documented install command was not valid syntax, and the repository had no `marketplace.json`.
  Added one, so `claude plugin marketplace add ExtractableMedia/review-toolkit` works.
- `change-set.sh` treated a base branch the remote names but the clone lacks as simply absent, so
  `/local-review` reviewed only uncommitted work and called a branch full of commits clean. Routine
  in single-branch and shallow clones. It is now reported as unresolved and the skill stops to ask.
- `change-set.sh` resolved the base only against a remote named `origin`, so an `--origin upstream`
  clone got no base at all. The remote is now derived.
- The triage audit log was created under the invoking user's umask — 0644 on most systems — while
  storing the code snippets and findings `/triage` puts in its prompts. Now 0600 in a 0700 directory.
- The triage hook treated every `jq` failure, including `jq` not being installed, as "not a triage
  decision" and logged nothing silently — the worst failure for an audit log, which then looks fine
  and is empty. It now checks for `jq` once and reports real errors.
- The triage hook exited 1 when `HOME` was unset, interrupting the user mid-triage, and exited
  silently when its log directory could not be created. Both now report on stderr and exit 0.

### Changed

- CI checks what prose cannot: that skill-interpolated paths resolve, that each skill still sets
  `disable-model-invocation`, that the triage hook never exits non-zero, and that the sample review
  conforms to the finding format.
- The Claude Code CLI is pinned and installed without transitive lifecycle scripts, and validated
  against both the version floor `README.md` declares and the latest release.
- The plugin-manifest check copies the whole tree instead of a hand-kept list of component
  directories.
- Pushes to the default branch are no longer cancelled by a following push, so every commit the
  marketplace installs from keeps its own validation record.
- Triage presents up to 4 findings per prompt, each with its full issue and suggestion, replacing
  the per-finding dialog and its "View details" round trip.
- Triage writes decisions to the review file after every batch, so interrupting it no longer
  discards the ones it has already collected.
- Free-text guidance replaces the separate "Fix with guidance" action.
- The finding format specification is now only in `reference/finding-format.md`, rather than three
  files that had begun to drift.
- `/local-review` no longer ends by asking which findings to fix; that is `/triage`.
- `/local-review` runs a bundled `scripts/change-set.sh` at skill load, so the branch, base, and
  diffstat are in context before Claude reads the instructions.

### Added

- `.github/workflows/validate.yml`.
- `scripts/check-finding-format.sh`, which checks any review file against
  `reference/finding-format.md`. It replaces the heading grammar lost with the MCP server.

### Known issue

`allowed-tools` frontmatter is not set on any skill. Declaring it on a plugin skill makes
invocation fail with a bare `Execute skill: <name>` error — reproduced on 2.1.222, and not
retested since. The cost is a one-time permission prompt for `scripts/change-set.sh`. Add the
field back once the platform accepts it. Otherwise verified against 2.1.145 and 2.1.251.

## 0.1.0 - 2026-03-14

Initial release: `/local-review`, `/doc-review`, and `/triage` via an MCP elicitation server.
