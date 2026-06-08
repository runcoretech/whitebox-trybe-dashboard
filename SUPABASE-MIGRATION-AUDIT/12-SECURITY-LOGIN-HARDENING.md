# 12 — Security & Login Hardening

## Current Front-End Protections

**File:** [login.html](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/public-website/login.html)

### A. Rate Limiting (Client-Side)

| Mechanism | Value | Description |
|:----------|:------|:------------|
| `failedAttempts` counter | Starts at 0 | Increments on each invalid login |
| Max attempts before lockout | 3 | After 3 failed attempts, lockout triggers |
| Lockout duration | 30 seconds | Login form is disabled during countdown |
| Lockout message | `"Too many failed attempts. Portal locked. Please wait X seconds."` | Displayed in error text |

### B. Lockout Countdown Function

**Function:** `startLockoutCountdown(seconds)` (Line 396)

```javascript
function startLockoutCountdown(seconds) {
    // Disables form inputs
    // Shows countdown timer in error text
    // Re-enables form after countdown expires
    // Resets failedAttempts to 0
}
```

### C. Error Messages

| Attempt | Message |
|:--------|:--------|
| 1st failure | `"Invalid work email or password. Attempt 1 of 3 before lockout."` |
| 2nd failure | `"Invalid work email or password. Attempt 2 of 3 before lockout."` |
| 3rd failure | Triggers 30-second lockout |
| During lockout | `"Too many failed attempts. Portal locked. Please wait X seconds."` |

### D. Limitations of Current Approach

> [!CAUTION]
> **ALL current security measures are CLIENT-SIDE ONLY.** They provide zero actual protection because:
> 1. The `users.json` file is publicly accessible via direct URL
> 2. `failedAttempts` resets on page refresh
> 3. Lockout is JavaScript-only — disabled by opening DevTools
> 4. Credentials are compared in the browser, not on a server
> 5. No CSRF tokens, no session management, no server-side validation
> 6. A bot can bypass everything by fetching `users.json` directly

## Backend Security Requirements for Supabase Migration

### Authentication
| Requirement | Implementation |
|:------------|:---------------|
| Server-side credential validation | `supabase.auth.signInWithPassword()` |
| Password hashing | Handled by Supabase Auth (bcrypt) |
| Session tokens | Supabase JWT tokens (httpOnly cookies recommended) |
| Delete `users.json` files | Both `public-website/users.json` and `public/users.json` |

### Rate Limiting
| Requirement | Implementation |
|:------------|:---------------|
| Server-side rate limiting | Supabase Edge Function + rate limiter middleware |
| IP-based throttling | Cloudflare rate limiting rules on the subdomain |
| Account lockout | Supabase Auth lockout config (configurable attempts + duration) |
| CAPTCHA on lockout | Google reCAPTCHA v3 or Cloudflare Turnstile after N failures |

### Session Security
| Requirement | Implementation |
|:------------|:---------------|
| Concurrent session isolation | Each user gets their own JWT — sessions are independent |
| Cross-user session leakage prevention | Supabase RLS + `auth.uid()` ensures data isolation |
| Session expiry | Configurable JWT expiry in Supabase Auth settings |
| Refresh token rotation | Supabase handles this automatically |

### Bot Protection
| Requirement | Implementation |
|:------------|:---------------|
| Automated login prevention | CAPTCHA integration on login form |
| API abuse prevention | Rate limit Supabase Edge Functions |
| Credential stuffing defense | Account lockout after N failures + email notification |
| Brute force protection | Exponential backoff on failed attempts (server-side) |

### Multi-User Concurrency
| Requirement | Implementation |
|:------------|:---------------|
| 100+ simultaneous logins | Supabase handles this natively (PostgreSQL connection pooling) |
| No session collision between roles | Each session is tied to `auth.uid()` — completely isolated |
| Owner login doesn't affect rep login | Separate JWT tokens per user, no shared state |

---

## Supabase Migration Notes

| Current | Target |
|:--------|:-------|
| `users.json` plaintext file | **DELETE** — replaced by Supabase Auth |
| Client-side credential comparison | `supabase.auth.signInWithPassword()` |
| `failedAttempts` JS variable | Server-side lockout in Supabase Auth config |
| `startLockoutCountdown()` JS function | Server responds with 429 Too Many Requests |
| No CAPTCHA | Cloudflare Turnstile or reCAPTCHA v3 |
| No session management | Supabase JWT + refresh token rotation |
| `localStorage` auth tokens | Supabase session management (auto-handles tokens) |
