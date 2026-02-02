# Technical Risks: KOLIA-1517 - Kết nối Người thân

> **Phase:** 7 - Technical Risks & Recommendations  
> **Date:** 2026-01-28

---

## 1. Risk Matrix

| Risk | Probability | Impact | Severity | Status |
|------|:-----------:|:------:|:--------:|:------:|
| R1: ZNS Approval Delay | 🟡 Medium | 🟡 Medium | 🟡 MEDIUM | Mitigated |
| R2: Deep Link Failures | 🟢 Low | 🔴 High | 🟡 MEDIUM | Action Required |
| R3: Permission Desync | 🟢 Low | 🟡 Medium | 🟢 LOW | Mitigated |
| R4: State Machine Edge Cases | 🟡 Medium | 🟡 Medium | 🟡 MEDIUM | Mitigated |
| R5: Notification Delivery | 🟢 Low | 🟡 Medium | 🟢 LOW | Mitigated |

---

## 2. Risk Details

### R1: ZNS Approval Delay

**Description:** Zalo Notification Service requires template approval which may take 3-5 business days.

**Impact:** 
- Cannot send ZNS invitations
- Users with only Zalo app won't receive invites

**Mitigation:**
- ✅ SMS fallback ready from Day 1
- ✅ Early template submission (parallel with development)
- ✅ Push notification as secondary channel

**Owner:** DevOps Team

---

### R2: Deep Link Failures

**Description:** Deep link infrastructure (`kolia://invite?id=xxx`) may not work on all devices or OS versions.

**Impact:**
- Poor UX for invite acceptance
- Manual navigation required

**Mitigation:**
- ⚠️ Verify infrastructure in Week 1
- ✅ Universal links as fallback
- ✅ In-app notification with direct navigation

**Owner:** Mobile Team

---

### R3: Permission Desync

**Description:** Race condition where Caregiver sees stale permissions.

**Impact:**
- Privacy concern if old permission cached
- Incorrect UI display

**Mitigation:**
- ✅ Server as single source of truth
- ✅ Real-time notification on permission change
- ✅ API always returns fresh data

**Owner:** Backend Team

---

### R4: State Machine Edge Cases

**Description:** Complex invite/connection state transitions may have edge cases.

**Impact:**
- Invalid states
- Duplicate connections
- Orphan records

**Mitigation:**
- ✅ Database constraints (unique indexes)
- ✅ Transactional operations
- ✅ Comprehensive unit tests
- ✅ State diagram documentation

**Owner:** Backend Team

---

### R5: Notification Delivery

**Description:** Notifications may fail due to network issues or service outages.

**Impact:**
- User doesn't receive invite
- Poor experience

**Mitigation:**
- ✅ 3x retry with 30s interval (BR-004)
- ✅ Multiple channels (ZNS → SMS → Push)
- ✅ invite_notifications tracking table

**Owner:** Schedule Service Team

---

## 3. Dependencies

| Dependency | Risk Level | Notes |
|------------|:----------:|-------|
| ZNS API | 🟡 | External service, SLA unknown |
| SMS Gateway | 🟢 | Already in use, reliable |
| FCM | 🟢 | Already in use, reliable |
| Deep Link | 🟡 | Must verify before launch |

---

## 4. Contingency Plans

| Scenario | Action |
|----------|--------|
| ZNS not approved by launch | Use SMS as primary |
| Deep links don't work | Use in-app notifications |
| High load on invites | Add rate limiting |
| Connection data corrupted | Rollback + restore from backup |
