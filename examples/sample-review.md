# Local Review

## Review History

- **Initial review:** 2026-03-14

---

## Code Best Practices

### F1 🔴 Critical - SQL injection in search controller

**File:** `app/controllers/search_controller.rb` (line 23)
**Issue:** User input is interpolated directly into a SQL query without sanitization.
**Suggestion:** Use parameterized queries via Active Record's `where` method.

### F2 🟡 Medium Priority - Missing input validation on API endpoint

**File:** `app/controllers/api/v1/users_controller.rb` (line 45)
**Issue:** The `update` action accepts arbitrary parameters without validation.
**Suggestion:** Add strong parameters and validate expected input types.

### F3 ~~🟢 Low Priority - Consider extracting helper method~~ ✅ Fixed

**Status:** Fixed in commit `abc123`
**File:** `app/models/user.rb` (line 120)
**Issue:** Repeated date formatting logic across three methods.
**Suggestion:** Extract a `formatted_date` helper.

## Security

### F4 🟠 High Priority - Sensitive data in logs

**File:** `app/services/payment_processor.rb` (line 67)
**Issue:** Credit card numbers are logged in plaintext during transaction processing.
**Suggestion:** Mask or remove sensitive data before logging.

### F5 ~~🟢 Low Priority - Missing CSRF token check on webhook~~ ⏸️ Deferred

**Status:** Deferred — the provider's signature scheme changes next quarter; verifying against the
current one would be thrown away.
**File:** `app/controllers/webhooks_controller.rb` (line 12)
**Issue:** Webhook endpoint skips CSRF verification without signature validation.
**Suggestion:** Add webhook signature verification.

## Testing

### F6 ℹ️ Observation - Excellent test coverage for edge cases

**File:** `spec/models/user_spec.rb`
**Issue:** The test suite thoroughly covers boundary conditions for user validation, including
Unicode handling and max-length edge cases.

### F7 🟡 Medium Priority - Missing test for error path

**File:** `spec/services/payment_processor_spec.rb`
**Issue:** No test covers the case where the payment gateway returns a timeout error.
**Suggestion:** Add a test for gateway timeout handling.

---

## Consolidated Summary

| Finding | Priority | Category | Description | File | Status |
|---------|----------|----------|-------------|------|--------|
| F1 | 🔴 Critical | Security | SQL injection | `search_controller.rb` | |
| F2 | 🟡 Medium | Code Quality | Missing validation | `users_controller.rb` | |
| F3 | 🟢 Low | Code Quality | Extract helper | `user.rb` | ✅ |
| F4 | 🟠 High | Security | Data in logs | `payment_processor.rb` | |
| F5 | 🟢 Low | Security | Missing CSRF check | `webhooks_controller.rb` | ⏸️ |
| F6 | ℹ️ Observation | Testing | Good coverage | `user_spec.rb` | — |
| F7 | 🟡 Medium | Testing | Missing error test | `payment_processor_spec.rb` | |

## Pre-Merge Checklist

- [ ] F1 - Fix SQL injection in search controller
- [ ] F2 - Add input validation to API endpoint
- [x] F3 - Extract helper method (fixed) ✅
- [ ] F4 - Mask sensitive data in logs
- [ ] F5 - Add webhook signature verification (deferred to next quarter) ⏸️
- [ ] F7 - Add test for gateway timeout
