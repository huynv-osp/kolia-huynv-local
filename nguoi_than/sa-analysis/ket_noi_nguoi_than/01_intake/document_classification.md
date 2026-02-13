# Document Classification: KOLIA-1517 - Kết nối Người thân

> **Phase:** 1 - Document Intake & Classification  
> **Date:** 2026-02-13 (Updated from 2026-01-28)  
> **Analyst:** SA Team  
> **Revision:** v4.0 — Updated for Family Group model (SRS v4.0/v5.0)

---

## 1. Document Information

| Field | Value |
|-------|-------|
| **Document Name** | SRS: KOLIA-1517 - Kết nối Người thân (Connection Flow) |
| **Version** | v4.0 |
| **Date** | 2026-02-12 |
| **Author** | BA Team |
| **Status** | Ready for Dev Review |

---

## 2. Classification

| Criteria | Classification |
|----------|----------------|
| **Type** | SRS (Software Requirements Specification) |
| **Scope** | Major Enhancement (from bi-directional → Admin-managed Family Group) |
| **Complexity** | Complex |
| **Priority** | High |

---

## 3. Affected Services (Preliminary)

| Service | Likely Impact | Confidence |
|---------|:-------------:|:----------:|
| user-service | 🔴 HIGH | High |
| api-gateway-service | 🔴 HIGH | High |
| payment-service | 🟡 MEDIUM | High |
| schedule-service | 🟡 MEDIUM | High |
| auth-service | 🟢 LOW | High |
| Mobile App | 🔴 HIGH | High |

---

## 4. Document Structure

```
SRS v4.0
├── 1. Giới thiệu
│   ├── 1.1 Mục đích
│   ├── 1.2 Phạm vi (Admin-only invites, Family Group)
│   ├── 1.3 Thuật ngữ (Admin, Member, Exclusive Group)
│   └── 1.4 Dependencies & Assumptions (10 items)
├── US-1: KẾT NỐI TÀI KHOẢN
│   ├── PHẦN A: Role Người bệnh (Patient)
│   │   ├── A.1 Gửi lời mời (Admin-only, simplified form v5.0)
│   │   ├── A.2 Nhận lời mời (Accept with MQH selection POP-MQH)
│   │   ├── A.3 Quản lý danh sách (với permission_revoked badge)
│   │   ├── A.4 Phân quyền (6 permissions, toggle)
│   │   └── A.5 Tắt quyền theo dõi (soft-disconnect, revoke ALL)
│   ├── PHẦN B: Role Người thân (Caregiver)
│   │   ├── B.1 (Admin-only, no Caregiver self-invite)
│   │   ├── B.2 Nhận lời mời
│   │   ├── B.3 Danh sách theo dõi (auto-connect ALL patients)
│   │   ├── B.4 Xem chi tiết Patient
│   │   └── B.5 Được tắt quyền bởi Patient
│   └── PHẦN C: Yêu cầu chung
│       ├── C.1 Quản lý Nhóm Gia đình (BS-QLTV)
│       ├── C.2 Slot Management
│       ├── C.3 UI Screens (SCR-01~06 + BS-QLTV)
│       └── C.4 Error Handling & Validation
├── US-1.1~1.5: Dashboard, Alerts, Compliance, Encouragement
└── Business Rules (BR-001 ~ BR-060+)
```

---

## 5. Key Changes from SRS v2.0 → v4.0

| Area | SRS v2.0 | SRS v4.0 |
|------|----------|----------|
| **Invite** | Bi-directional (cả Patient lẫn CG gửi) | **Admin-only** (chỉ Admin gửi) |
| **Group** | Không có concept nhóm | **Family Group** (gắn gói payment) |
| **Slot** | Không giới hạn (BR-021) | **Slot-based** từ gói subscription |
| **Connect** | 1-to-1 khi accept | **Auto-connect CG → ALL Patients** |
| **Disconnect** | Hard delete connection | **Soft disconnect** (tắt quyền, giữ connection) |
| **Form** | SĐT + MQH + Tên + 6 permissions | **Chỉ SĐT** (v5.0 simplified) |
| **BRs** | BR-001 ~ BR-025 | BR-001 ~ BR-060+ |
| **Exclusive** | Không ràng buộc | **1 user = 1 group** (BR-057) |

---

## 6. Analysis Priority Order

1. **Family Group Architecture** — New concept, core design decision
2. **Admin-only Invite Flow** — Changed from bi-directional
3. **Auto-connect Pattern** — CG connects to ALL patients automatically
4. **Soft Disconnect (Tắt quyền)** — New pattern replacing hard delete
5. **Slot Management** — Payment integration for member limits
6. **Database Schema Changes** — family_groups + family_group_members tables
7. **Notification Updates** — Member broadcast, silent revoke

---

## 7. Key Dependencies

| Dependency | Type | Status |
|------------|------|:------:|
| ZNS (Zalo Notification) | External | 🟡 Pending |
| Deep Link Infrastructure | Internal | 🟡 Pending |
| Push Notification | Internal | ✅ Ready |
| SMS Gateway | External | ✅ Ready |
| **Payment Service** | Internal | ✅ Ready (GetSubscription + SyncMembers) |

---

## 8. Next Phase

➡️ **Phase 2**: Load ALIO Architecture Context (updated with payment-service)
