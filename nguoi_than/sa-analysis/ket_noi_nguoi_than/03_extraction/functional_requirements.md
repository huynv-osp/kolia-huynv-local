# Functional Requirements: KOLIA-1517 - Kết nối Người thân

> **Phase:** 3 - Functional Requirements Extraction  
> **Date:** 2026-02-13  
> **Source:** SRS v4.0 / v5.0  
> **Revision:** v4.0 - Updated for Family Group model, Admin-only invites, auto-connect, soft-disconnect

---

## PHẦN A: Role Người bệnh (Patient)

### A.1 Gửi lời mời kết nối (Admin-only)

> **v4.0:** Chỉ Admin (Quản trị viên) mới có thể gửi lời mời. Member không gửi được.
> **v5.0:** Form đơn giản hóa — chỉ SĐT. Bỏ MQH, bỏ config permissions.

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-A1.1 | **Chỉ Admin** mới có quyền gửi lời mời (BR-041) | P0 |
| FR-A1.2 | Admin nhấn "+ Mời" tại slot trống trong BS-QLTV | P0 |
| FR-A1.3 | Pre-check: gói hết hạn? → CTA Gia hạn (BR-037) | P0 |
| FR-A1.4 | Pre-check: slot trống cho role? → CTA Nâng cấp (BR-047) | P0 |
| FR-A1.5 | Form chỉ có 1 trường: SĐT (v5.0, bỏ MQH + permissions) | P0 |
| FR-A1.6 | Validate: exclusive group (BR-057, 1 user = 1 group) | P0 |
| FR-A1.7 | Gửi notification (ZNS/SMS/Push) | P0 |
| FR-A1.8 | Permissions mặc định ALL ON (6 quyền) | P0 |

### A.2 Nhận lời mời

> **v4.0:** Receiver chọn MQH khi accept (POP-MQH)

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-A2.1 | Hiển thị lời mời trong list (SCR-01 hoặc Bản tin) | P0 |
| FR-A2.2 | Accept: Hiển thị POP-MQH để chọn Mối quan hệ | P0 |
| FR-A2.3 | Accept → Auto-connect CG to ALL Patients in group (v4.1) | P0 |
| FR-A2.4 | Notify ALL existing members when new member joins (BR-052) | P1 |

### A.3 Quản lý danh sách Người thân

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-A3.1 | Xem list "Người thân của tôi" (tab "Theo dõi tôi") | P1 |
| FR-A3.2 | Hiển thị badge "🚫 Bị tắt quyền" cho CG bị revoke | P0 |
| FR-A3.3 | Hiển thị pending invites với badge "⏳ Chờ phản hồi" | P1 |
| FR-A3.4 | Section counts chỉ đếm connected (không đếm revoked) | P1 |

### A.4 Phân quyền truy cập

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-A4.1 | Toggle 6 permission categories | P0 |
| FR-A4.2 | Red warning for Emergency OFF (BR-018) | P0 |
| FR-A4.3 | Block toggle nếu CG bị "Tắt quyền" → hiện "Mở lại quyền trước" | P0 |
| FR-A4.4 | Minimum 1 permission ON khi toggle bình thường (BR-039) | P1 |

### A.5 Tắt quyền theo dõi (Soft Disconnect)

> **v4.0:** Thay thế "Hủy kết nối" (hard delete). Connection giữ nguyên, chỉ tắt ALL permissions.

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-A5.1 | Patient tắt quyền → ALL 6 permissions → OFF | P0 |
| FR-A5.2 | Hành động **im lặng** (KHÔNG notify CG, BR-056) | P0 |
| FR-A5.3 | CG vẫn thấy connection nhưng KHÔNG truy cập data nào | P0 |
| FR-A5.4 | Patient có thể "Mở lại quyền" → ALL 6 permissions → ON | P0 |
| FR-A5.5 | Bypass BR-039 (minimum 1 ON) khi revoke | P1 |

---

## PHẦN B: Role Người thân (Caregiver)

### B.1 ~~Gửi yêu cầu theo dõi~~ → REMOVED

> **v4.0:** Caregiver KHÔNG tự gửi invite. Chỉ Admin mới gửi (BR-041).

### B.2 Nhận lời mời từ Admin

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-B2.1 | Hiển thị lời mời trong list | P0 |
| FR-B2.2 | Accept → chọn MQH (POP-MQH) | P0 |
| FR-B2.3 | Accept → Auto-connect ALL Patients trong nhóm | P0 |
| FR-B2.4 | 6 default permissions = ALL ON | P0 |
| FR-B2.5 | Reject và clear từ list | P0 |
| FR-B2.6 | Notification qua ZNS/Push | P0 |

### B.3 Danh sách "Tôi đang theo dõi"

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-B3.1 | Xem list Patients đang theo dõi | P1 |
| FR-B3.2 | Nhìn thấy Patient bị "Tắt quyền" với badge phù hợp | P1 |
| FR-B3.3 | Context switch to Patient profile | P1 |

### B.4 Xem chi tiết Patient

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-B4.1 | View Patient dashboard (per permissions) | P1 |
| FR-B4.2 | Block access khi bị "Tắt quyền" → empty state | P0 |

### B.5 Bị tắt quyền bởi Patient

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-B5.1 | CG thấy connection nhưng KHÔNG truy cập data | P0 |
| FR-B5.2 | KHÔNG nhận notification khi bị tắt (im lặng) | P0 |

---

## PHẦN C: Quản lý Nhóm Gia Đình (Admin)

### C.1 Family Group Management (BS-QLTV)

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-C1.1 | BS-QLTV hiển thị danh sách members với slots | P0 |
| FR-C1.2 | Phân section: Người bệnh / Người thân | P0 |
| FR-C1.3 | Hiển thị slot trống với CTA "Mời" | P0 |
| FR-C1.4 | Admin xoá member → giải phóng slot | P0 |
| FR-C1.5 | Admin xoá member → SyncMembers REMOVE to payment | P0 |
| FR-C1.6 | Popup chọn MQH cho thành viên cũ khi có người mới (POP-NEW-MEMBER) | P1 |

### C.2 Slot Management

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-C2.1 | Formula: slot_trống = tổng_slot - đã_gán - pending | P0 |
| FR-C2.2 | Nút "Mời" luôn hiển thị, popup khi hết slot (BR-059) | P0 |
| FR-C2.3 | Accept re-check slot (race condition, AD-04) | P0 |

---

## PHẦN D: Dashboard Requirements (US 1.1) — GIỮU GUYêN

> Các FR-C1.x~C3.x từ SRS v3.0 giữ nguyên, không thay đổi. Xem functional_requirements v2.11 cho chi tiết.

---

## Business Rules Summary (v4.0)

### Core Connection Rules (BR-001 → BR-029 — UPDATED)

| BR-ID | Description | v4.0 Change |
|-------|-------------|:-----------:|
| BR-001 | ~~Bi-directional invites~~ → **Admin-only invites** | 🔴 CHANGED |
| BR-006 | No self-invite | ✅ KEEP |
| BR-007 | No duplicate pending invite | ✅ KEEP |
| BR-008 | Accept → Create connection + 6 perms | 🟡 UPDATE (+auto-connect) |
| BR-009 | Default permissions ALL ON | ✅ KEEP |
| BR-010 | Notify sender khi accept | 🟡 UPDATE (+broadcast all) |
| BR-011 | Reject → Allow re-invite | ✅ KEEP |
| BR-021 | ~~KHÔNG GIỚI HẠN~~ → **Slot-based from payment** | 🔴 CHANGED |
| BR-022 | Account deleted → Cascade delete + Notify | ✅ KEEP |

### NEW Business Rules (v4.0)

| BR-ID | Description | Impact |
|-------|-------------|--------|
| BR-037 | Check gói hết hạn trước khi invite | Pre-check |
| BR-039 | Minimum 1 permission ON (bypass khi revoke) | Permission logic |
| BR-041 | **Admin-only invites** | Core change |
| BR-047 | Slot check trước khi invite | Pre-check |
| BR-052 | Broadcast noti khi thành viên mới accept | Notification |
| BR-056 | Tắt quyền = **silent** (không notify CG) | Behavior |
| BR-057 | **Exclusive Group** (1 user = 1 group) | Constraint |
| BR-059 | Nút Mời luôn hiển thị, popup khi hết slot | UX |

### Security Requirements (Updated)

| SEC-ID | Description | Priority |
|--------|-------------|:--------:|
| SEC-001 | API health-overview PHẢI check permission + permission_revoked | P0 |
| SEC-002 | Permission Revoke: check mỗi lần gọi → 403 | P0 |
| SEC-003 | Deep Link Protection: Validate quyền trước render | P1 |
| SEC-004 | **Admin check: Verify Admin role from payment-service** | P0 |
| SEC-005 | **Slot race condition: Double-check at accept time** | P0 |
