# WhiteBox RMOS Dashboard - Gifting Seed Plan

This document establishes the detailed migration plan for the WhiteBox RMOS gifting catalog, order queue, dispatch schedule, and spend calculations.

---

## 1. Product Catalog Mapping (`boxes` Table)

To support the current catalog and dynamic selectors, we map the three core box categories to rows in the `boxes` table:

| Box Name | Target `theme_color` | Base Price | Target `is_active` | Seed UUID Reference |
| :--- | :--- | :--- | :--- | :--- |
| **Sweet Box** | `'#fbbf24'` (Amber/Gold) | $90.00 | `true` | `9b1933c0-0f0e-4361-b472-3c8cfa2b9821` |
| **Pack Box** | `'#3b82f6'` (Blue) | $80.00 | `true` | `9b1933c0-0f0e-4361-b472-3c8cfa2b9822` |
| **Premium Box** | `'#8b5cf6'` (Purple) | $300.00 | `true` | `9b1933c0-0f0e-4361-b472-3c8cfa2b9823` |

---

## 2. Gifting Category & Reason Mapping
Every gift has an associated purpose category (`public.gift_category` enum) which maps to the dashboard's four marketing segments:

| Marketing Segment | Enum Value | Common Seed Reasons |
| :--- | :--- | :--- |
| **Reach** | `'reach'` | Outbound cold warming, pipeline intro, outbound prospect nudge |
| **Retain** | `'retain'` | Contract anniversary, client retention, contract renewal appreciation |
| **Remember** | `'remember'` | B2B relationship anniversary, founding partner milestone |
| **Reward** | `'reward'` | Employee sales volume achievement, CEO excellence award, birthday recognition |

---

## 3. Order Status Lifecycle Mapping
The dashboard features a multi-step gifting dispatch queue that guides orders from creation to delivery. We map the JS status codes to `public.gift_status` enum:

| JS Dashboard Status | Enum Value | Gifting Tab Placement / Behavior |
| :--- | :--- | :--- |
| `Awaiting Owner Approval` | `'awaiting_approval'` | Displayed in Gifting Tab with "Approve" and "Reject" actions. |
| `Awaiting Design & Quote` | `'awaiting_design'` | Displayed in Gifting Tab queue with design specifications. |
| `Quote Ready` | `'quote_ready'` | Displayed in queue showing final custom box quote price. |
| `Approved` | `'approved'` | Released from queue, waiting for carrier pick-up. |
| `Dispatched` | `'dispatched'` | Active transit state (carrier name + tracking number visible). |
| `Finalized` (Delivered) | `'delivered'` | Completed order, contributes to "Spend Outlay" and "Gifts Sent" KPIs. |
| `Failed` | `'failed'` | Shipping bounce / delivery exception. |
| `Rejected` | `'rejected'` | Order rejected during Owner review. |

---

## 4. Gifting Dispatch Schedule Inventory (Seeding Records)

To preserve the identical counts and data columns of the `giftingDispatchSchedule` and `activeB2BOrders` arrays, the seed script will insert the following 14 records into the `gifts` table:

| ID | Recipient (Contact/Org) | Sender (Profile) | Box Type | Category | Amount | Status | Reason |
|:---|:---|:---|:---|:---|:---|:---|:---|
| `g01` | Marcus Dupond | Gregory Sterling | Sweet Box | `reward` | $90.00 | `delivered` | Employee Milestone: May B2B Sales Record |
| `g02` | Tom Collins | Sarah Lansky | Sweet Box | `remember` | $90.00 | `delivered` | Employee Birthday Recognition |
| `g03` | Sarah Lansky | Gregory Sterling | Premium Box | `reward` | $300.00 | `delivered` | CEO Excellence Award: HR System Deployment |
| `g04` | BlueStar Retail | Tom Collins | Sweet Box | `retain` | $90.00 | `delivered` | Customer Retention: Contract Anniversary |
| `g05` | Operations Team | Gregory Sterling | Pack Box | `reward` | $80.00 | `delivered` | Team Celebration: Q1 Operations Target Met |
| `g06` | Apex Solutions | System Engine | Sweet Box | `reach` | $90.00 | `awaiting_approval` | Outbound Pipeline: Warm Prospect Nudge |
| `g07` | Peak Financial | Tom Collins | Premium Box | `retain` | $300.00 | `awaiting_design` | Contract renewal appreciation |
| `g08` | Nova Financial | System Engine | Premium Box | `remember` | $300.00 | `quote_ready` | B2B Relationship Anniversary |
| `g09` | Zenith Group | System Engine | Premium Box | `reach` | $300.00 | `delivered` | Executive Outreach: Cold Account Warming |
| `g10` | Silverline Tech | Marcus Dupond | Pack Box | `retain` | $80.00 | `delivered` | Customer Success: 3-Year Enterprise Anniversary |
| `g11` | Helix Labs | System Engine | Pack Box | `remember` | $80.00 | `delivered` | Partner Founding Anniversary |
| `g12` | Chevron Logistics | Tom Collins | Pack Box | `reach` | $80.00 | `awaiting_approval` | 1 year partnership anniversary |
| `g13` | Alpha Digital | System Engine | Premium Box | `reach` | $300.00 | `delivered` | Executive Branding campaign |
| `g14` | Quantum Tech | System Engine | Pack Box | `reach` | $80.00 | `delivered` | Engineering Lead Nudge |

---

## 5. Address & Tracking Metadata Mappings

To support realistic logistics audits in the dashboard, seeded records will use the following default shipping structures:

*   **Shipping Address:** Falls back to target organization address (e.g. `'99 Brand St, Los Angeles, CA 90015'`).
*   **Carrier Details:** Mapped to FedEx or UPS in finalized dispatches.
*   **Tracking Number:** Mapped to standard tracking strings (e.g. `'1Z9A29810300123456'`) for dispatched/delivered states.
*   **Dispatched Date:** Seeded relative to baseline history (e.g. `now() - INTERVAL '3 days'`).

---

## 6. Historical Pricing Preservation Lock

### 6.1. The Price Decoupling Architecture
To prevent changing the price of a box catalog item (e.g., raising "Sweet Box" to $95.00) from corrupting the historical analytics of previously sent gifts:
1.  **Catalog Price:** Checked from `boxes.price`.
2.  **Order Price:** Stored in `gifts.amount` at creation time.
3.  **Analytics Queries:** All spend metrics run `SUM(gifts.amount)` rather than performing a join on `boxes.price`.
This decoupling pattern guarantees that historical billing records remain constant and independent of catalog updates.
```sql
-- Dynamic Seed Code representing decoupled price lock:
INSERT INTO public.gifts (..., box_id, amount, status) 
VALUES (..., '9b1933c0-0f0e-4361-b472-3c8cfa2b9821', 90.00, 'delivered');
```
This aligns perfectly with the database design, ensuring consistent analytics.
