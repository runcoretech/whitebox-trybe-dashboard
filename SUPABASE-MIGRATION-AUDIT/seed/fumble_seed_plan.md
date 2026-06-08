# WhiteBox RMOS Dashboard - Fumble & Recovery Seed Plan

This document establishes the detailed migration plan for the WhiteBox RMOS Fumble Detection System, relationship health decay thresholds, and account recovery claim mechanisms.

---

## 1. Fumble & Neglect Categories

The RMOS Fumble detector automatically flags client accounts based on their inactivity. We map these categories to settings thresholds defined in the database:

| Status Zone | Inactivity Range (Default Settings) | Dynamic Decay Action | UI Representation |
| :--- | :--- | :--- | :--- |
| **Healthy Zone** | `< 30 days` | No health decay. base health at 100%. | Green badge indicators. |
| **Warning Zone** | `30 to 59 days` | Health decays by `decay_factor` (default 1.50) per day past 30. | Orange warning badge. |
| **Critical Neglect** | `60 to 74 days` | Health decays heavily. Account enters critical alert. | Red neglect badge; added to Recovery Queue count. |
| **Open Fumble Pool** | `>= 75 days` (`decay_critical + 15`) | Account ownership is unlocked. Any Rep can claim/request reassignment. | Appears in public Fumble Recovery board. |

---

## 2. Inactivity Threshold Configuration (`workspace_settings`)

All thresholds must be mapped to columns in the `workspace_settings` table to avoid hardcoding:

*   **Warning Threshold (`decay_warning`):** `30` (days) - triggers orange alert.
*   **Critical Threshold (`decay_critical`):** `60` (days) - triggers red alert / automatic neglect status.
*   **Decay Coefficient (`decay_factor`):** `1.50` - health penalty per day past warning.
*   **Automated Flagging (`auto_neglect`):** `true` - enables automatic status transitions on cron cycles.

---

## 3. Seed Accounts Inactivity Configuration (Target Data Mappings)

To verify the Fumble detector computes exact mock statuses, the seed script will log historical touchpoints backdating from the present date:

| Account Name | Target Neglect Zone | Target Inactive Days | Seeded Last Touchpoint Date | Seeded Base Health | Decayed Health in View |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Vanguard Health** | Open Fumble Pool | `84 days` | `now() - INTERVAL '84 days'` | `74%` | `74 - (84-30)*1.5 = 74 - 81 = 0%` (capped at `38%` base fallback) |
| **Pinnacle Brands** | Critical Neglect | `68 days` | `now() - INTERVAL '68 days'` | `100%` | `100 - (68-30)*1.5 = 100 - 57 = 43%` |
| **Orion Biotech** | Critical Neglect | `64 days` | `now() - INTERVAL '64 days'` | `100%` | `100 - (64-30)*1.5 = 100 - 51 = 49%` |
| **Chevron Logistics** | Warning Zone | `42 days` | `now() - INTERVAL '42 days'` | `90%` | `90 - (42-30)*1.5 = 90 - 18 = 72%` |

---

## 4. Recovery Request Claim & Approval Logic

When a Rep claims an open pool account from the Fumble board, the transaction maps to the `recovery_requests` table:

*   **Original Rep (`original_rep_id`):** Mapped to the current neglected owner (e.g. Tom Collins).
*   **Claiming Rep (`requester_rep_id`):** Mapped to the active user claiming the account (e.g. Marcus Dupond).
*   **Justification:** User-supplied reasoning (seeded with mock justifications like `'Outlined 3-step outbound gifting sequence to restore relationship.'`).
*   **Status Lifecycle:** Mapped to the `public.recovery_status` enum:
    *   `pending`: Requested claim awaiting manager or owner sign-off.
    *   `approved`: Transferred ownership. Triggers automatic insertion into `public.contact_assignments` history.
    *   `rejected`: Denied claim with associated manager note.

---

## 5. Contact Assignments (Ownership Transfer History)

To verify history integrity, we seed the `contact_assignments` ledger with historical reassignments:

1.  **Vanguard Health:** Mapped as historically reassigned from *Tom Collins* to *Paul K.*
    *   `assigned_by`: `Paul K.` (Owner)
    *   `justification`: `'Owner emergency intervention: account inactive for 84 days.'`
    *   `created_at`: `now() - INTERVAL '2 days'`

---

## 6. Recovery Leaderboard

The recovery leaderboard is calculated dynamically by joining profiles and resolved claims:

```sql
CREATE OR REPLACE VIEW public.recovery_leaderboard AS
SELECT 
    p.id AS profile_id,
    p.name,
    p.workspace_id,
    COUNT(rr.id) FILTER (WHERE rr.status = 'approved') AS successful_recoveries
FROM public.profiles p
LEFT JOIN public.recovery_requests rr ON rr.requester_rep_id = p.id
GROUP BY p.id, p.name, p.workspace_id;
```
This ensures reps are recognized dynamically based on real database records rather than static arrays.
