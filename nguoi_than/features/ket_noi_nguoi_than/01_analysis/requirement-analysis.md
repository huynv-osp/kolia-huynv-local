# Requirement Analysis: KOLIA-1517 - Kết nối Người thân

> **Phase:** 1 - Requirement Intake & Classification  
> **Date:** 2026-02-13  
> **SRS Version:** v4.0 (v5.3 revisions)  
> **Revision:** v4.0 - Admin-only invites, Family Group model, 5-service architecture

---

## 1. Feature Classification

| Field | Value |
|-------|-------|
| **Feature Name** | Kết nối Người thân (Connection Flow) |
| **Type** | New Feature |
| **Complexity** | Complex (Multi-role, Admin-managed groups, Payment integration, 5 services) |
| **JIRA Ticket** | KOLIA-1517 |
| **Feasibility** | 82/100 ✅ FEASIBLE |
| **Impact Level** | 🟡 MEDIUM |
| **Effort** | ~80h (5 services) |

---

## 2. Architecture Decision Record (ADR)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Primary Service | user-service | User relationship + family group management belongs in user domain |
| Communication | gRPC | Standard pattern for service-to-service calls |
| Data Storage | 7 tables (5 original + 2 NEW) + 1 ALTER | +family_groups, +family_group_members |
| Notification Channel | ZNS → SMS → Push | Multi-channel with fallback for reliability |
| Permission Model | RBAC (6 categories) | SRS A.4 lists 5, BRs reference 6, code keeps 6 for extensibility |
| Invite Model | **Admin-only** (BR-041) | Payment SRS §2.8 — only package Admin sends invites |
| Group Model | **Exclusive** (BR-057) | 1 user = 1 family group at any time |
| Disconnect Model | **Soft disconnect** (BR-040) | permission_revoked flag, keep connection, restorable |
| Payment Integration | user→payment gRPC | Slot check, GetSubscription for package info |
| Auto-connect | **CG → ALL patients** (BR-045) | When CG accepts → auto-follow all patients in group |

---

## 3. Scope Boundaries

### ✅ IN SCOPE
- **Admin-only invites** — Only Admin (Quản trị viên) can invite members to family group (BR-041)
- **Family Group management** — Admin manages group slots, add/remove members (BR-043, BR-044)
- 6-permission RBAC system with soft disconnect (permission_revoked)
- ZNS/SMS notification with deep links
- Profile Selector UI (4 states: A/B/C/E) — v5.3 simplified from 8→4
- Connection lifecycle: invite → accept → tắt quyền theo dõi (no hard delete)
- **Slot-based connections** per package (BR-033, BR-059)
- **Auto-connect:** CG accept → follow ALL patients (BR-045)
- **Leave group:** Non-Admin can self-leave (BR-061)
- **Admin remove member:** Admin can remove any member except self (BR-058)
- Payment integration for slot check/consume

### ❌ OUT OF SCOPE
- Caregiver Dashboard nâng cao (SRS #2)
- Thực hiện nhiệm vụ thay Patient (chỉ define permission)
- Messaging system (chỉ define permission, không implement)
- Analytics và reporting

---

## 4. User Stories Summary

### PHẦN A: Role Người bệnh (Patient)

| Story ID | User Story | Priority | v4.0 Changes |
|----------|------------|:--------:|:------------:|
| A1 | **Admin** mời người thân vào nhóm gia đình | P0 | ⚠️ Admin-only (was bi-directional) |
| A2 | Nhận lời mời từ Admin | P0 | ⚠️ Shared flow (→ §C.2.2) |
| A3 | Quản lý danh sách "Người đang theo dõi tôi" | P1 | Updated empty states |
| A4 | Kiểm soát quyền truy cập Caregiver (5 permissions) | P0 | ⚠️ Soft disconnect instead of hard delete |
| A5 | **Tắt quyền theo dõi** của Caregiver | P0 | ⚠️ NEW (was "Hủy kết nối") |

### PHẦN B: Role Người thân (Caregiver)

| Story ID | User Story | Priority | v4.0 Changes |
|----------|------------|:--------:|:------------:|
| B1 | Nhận và xử lý lời mời từ Admin | P0 | ⚠️ Accept only (was bi-directional) |
| B2 | Xem danh sách "Tôi đang theo dõi" | P1 | Auto-connect populates list |
| B3 | Trạng thái màn hình & Empty States | P1 | ⚠️ UX-DVS updated, "Ngừng theo dõi" ẨN |
| D1 | Dashboard Patient (US 1.1 Health Overview) | P1 | Unchanged |

### PHẦN C: Shared

| Story ID | User Story | Priority | v4.0 Note |
|----------|------------|:--------:|:---------:|
| C2.1 | Chấp nhận lời mời vào nhóm | P0 | Unified accept flow |
| C2.2 | Từ chối lời mời vào nhóm | P0 | Unified reject flow |
| C2.3 | Rời nhóm (Non-Admin) | P0 | ⚠️ NEW (BR-061) |

---

## 5. Key Business Rules (60+ BRs)

### 5.1 Core Connection Rules (25 BRs)

| BR-ID | Description | Priority | v4.0 Δ |
|-------|-------------|:--------:|:------:|
| BR-001 | **Admin-only invites** (was bi-directional) | P0 | ⚠️ |
| BR-002 | ZNS + Push for existing users | P0 | |
| BR-003 | ZNS + Deep Link for new users | P0 | |
| BR-004 | ZNS fail → SMS fallback (3x retry, 30s) | P0 | |
| BR-006 | No self-invite (**Admin exception:** can self-add with auto-accept, BR-049) | P0 | ⚠️ |
| BR-007 | No duplicate pending invite | P0 | |
| BR-008 | Accept → Create connection + Apply 6 permissions | P0 | |
| BR-009 | Default permissions = ALL ON | P0 | |
| BR-010 | Notify sender khi accept/reject | P1 | |
| BR-011 | Reject → Allow re-invite | P1 | |
| BR-012 | Pending invite → Action item in Bản tin | P1 | |
| BR-013 | Multiple invites → FIFO order | P1 | |
| BR-014 | Display: Avatar, Tên. **KHÔNG có** Last active. Badge "🚫" nếu bị tắt quyền | P1 | ⚠️ |
| BR-015 | Empty state phân biệt Admin vs Member (CTA khác nhau) | P2 | ⚠️ |
| BR-016 | Permission change → **KHÔNG notify** Caregiver (silent, BR-056) | P0 | ⚠️ |
| BR-017 | Permission OFF → Hide UI block | P0 | |
| BR-018 | Red warning for emergency alert toggle | P0 | |
| BR-019 | **Tắt quyền theo dõi** → silent revoke, connection giữ (was disconnect+notify) | P0 | ⚠️ |
| BR-020 | Caregiver exit → Notify Patient | P1 | |
| BR-021 | **Giới hạn slot theo gói** (was unlimited) | P0 | ⚠️ |
| BR-022 | Account deleted → Cascade delete + Notify | P0 | |
| BR-023 | Badge tap → Navigate to "Kết nối NT" | P1 | |
| BR-024 | Confirm popup **chỉ khi TẮT** permission. BẬT = apply ngay | P0 | ⚠️ |
| BR-025 | Message phân biệt rõ invite type | P0 | |
| BR-028 | Relationship type lưu khi tạo connection | P0 | |
| BR-029 | Display: "Tôi đang theo dõi" = {MQH} ({Tên}), "Người đang theo dõi tôi" = {Tên} | P0 | |

### 5.2 Admin & Group Rules (20 BRs — NEW v4.0)

| BR-ID | Description | Priority |
|-------|-------------|:--------:|
| BR-030 | Relationship direction ONE-WAY: "Bạn là gì với người này?" | P0 |
| BR-031 | ZNS cho add_caregiver dùng tên Admin | P0 |
| BR-032 | No name collection on invite (from onboarding profile) | P0 |
| BR-033 | **Slot pre-check** before invite (→ payment-service) | P0 |
| BR-034 | Auto-assign sender role if no slot | P0 |
| BR-035 | Connection = Premium access (slot consumed) | P0 |
| BR-036 | Hủy connection/invite = giải phóng slot | P0 |
| BR-037 | Expired package = block invite | P0 |
| BR-038 | CG cannot self-monitor (EC-43) | P0 |
| BR-039 | Minimum 1 permission ON (exception: tắt quyền theo dõi) | P0 |
| BR-040 | **Tắt quyền theo dõi:** permission_revoked=true, connection giữ, restorable | P0 |
| BR-041 | **Admin-only:** Ma trận quyền (Admin: invite+remove, Member: accept/reject only) | P0 |
| BR-042 | Bottom Sheet icons: [✏️] for "Tôi đang theo dõi", [⚙️] for "Người đang theo dõi tôi" | P0 |
| BR-043 | Nút 👥 header SCR-01 → BS-QLTV (Admin only) | P0 |
| BR-044 | BS-QLTV hiển thị theo cấu trúc gói (slots), **không hiển slot count** | P1 |
| BR-045 | **Auto-connect:** CG accept → follow ALL patients, ALL ON | P0 |
| BR-046 | **Patient dual-control:** Tầng 1 (ai follow), Tầng 2 (xem gì) | P0 |
| BR-047 | Slot full → popup "Đã đạt giới hạn", [Nhập mã kích hoạt] | P0 |
| BR-048 | Dual-role allowed: 1 user = 2 roles (P + CG) in 1 group | P0 |
| BR-049 | Admin self-add → auto-accept, no invite sent | P0 |

### 5.3 Group Constraints & Leave (BRs 050–061 — NEW v4.0–v5.3)

| BR-ID | Description | Priority |
|-------|-------------|:--------:|
| BR-050 | MQH optional on accept (→ CG chọn sau tại SCR-06) | P0 |
| BR-051 | Empty state theo role: Admin CTA → BS-QLTV, Non-Admin → guidance only | P0 |
| BR-052 | New member push noti → ALL existing members | P0 |
| BR-054 | MQH fallback + substitution (chưa chọn → {Tên}) | P0 |
| BR-055 | Simplified invite form: chỉ SĐT (bỏ MQH + config quyền) | P0 |
| BR-056 | **Silent revoke/restore:** KHÔNG notify CG khi on/off quyền | P0 |
| BR-057 | **Exclusive Group:** 1 user = 1 nhóm, chặn invite user đã thuộc nhóm khác | P0 |
| BR-058 | Admin KHÔNG thể xoá chính mình | P0 |
| BR-059 | Slot limit formula: `slot_trống = tổng_slot - đã_gán - pending` | P0 |
| BR-061 | **Leave group:** Non-Admin tự rời nhóm, slot giải phóng | P0 |

### 5.4 Dashboard Rules (11 BR-DB-*)

_Unchanged from v2.23 — see SA analysis for details._

### 5.5 Report Rules (2 BR-RPT-*)

_Unchanged from v2.23._

### 5.6 Security Rules (3 SEC-DB-*)

_Unchanged from v2.23._

### 5.7 Default View State Rules (5 UX-DVS-*) — Updated v4.0

| Rule-ID | Description | Priority | v4.0 Δ |
|---------|-------------|:--------:|:------:|
| UX-DVS-001 | Page load (no localStorage) → Default View Prompt | P0 | |
| UX-DVS-002 | CTA "Xem danh sách" → toggleBottomSheet() | P0 | |
| UX-DVS-003 | Close Bottom Sheet → updateStopFollowUI(selectedPatient) | P0 | |
| UX-DVS-004 | **v4.0: ĐÃ ẨN.** Link "Ngừng theo dõi" ẨN trong mọi trường hợp (Admin-only remove) | P0 | ⚠️ |
| UX-DVS-005 | showStopFollowModal() validates selectedPatient | P1 | |

---

## 6. Dependencies & Assumptions

### Dependencies

| Dependency | Status | Notes |
|------------|:------:|-------|
| ZNS (Zalo Notification Service) | 🟡 Cần setup | Kênh chính gửi lời mời |
| Deep Link Infrastructure | 🟡 Cần setup | `kolia://invite?id={xxx}` |
| Push Notification Service | ✅ Available | Đã có từ features khác |
| SMS Gateway | ✅ Available | Fallback khi ZNS fail |
| **Payment Service** | ✅ Available | **NEW v4.0:** Slot check, GetSubscription gRPC |

### Assumptions

1. User đã hoàn thành onboarding trước khi sử dụng tính năng
2. Mỗi user chỉ đăng nhập 1 thiết bị tại 1 thời điểm
3. **Giới hạn slot theo gói:** `slot_trống = tổng_slot - đã_gán - pending` (BR-059). Nút "+" LUÔN hiển thị, popup khi slot=0
4. 1 user có thể vừa là Patient vừa là Caregiver (BR-048)
5. **Admin-only invites:** Chỉ Admin gửi invite. Member chỉ accept/reject (BR-041)
6. **Connection = Slot:** Accept = Premium access, slot consumed (BR-035)
7. **Admin role từ Payment:** Người kích hoạt gói = Admin (cross-ref Payment SRS §2.8)
8. **Auto-connect:** CG accept → auto-follow ALL patients, ALL ON (BR-045)
9. **Patient dual-control:** 2 tầng quyền — ai follow + xem gì (BR-046)
10. **Exclusive Group:** 1 user = 1 nhóm duy nhất (BR-057)

---

## 7. Validation Rules

| Field | Rule | Example |
|-------|------|---------|
| Số điện thoại | 10 digits, starts with 0 | 0912345678 |
| Mối quan hệ | Optional on invite, enum (14 values), chọn tại SCR-06 | con_trai, me |
| Permission | Boolean ON/OFF | true, false |

> **v4.0:** Bỏ trường Tên và MQH khỏi form invite (BR-055). Tên từ onboarding profile (BR-032).

---

## 8. UI Screens

| Screen ID | Name | Role | v4.0 Status |
|-----------|------|:----:|:-----------:|
| SCR-01 | Kết nối Người thân | Both | Updated (4 states) |
| SCR-02-BS | Invite Bottom Sheet | **Admin** | ⚠️ Admin-only, 2 variants (🩺/👥) |
| ~~SCR-02~~ | ~~Mời Người thân~~ | ~~Both~~ | ❌ DEPRECATED |
| ~~SCR-02B~~ | ~~Cấu hình quyền (Invite)~~ | ~~Patient~~ | ❌ DEPRECATED (v5.0) |
| ~~SCR-02B-ACCEPT~~ | ~~Cấu hình quyền (Accept)~~ | ~~Patient~~ | ❌ DEPRECATED (v5.0) |
| SCR-04 | Chi tiết Caregiver | Patient | Updated (tắt/mở quyền) |
| SCR-04B | Chi tiết Pending Invite | Patient | Unchanged |
| SCR-05 | Quyền truy cập | Patient | Unchanged |
| SCR-06 | Chi tiết người thân | Caregiver | ⚠️ MQH dropdown (v5.2) |
| **BS-QLTV** | **Bottom Sheet Quản lý nhóm** | **Admin** | ⚠️ NEW v4.0 |
| SCR-REPORT-LIST | Danh sách Báo cáo | Caregiver | Unchanged |

---

## References

- [SRS v4.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/srs_input_documents/srs_nguoi_than_nhom_gia_dinh.md)
- [SA Analysis v4.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/ket_noi_nguoi_than/)
- [SA Service Mapping v4.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/ket_noi_nguoi_than/04_mapping/service_mapping.md)
- [SA Feasibility v4.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/ket_noi_nguoi_than/05_feasibility/feasibility_report.md)
