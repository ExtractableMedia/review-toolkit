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

### Added

- **`.claude/review-config.md` gained two prose sections**, both optional and both passed verbatim
  to every reviewer, bundled ones included. **Review Context** carries what a reviewer can't infer
  from the code — a migration in flight, an idiom that would otherwise read as a mistake.
  **Verifying Changes** carries how to run tests or builds in this repository, including the
  namespacing that keeps parallel reviewers off each other's database and ports. Together they cover
  the customization that previously forced projects to fork the whole review command.
- **`/local-review --plan`** reviews an implementation plan instead of a diff, picking `PLAN.md` or
  the newest plan under `~/.claude/plans/`. Conditional reviewers are chosen by the paths the plan
  says it will touch, and reviewers read the files it references so they can catch assumptions the
  code doesn't support.
- **`/local-review --reconcile`** marks findings that have since been fixed without re-running the
  review. No reviewer is dispatched and no finding is added, removed, or re-judged.
- **Findings carry a `Recommendation` of Implement, Defer, or Skip**, with a one-line rationale, so
  a reader learns whether a fix is worth making rather than only that it is possible.
- **A new ❓ Open status**, where every actionable finding starts. Without it an undecided finding
  renders blank, which is indistinguishable from an observation that needs no decision.
- **Review files record which model produced them.** Each run appends a Review History entry with
  the orchestrating model and a table of every reviewer that ran, each with the model it actually
  resolved to. A `model:` alias isn't evidence — it resolves differently as new models ship, and
  downward when the preferred model is unavailable.
- **Each bundled reviewer declares a `color`**, so parallel reviewers stay distinguishable while
  their output streams. The four leave most of the palette free for agents a project defines in its
  own `~/.claude/agents/`.
- `.github/workflows/validate.yml`.
- `scripts/check-finding-format.sh`, which checks any review file against
  `reference/finding-format.md`. It replaces the heading grammar lost with the MCP server.

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
- `security-reviewer` recomputed its own diff against a hardcoded base, so on a repository whose
  default branch is `master`, `develop`, or `trunk` it reviewed nothing and reported clean. It now
  resolves the base, and `validate.yml` fails if a hardcoded one reappears under `agents/` or
  `skills/`.
- Reviewer agents could edit the code they were reviewing. All four now declare
  `tools: Read, Grep, Glob, Bash`, so none has an `Edit` or `Write` tool.

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
- **Status is no longer derived from a reviewer's recommendation.** Mapping Defer to ⏸️ and Skip to
  🚫 let a review close its own findings before anyone read them, collapsing the difference between
  advice and consent. ⏸️ and 🚫 are now written only after the user confirms that specific finding —
  `/triage` is where that happens — while ✅ Fixed still needs no confirmation, since it asserts
  something verifiable by reading the code.
- **Every pre-merge checklist item is a checkbox, with its status glyph immediately after it.** The
  old mix of `- [x] … ✅` and `- 🚫 …` rendered with two different left margins, because Markdown lays
  out task-list items flush and plain bullets indented — which destroyed the column the glyphs
  existed to create. A checked box now means the finding is off the pre-merge path, fixed, deferred,
  or ignored alike; the glyph says which.
- **A snippet quoting Markdown that contains a fenced block needs a four-backtick outer fence.** A
  three-backtick fence is closed by the inner block's closing fence, swallowing every following
  finding into a code block. The corruption appears after the finding that caused it, so it reads as
  damage to a section that is actually fine.
- **Project reviewers resolve only from `~/.claude/agents/`.** `.claude/review-config.md` ships
  inside the repository under review, so a repository could previously supply both the config naming
  a reviewer and that reviewer's own definition, and have it dispatched with the reviewing user's
  permissions — no prompt injection required, since obeying the config is the intended path. The
  config now routes only: an agent found solely in the repository is named for approval rather than
  run, and a change set that touches the config skips project reviewers entirely.
- Reviewer prose follows the new permissions: `test-suite-architect` specifies tests rather than
  writing them, and `documentation-expert` returns findings rather than assembling the review file.

### Known issue

`allowed-tools` frontmatter is not set on any skill. Declaring it on a plugin skill makes
invocation fail with a bare `Execute skill: <name>` error — reproduced on 2.1.222, and not
retested since. The cost is a one-time permission prompt for `scripts/change-set.sh`. Add the
field back once the platform accepts it. Otherwise verified against 2.1.145 and 2.1.251.

## 0.1.0 - 2026-03-14

Initial release: `/local-review`, `/doc-review`, and `/triage` via an MCP elicitation server.
