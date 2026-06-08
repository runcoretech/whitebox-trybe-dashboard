# WhiteBox GiftWorks — Supabase Migration Audit Report

**Audit Date:** June 7, 2026  
**Auditor:** Antigravity IDE  
**Scope:** Complete identification of all mock, demo, sample, hardcoded, seeded, and temporary data across the entire WhiteBox GiftWorks project.  
**Purpose:** Prepare the application for a future Supabase integration while preserving ALL existing functionality, routing, analytics, KPI calculations, permissions, and role-based visibility.

> [!CAUTION]
> **DO NOT modify, delete, refactor, or replace any code based on this audit.** This document is a read-only blueprint. All changes will be made in a separate migration phase.

---

## Table of Contents

| Section | File | Description |
|:--------|:-----|:------------|
| 01 | `01-MOCK-USERS-AND-AUTH.md` | All mock user accounts, credentials, login logic, and auth state management |
| 02 | `02-MOCK-EMPLOYEES.md` | Employee records, hierarchy, management chains |
| 03 | `03-MOCK-CUSTOMERS-PROSPECTS.md` | Customer and prospect organization records |
| 04 | `04-MOCK-TOUCHPOINTS-ACTIVITIES.md` | Client graph data, touchpoint logs, timeline history |
| 05 | `05-MOCK-GIFTING-DATA.md` | Gift dispatch schedule, active B2B orders, calendar events, spend ledger generation |
| 06 | `06-MOCK-LEADERBOARD-DATA.md` | Overview and employees leaderboard datasets across all timeframes |
| 07 | `07-MOCK-AI-COSMO-DATA.md` | COSMO Jarvis AI audit cards, insight descriptions, and role-specific audit panels |
| 08 | `08-MOCK-EXECUTIVE-OWNER-DATA.md` | Executive calendar events, nudges, activity history, live activity feed |
| 09 | `09-KPI-CALCULATIONS.md` | All KPI cards, metrics, counters, graphs, and how they are calculated |
| 10 | `10-ROLE-PERMISSIONS-ROUTING.md` | Role-based visibility, localStorage tokens, view mode toggles, routing rules |
| 11 | `11-SETTINGS-CONFIGURATION.md` | RMOS settings defaults, budget thresholds, integrations, webhook configs |
| 12 | `12-SECURITY-LOGIN-HARDENING.md` | Front-end login rate limiting, lockout logic, bot protection |
| 13 | `13-ENTITY-RELATIONSHIP-DIAGRAM.md` | Full ERD for recommended Supabase schema |
| 14 | `14-SUPABASE-SCHEMA-BLUEPRINT.md` | Recommended PostgreSQL tables, RLS policies, and migration SQL |
| 15 | `15-ADDENDUM-RECHECK-FINDINGS.md` | Recheck addendum: 10 additional findings — analyticsDataSets, recoveryBoard, seats, TODOs, fallback timelines, software page demo data, duplicate public-website JS layer, **dashboard/index.html 682KB inline HTML data**, software.js magnet names, spend-ledger filler arrays |
| 16 | `16-FINAL-SWEEP-FINDINGS.md` | Final sweep: 10 deep-code structures — employeeSectorTimeframeData, calendarEventsDB, activeB2BOrders, categorySpends, mockSectors, bonusRep4–10 (7 phantom employees), activeAuditsDB, auditNameMapping, mockTargets/mockActions, liveActivityFeed |
| 17 | `17-COMPLETE-APPLICATION-MAP.md` | **Definitive complete map**: every view (15), modal (15), KPI card (30+), graph (10), routing rule, localStorage key (8), data flow chain, entity master list (60+ names), hardcoded date |
| 18 | `18-REPORTING-AND-EXPORTS.md` | Detailed mapping of all document generation, CSV exports, and printable statements across role dashboards |

---

## Files Containing Mock Data (Master Index)

| File | Path | Contains |
|:-----|:-----|:---------|
| `users.json` | `public-website/users.json` | 4 mock login credentials |
| `users.json` | `public/users.json` | Duplicate of above (Vite build copy) |
| `login.html` | `public-website/login.html` | Login form, rate limiting, lockout logic, users.json fetch |
| `main-dashboard-v34.js` | `dashboard/main-dashboard-v34.js` | **Primary source** — ALL mock data arrays, business logic, KPIs, permissions |
| `spend-ledger-modal.js` | `dashboard/spend-ledger-modal.js` | Dynamic mock filler row generation for spend ledger |
| `main-theme-v34.js` | `public-website/main-theme-v34.js` | localStorage auth state reads, role-based UI toggles |
| `index.html` | `dashboard/index.html` | Inline COSMO audit card HTML with hardcoded descriptions |

---

## Key localStorage Tokens Used

| Token Key | Purpose | Set By | Read By |
|:----------|:--------|:-------|:--------|
| `whitebox_role` | Current user role (`owner`, `hr`, `manager`, `rep`) | `login.html` | All dashboard JS + public-website JS |
| `whitebox_username` | Current user display name | `login.html` | All dashboard JS + public-website JS |
| `whitebox_logged_in` | Boolean login state flag | `login.html` | Public website nav buttons |
| `rmos_system_settings` | JSON blob of all RMOS operating parameters | Settings panel | Dashboard init, `getInactivityStatus()` |
| `rmos_provisioned_seats` | JSON array of provisioned user seats | Settings panel | Seat management UI |
| `rmos-sidebar-collapsed` | Sidebar collapse state | Sidebar toggle | Sidebar init |
