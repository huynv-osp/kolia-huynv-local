# Document Classification: KOLIA-1517 - Kết nối Người thân

> **Phase:** 1 - Document Intake & Classification  
> **Date:** 2026-01-28  
> **Analyst:** SA Team

---

## 1. Document Information

| Field | Value |
|-------|-------|
| **Document Name** | SRS: KOLIA-1517 - Kết nối Người thân (Connection Flow) |
| **Version** | v2.0 |
| **Date** | 2026-01-28 |
| **Author** | BA Team |
| **Status** | Ready for Dev Review |

---

## 2. Classification

| Criteria | Classification |
|----------|----------------|
| **Type** | SRS (Software Requirements Specification) |
| **Scope** | New Feature |
| **Complexity** | Complex |
| **Priority** | High |

---

## 3. Affected Services (Preliminary)

| Service | Likely Impact | Confidence |
|---------|:-------------:|:----------:|
| user-service | 🔴 HIGH | High |
| api-gateway-service | 🟡 MEDIUM | High |
| schedule-service | 🟡 MEDIUM | High |
| Mobile App | 🟡 MEDIUM | Medium |

---

## 4. Document Structure

```
SRS v2.0
├── 1. Giới thiệu
│   ├── 1.1 Mục đích
│   ├── 1.2 Phạm vi (In/Out Scope)
│   └── 1.3 Tham chiếu
├── 2. Yêu cầu nghiệp vụ
│   └── 2.1 Business Rules (BR-001 ~ BR-025)
├── 3. PHẦN A: Role Người bệnh
│   ├── 3.1 Gửi lời mời (FR-A1.x)
│   ├── 3.2 Nhận lời mời (FR-A2.x)
│   ├── 3.3 Quản lý danh sách (FR-A3.x)
│   ├── 3.4 Phân quyền (FR-A4.x)
│   └── 3.5 Hủy kết nối (FR-A5.x)
├── 4. PHẦN B: Role Người thân
│   ├── 4.1 Gửi lời mời (FR-B1.x)
│   ├── 4.2 Nhận lời mời (FR-B2.x)
│   ├── 4.3 Danh sách theo dõi (FR-B3.x)
│   ├── 4.4 Xem chi tiết Patient (FR-B4.x)
│   └── 4.5 Ngừng theo dõi (FR-B5.x)
├── 5. PHẦN C: Yêu cầu chung
│   ├── 5.1 UI Screens (SCR-01 ~ SCR-06)
│   ├── 5.2 Profile Selector
│   ├── 5.3 Validation Rules
│   └── 5.4 Error Handling
└── 6. Yêu cầu phi chức năng
```

---

## 5. Analysis Priority Order

1. **RBAC Permission System** - Core architecture decision
2. **Bi-directional Invite Flow** - Primary user interaction
3. **Database Schema** - Foundation for implementation
4. **Notification Integration** - External dependencies (ZNS/SMS)
5. **Profile Selector UI** - Complex state management

---

## 6. Key Dependencies

| Dependency | Type | Status |
|------------|------|:------:|
| ZNS (Zalo Notification) | External | 🟡 Pending |
| Deep Link Infrastructure | Internal | 🟡 Pending |
| Push Notification | Internal | ✅ Ready |
| SMS Gateway | External | ✅ Ready |

---

## 7. Next Phase

➡️ **Phase 2**: Load ALIO Architecture Context
