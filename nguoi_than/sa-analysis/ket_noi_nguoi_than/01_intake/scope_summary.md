# Scope Summary: KOLIA-1517 - Kết nối Người thân

> **Phase:** 1 - Document Intake & Classification  
> **Date:** 2026-02-13 (Updated from 2026-01-28)  
> **Revision:** v4.0 — Family Group model

---

## 1. Feature Overview

**Kết nối Người thân** (Connection Flow) cho phép thiết lập mối quan hệ giữa Patient và Caregiver thông qua mô hình **Nhóm Gia Đình (Family Group)** do **Admin (Quản trị viên)** quản lý, gắn liền với gói dịch vụ payment.

---

## 2. Scope Definition

### ✅ IN SCOPE

| Category | Items |
|----------|-------|
| **Core Functions** | Admin-only invites, Accept/Reject, Family Group management |
| **RBAC** | 6-category permission system (giữ nguyên) |
| **Group** | Family Group CRUD, Slot management, Exclusive group (1 user = 1 group) |
| **Auto-connect** | CG accept → auto-connect ALL Patients in group |
| **Soft disconnect** | Patient tắt quyền CG (giữ connection, revoke ALL permissions) |
| **Notifications** | ZNS, SMS fallback, Push, Member broadcast |
| **UI** | SCR-01~06 + BS-QLTV (Quản lý nhóm bottom sheet) |
| **Lifecycle** | Admin Invite → Accept (+MQH) → Auto-connect → Active → Tắt quyền/Xoá member |

### ❌ OUT OF SCOPE

| Item | Notes |
|------|-------|
| Caregiver Dashboard nâng cao | Deferred to SRS #2 |
| Thực hiện nhiệm vụ thay Patient | Only permission defined |
| Messaging system | Only permission defined |
| ~~Bi-directional invites~~ | **REMOVED** — Admin-only model |

---

## 3. User Roles

| Role | Description | Actions |
|------|-------------|---------|
| **Admin** | Quản trị viên (người kích hoạt gói) | Invite members, Remove members, Manage group |
| **Patient** | Người bệnh được theo dõi | Accept invite, Grant/Revoke permissions per CG |
| **Caregiver** | Người thân theo dõi | Accept invite, Auto-connect ALL patients, View data |
| **Hybrid** | Vừa Patient vừa Caregiver | Both sets of actions |

---

## 4. Key Metrics

| Metric | v2.0 | v4.0 |
|--------|:----:|:----:|
| Functional Requirements | ~25 | ~40+ |
| Business Rules | 25 | **60+** |
| UI Screens | 7 | **8+** (+ BS-QLTV) |
| Permission Categories | 6 | **6** (giữ nguyên) |
| Relationship Types | 14 | **14** (giữ nguyên) |
| New DB Tables | 0 | **2** (family_groups, family_group_members) |
| Altered DB Tables | 0 | **1** (user_emergency_contacts) |

---

## 5. Success Criteria

- [x] ~~Patient can invite Caregiver via phone number~~ → **Admin** invites members
- [x] ~~Caregiver can request to monitor Patient~~ → **Removed** (Admin-only)
- [ ] Admin can invite Patient/Caregiver to Family Group
- [ ] Admin can manage members (add/remove) via BS-QLTV
- [ ] Accept → Auto-connect CG to ALL patients in group
- [ ] Patient controls 6 granular permissions per CG
- [ ] Patient can "Tắt quyền" (revoke ALL permissions, silent)
- [ ] Patient can "Mở lại quyền" (restore ALL permissions)
- [ ] ZNS/SMS/Push notifications delivered (including member broadcast)
- [ ] Exclusive Group: 1 user = 1 group at a time
- [ ] Slot management integrated with Payment service
