# Executive Summary: KOLIA-1517 (REVISED v4.0)

> **Phase:** 8 - Report Generation  
> **Date:** 2026-02-13  
> **SA:** Solution Architect Team

---

## Key Metrics

| Metric | v2.0 | v4.0 |
|--------|:----:|:----:|
| Feasibility | 88/100 | **82/100** |
| Impact | 🟢 LOW | **🟡 MEDIUM** |
| New Tables | 5 | 5 + **2 NEW** |
| Altered Tables | 1 | 1 + **1 ALTER** |
| Services Affected | 3 | **5** |
| New APIs | 8 | 8 + **6 NEW** |
| Effort | 56h | **~80h** |

---

## Architecture Changes (v4.0)

### 1. Family Group Model
- **NEW:** `family_groups` + `family_group_members` tables
- Linked to payment subscription, Admin-owned
- Exclusive group constraint (1 user = 1 group per role)

### 2. Admin-Only Invites
- ~~Bi-directional~~ → **Admin-only** (BR-041)
- Simplified form: **SĐT only** (v5.0, bỏ MQH + permissions)
- Slot-based from payment package

### 3. Auto-Connect Pattern
- CG accept → auto-connect ALL Patients in group
- Transactional, ALL-or-nothing
- Permissions ALL ON (6 types)

### 4. Soft Disconnect
- ~~Hard delete~~ → **permission_revoked = TRUE**
- Silent (no notification, BR-056)
- Reversible (Patient có thể "Mở lại quyền")

---

## Service Impact

| Service | Impact | Changes |
|---------|:------:|---------|
| user-service | 🔴 | +8 new files (FamilyGroup), update 17 files |
| api-gateway-service | 🔴 | +6 new endpoints, update 3 files |
| payment-service | 🟡 | Existing RPCs (GetSubscription, SyncMembers) |
| schedule-service | 🟡 | +Member broadcast, update notifications |
| auth-service | 🟢 | Existing backfillPendingInviteReceiverIds |

---

## Database Summary

| Change | Count |
|--------|:-----:|
| New tables | 2 (family_groups, family_group_members) |
| Altered tables | 1 (user_emergency_contacts: +permission_revoked, +family_group_id) |
| Updated constraints | 1 (connection_invites invite_type enum) |
| New indexes | 4 |
| Permissions | **6 (giữ nguyên)** |
| Relationships | **14 (giữ nguyên)** |

---

## SRS Coverage

**Key BRs covered:**
- BR-041: Admin-only ✅
- BR-047: Slot check ✅
- BR-052: Member broadcast ✅
- BR-056: Silent revoke ✅
- BR-057: Exclusive group ✅
- BR-059: Slot full popup ✅
- BR-006: No self-invite ✅
- BR-009: Default perms ✅
- BR-028: Relationships ✅

---

## Recommendation

**✅ APPROVED for implementation**

Score 82/100 — FEASIBLE with medium complexity. The Family Group model adds new entity layer but reuses established patterns. Key risk is cross-service dependency on payment-service (mitigated by caching + retry).

**Estimated effort:** ~80 hours across 5 services
