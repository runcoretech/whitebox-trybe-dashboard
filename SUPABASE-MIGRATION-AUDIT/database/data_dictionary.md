# WhiteBox RMOS Database Data Dictionary

This document provides a comprehensive data dictionary for the WhiteBox Relationship Operating System (RMOS) Supabase backend. It documents every table, column, relationship, constraint, check, and business purpose in plain, clear English.

---

## Table of Contents
1. [`workspaces`](#1-workspaces)
2. [`profiles`](#2-profiles)
3. [`workspace_settings`](#3-workspace_settings)
4. [`organizations`](#4-organizations)
5. [`contacts`](#5-contacts)
6. [`activities`](#6-activities)
7. [`boxes`](#7-boxes)
8. [`gifts`](#8-gifts)
9. [`calendar_events`](#9-calendar_events)
10. [`nudges`](#10-nudges)
11. [`cosmo_audits`](#11-cosmo_audits)
12. [`audit_logs`](#12-audit_logs)
13. [`contact_assignments`](#13-contact_assignments)
14. [`recovery_requests`](#14-recovery_requests)
15. [`integration_credentials`](#15-integration_credentials)
16. [`integration_mappings`](#16-integration_mappings)

---

## 1. `workspaces`
**Purpose:** Acts as the primary tenant container. All data in the system belongs to a specific workspace, enabling multi-tenant isolation.

| Column Name | Data Type | Key Type | Nullable | Default Value | Description / Constraints / Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `uuid` | Primary Key | No | `gen_random_uuid()` | Unique identifier for the workspace. |
| `name` | `text` | - | No | - | The name of the client organization or business unit. |
| `subdomain` | `text` | Unique | Yes | - | Unique subdomain string (e.g., `hq` or `chicago`) for tenant identification. |
| `logo_url` | `text` | - | Yes | - | URL path to the workspace's customized branding logo image. |
| `theme` | `jsonb` | - | No | `'{}'` | JSON structure containing custom color palettes, UI flags, and theme variants. |
| `created_at`| `timestamptz` | - | No | `timezone('utc', now())` | Record creation timestamp. |

---

## 2. `profiles`
**Purpose:** Holds employee, administrator, and user profiles. Synchronized directly with Supabase's internal `auth.users` authentication tables.

| Column Name | Data Type | Key Type | Nullable | Default Value | Description / Constraints / Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `uuid` | Primary Key, FK | No | - | Links directly to Supabase Auth (`auth.users.id`). Cascades on delete. |
| `email` | `text` | Unique | No | - | User's work email address. Must be unique. |
| `name` | `text` | - | No | - | User's full display name (e.g., `Paul K.`, `Tom Collins`). |
| `role` | `public.user_role`| - | No | `'rep'` | Enum constraints: `owner`, `executive`, `manager`, `rep`. *CPO/HR maps to executive.* |
| `manager_id`| `uuid` | Foreign Key | Yes | - | Self-referencing link to another profile representing reporting hierarchies. |
| `workspace_id`| `uuid` | Foreign Key | No | - | Links to `workspaces.id`. Defines which tenant this staff profile belongs to. |
| `avatar_url`| `text` | - | Yes | - | URL link to user's display avatar. |
| `status` | `profile_status` | - | No | `'active'` | Custom Enum check constraint: `active` or `revoked`. |
| `created_at`| `timestamptz` | - | No | `timezone('utc', now())` | Record creation timestamp. |

---

## 3. `workspace_settings`
**Purpose:** Stores configuration parameters that control RMOS automation thresholds, financial limits, webhook routes, and active integration switches.

| Column Name | Data Type | Key Type | Nullable | Default Value | Description / Constraints / Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `uuid` | Primary Key | No | `gen_random_uuid()` | Unique setting row identifier. |
| `workspace_id`| `uuid` | Foreign Key, Unique| No | - | Linked one-to-one to `workspaces.id`. Cascades on workspace deletion. |
| `decay_warning`| `integer` | - | No | `30` | Grace period in days before health starts decaying (must be non-negative). |
| `decay_critical`| `integer` | - | No | `60` | Threshold of days inactive before entering Fumble queue (must be > decay_warning). |
| `decay_factor`| `numeric(4,2)`| - | No | `1.50` | Decay rate multiplier per day of inactivity after warning period. |
| `target_conversion`| `integer`| - | No | `48` | Target conversion percentage threshold (must be between 0 and 100). |
| `hours_start`| `time` | - | No | `'09:00'` | Start time of the company's operating hours boundary. |
| `hours_end` | `time` | - | No | `'17:00'` | End time of operating hours. Must be greater than `hours_start`. |
| `nudge_cap` | `integer` | - | No | `5` | Cap on the number of daily notifications/nudges pushed to a single profile. |
| `auto_neglect`| `boolean` | - | No | `true` | When true, system auto-flags neglected contacts based on decay. |
| `manager_override`| `boolean` | - | No | `true` | When true, managers can bypass standard rules or reassign without owner check. |
| `alert_routing`| `boolean` | - | No | `true` | When true, routes critical decay alerts to external webhooks. |
| `budget_milestone`| `numeric(10,2)`| - | No | `45.00` | Average threshold per unit before triggering a budget warning. |
| `budget_monthly`| `numeric(10,2)`| - | No | `500.00` | Monthly budget limit for general gifting per representative. |
| `approval_gate`| `boolean` | - | No | `true` | When true, holds gifts above threshold in `awaiting_approval` queue. |
| `approval_threshold`| `numeric(10,2)`| - | No | `100.00` | Gift cost amount above which manual Owner approval is required. |
| `auto_gifting`| `boolean` | - | No | `true` | When true, allows AI auto-dispatching of milestone confections. |
| `webhook_slack`| `text` | - | No | `''` | Target webhook URL path for pushing alert payloads to Slack. |
| `webhook_teams`| `text` | - | No | `''` | Target webhook URL path for pushing alert payloads to MS Teams. |
| `integrations`| `jsonb` | - | No | *(JSON default)* | Boolean state map of integration activation status. |
| `updated_at`| `timestamptz` | - | No | `timezone('utc', now())` | Timestamp of last setting change. |

---

## 4. `organizations`
**Purpose:** Represents client businesses, strategic partners, and companies.

| Column Name | Data Type | Key Type | Nullable | Default Value | Description / Constraints / Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `uuid` | Primary Key | No | `gen_random_uuid()` | Unique identifier. |
| `name` | `text` | - | No | - | Display name of the corporation. Unique per workspace. |
| `sector` | `text` | - | Yes | - | Vertical category (e.g., `retail`, `healthcare`, `finance`). |
| `category` | `public.org_category`| - | No | `'prospect'` | Enum constraints: `enterprise`, `smb`, `prospect`. |
| `street_address`| `text` | - | Yes | - | Physical street address. |
| `city` | `text` | - | Yes | - | City name. |
| `province` | `text` | - | Yes | - | State or Province code. |
| `postal_code`| `text` | - | Yes | - | Postal/Zip code. |
| `phone` | `text` | - | Yes | - | Primary corporate office phone number. |
| `email` | `text` | - | Yes | - | Primary general email inbox. |
| `workspace_id`| `uuid` | Foreign Key | No | - | Workspace reference mapping this organization to its tenant scope. |
| `created_at`| `timestamptz` | - | No | `timezone('utc', now())` | Timestamp of organization record creation. |

---

## 5. `contacts`
**Purpose:** Individual people at customer companies or prospective leads. Tracks relationship health scores.

| Column Name | Data Type | Key Type | Nullable | Default Value | Description / Constraints / Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `uuid` | Primary Key | No | `gen_random_uuid()` | Unique identifier. |
| `org_id` | `uuid` | Foreign Key | Yes | - | Links to `organizations.id`. Cascades on deletion of organization. |
| `name` | `text` | - | No | - | Full name of the contact. |
| `email` | `text` | - | Yes | - | Personal work email address of contact. |
| `phone` | `text` | - | Yes | - | Cell or direct line number. |
| `assigned_rep_id`| `uuid` | Foreign Key | Yes | - | Links to `profiles.id` representing current account owner. |
| `status` | `text` | - | No | `'active'` | CHECK constraint limits to `active`, `inactive`, or `neglected`. |
| `relationship_health`| `integer`| - | No | `100` | Dynamic numeric representation of connection grade (between 0 and 100). |
| `ai_recommendation`| `text` | - | Yes | - | Narrative trigger recommendations compiled by Cosmo. |
| `workspace_id`| `uuid` | Foreign Key | No | - | Workspace isolation scope reference. |
| `created_at`| `timestamptz` | - | No | `timezone('utc', now())` | Record insertion timestamp. |

---

## 6. `activities`
**Purpose:** History log of calls, meetings, emails, proposals, and system touchpoints. Serves as the raw timeline input data for health calculations.

| Column Name | Data Type | Key Type | Nullable | Default Value | Description / Constraints / Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `uuid` | Primary Key | No | `gen_random_uuid()` | Unique touchpoint entry identifier. |
| `contact_id`| `uuid` | Foreign Key | Yes | - | Linked target recipient `contacts.id`. Cascades on delete. |
| `rep_id` | `uuid` | Foreign Key | Yes | - | Staff profile `profiles.id` that performed this activity. Null allowed (system logs). |
| `type` | `public.activity_type`| - | No | - | Enum constraints: `Call`, `Email`, `Meeting`, `Proposal`, `Gift`, `Note`, `System`. |
| `grade` | `public.activity_grade`| - | Yes | - | Custom score validation: `A`, `B`, `C`, `D`, `F` (quality of conversation). |
| `notes` | `text` | - | Yes | - | Narrative summaries or transcripts of the interaction. |
| `workspace_id`| `uuid` | Foreign Key | No | - | Tenant scope validation link. |
| `logged_at` | `timestamptz` | - | No | `timezone('utc', now())` | Timestamp of interaction. Used for age decay checks. |

---

## 7. `boxes`
**Purpose:** Inventory and configuration dictionary of the physical confections boxes available (e.g. Sweet, Pack, Premium). Prevents hardcoding prices.

| Column Name | Data Type | Key Type | Nullable | Default Value | Description / Constraints / Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `uuid` | Primary Key | No | `gen_random_uuid()` | Unique box product identifier. |
| `workspace_id`| `uuid` | Foreign Key | No | - | Scoped to a specific tenant workspace. |
| `name` | `text` | - | No | - | Product box display name (e.g., `Tech Essentials Box`, `Artisan Cookies`). |
| `description`| `text` | - | Yes | - | Box content descriptions. |
| `theme_color`| `text` | - | Yes | - | HEX or CSS color code assigned to the box theme branding. |
| `price` | `numeric(10,2)`| - | No | - | Transactional price cost (must be non-negative). |
| `is_active` | `boolean` | - | No | `true` | Status toggle allowing archiving of obsolete box designs. |
| `created_at`| `timestamptz` | - | No | `timezone('utc', now())` | Creation date. |

---

## 8. `gifts`
**Purpose:** Captures the transaction pipeline, carrier metrics, and shipping addresses for confections dispatches.

| Column Name | Data Type | Key Type | Nullable | Default Value | Description / Constraints / Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `uuid` | Primary Key | No | `gen_random_uuid()` | Unique identifier. |
| `contact_id`| `uuid` | Foreign Key | Yes | - | Links to `contacts.id`. |
| `rep_id` | `uuid` | Foreign Key | Yes | - | Profile `profiles.id` of sending representative. |
| `box_id` | `uuid` | Foreign Key | No | - | Product reference constraint linking to `boxes.id` (RESTRICT deletion policy). |
| `category` | `public.gift_category`| - | No | - | Enum constraints: `reach`, `retain`, `remember`, `reward`. |
| `amount` | `numeric(10,2)`| - | No | - | Snapshot of price at dispatch (historical pricing integrity check). |
| `status` | `public.gift_status`| - | No | `'pending'` | Enum: `pending`, `awaiting_approval`, `awaiting_design`, `quote_ready`, `approved`, etc. |
| `shipping_street`| `text`| - | Yes | - | Recipient street address. |
| `shipping_city`| `text` | - | Yes | - | Recipient city. |
| `shipping_province`| `text`| - | Yes | - | Recipient state/province. |
| `shipping_postal`| `text`| - | Yes | - | Recipient postal/zip code. |
| `carrier` | `text` | - | Yes | - | Logistics handler (e.g., `FedEx`, `UPS`, `DHL`). |
| `tracking_number`| `text`| - | Yes | - | Tracking link identifier package. |
| `sender_label`| `text` | - | Yes | - | Custom display name of the sender (e.g. `Paul K. (CEO)`). |
| `reason` | `text` | - | Yes | - | Context justification note (e.g. `1-year contract anniversary`). |
| `workspace_id`| `uuid` | Foreign Key | No | - | Tenant scope validation link. |
| `dispatched_at`| `timestamptz`| - | Yes | - | Date/time package left the warehouse. |
| `created_at`| `timestamptz` | - | No | `timezone('utc', now())` | Record insertion timestamp. |

---

## 9. `calendar_events`
**Purpose:** Scheduled events and follow-ups.

| Column Name | Data Type | Key Type | Nullable | Default Value | Description / Constraints / Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `uuid` | Primary Key | No | `gen_random_uuid()` | Unique event identifier. |
| `profile_id`| `uuid` | Foreign Key | No | - | Linked profile `profiles.id` that owns the schedule. |
| `type` | `text` | - | No | - | Classification string of event. |
| `target` | `text` | - | No | - | Subject title or client entity name. |
| `event_date`| `date` | - | No | - | Date scheduled. |
| `event_time`| `time` | - | Yes | - | Start time. |
| `agenda` | `text` | - | Yes | - | Description of details or targets. |
| `workspace_id`| `uuid` | Foreign Key | No | - | Tenant scope validation link. |
| `created_at`| `timestamptz` | - | No | `timezone('utc', now())` | Creation date. |

---

## 10. `nudges`
**Purpose:** Targeted operational warnings and notifications pushed to reps or administrators.

| Column Name | Data Type | Key Type | Nullable | Default Value | Description / Constraints / Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `uuid` | Primary Key | No | `gen_random_uuid()` | Unique alert identifier. |
| `profile_id`| `uuid` | Foreign Key | No | - | Linked profile recipient `profiles.id`. Cascades on deletion. |
| `message` | `text` | - | No | - | Text string of the notification warning. |
| `severity` | `severity_level`| - | No | `'warning'` | Enum: `info`, `warning`, `critical`. |
| `is_read` | `boolean` | - | No | `false` | Read status toggle. |
| `workspace_id`| `uuid` | Foreign Key | No | - | Tenant scope validation link. |
| `created_at`| `timestamptz` | - | No | `timezone('utc', now())` | Creation date. |

---

## 11. `cosmo_audits`
**Purpose:** Stores cached AI relationship audit narratives generated by Cosmo, protecting pipeline response performance.

| Column Name | Data Type | Key Type | Nullable | Default Value | Description / Constraints / Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `uuid` | Primary Key | No | `gen_random_uuid()` | Unique audit identifier. |
| `contact_id`| `uuid` | Foreign Key | No | - | Reference targeting `contacts.id`. Cascades on contact deletion. |
| `narrative` | `text` | - | No | - | Detailed narrative of risk analysis. |
| `severity` | `severity_level`| - | No | `'info'` | Custom Enum level constraint: `info`, `warning`, `critical`. |
| `workspace_id`| `uuid` | Foreign Key | No | - | Tenant scope validation link. |
| `created_at`| `timestamptz` | - | No | `timezone('utc', now())` | Creation date. |

---

## 12. `audit_logs`
**Purpose:** Partitioned security journal tracking all critical transactions, privilege alterations, and access events. Relies on a composite primary key to comply with range partitioning syntax rules in PostgreSQL.

| Column Name | Data Type | Key Type | Nullable | Default Value | Description / Constraints / Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `uuid` | Primary Key (Composite Part)| No | `gen_random_uuid()` | Unique transaction action identifier. |
| `workspace_id`| `uuid` | Foreign Key | No | - | Tenant tracking reference. |
| `actor_id` | `uuid` | Foreign Key | Yes | - | Profile `profiles.id` that performed the audited action. |
| `actor_name`| `text` | - | No | - | Display name of the user. |
| `role` | `public.user_role`| - | No | - | User role at time of transaction execution. |
| `action` | `text` | - | No | - | Internal command name (e.g. `settings.update`, `auth.logout`). |
| `entity_type`| `text` | - | No | - | Database table targeted (e.g., `gifts`, `workspace_settings`). |
| `entity_id` | `uuid` | - | Yes | - | Row UUID value of the changed record. |
| `client_ip` | `text` | - | Yes | - | IP address of user client source. |
| `user_agent`| `text` | - | Yes | - | Browser client metadata signature. |
| `old_values`| `jsonb` | - | Yes | - | Snapshot of column records before modification. |
| `new_values`| `jsonb` | - | Yes | - | Snapshot of column records post-execution. |
| `created_at`| `timestamptz` | Primary Key (Composite Part)| No | `timezone('utc', now())` | Creation date. *Composite primary key column and range partition key.* |

---

## 13. `contact_assignments`
**Purpose:** Historical ledger tracking relationship ownership changes. Documents reassignment logs and claiming justifications. Enforces a RESTRICT foreign key deletion policy to ensure transfer records are not orphaned if staff profiles are deleted.

| Column Name | Data Type | Key Type | Nullable | Default Value | Description / Constraints / Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `uuid` | Primary Key | No | `gen_random_uuid()` | Unique mapping identifier. |
| `workspace_id`| `uuid` | Foreign Key | No | - | Tenant scope validation link. |
| `contact_id`| `uuid` | Foreign Key | No | - | Target reassigned `contacts.id`. Cascades on deletion of contact. |
| `previous_rep_id`| `uuid`| Foreign Key | Yes | - | Profile `profiles.id` of the old representative who lost ownership. Null allowed if unassigned. |
| `new_rep_id`| `uuid` | Foreign Key | No | - | Profile `profiles.id` of the new representative claiming the client. Enforces RESTRICT on profile delete. |
| `assigned_by`| `uuid` | Foreign Key | No | - | User ID who executed/approved the transfer. Enforces RESTRICT on profile delete. |
| `justification`| `text` | - | No | - | Written validation details explaining the reason for the transfer. |
| `created_at`| `timestamptz` | - | No | `timezone('utc', now())` | Record insertion timestamp. |

---

## 14. `recovery_requests`
**Purpose:** Manages the approval gate for claiming neglected relationships from the shared Fumble pool. Enforces a CASCADE foreign key policy on requester profiles.

| Column Name | Data Type | Key Type | Nullable | Default Value | Description / Constraints / Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `uuid` | Primary Key | No | `gen_random_uuid()` | Unique request identifier. |
| `workspace_id`| `uuid` | Foreign Key | No | - | Tenant scope validation link. |
| `contact_id`| `uuid` | Foreign Key | No | - | Target `contacts.id` requested. Cascades on deletion. |
| `original_rep_id`| `uuid`| Foreign Key | Yes | - | Representative `profiles.id` who let the account decay. |
| `requester_rep_id`| `uuid`| Foreign Key | No | - | Rep `profiles.id` claiming ownership. Enforces CASCADE on profile delete. |
| `justification`| `text` | - | No | - | Action plan justification note. |
| `status` | `recovery_status`| - | No | `'pending'` | Enum: `pending`, `approved`, `rejected`, `expired`. |
| `reviewed_by`| `uuid` | Foreign Key | Yes | - | User profile `profiles.id` who acted on the request. |
| `rejection_reason`| `text` | - | Yes | - | Notes detailing why request was denied. |
| `created_at`| `timestamptz` | - | No | `timezone('utc', now())` | Submission timestamp. |
| `updated_at`| `timestamptz` | - | No | `timezone('utc', now())` | Review confirmation timestamp. |

---

## 15. `integration_credentials`
**Purpose:** Secures workspace API access packages and webhook connection configurations.

| Column Name | Data Type | Key Type | Nullable | Default Value | Description / Constraints / Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `uuid` | Primary Key | No | `gen_random_uuid()` | Unique connection credential row identifier. |
| `workspace_id`| `uuid` | Foreign Key | No | - | Tenant scope validation link. |
| `integration_name`| `text` | - | No | - | CHECK constraints include CRM, HRIS, Comm, VoIP, and TMS names. |
| `auth_payload`| `jsonb` | - | No | - | Encrypted credential payload data (tokens, secrets). |
| `is_active` | `boolean` | - | No | `true` | Connection state toggle. |
| `updated_at`| `timestamptz` | - | No | `timezone('utc', now())` | Timestamp of last setup modification. |

---

## 16. `integration_mappings`
**Purpose:** Maps local RMOS records (profiles, contacts, organizations, gifts) to external records in CRM, HRIS, or TMS systems.

| Column Name | Data Type | Key Type | Nullable | Default Value | Description / Constraints / Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | `uuid` | Primary Key | No | `gen_random_uuid()` | Unique map row identifier. |
| `workspace_id`| `uuid` | Foreign Key | No | - | Tenant scope validation link. |
| `local_entity_type`| `text` | - | No | - | Entity classification CHECK limit: `contact`, `organization`, `profile`, `gift`. |
| `local_entity_id`| `uuid` | - | No | - | Local database row UUID target. |
| `integration_name`| `text` | - | No | - | Mapped system identifier (e.g. `salesforce`, `hubspot`, `mcleod`). |
| `external_entity_id`| `text` | - | No | - | External API record ID string of partner platform. |
| `last_synced_at`| `timestamptz`| - | No | `timezone('utc', now())` | Last date/time synchronization completed successfully. |
