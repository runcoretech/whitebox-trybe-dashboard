# 08 — Mock Executive & Owner Dashboard Data

## A. Executive Calendar Events

**File:** [main-dashboard-v34.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/dashboard/main-dashboard-v34.js)  
**Variable:** `executiveCalendarEvents` (Line 201331)

| ID | Type | Target | Date | Time | Agenda |
|:---|:-----|:-------|:-----|:-----|:-------|
| 1 | Performance Review | Tom Collins | 2026-05-27 | 10:00 AM | Review sales pipelines and healthcare account activity. Focus on conversion drop. |
| 2 | Client Strategic Meeting | Nova Healthcare | 2026-05-29 | 02:30 PM | Discuss premium confections shipment and Q2 contract renewal. |
| 3 | Performance Review | Sarah Lansky | 2026-06-02 | 11:00 AM | HR workflow assessment and workload balance check-in. Sentiment is high risk. |
| 4 | Milestone Gift Delivery | Aero Dynamics | 2026-06-05 | 01:00 PM | Verify VIP customer anniversary sweet box reception. |

This data populates the Owner/Executive calendar view with event dots, day breakdown panels, and event detail modals.

## B. Executive Nudges / Operational Warnings

**Variable:** `executiveNudges` (Line 201459)

| Date | Text | Type |
|:-----|:-----|:-----|
| 2026-05-27 | ⚠️ Vanguard Health has exceeded 84 days of inactivity. Touchpoint recommended. | critical |
| 2026-05-28 | ⚠️ Sarah Lansky resolved 14 warnings in 4 days. Monitor team burnout. | warning |
| 2026-06-01 | ⚠️ Tom Collins conversion rate dropped 12% in healthcare accounts. | critical |

These nudges appear as warning banners in the executive dashboard calendar day view.

## C. Executive Activity History (`executiveActivityHistory`)

**Variable:** `executiveActivityHistory` (Line 201571)

### Manually Written Entries (17 records spanning Dec 2025 – May 2026)

| Date | Activity |
|:-----|:---------|
| 2026-05-27 | 📅 Scheduled Performance Review with Tom Collins at 09:00 AM. |
| 2026-05-25 | 📞 Logged a performance sync with Marcus Dupond regarding Q2 retail conversion. |
| 2026-05-24 | 🎁 Dispatched Direct Owner Gift (Premium Executive Box) to Apex Global CEO. |
| 2026-05-20 | 🤝 Logged strategic touchpoint with Stripe Canada Managing Partner. |
| 2026-05-18 | 💼 Reviewed operations performance matrix with Chief People Officer. |
| 2026-05-15 | 📞 Conducted B2B pipeline review with Miami Regional manager Tom Collins. |
| 2026-05-12 | 🎁 Logged Direct Owner Gift shipment (Artisan Sweet Box) to Vanguard Health. |
| 2026-05-08 | 🤝 Logged a key sync with Delta Aerospace Procurement VP. |
| 2026-05-02 | 💼 Resolved internal operational alignment trigger with employee rep. |
| 2026-04-28 | 📞 Conducted employee performance sync with representative Marcus Dupond. |
| 2026-04-12 | 🎁 Sent B2B milestone sweet box to Chevron Solutions. |
| 2026-03-22 | 🤝 Negotiated contract renewal with Nova Financial Chief Financial Officer. |
| 2026-03-05 | 📞 Logged strategic touchpoint with Stripe Canada operations director. |
| 2026-02-14 | 💼 Conducted HR operations quarterly review with Sarah Lansky. |
| 2026-01-20 | 🎁 Initiated VIP milestone confections dispatch campaign to Northeast prospects. |
| 2026-01-08 | 📞 Conducted annual executive B2B review with Apex Global CEO. |
| 2025-12-18 | 🤝 Signed high-value B2B confections contract with Delta Aerospace. |

### Dynamically Generated Filler Entries (125 additional records)

**Lines 201910–201960:** An IIFE generates 125 additional history entries to reach exactly **142 total touchpoints** (matching the owner KPI "Gifts Sent" count).

```javascript
(function() {
    const companies = ['Apex Global', 'Chevron Solutions', 'Delta Aerospace',
        'Vanguard Health', 'Nova Financial', 'Stripe Canada', 'Summit Ventures',
        'Acme Corp', 'Global Logistics', 'Epic Foods', 'Quantum Tech',
        'Horizon Media', 'BlueSky Ventures', 'Pacific Trade', 'Atlantic Energy'];
    const roles = ['CEO', 'CFO', 'VP of Procurement', 'Operations Director', ...];
    const boxTypes = ['Premium Executive Box', 'Artisan Sweet Box', 'VIP Milestone Box', ...];
    const repNames = ['Tom Collins', 'Marcus Dupond', 'Sarah Lansky', 'Alice Smith', 'John Doe'];
    // Generates 125 entries using deterministic sin() seeding
    for (let i = 0; i < 125; i++) { ... }
})();
```

This uses a deterministic `Math.sin(seed)` approach to generate consistent pseudo-random entries from template arrays, ensuring the total count always matches the owner KPI.

## D. Live Activity Feed (`liveActivityFeed`)

**Variable:** `liveActivityFeed` (Line 159057)

| Icon | Text | Time |
|:-----|:-----|:-----|
| 📞 | **Sarah Lansky** logged a call with Stripe Canada | 3m ago |
| 🎁 | Gift dispatched to **Chevron Logistics** | 12m ago |
| ✅ | **Apex Global Retail** converted to Customer | 1h ago |
| ⚠️ | **Vanguard Health** entered Red Alert zone | 2h ago |
| 📧 | **Marcus Dupond** emailed Vanguard Logistics | 4h ago |
| 🎁 | AI Gift recommendation approved for **Apex Global Retail** | 5h ago |
| 📞 | **Tom Collins** logged a video sync with Nova Healthcare | 1d ago |
| ➕ | New prospect **Starlight Ventures** added | 2d ago |

This feed is displayed in a sidebar panel or activity stream widget, showing real-time-style activity updates.

---

## Supabase Migration Notes

| Current | Target |
|:--------|:-------|
| `executiveCalendarEvents` static array | `calendar_events` table or Supabase-powered calendar integration |
| `executiveNudges` static array | Generated from `activities` monitoring — threshold breach triggers |
| `executiveActivityHistory` (17 manual + 125 generated) | Fetched from `activities` table filtered by owner/executive `rep_id` |
| 125 filler entries via `Math.sin()` seed | Eliminated — real activity data |
| `liveActivityFeed` static array | Real-time subscription via Supabase Realtime on `activities` inserts |
