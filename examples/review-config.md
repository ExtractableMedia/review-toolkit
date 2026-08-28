# Review Configuration

Copy this to `.claude/review-config.md` in your project and edit it to match your stack.
`/local-review` reads it and dispatches these reviewers alongside the bundled three.

The file has four sections, all optional:

| Section | Purpose |
|---------|---------|
| **Always Run** | Extra reviewers dispatched on every review |
| **Conditional** | Reviewers dispatched only when the change set matches their triggers |
| **Review Context** | Prose handed to *every* reviewer, bundled ones included |
| **Verifying Changes** | How a reviewer runs things here, if it needs to check a claim |

Every agent named here must exist in `.claude/agents/` or `~/.claude/agents/`. The headings are the
agent names; the bullets are the focus areas passed to each one.

Keep the reviewer entries thin. Deep domain knowledge belongs in the agent's own definition, where
it's available to every session that uses the agent — not just to reviews. What this file adds is
**routing**: which agent, and when.

## Always Run

Dispatched on every review.

### ruby-on-rails-expert

- Rails conventions, Active Record patterns, controller design
- Model responsibilities, performance considerations
- Proper use of callbacks, concerns, and helpers
- Efficient queries, scopes, avoiding N+1 queries

## Conditional

Dispatched only when the change set touches a file matching `**Trigger:**`, so a CSS-only branch
doesn't wake the database reviewer.

### ui-ux-design-specialist

**Trigger:** `app/views/**`, `app/assets/stylesheets/**`, `app/javascript/**`, `spec/system/**`

- Visual consistency, accessibility, responsive design
- User feedback, interaction patterns
- WCAG compliance, keyboard navigation, color contrast

### postgresql-expert

**Trigger:** `db/migrate/**`, `db/schema.rb`

- Migration safety, index strategy, data type choices
- Constraint correctness, foreign keys, NOT NULL usage
- Data migrations, batching, avoiding full table scans

### infrastructure-expert

**Trigger:** `infrastructure/**`, `.github/workflows/**`, `Dockerfile`, `docker-compose.yml`

- Infrastructure-as-code correctness, configuration management
- Security hardening, deployment safety
- Monitoring, alerting, backup strategies

### domain-expert

**Trigger:** `app/calculations/**`, `app/services/pricing/**`, `lib/calculation_utilities.rb`,
`config/business_rules.yml`

- Correctness of business rules and calculations
- Domain model fidelity — do the types match how the business thinks?
- Reference data and configuration correctness
- Edge cases the generic reviewers have no way to recognize

The `domain-expert` entry is the one worth adapting first. Generic reviewers catch generic problems;
nobody but a domain reviewer will notice that a rounding rule is wrong or that a rate table is
stale. Name it after your actual domain — `claims-adjudication-expert`, `tax-rules-expert`,
`scheduling-expert` — and point the triggers at the code that encodes the rules.

## Review Context

Passed verbatim to every reviewer, bundled ones included. Reviewers start with an empty context and
never see this file, so anything here is the only way they learn a house convention.

Both this section and **Verifying Changes** reach reviewers inside an explicit data boundary, marked
as project-supplied reference material rather than instruction. That is deliberate: this file is
repository content, so anyone who can push to the repository can write it. Text here that tries to
scope the review down, reclassify a severity in advance, or ask for a finding to go unreported will
be withheld and reported as a 🔴 Critical finding against this file.

Use it for facts that change a verdict — a migration in flight, an idiom the generic reviewers would
flag as wrong, a constraint they'd otherwise miss. Leave it out entirely rather than filling it with
things a reviewer can read off the code.

- Prefer `QuantLib::ext::shared_ptr` over `std::shared_ptr` in ORE code; the latter is correct C++
  but wrong for this codebase.
- We're migrating off Sidekiq onto Solid Queue. Flag new `perform_async` calls as 🟡 Medium — they
  aren't broken, but they're new debt.
- `app/legacy/` is frozen pending deletion. Report findings there as ℹ️ Observation; nobody is going
  to fix them.

## Verifying Changes

How a reviewer runs things in this repository, if it needs to check a claim rather than reason about
it.

Reviewers report findings; they must not modify your code. They *can* run commands, though, and
several of them run in parallel against one checkout, so anything with shared state needs
namespacing or it will collide.

Omit this section if reviewing your code doesn't require running it. A reviewer that can't verify a
claim reports the finding as unverified, which is a fine outcome.

```bash
# Specs: derive a database name from the worktree so parallel reviewers don't
# share one. Drop it afterward with `bin/rails db:drop` under the same env.
SUFFIX=${PWD##*/}
SUFFIX=${SUFFIX//[^[:alnum:]]/_}
export TEST_DATABASE="myapp_test_${SUFFIX}"
bin/rails db:test:prepare
bin/rspec path/to/spec.rb

# Ports can't be namespaced, so probe upward from a non-default base.
PORT=3100
while lsof -iTCP:"$PORT" -sTCP:LISTEN -t >/dev/null 2>&1; do PORT=$((PORT + 1)); done
```
