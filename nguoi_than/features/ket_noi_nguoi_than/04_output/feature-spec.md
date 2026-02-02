# Feature Specification: KOLIA-1517 - Kết nối Người thân

> **Version:** 2.13  
> **Date:** 2026-01-30  
> **Status:** Ready for Implementation  
> **Schema:** v2.13 + Dashboard APIs + Patient BP Thresholds

---

## 1. Overview

**Kết nối Người thân** cho phép Patient và Caregiver thiết lập bi-directional relationship để giám sát sức khỏe từ xa với 6-permission RBAC system.

### Key Features
- Bi-directional invites (Patient ↔ Caregiver)
- 6 granular permission categories
- ZNS + Deep Link invitations (SMS fallback)
- Real-time permission updates
- Dual-role support (Patient + Caregiver)
- **Profile Selection** (is_viewing) - persist selected patient across sessions

---

## 2. Metrics (v2.11)

| Metric | v1.0 | v2.11 (Current) |
|--------|:----:|:----------------:|
| **Feasibility** | 84/100 | **88/100** ✅ |
| **Impact** | 🟡 MEDIUM | 🟢 **LOW** |
| **Services** | 3 | 3 |
| **New Tables** | 4 | **6 NEW + 1 ALTER** |
| **Endpoints** | 8 REST, 9 gRPC | **14 REST, 15 gRPC** |
| **Tasks** | 29 | 40 |
| **Effort** | 67h | **80h** |

---

## 3. User Roles

| Role | Description |
|------|-------------|
| **Patient** | Người bệnh được theo dõi |
| **Caregiver** | Người thân theo dõi Patient |
| **Hybrid** | Vừa là Patient vừa là Caregiver |

---

## 4. Permission Categories

| ID | Permission | Description |
|:--:|------------|-------------|
| 1 | Health Overview | Xem tổng quan sức khỏe |
| 2 | Emergency Alert | Nhận cảnh báo khẩn cấp |
| 3 | Task Config | Thiết lập nhiệm vụ |
| 4 | Compliance Tracking | Theo dõi tuân thủ |
| 5 | Proxy Execution | Thực hiện thay |
| 6 | Encouragement | Gửi động viên |

---

## 5. API Summary

### Invite Management
| Method | Path | Description |
|:------:|------|-------------|
| POST | `/api/v1/invites` | Create invite |
| GET | `/api/v1/invites` | List invites |
| DELETE | `/api/v1/invites/{id}` | Cancel pending |
| POST | `/api/v1/invites/{id}/accept` | Accept |
| POST | `/api/v1/invites/{id}/reject` | Reject |

### Connection Management
| Method | Path | Description |
|:------:|------|-------------|
| GET | `/api/v1/connections` | List connections |
| DELETE | `/api/v1/connections/{id}` | Disconnect |
| GET | `/api/v1/connections/{id}/permissions` | Get permissions |
| PUT | `/api/v1/connections/{id}/permissions` | Update |
| GET | `/api/v1/connections/viewing` | Get viewing patient |
| PUT | `/api/v1/connections/viewing` | Set viewing patient |

### Lookup APIs
| Method | Path | Description |
|:------:|------|-------------|
| GET | `/api/v1/connection/permission-types` | List permission types |
| GET | `/api/v1/connection/relationship-types` | List relationship types |

### Dashboard APIs (v2.13)
| Method | Path | Description |
|:------:|------|-------------|
| GET | `/api/v1/patients/{id}/blood-pressure-chart` | BP chart + patient thresholds |
| GET | `/api/v1/patients/{id}/periodic-reports` | Patient reports + read status |

> **v2.13:** Blood pressure chart now includes `patient_target_thresholds` from health_profile

---

## 6. Database Schema (v2.11)

| Table | Status | Purpose |
|-------|:------:|---------|
| `relationships` | ✅ NEW | Lookup (17 types) |
| `connection_permission_types` | ✅ NEW | Permission lookup (6 types) |
| `connection_invites` | ✅ NEW | Invite records |
| `user_emergency_contacts` | 🔄 EXTEND | +5 columns for caregiver (incl. is_viewing) |
| `connection_permissions` | ✅ NEW | RBAC flags (FK to permission_types) |
| `invite_notifications` | ✅ NEW | Delivery tracking |
| **`caregiver_report_views`** | ✅ **NEW** | Report read tracking |

> `user_connections` from v1.0 merged into `user_emergency_contacts`
> `is_viewing` column added in v2.7 for profile selection

---

## 7. Implementation Phases

| Phase | Duration | Focus |
|:-----:|----------|-------|
| 1 | Week 1-2 | DB, Entities, gRPC, REST |
| 2 | Week 3 | Permissions, Kafka, Notifications |
| 3 | Week 4 | Testing, UAT |

---

## 8. Key Business Rules (41 total)

| BR-ID | Description |
|-------|-------------|
| BR-001 | Bi-directional invites |
| BR-004 | ZNS → SMS fallback (3x retry) |
| BR-006 | No self-invite |
| BR-007 | No duplicate pending invite |
| BR-009 | Default permissions ALL ON |
| BR-018 | Red warning for emergency OFF |
| BR-026 | Profile selection persisted (is_viewing) |
| **BR-DB-*** | 11 Dashboard rules |
| **BR-RPT-*** | 2 Report rules |
| **SEC-DB-*** | 3 Security rules |

---

## 9. Documentation

| Document | Path |
|----------|------|
| Analysis | `01_analysis/` |
| Planning | `02_planning/` |
| Review | `03_review/` |
| Output | `04_output/` |

---

## References

- [SRS v2.4](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/srs_input_documents/srs_nguoi_than.md)
- [Implementation Plan](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/features/ket_noi_nguoi_than/04_output/implementation-plan.md)
- [Tasks](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/features/ket_noi_nguoi_than/02_planning/implementation-tasks.md)
