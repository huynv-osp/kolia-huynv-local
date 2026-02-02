# Scope Summary: KOLIA-1517 - Kết nối Người thân

> **Phase:** 1 - Document Intake & Classification  
> **Date:** 2026-01-28

---

## 1. Feature Overview

**Kết nối Người thân** (Connection Flow) cho phép thiết lập mối quan hệ bi-directional giữa Patient và Caregiver để giám sát sức khỏe từ xa.

---

## 2. Scope Definition

### ✅ IN SCOPE

| Category | Items |
|----------|-------|
| **Core Functions** | Bi-directional invites, Accept/Reject, Manage list |
| **RBAC** | 6-category permission system |
| **Notifications** | ZNS, SMS fallback, Push |
| **UI** | 7 screens (SCR-01 ~ SCR-06) |
| **Lifecycle** | Invite → Accept → Active → Disconnect |

### ❌ OUT OF SCOPE

| Item | Notes |
|------|-------|
| Caregiver Dashboard nâng cao | Deferred to SRS #2 |
| Thực hiện nhiệm vụ thay Patient | Only permission defined |
| Messaging system | Only permission defined |
| Admin management panel | Not defined |

---

## 3. User Roles

| Role | Description | Actions |
|------|-------------|---------|
| **Patient** | Người bệnh được theo dõi | Invite, Accept, Grant permissions |
| **Caregiver** | Người thân theo dõi | Request, Accept, View data |
| **Hybrid** | Vừa Patient vừa Caregiver | Both sets of actions |

---

## 4. Key Metrics

| Metric | Value |
|--------|-------|
| Functional Requirements | ~25 (FR-A + FR-B) |
| Business Rules | 25 (BR-001 ~ BR-025) |
| UI Screens | 7 |
| Permission Categories | 6 |
| Relationship Types | 14 |

---

## 5. Success Criteria

- [ ] Patient can invite Caregiver via phone number
- [ ] Caregiver can request to monitor Patient
- [ ] Patient controls 6 granular permissions
- [ ] ZNS/SMS/Push notifications delivered
- [ ] Profile Selector shows correct state
- [ ] Disconnect works bi-directionally
