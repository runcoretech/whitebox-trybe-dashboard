# 05 — Mock Gifting Data

## A. Gifting Dispatch Schedule

**File:** [main-dashboard-v34.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/dashboard/main-dashboard-v34.js)  
**Variable:** `giftingDispatchSchedule` (Line 76722)

This is the main gift queue array that populates the Gifting Calendar and dispatch cards.

### All Dispatch Schedule Entries

| Date | Client | Category | Box Type | Sender | Reason | Status | Price |
|:-----|:-------|:---------|:---------|:-------|:-------|:-------|:------|
| 2026-05-29 | Marcus Dupond | reward | Sweet Box | Gregory Sterling (CEO) | Employee Milestone: May B2B Sales Volume Record | Finalized | $90.00 |
| 2026-06-01 | Tom Collins | remember | Remember Sweet Box | HR Department | Employee Birthday Recognition | Finalized | $90.00 |
| 2026-06-01 | Sarah Lansky | reward | Premium Box | Gregory Sterling (CEO) | CEO Excellence Award: HR System Deployment | Finalized | $300.00 |
| 2026-06-02 | BlueStar Retail | retain | Sweet Box | Tom Collins (Rep) | Customer Retention: Contract Anniversary | Finalized | $90.00 |
| 2026-06-02 | Operations Team | reward | Pack Box | CEO Office | Team Celebration: Q1 Operations Target Met | Finalized | $80.00 |
| 2026-06-03 | Apex Solutions | reach | Sweet Box | AI Automated Engine | Outbound Pipeline: Warm Prospect Nudge | Awaiting Owner Approval | Custom |
| 2026-06-03 | Peak Financial | retain | Premium Tier Custom Box | Tom Collins (Rep) | Contract renewal appreciation | Awaiting Design & Quote | Custom |
| 2026-06-03 | Nova Financial | remember | Remember Premium Box | AI Automated Engine | B2B Relationship Anniversary | Quote Ready | $300.00 |
| 2026-06-04 | Zenith Group | reach | Premium Box | AI Automated Engine | Executive Outreach: Cold Account Warming | Finalized | $300.00 |
| 2026-06-04 | Silverline Tech | retain | Pack Box | Marcus Dupond (Rep) | Customer Success: 3-Year Enterprise Anniversary | Finalized | $80.00 |
| 2026-06-04 | Helix Labs | remember | Remember Pack Box | AI Automated Engine | Partner Founding Anniversary | Finalized | $80.00 |
| 2026-06-05 | Chevron Logistics | reach | Tech Essentials Box | Tom Collins (Rep) | 1 year partnership anniversary | Awaiting Owner Approval | Custom |
| 2026-06-05 | Alpha Digital | reach | Premium Box | AI Automated Engine | Executive Branding campaign | Finalized | $300.00 |
| 2026-06-05 | Quantum Tech | reach | Pack Box | AI Automated Engine | Engineering Lead Nudge | Finalized | $80.00 |

## B. Active B2B Orders (Multi-Step Order Objects)

**Variable:** `activeB2BOrders` (Line 77075)

These are the detailed order objects for non-finalized gifts that go through the approval/design/dispatch workflow:

### Order: `order-chevron`
| Field | Value |
|:------|:------|
| `recipientName` | Chevron Logistics |
| `recipientScale` | team (12 recipients) |
| `boxType` / `boxTypeDisplay` | pack / Tech Essentials Box (Premium Blue Theme) |
| `dispatchDate` | 2026-06-05 |
| `category` | reach |

### Order: `order-apex`
| Field | Value |
|:------|:------|
| `recipientName` | Apex Solutions |
| `boxTypeDisplay` | Sweet Box |
| `dispatchDate` | 2026-06-03 |
| `category` | reach |

### Order: `order-peak`
| Field | Value |
|:------|:------|
| `recipientName` | Peak Financial |
| `boxTypeDisplay` | Premium Tier Custom Box |
| `dispatchDate` | 2026-06-03 |
| `category` | retain |

### Order: `order-nova`
| Field | Value |
|:------|:------|
| `recipientName` | Nova Financial |
| `boxTypeDisplay` | Remember Premium Box |
| `dispatchDate` | 2026-06-03 |
| `category` | remember |

## C. Calendar Events Database (`calendarEventsDB`)

**Variable:** `calendarEventsDB` (Line 116195)

A per-client object containing scheduled gift send/receive events displayed on the Gifting Calendar.

### Structure

```javascript
calendarEventsDB = {
    "Apex Global Retail": {
        send: [
            { day: 5, box: "Premium Box", recipient: "Apex Executive Suite",
              reason: "Strategic Partner Q2 Milestone Appreciation",
              status: "scheduled", date: "June 5, 2026" },
            { day: 15, box: "Sweet Box", recipient: "Customer Success Team",
              reason: "Quarterly Service Excellence Appreciation",
              status: "scheduled", date: "June 15, 2026" }
        ]
    },
    "Chevron Solutions": { send: [...] },
    // ... more clients
}
```

Each client has `send` and `receive` arrays with gift dispatch calendar events.

## D. Spend Ledger Dynamic Filler Generation

**File:** [spend-ledger-modal.js](file:///c:/Users/paulk/OneDrive/Desktop/WHITEBOX%20GIFTWORKS%20PROJECT/dashboard/spend-ledger-modal.js), Lines 130–260

### How It Works

1. When the spend ledger modal opens, it scrapes visible rows from `#spend-ledger-rows` in the DOM
2. If scraped rows < active KPI "Gifts Sent" count, it generates **mock filler rows** at runtime
3. Outlay values use deterministic variance: `[-15, 5, 20, -10, -5, 10, -5]` (sums to 0) to balance totals
4. Dates decrement deterministically from May 22, 2026 baseline
5. Recipients/confections are role-specific (see Section 03 for customer lists)

### Confection Types Used in Filler Rows

| Role | Confection Options |
|:-----|:-------------------|
| Rep | Premium Custom Luxury Box, Tech Essentials Box (Blue Theme), Artisan Cookie Basket, Assorted Truffles Box |
| Manager (employee) | Sweet Box (Confections Gold Theme), Celebration Cupcakes Shared Pack, Gourmet Chocolate Sampler, Cosmo Signature Pack |
| Manager (customer) | Same as Rep |
| Owner/Exec (employee) | Same as Manager (employee) |
| Owner/Exec (customer) | Same as Rep |

### Gift Categories

| Category | Use Case |
|:---------|:---------|
| `Reach` | Outbound prospecting / cold warming |
| `Retain` | Customer retention / renewal appreciation |
| `Remember` | Milestone / anniversary recognition |
| `Reward` | Employee recognition / performance reward |

---

## Supabase Migration Notes

| Current | Target |
|:--------|:-------|
| `giftingDispatchSchedule` array | `gifts` table with `contact_id`, `rep_id`, `confection_type`, `amount`, `status`, `dispatched_at` |
| `activeB2BOrders` hashmap | `gifts` table with `status IN ('pending_approval', 'design_quote', 'quote_ready', 'dispatched', 'delivered')` |
| `calendarEventsDB` per-client object | SQL view joining `gifts` + `contacts` grouped by dispatch date |
| Spend ledger filler generation | Eliminated — real `gifts` table provides all rows |
| Deterministic variance `[-15,5,20,-10,-5,10,-5]` | Eliminated — real transaction amounts |
