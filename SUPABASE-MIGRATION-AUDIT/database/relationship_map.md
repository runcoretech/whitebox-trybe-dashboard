# WhiteBox RMOS Database Relationship Map

This document charts the relational map of the WhiteBox RMOS Supabase database. It categorizes relationships into distinct logic layers: Entity, Ownership, Gifting, Reporting, Recovery, Security Audits, and Integrations.

---

## 1. Complete Entity Relationship Overview (Mermaid)

```mermaid
erLockout -- ER Diagram --
erDiagram
    workspaces ||--o{ profiles : "has users"
    workspaces ||--|| workspace_settings : "has configuration"
    workspaces ||--o{ organizations : "owns companies"
    workspaces ||--o{ contacts : "owns individuals"
    workspaces ||--o{ activities : "contains logs"
    workspaces ||--o{ boxes : "contains products"
    workspaces ||--o{ gifts : "dispatches confections"
    workspaces ||--o{ calendar_events : "schedules milestones"
    workspaces ||--o{ nudges : "issues alerts"
    workspaces ||--o{ cosmo_audits : "stores narratives"
    workspaces ||--o{ audit_logs : "records actions"
    workspaces ||--o{ contact_assignments : "tracks transfers"
    workspaces ||--o{ recovery_requests : "manages claims"
    workspaces ||--o{ integration_credentials : "secures APIs"
    workspaces ||--o{ integration_mappings : "routes syncs"

    profiles ||--o{ contacts : "assigned rep"
    profiles }|--|? profiles : "reports to manager"
    profiles ||--o{ activities : "logs touchpoint"
    profiles ||--o{ gifts : "sends gift"
    profiles ||--o{ calendar_events : "owns calendar"
    profiles ||--o{ nudges : "receives warnings"
    profiles ||--o{ recovery_requests : "requests or reviews claims"

    organizations ||--o{ contacts : "employs"
    contacts ||--o{ activities : "timeline target"
    contacts ||--o{ gifts : "receives confections"
    contacts ||--o{ cosmo_audits : "analyzed by"
    contacts ||--o{ recovery_requests : "fumble subject"
```

---

## 2. Relational Mapping by Logic Layers

### Entity Layer
*   **`workspaces` to `organizations` (One-to-Many):** A tenant workspace contains multiple client organizations.
*   **`organizations` to `contacts` (One-to-Many):** An organization contains multiple individual contacts.
*   **`contacts` to `activities` (One-to-Many):** A contact holds a chronological timeline of CRM touchpoints.

### Ownership & Scope Layer
*   **`workspaces` to All Tables (One-to-Many / One-to-One):** Every table contains a `workspace_id` column. RLS uses this to enforce multi-tenant isolation.
*   **`profiles` to `contacts` (One-to-Many):** A representative profile (`assigned_rep_id`) is assigned to manage specific contacts.
*   **`profiles` to `activities` (One-to-Many):** A representative logs CRM touchpoints (`rep_id` references the profile logging the call or email).

### Gifting Layer
*   **`boxes` to `gifts` (One-to-Many):** A box product (from the active inventory directory) is assigned to a gifting order via `box_id`.
*   **`profiles` to `gifts` (One-to-Many):** A representative triggers or schedules a gifting dispatch order (`rep_id` tracks the sender).
*   **`contacts` to `gifts` (One-to-Many):** A contact acts as the recipient of the gift dispatch order (`contact_id` tracks the destination user).

### Reporting Hierarchy Layer
*   **`profiles` to `profiles` (Self-Referential / One-to-Many):** The `manager_id` foreign key maps user profiles back to a manager. This forms the organizational hierarchy.
    *   *Managers* can access direct reports by querying `manager_id = auth.uid()`.
    *   *Executives/Owners* overlook the entire workspace tree.

### Recovery (Fumble) Layer
*   **`contacts` to `recovery_requests` (One-to-Many):** A neglected contact can be the subject of multiple reassignment claims over its lifecycle.
*   **`profiles` to `recovery_requests` (Many-to-One / Dual Mapping):**
    *   `requester_rep_id` tracks the rep seeking to claim the neglected account. (Enforces `ON DELETE CASCADE` policy).
    *   `original_rep_id` tracks the rep who let the account decay.
    *   `reviewed_by` tracks the Manager or Owner who approved/rejected the claim.
*   **`contacts` to `contact_assignments` (One-to-Many):** Tracks ownership history for audits.
    *   `previous_rep_id` and `new_rep_id` track the reassignment loop.
    *   `assigned_by` tracks the authorizing user (both new rep and author fields enforce `ON DELETE RESTRICT` to protect audit trail integrity).

### Security & Audit Layer
*   **`profiles` to `audit_logs` (One-to-Many):** System operations logged inside `audit_logs` reference the user profile (`actor_id`) executing the transaction.
*   **`profiles` to `nudges` (One-to-Many):** Operational system notifications and warning alerts target specific profiles (`profile_id`).

### Integration Layer
*   **`workspaces` to `integration_credentials` (One-to-Many):** A tenant workspace configures credentials and tokens per integrated external partner platform.
*   **`integration_mappings` to All Entities (Polymorphic Mapping):** Maps a local entity ID (`local_entity_id`) and table type (`local_entity_type`) to its corresponding ID in an external CRM, HRIS, or TMS.
