# Technical Risks: KOLIA-1517 - Kết nối Người thân

> **Phase:** 7 - Technical Risks & Recommendations  
> **Date:** 2026-02-13  
> **Revision:** v4.0 — Updated risks for Family Group model

---

## 1. Risk Matrix

| Risk | Probability | Impact | Severity | Status |
|------|:-----------:|:------:|:--------:|:------:|
| R1: ZNS Approval Delay | 🟡 Medium | 🟡 Medium | 🟡 MEDIUM | Mitigated |
| R2: Deep Link Failures | 🟢 Low | 🔴 High | 🟡 MEDIUM | Action Required |
| R3: Permission Desync | 🟢 Low | 🟡 Medium | 🟢 LOW | Mitigated |
| R4: State Machine Edge Cases | 🟡 Medium | 🟡 Medium | 🟡 MEDIUM | Mitigated |
| R5: Notification Delivery | 🟢 Low | 🟡 Medium | 🟢 LOW | Mitigated |
| **R6: Slot Race Condition** | 🟡 Medium | 🔴 High | 🔴 **HIGH** | **NEW** |
| **R7: Auto-connect Failure** | 🟢 Low | 🔴 High | 🟡 **MEDIUM** | **NEW** |
| **R8: Payment Service Downtime** | 🟢 Low | 🔴 High | 🟡 **MEDIUM** | **NEW** |
| **R9: Exclusive Group Violation** | 🟢 Low | 🟡 Medium | 🟢 **LOW** | **NEW** |

---

## 2. Risk Details

### R1-R5: KEPT FROM v2.0 (unchanged)

> ZNS delay, Deep Link, Permission Desync, State Machine, Notification — see previous version.

---

### R6: Slot Race Condition (NEW v4.0)

**Description:** Multiple invites accepted simultaneously could exceed slot limit.

**Scenario:**
1. Admin invites CG-A and CG-B (2 slots left)
2. Both accept at the same time
3. Both pass slot check → 2 connections created but only 1 slot left

**Impact:**
- Over-provisioned slots → payment inconsistency
- Hard to detect and fix

**Mitigation:**
- ✅ **AD-04:** Double-check slot at accept time (re-verify)
- ✅ Pessimistic locking on slot count during accept
- ✅ SyncMembers ADD called inside same transaction
- ✅ Rollback if slot check fails post-accept

**Owner:** Backend Team (user-service)

---

### R7: Auto-connect Failure (NEW v4.0)

**Description:** When CG accepts invite, auto-connect to ALL patients may partially fail.

**Scenario:**
1. CG accepts invite
2. System tries to create connections to Patient A, B, C
3. Connection to Patient B fails (constraint violation or timeout)
4. CG connected to A and C but NOT B → inconsistent state

**Impact:**
- Partial connections → confusing UI
- Missing permissions for some patients

**Mitigation:**
- ✅ Transactional batch: ALL connections in single transaction
- ✅ Rollback entire accept if any connection fails
- ✅ Retry logic with idempotency (ON CONFLICT DO NOTHING)

**Owner:** Backend Team (user-service)

---

### R8: Payment Service Downtime (NEW v4.0)

**Description:** user-service depends on payment-service for GetSubscription/SyncMembers.

**Impact:**
- Cannot verify Admin role → invite blocked
- Cannot check slots → invite blocked
- Cannot sync member after accept

**Mitigation:**
- ⚠️ Cache Admin role + slot count (TTL: 5min)
- ✅ Async SyncMembers with retry (non-blocking)
- ✅ Graceful degradation: show "Service unavailable" message

**Owner:** Backend Team

---

### R9: Exclusive Group Violation (NEW v4.0)

**Description:** Race condition where user joins two groups simultaneously.

**Mitigation:**
- ✅ DB UNIQUE index `idx_user_single_group(user_id, role)`
- ✅ Pre-check at invite time
- ✅ Re-check at accept time → return "already in group" error

**Owner:** Backend Team

---

## 3. Dependencies (Updated v4.0)

| Dependency | Risk Level | Notes |
|------------|:----------:|-------|
| ZNS API | 🟡 | External service |
| SMS Gateway | 🟢 | Already in use |
| FCM | 🟢 | Already in use |
| Deep Link | 🟡 | Must verify |
| **Payment Service** | **🟡** | **New: GetSubscription + SyncMembers** |

---

## 4. Contingency Plans (Updated)

| Scenario | Action |
|----------|--------|
| ZNS not approved by launch | Use SMS as primary |
| Deep links don't work | Use in-app notifications |
| High load on invites | Add rate limiting |
| **Payment service down** | **Cache Admin/Slot, retry SyncMembers** |
| **Slot over-provision detected** | **Background job reconciliation** |
| **Auto-connect partial failure** | **Retry with idempotent operations** |
