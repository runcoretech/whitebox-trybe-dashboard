# 07 — Mock COSMO Jarvis AI Data

## Overview

COSMO Jarvis is the AI-branded intelligence engine in the dashboard. All its "intelligence" is currently hardcoded mock data — audit cards, insight descriptions, and recommendation text.

## A. COSMO Audit Cards (Inline HTML)

**File:** [dashboard/index.html](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/dashboard/index.html)  
**Also in:** [main-dashboard-v34.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/dashboard/main-dashboard-v34.js), Lines 100–270

### Owner Dashboard COSMO Audit Cards (Lines ~145–270)

| Card # | Target | Type | Title | Priority | Description |
|:-------|:-------|:-----|:------|:---------|:------------|
| 1 | Vanguard Health | customer | Account Neglect Risk | Urgent | Exceeded 34 days inactivity. Reassigning to Paul K. (CEO). |
| 2 | Nova Financial | customer | Renewal Appreciation Sync | Low | Q3 contract renewal approaching. Health at 91%. |
| 3 | Chevron Logistics | prospect | Prospect Bottleneck | High | Prospect for 42 days, zero manual touches. |
| 4 | Apex Solutions | prospect | Outreach ROI Acceleration | Medium | Health decayed to 82%. Physical intros convert 2.8x faster. |

### Rep Dashboard COSMO Audit Cards (Lines ~145–200)

| Card # | Target | Type | Title | Priority | Description |
|:-------|:-------|:-----|:------|:---------|:------------|
| 1 | Vanguard Health | customer | Account Neglect Risk | Urgent | Exceeded 34 days inactivity. |
| 2 | Pinnacle Brands | customer | Renewal Appreciation Sync | Medium | Contract renewal approaching. Health at 62%, 68 days inactive. |
| 3 | Chevron Logistics | prospect | Prospect Bottleneck | High | 42 days with zero manual touches. |
| 4 | Orion Biotech | prospect | Prospect Bottleneck | Medium | 64 days in prospect stage, health at 54%. |

### Executive Dashboard COSMO Audit Cards

Similar set of cards but with executive-level language (e.g., "reassigning ownership to CEO", org-wide metrics).

### Manager Dashboard COSMO Audit Cards

Focus on team-level management — Dwight Schrute's 0% conversion rate, Sarah Lansky's burnout risk, etc.

## B. `activeAuditsDB` — COSMO Insight Descriptions Database

**File:** `main-dashboard-v34.js`, Line 227125

This object maps entity names to COSMO's narrative description text, used when clicking audit cards or opening COSMO's detail view.

```javascript
const activeAuditsDB = {
    "Dwight Schrute": "Dwight Schrute is active and logged 14 touches this week, but has yielded a 0% conversion rate...",
    "Sarah Lansky": "Sarah Lansky successfully resolved 14 at-risk relational warnings within 4 days...",
    "Vanguard Health": "Vanguard Health exceeded threshold inactivity levels (34 days neglected)...",
    "Vanguard Logistics": "Vanguard Health exceeded threshold inactivity levels...",
    "Nova Financial": "Nova Financial has Q3 contract renewal approaching in June...",
    "Nova Healthcare": "Nova Financial has Q3 contract renewal approaching...",
    "Chevron Logistics": "Chevron Logistics has remained a prospect for 42 days...",
    "Chevron Solutions": "Chevron Logistics has remained a prospect for 42 days...",
    "Apex Solutions": "Apex Solutions' relationship health has decayed to 82%...",
    "Apex Global Retail": "Apex Solutions' relationship health has decayed to 82%..."
};
```

> [!NOTE]
> Some entries are **duplicated** with slightly different names mapping to the same description (e.g., "Nova Financial" and "Nova Healthcare" both return the same text). This is intentional to handle different name references across the dashboard.

## C. Role-Specific COSMO Audit Detail Panels

**Function:** `window.showCosmoAuditDetail(auditNumber)` (Line 217765)

Clicking a COSMO audit card triggers a role-specific detail panel with hardcoded narratives:

### Owner COSMO Detail — Audit #1 (Tom Collins Performance Review)
- **Lines ~213900–214000:** Multi-paragraph narrative about Tom Collins' healthcare account conversion drop (12%), 22-day lag in milestone box dispatch
- References specific clients and metrics

### Owner COSMO Detail — Audit #2 (Chevron B2B Milestone)
- **Lines ~214300–214400:** Narrative about Chevron procurement director satisfaction with gourmet confectionery pack

### Owner COSMO Detail — Audit #3 (Apex Solutions Conversion Strategy)
- **Lines ~218900–219100:** Narrative about physical boxes converting pipelines 2.8x faster than automated drips

### Rep COSMO Audit Cards
- **Lines ~50380–50640:** Tom Collins sees insights about his own conversion rate drops, healthcare account lag, and specific client recommendations
- Contains hardcoded conversion percentages (12% drop, 97% stable, 2.8x conversion rate)

### Executive/Manager COSMO Cards
- **Lines ~50450–50560:** Similar structure with role-appropriate context

## D. COSMO Recommendations in Customer Records

Each customer/prospect record in `customersData`/`prospectsData` has an `aiRecommend` field:

```javascript
aiRecommend: "Send Sweet Box for reaching retention."
```

These are displayed in the client detail panel as COSMO's live recommendation.

---

## Supabase Migration Notes

| Current | Target |
|:--------|:-------|
| Hardcoded COSMO audit cards in HTML | Database-driven audit queue with priority scoring |
| `activeAuditsDB` static object | Generated by backend AI engine analyzing real `activities` + `gifts` data |
| `showCosmoAuditDetail()` hardcoded narratives | AI-generated narratives from Supabase data (or template system) |
| `aiRecommend` field in customer records | Real-time computed recommendations based on inactivity + health |
| Hardcoded conversion rates (12%, 2.8x) | Computed from actual `activities` → `gifts` → conversion pipeline |
