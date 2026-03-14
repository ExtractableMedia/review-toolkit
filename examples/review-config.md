# Review Configuration

## Always Run

### ruby-on-rails-expert
- Rails conventions, Active Record patterns, controller design
- Model responsibilities, performance considerations
- Proper use of callbacks, concerns, and helpers
- Efficient queries, scopes, avoiding N+1 queries

## Conditional

### ui-ux-design-specialist
**Trigger:** `app/views/**`, `app/assets/stylesheets/**`,
`app/javascript/**`, `spec/system/**`
- Visual consistency, accessibility, responsive design
- User feedback, interaction patterns
- WCAG compliance, keyboard navigation, color contrast

### postgresql-expert
**Trigger:** `db/migrate/**`, `db/schema.rb`
- Migration safety, index strategy, data type choices
- Constraint correctness, foreign keys, NOT NULL usage
- Data migrations, batching, avoiding full table scans

### infrastructure-expert
**Trigger:** `infrastructure/**`, `.github/workflows/**`, `Dockerfile`,
`docker-compose.yml`
- Infrastructure-as-code correctness, configuration management
- Security hardening, deployment safety
- Monitoring, alerting, backup strategies

### domain-expert
**Trigger:** `app/calculations/**`, `app/services/pricing/**`,
`lib/calculation_utilities.rb`, `config/business_rules.yml`
- Correctness of business rules and calculations
- Domain model fidelity — do the types match how the business thinks?
- Reference data and configuration correctness
- Edge cases the generic reviewers have no way to recognize

The last entry is the one worth adapting first. Generic reviewers catch generic
problems; nobody but a domain reviewer will notice that a rounding rule is wrong
or that a rate table is stale. Name it after your actual domain —
`claims-adjudication-expert`, `tax-rules-expert`, `scheduling-expert` — and
point the triggers at the code that encodes the rules.
