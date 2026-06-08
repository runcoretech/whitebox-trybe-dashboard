# 01 — Mock Users & Authentication Credentials

## A. Mock Login Accounts

**File:** [users.json](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/public-website/users.json)  
**Duplicate:** [public/users.json](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/public/users.json) (Vite build copy — identical content)

| Email | Password | Role | Display Name | Dashboard Scope |
|:------|:---------|:-----|:-------------|:----------------|
| `owner@whitebox.com` | `wb_owner_2026!` | `owner` | Paul K. | Full org-wide read/write + Settings |
| `executive@whitebox.com` | `wb_exec_2026!` | `hr` | Sarah Lansky | Full org-wide read (Chief People Officer) |
| `manager@whitebox.com` | `wb_mgr_2026!` | `manager` | Marcus Dupond | Self + direct team reports |
| `rep@whitebox.com` | `wb_rep_2026!` | `rep` | Tom Collins | Self only |

> [!WARNING]
> Passwords are stored in **plaintext JSON** and fetched client-side via `fetch('/users.json')`. This MUST be replaced with Supabase Auth (email/password provider) during migration. The `users.json` files must be deleted entirely.

## B. Authentication Flow (Current)

**File:** [login.html](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/public-website/login.html)

1. User enters email + password on `login.html`
2. JS fetches `users.json` via `fetch()`
3. Credentials are compared client-side against the JSON object
4. On success, the following are stored in `localStorage`:
   - `whitebox_role` → user's role string
   - `whitebox_username` → user's display name
   - `whitebox_logged_in` → `'true'`
5. User is redirected to `dashboard/index.html`
6. On failure, `failedAttempts` counter increments (see Section 12)

## C. Auth State Reads (Dashboard Side)

**File:** [main-dashboard-v34.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/dashboard/main-dashboard-v34.js)

The dashboard reads auth state at initialization via:
```javascript
const savedRole = localStorage.getItem('whitebox_role') || 'owner';  // default fallback
const savedName = localStorage.getItem('whitebox_username') || 'Paul K.';
```

**Fallback defaults:** If no `localStorage` token exists, the dashboard defaults to `owner` / `Paul K.` — this means an unauthenticated user sees the full owner dashboard. This must be replaced with a Supabase auth session check + redirect.

## D. Auth State Reads (Public Website Side)

**File:** [main-theme-v34.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/public-website/main-theme-v34.js)

Multiple locations read auth state for UI toggles:
- **Line 3793–3794:** Reads `whitebox_role` and `whitebox_username` for software page role-aware rendering
- **Line 9414–9415:** Reads `whitebox_role` and `whitebox_username` for dashboard role selector initialization
- **Line 10866:** Reads `whitebox_role` for overview panel visibility
- **Line 18317:** Reads `whitebox_role` for employee leaderboard tab control
- **Line 28868:** Reads `whitebox_role` for sidebar navigation visibility
- **Line 29010–29012:** Listens for `storage` event changes to sync auth state across tabs

## E. Cross-Tab Synchronization

**File:** `main-theme-v34.js`, Line 29010

```javascript
window.addEventListener('storage', function(e) {
    if (e.key === 'whitebox_role' || e.key === 'whitebox_username' || e.key === null) {
        // Re-renders UI based on new role
    }
});
```

This ensures that if a user logs in from one tab, other open tabs of the website detect the change and update their UI (e.g., "Sign In" becomes "Signed In", Dashboard button appears). This behavior must be preserved via Supabase `onAuthStateChange()` listener.

---

## Supabase Migration Notes

| Current | Target |
|:--------|:-------|
| `users.json` plaintext credentials | Supabase Auth (email/password provider) |
| `localStorage` role/name tokens | Supabase session + `profiles` table lookup |
| Client-side credential comparison | Server-side auth via `supabase.auth.signInWithPassword()` |
| Default fallback to owner role | Redirect to login if no active session |
| `storage` event listener for cross-tab sync | `supabase.auth.onAuthStateChange()` |
