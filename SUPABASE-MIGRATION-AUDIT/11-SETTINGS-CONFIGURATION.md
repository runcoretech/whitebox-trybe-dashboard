# 11 — Settings Configuration Defaults

## Data Location

**File:** [main-dashboard-v34.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/dashboard/main-dashboard-v34.js)  
**Variable:** `window.rmosSettings` (Line 233881)

## Default Settings Object

```javascript
window.rmosSettings = {
    // General Operating Parameters
    decayWarning: 30,          // Inactivity Warning Threshold (days)
    decayCritical: 60,         // Critical Neglect Threshold (days)
    targetConversion: 48,      // Target Conversion Rate (%)
    hoursStart: '09:00',       // Operating Hours Start
    hoursEnd: '17:00',         // Operating Hours End
    nudgeCap: 5,               // Max AI nudges per day
    autoNeglect: true,         // Auto-flag neglected accounts
    managerOverride: true,     // Allow managers to override rep assignments
    alertRouting: true,        // Route alerts to managers

    // Financial Policies & Budget
    budgetMilestone: 45.00,    // Per-milestone budget cap ($)
    budgetMonthly: 500.00,     // Monthly gifting budget cap ($)
    approvalGate: true,        // Require owner approval for gifts
    approvalThreshold: 100.00, // Auto-approve gifts under this amount ($)
    autoGifting: true,         // AI auto-gifting enabled

    // Operational Alert Webhooks
    webhooks: {
        slack: '',             // Slack Webhook URL
        teams: ''              // Microsoft Teams Connector URL
    },

    // Integration Connections
    integrations: {
        salesforce: false,     // Salesforce CRM
        hubspot: false,        // HubSpot CRM
        twilio: false,         // Twilio (SMS/Voice)
        ringcentral: false,    // RingCentral
        gmail: false,          // Gmail
        outlook: false         // Outlook
    }
};
```

## Settings Persistence

- Settings are stored in `localStorage` under key `rmos_system_settings` as a JSON blob
- On dashboard load, saved settings are merged with defaults:
  ```javascript
  const savedSettings = localStorage.getItem('rmos_system_settings');
  if (savedSettings) {
      const parsed = JSON.parse(savedSettings);
      window.rmosSettings = { ...window.rmosSettings, ...parsed };
  }
  ```
- When the user saves any settings panel, the full object is re-serialized to `localStorage`

## Settings Impact on Dashboard

| Setting | Dashboard Impact |
|:--------|:----------------|
| `decayWarning` (30) | `getInactivityStatus()` returns `'orange'` at this threshold |
| `decayCritical` (60) | `getInactivityStatus()` returns `'red'` at this threshold |
| `targetConversion` (48) | Displayed as conversion target on KPI cards |
| `budgetMilestone` (45) | Per-gift budget validation |
| `budgetMonthly` (500) | Monthly spend cap validation |
| `approvalGate` (true) | Controls whether owner approval is required for non-auto gifts |
| `approvalThreshold` (100) | Gifts under this amount auto-approve |
| `autoGifting` (true) | Enables AI-driven automatic gift dispatches |

## Seat Provisioning

**localStorage key:** `rmos_provisioned_seats`

The Settings → User Management panel maintains a list of provisioned seats stored in localStorage. Each seat contains:

| Field | Description |
|:------|:------------|
| `name` | User display name |
| `email` | Corporate email |
| `role` | Assigned role (owner, hr, manager, rep) |
| `status` | Active / Revoked |

**Seat Limits:**
- Default seat allocation limit exists (configurable)
- Adding users beyond the limit triggers: `"Seat allocation limit reached! Please release an active seat or upgrade."`
- Duplicate email check: `"Corporate email is already provisioned in another active seat."`

## Workspace Branding

Settings panel allows:
- Custom logo upload (max 2MB, stored as base64 in localStorage)
- Theme color customization
- Reset to default WhiteBox branding

---

## Supabase Migration Notes

| Current | Target |
|:--------|:-------|
| `window.rmosSettings` JS object | `workspace_settings` table (one row per workspace) |
| `localStorage('rmos_system_settings')` | Supabase row in `workspace_settings` |
| `localStorage('rmos_provisioned_seats')` | `profiles` table with `status` column |
| Webhook URLs in settings | `workspace_settings.webhook_slack`, `workspace_settings.webhook_teams` |
| Integration booleans | `workspace_integrations` table or JSON column |
| Logo as base64 in localStorage | Supabase Storage bucket + URL in `workspace_settings` |
