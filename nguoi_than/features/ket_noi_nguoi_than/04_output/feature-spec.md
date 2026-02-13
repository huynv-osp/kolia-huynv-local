# Feature Specification: KOLIA-1517 - Kết nối Người thân

> **Phase:** 4 - Output  
> **Date:** 2026-02-13  
> **SRS Version:** v4.0 (v5.3 revisions)  
> **Revision:** v4.0 - Admin-only, Family Group, 5 services, 82/100 feasibility

---

## 1. Overview

Tính năng **Kết nối Người thân** cho phép Quản trị viên (Admin) quản lý nhóm gia đình, mời thành viên, và thiết lập kết nối giữa Người bệnh (Patient) và Người thân (Caregiver) để theo dõi sức khỏe từ xa.

### Key Metrics

| Metric | v2.23 | v4.0 |
|--------|:-----:|:----:|
| Feasibility Score | 88/100 | **82/100** |
| Impact Level | 🟢 LOW | **🟡 MEDIUM** |
| Services Affected | 3 | **5** |
| New Tables | 5 | **7** (5+2 NEW) |
| New REST APIs | 8 | **14** (8+6 NEW) |
| Business Rules | ~41 | **60+** |
| Effort Estimate | ~56h | **~80h** |

---

## 2. Roles & Permissions

### 2.1 Roles

| Role | Description | Key Permissions |
|------|-------------|-----------------|
| **Admin (Quản trị viên)** | Người kích hoạt gói. Quản lý nhóm, mời/xoá thành viên | Full group management (BR-041) |
| **Patient (Người bệnh)** | Người cao tuổi quản lý sức khỏe | Control who follows, manage permissions |
| **Caregiver (Người thân)** | Theo dõi sức khỏe Patient | Accept/reject invites, view dashboard |

> **Note:** 1 user có thể vừa là Patient vừa là Caregiver (BR-048). Admin role từ Payment SRS.

### 2.2 Permission Categories (6)

| # | Permission | Default | UI Block |
|:-:|-----------|:-------:|----------|
| 1 | Xem tổng quan sức khỏe | ✅ ON | Xu hướng huyết áp |
| 2 | Nhận cảnh báo khẩn cấp | ✅ ON | Cảnh báo |
| 3 | Thiết lập nhiệm vụ tuân thủ | ✅ ON | Thiết lập |
| 4 | Theo dõi & thực hiện nhiệm vụ tuân thủ | ✅ ON | Kết quả + Thực hiện |
| 5 | Gửi lời động viên | ✅ ON | Nhắn tin |

> **Note:** SRS A.4 bảng có 5 dòng, nhưng BRs reference "6 permissions". Code giữ 6 categories cho extensibility. Permission #3+#4 có thể tách thành 2 code entries.

### 2.3 Permission Behaviors — v4.0

| Action | Behavior | BR |
|--------|----------|:--:|
| BẬT permission | Apply ngay, KHÔNG hiện popup | BR-024 |
| TẮT permission | Hiện confirmation popup trước | BR-024 |
| TẮT "Cảnh báo khẩn cấp" | Hiện red warning popup | BR-018 |
| Tắt permission cuối cùng | Block, toast "Cần ≥1 quyền ON" | BR-039 |
| **Tắt quyền theo dõi** | ALL OFF, bypass BR-039, silent | BR-040, BR-056 |
| **Mở lại quyền** | Navigate SCR-05, toggle ON | BR-040 |

---

## 3. API Summary

### 3.1 REST Endpoints (14)

| # | Method | Path | Auth | Status |
|:-:|:------:|------|:----:|:------:|
| 1 | POST | `/api/v1/connections/invite` | Admin | Updated (phone only) |
| 2 | POST | `/api/v1/connections/invites/:id/accept` | User | Updated (auto-connect) |
| 3 | POST | `/api/v1/connections/invites/:id/reject` | User | Existing |
| 4 | GET | `/api/v1/connections` | User | Existing |
| 5 | PUT | `/api/v1/connections/:id/permissions` | Patient | Existing |
| 6 | GET | `/api/v1/connections/invites/pending` | User | Existing |
| 7 | DELETE | `/api/v1/connections/invites/:id` | Sender | Existing |
| 8 | PUT | `/api/v1/connections/invites/:id/permissions` | Sender | Existing |
| 9 | **GET** | `/api/v1/family-groups` | User | ⚠️ NEW |
| 10 | **DELETE** | `/api/v1/family-groups/members/:memberId` | Admin | ⚠️ NEW |
| 11 | **PUT** | `/api/v1/connections/:contactId/revoke` | Patient | ⚠️ NEW |
| 12 | **PUT** | `/api/v1/connections/:contactId/restore` | Patient | ⚠️ NEW |
| 13 | **PUT** | `/api/v1/connections/:contactId/relationship` | CG | ⚠️ NEW |
| 14 | **POST** | `/api/v1/family-groups/leave` | Non-Admin | ⚠️ NEW |
| ~~15~~ | ~~DELETE~~ | ~~`/api/v1/connections/:id`~~ | | ❌ DEPRECATED |

### 3.2 gRPC Methods (user-service)

| Method | Direction | v4.0 |
|--------|:---------:|:----:|
| CreateInvite | GW→US | Updated |
| AcceptInvite | GW→US | Updated (auto-connect) |
| RejectInvite | GW→US | Existing |
| GetConnections | GW→US | Existing |
| UpdatePermissions | GW→US | Existing |
| **CreateFamilyGroup** | GW→US | NEW |
| **GetFamilyGroup** | GW→US | NEW |
| **RemoveMember** | GW→US | NEW |
| **RevokePermission** | GW→US | NEW |
| **RestorePermission** | GW→US | NEW |
| **UpdateRelationship** | GW→US | NEW |
| **LeaveGroup** | GW→US | NEW |
| GetSubscription | US→PS | NEW (outbound) |

---

## 4. Database Schema — v4.0

### 4.1 Tables (7 + 2 extensions)

| Table | Type | Key Columns |
|-------|:----:|-------------|
| `family_groups` | **NEW** | admin_user_id, subscription_id, name, status |
| `family_group_members` | **NEW** | user_id (UNIQUE), family_group_id, role, status |
| `relationships` | Existing | code, label, inverse_code |
| `relationship_inverse_mapping` | Existing | relationship_code, inverse_code |
| `connection_permission_types` | Existing | code, name, description |
| `connection_invites` | Modified | **invite_type**: `add_patient`/`add_caregiver` |
| `connection_permissions` | Existing | contact_id, permission_code, is_enabled |
| `user_emergency_contacts` | Modified | **+permission_revoked**, **+family_group_id** |
| `invite_notifications` | Existing | invite_id, channel, status |

### 4.2 Key Constraints

| Constraint | Table | Purpose |
|-----------|-------|---------|
| `UNIQUE(user_id)` | family_group_members | Exclusive group (BR-057) |
| `FK family_group_id` | user_emergency_contacts | Link connection to group |
| `CHECK invite_type` | connection_invites | Only add_patient/add_caregiver |

---

## 5. Implementation Phases

| Phase | Focus | Effort | Key Deliverables |
|:-----:|-------|:------:|------------------|
| 0 | DB Migration + Family Group | 12h | Tables, entities, repositories |
| 1 | user-service Core Logic | 18h | Admin invite, auto-connect, soft disconnect |
| 2 | api-gateway Endpoints | 20h | 6 new endpoints, DTO updates |
| 3 | Cross-Service Integration | 15h | Payment, notifications, auth |
| 4 | Testing & Verification | 15h | Unit, integration, regression |

---

## 6. Key Business Rules (v4.0 Highlights)

| BR | Rule | Impact |
|:--:|------|:------:|
| BR-041 | Admin-only invites | 🔴 Architecture change |
| BR-045 | Auto-connect CG → ALL patients | 🔴 New flow |
| BR-040 | Soft disconnect (permission_revoked) | 🔴 Replaces hard delete |
| BR-057 | Exclusive group (1 user = 1 group) | 🟡 DB constraint |
| BR-061 | Leave group (Non-Admin) | 🟡 New flow |
| BR-033 | Slot pre-check via payment | 🟡 Cross-service |
| BR-056 | Silent permission change | 🟡 UX change |

---

## References

- [SRS v4.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/srs_input_documents/srs_nguoi_than_nhom_gia_dinh.md)
- [SA Complete Analysis v4.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/ket_noi_nguoi_than/08_report/complete_analysis.md)
- [FA Requirement Analysis v4.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/features/ket_noi_nguoi_than/01_analysis/requirement-analysis.md)
