# Requirement Analysis: KOLIA-1517 - Kết nối Người thân

> **Phase:** 1 - Requirement Intake & Classification  
> **Date:** 2026-02-02  
> **SRS Version:** v3.0  
> **Revision:** v2.15 - Added Default View State (UX-DVS-*) rules

---

## 1. Feature Classification

| Field | Value |
|-------|-------|
| **Feature Name** | Kết nối Người thân (Connection Flow) |
| **Type** | New Feature |
| **Complexity** | Complex (Multi-role, RBAC, Notification integration) |
| **JIRA Ticket** | KOLIA-1517 |

---

## 2. Architecture Decision Record (ADR)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Primary Service | user-service | User relationship management belongs in user domain |
| Communication | gRPC | Standard pattern for service-to-service calls |
| Data Storage | 5 new tables + 1 ALTER | Includes permission_types lookup |
| Notification Channel | ZNS → SMS → Push | Multi-channel with fallback for reliability |
| Permission Model | RBAC (6 categories) | Granular control per Patient requirement |

---

## 3. Scope Boundaries

### ✅ IN SCOPE
- Bi-directional invites (Patient ↔ Caregiver)
- 6-permission RBAC system
- ZNS/SMS notification with deep links
- Profile Selector UI (5 states)
- Connection lifecycle management (invite → accept → disconnect)
- Permission configuration on acceptance
- Real-time permission update notifications

### ❌ OUT OF SCOPE
- Caregiver Dashboard nâng cao (SRS #2)
- Thực hiện nhiệm vụ thay Patient (chỉ define permission)
- Messaging system (chỉ define permission, không implement)
- Admin panel for connection management
- Analytics và reporting

---

## 4. User Stories Summary

### PHẦN A: Role Người bệnh (Patient)

| Story ID | User Story | Priority |
|----------|------------|:--------:|
| A1 | Gửi lời mời cho người thân | P0 |
| A2 | Nhận và xử lý lời mời từ Caregiver | P0 |
| A3 | Quản lý danh sách "Người thân của tôi" | P1 |
| A4 | Kiểm soát quyền truy cập của Caregiver | P0 |
| A5 | Hủy kết nối với Caregiver | P1 |

### PHẦN B: Role Người thân (Caregiver)

| Story ID | User Story | Priority |
|----------|------------|:--------:|
| B1 | Gửi lời mời cho Patient | P0 |
| B2 | Nhận và xử lý lời mời từ Patient | P0 |
| B3 | Xem danh sách "Tôi đang theo dõi" | P1 |
| B4 | Xem chi tiết Patient | P1 |
| B5 | Ngừng theo dõi Patient | P1 |

---

## 5. Key Business Rules (46 BRs)

### 5.1 Core Connection Rules (25 BRs)

| BR-ID | Description | Priority |
|-------|-------------|:--------:|
| BR-001 | Bi-directional invites | P0 |
| BR-002 | ZNS + Push for existing users | P0 |
| BR-003 | ZNS + Deep Link for new users | P0 |
| BR-004 | ZNS fail → SMS fallback (3x retry, 30s) | P0 |
| BR-006 | No self-invite | P0 |
| BR-007 | No duplicate pending invite | P0 |
| BR-008 | Accept → Create connection + Apply 6 permissions | P0 |
| BR-009 | Default permissions = ALL ON | P0 |
| BR-010 | Notify sender khi accept | P0 |
| BR-011 | Reject → Allow re-invite | P1 |
| BR-012 | Pending invite → Action item in Bản tin | P1 |
| BR-013 | Multiple invites → FIFO order | P1 |
| BR-014 | Display: Avatar, Tên, Last active | P1 |
| BR-015 | Empty state với CTA phù hợp role | P2 |
| BR-016 | Permission change → Notify Caregiver | P0 |
| BR-017 | Permission OFF → Hide UI block | P0 |
| BR-018 | Red warning for emergency alert toggle | P0 |
| BR-019 | Patient disconnect → Notify Caregiver | P0 |
| BR-020 | Caregiver exit → Notify Patient | P0 |
| BR-021 | Phase 1: KHÔNG GIỚI HẠN số connections | P1 |
| BR-022 | Account deleted → Cascade delete connections | P0 |
| BR-023 | Badge tap → Navigate to Kết nối NT | P2 |
| BR-024 | Confirmation popup for ALL permission changes | P0 |
| BR-025 | Message phân biệt rõ invite type | P1 |
| BR-028 | Relationship type lưu khi tạo connection | P0 |
| BR-029 | Display format: "{Mối QH} ({Họ tên})", "khac"→"Người thân" | P1 |

### 5.2 Dashboard Rules (11 BR-DB-*)

| BR-ID | Description | Priority |
|-------|-------------|:--------:|
| BR-DB-001 | Line Chart 2 đường (Tâm thu xanh lá, Tâm trương xanh dương) | P0 |
| BR-DB-002 | Auto week/month toggle based on data availability | P1 |
| BR-DB-003 | Toggle Week/Month cho chart | P0 |
| BR-DB-004 | Drill-down ngày → danh sách chi tiết | P1 |
| BR-DB-005 | Giá trị trung bình mỗi ngày tính từ measurements | P0 |
| BR-DB-006 | Chart hiển thị 7 days (week) hoặc ~30 days (month) | P0 |
| BR-DB-007 | Empty state khi không có data trong khoảng thời gian | P1 |
| BR-DB-008 | Loading state khi fetch data | P1 |
| BR-DB-009 | Error state với retry button | P1 |
| BR-DB-010 | Refresh để load lại data | P2 |
| BR-DB-011 | Chart responsive theo screen size | P2 |

### 5.3 Report Rules (2 BR-RPT-*)

| BR-ID | Description | Priority |
|-------|-------------|:--------:|
| BR-RPT-001 | Hiển thị danh sách báo cáo với `is_read` status | P0 |
| BR-RPT-002 | Header format: "Báo cáo {type} - {period}" | P1 |

### 5.4 Security Rules (3 SEC-DB-*)

| SEC-ID | Description | Priority |
|--------|-------------|:--------:|
| SEC-DB-001 | API `/patients/{id}/...` PHẢI check connection + permission | P0 |
| SEC-DB-002 | Permission revoke → Real-time 403 response | P0 |
| SEC-DB-003 | Deep link protection với connection validation | P0 |

### 5.5 Default View State Rules (5 UX-DVS-*) - NEW v2.15

> **SRS Reference:** SRS v3.0 - Kịch bản B.4.3b, B.4.3c, B.4.3d

| Rule-ID | Description | Priority |
|---------|-------------|:--------:|
| UX-DVS-001 | Page load (no localStorage) → Default View Prompt | P0 |
| UX-DVS-002 | CTA "Xem danh sách" → toggleBottomSheet() | P0 |
| UX-DVS-003 | Close Bottom Sheet → updateStopFollowUI(selectedPatient) | P0 |
| UX-DVS-004 | "Ngừng theo dõi" link: visible when selectedPatient != null | P0 |
| UX-DVS-005 | showStopFollowModal() validates selectedPatient | P1 |

---

## 6. Dependencies & Assumptions

### Dependencies

| Dependency | Status | Notes |
|------------|:------:|-------|
| ZNS (Zalo Notification Service) | 🟡 Cần setup | Kênh chính gửi lời mời |
| Deep Link Infrastructure | 🟡 Cần setup | `kolia://invite?id={xxx}` |
| Push Notification Service | ✅ Available | Đã có từ features khác |
| SMS Gateway | ✅ Available | Fallback khi ZNS fail |

### Assumptions

1. User đã hoàn thành onboarding trước khi sử dụng tính năng
2. Mỗi user chỉ đăng nhập 1 thiết bị tại 1 thời điểm
3. Phase 1: Không giới hạn số lượng người thân
4. 1 user có thể vừa là Patient vừa là Caregiver
5. Bi-directional invites: Cả Patient và Caregiver đều có thể gửi lời mời

---

## 7. Validation Rules

| Field | Rule | Example |
|-------|------|---------|
| Số điện thoại | 10 digits, starts with 0 | 0912345678 |
| Tên người thân | 2-50 characters | Nguyễn Văn A |
| Mối quan hệ | Required, enum (14 values) | con_trai, me |
| Permission | Boolean ON/OFF | true, false |

---

## 8. UI Screens

| Screen ID | Name | Role |
|-----------|------|:----:|
| SCR-01 | Kết nối Người thân | Both |
| SCR-02-BS | Invite Bottom Sheet | Both |
| SCR-02B | Cấu hình quyền (Invite) | Patient |
| SCR-02B-ACCEPT | Cấu hình quyền (Accept) | Patient |
| SCR-04 | Chi tiết Caregiver | Patient |
| SCR-04B | Chi tiết Pending Invite | Patient |
| SCR-05 | Quyền truy cập | Patient |
| SCR-06 | Chi tiết Patient | Caregiver |

---

## References

- [SRS v3.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/srs_input_documents/srs_nguoi_than_v3.md)
- [SA Analysis v2.15](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/ket_noi_nguoi_than/v2.15_default_view_state.md)
