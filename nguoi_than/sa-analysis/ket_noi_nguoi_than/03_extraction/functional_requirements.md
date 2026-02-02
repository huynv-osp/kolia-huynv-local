# Functional Requirements: KOLIA-1517 - Kết nối Người thân

> **Phase:** 3 - Functional Requirements Extraction  
> **Date:** 2026-02-02  
> **Source:** SRS v3.0  
> **Revision:** v2.11 - Added Default View State (UX-DVS-*) requirements from SRS v3

---

## PHẦN A: Role Người bệnh (Patient)

### A.1 Gửi lời mời kết nối

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-A1.1 | Patient nhập SĐT → tìm user theo SĐT | P0 |
| FR-A1.2 | Hiển thị "Chọn mối quan hệ" (14 options) | P0 |
| FR-A1.3 | Nhập tên hiển thị (nếu new user) | P0 |
| FR-A1.4 | Cấu hình 6 quyền truy cập | P0 |
| FR-A1.5 | Gửi notification (ZNS/SMS/Push) | P0 |

### A.2 Nhận lời mời từ Caregiver

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-A2.1 | Hiển thị lời mời trong list | P0 |
| FR-A2.2 | Patient PHẢI cấu hình quyền khi Accept | P0 |

### A.3 Quản lý danh sách Người thân

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-A3.1 | Xem list "Người thân của tôi" | P1 |
| FR-A3.2 | Hiển thị last active timestamp | P1 |
| FR-A3.3 | Filter/sort capability | P2 |
| FR-A3.4 | Hiển thị pending invites (tự gửi) với badge "⏳ Chờ phản hồi", cancel action | P1 |

### A.4 Phân quyền truy cập

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-A4.1 | Toggle 6 permission categories | P0 |
| FR-A4.2 | Red warning for Emergency OFF (BR-018) | P0 |

### A.5 Hủy kết nối

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-A5.1 | Patient disconnect → notify Caregiver | P1 |

---

## PHẦN B: Role Người thân (Caregiver)

### B.1 Gửi yêu cầu theo dõi

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-B1.1 | Caregiver nhập SĐT Patient | P0 |
| FR-B1.2 | Gửi request notification | P0 |

### B.2 Nhận lời mời từ Patient

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-B2.1 | Hiển thị lời mời trong list | P0 |
| FR-B2.2 | Accept với 6 default permissions (ALL ON) | P0 |
| FR-B2.3 | Reject và clear từ list | P0 |
| FR-B2.4 | Notification qua ZNS/Push | P0 |

### B.3 Danh sách "Tôi đang theo dõi"

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-B3.1 | Xem list Patients đang theo dõi | P1 |
| FR-B3.2 | Prioritized trong Profile Selector | P1 |
| FR-B3.3 | Context switch to Patient profile | P1 |
| FR-B3.4 | Hiển thị pending requests (tự gửi) với badge "⏳ Chờ phản hồi", cancel action | P1 |

### B.4 Xem chi tiết Patient

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-B4.1 | View Patient dashboard (per permissions) | P1 |

### B.4-DVS Default View State (NEW - SRS v3)

> **Reference:** SRS v3.0 - Kịch bản B.4.3b, B.4.3c, B.4.3d

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-B4-DVS.1 | Khi chưa có selectedPatient, hiển thị Default View Prompt với CTA | P0 |
| FR-B4-DVS.2 | CTA "Xem danh sách người thân" → toggle Bottom Sheet | P0 |
| FR-B4-DVS.3 | Đóng Bottom Sheet mà không chọn → giữ Default View Prompt | P0 |
| FR-B4-DVS.4 | Link "Ngừng theo dõi" chỉ hiện khi selectedPatient != null | P0 |
| FR-B4-DVS.5 | showStopFollowModal() validate selectedPatient trước khi hiện | P1 |

#### UX Rules (UX-DVS-*)

| Rule-ID | Mô tả |
|---------|-------|
| UX-DVS-001 | Page load lần đầu (no localStorage) → Default View Prompt |
| UX-DVS-002 | CTA "Xem danh sách" → toggleBottomSheet() |
| UX-DVS-003 | Close Bottom Sheet → updateStopFollowUI(selectedPatient) |
| UX-DVS-004 | Link "Ngừng theo dõi" visibility: selectedPatient != null && !emptyState |
| UX-DVS-005 | Modal validation before show |

### B.5 Ngừng theo dõi

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-B5.1 | Caregiver tự remove → notify Patient | P1 |

---

## PHẦN C: Dashboard Requirements (US 1.1)

### C.1 Xem tổng quan sức khỏe (BR-DB-*)

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-C1.1 | Line Chart 2 đường: Tâm thu (xanh lá), Tâm trương (xanh dương) | P0 |
| FR-C1.2 | Toggle Tuần/Tháng: Ưu tiên Tuần, fallback Tháng nếu empty | P0 |
| FR-C1.3 | Chip ngày: Swipe ngang, thứ tự cũ → mới | P1 |
| FR-C1.4 | 1 ngày nhiều lần đo → Hiển thị TRUNG BÌNH | P1 |
| FR-C1.5 | Tap điểm dữ liệu → Hiển thị tooltip | P1 |
| FR-C1.6 | Tap chip ngày cụ thể → Drill-down view theo GIỜ | P1 |
| FR-C1.7 | Permission #1 = OFF → Ẩn block HA và button Báo cáo | P0 |

### C.2 Báo cáo sức khỏe (BR-RPT-*)

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-C2.1 | "Xem báo cáo sức khỏe" → Navigate đến list báo cáo | P1 |
| FR-C2.2 | Block Báo cáo: Tối đa 3 báo cáo chưa đọc mới nhất | P0 |
| FR-C2.3 | Màn danh sách: Header = "Báo cáo SK của [Danh xưng]" | P1 |
| FR-C2.4 | Permission #1 = ON → Xem TOÀN BỘ sections báo cáo | P0 |

### C.3 Empty States

| ID | Requirement | Priority |
|----|-------------|:--------:|
| FR-C3.1 | Không có data HA → Message "Không có đủ dữ liệu..." | P1 |
| FR-C3.2 | Không có báo cáo → Message "Chưa có báo cáo nào..." | P1 |

---

## Business Rules Summary

### Core Connection Rules (BR-001 → BR-029)

| BR-ID | Description | Impact |
|-------|-------------|--------|
| BR-001 | Bi-directional invites | Core architecture |
| BR-002 | ZNS + Push for existing users | Notification logic |
| BR-003 | ZNS + Deep Link for new users | Notification logic |
| BR-004 | ZNS → SMS fallback (3x retry, 30s) | Notification logic |
| BR-006 | No self-invite | Validation |
| BR-007 | No duplicate pending invite | Unique constraint |
| BR-008 | Accept → Create connection + 6 perms | Transaction |
| BR-009 | Default permissions ALL ON | Business logic |
| BR-010 | Notify sender khi accept | Kafka event |
| BR-011 | Reject → Allow re-invite | State machine |
| BR-012 | Pending invite → Action item in Bản tin | UI integration |
| BR-013 | Multiple invites → FIFO order | Display logic |
| BR-014 | Display: Avatar, Tên, Last active | UI requirement |
| BR-015 | Empty state với CTA phù hợp role | UI requirement |
| BR-016 | Permission change → Notify Caregiver | Kafka event |
| BR-017 | Permission OFF → Hide UI block | Real-time update |
| BR-018 | Red warning for emergency OFF | UI safety |
| BR-019 | Patient disconnect → Notify Caregiver | Kafka event |
| BR-020 | Caregiver exit → Notify Patient | Kafka event |
| BR-021 | Phase 1: KHÔNG GIỚI HẠN số connections | Business limit |
| BR-022 | Account deleted → Cascade delete + Notify | Data integrity |
| BR-023 | Badge tap → Navigate to Kết nối NT | Navigation |
| BR-024 | Confirmation popup cho TẤT CẢ permission changes | UI safety |
| BR-025 | Message phân biệt rõ invite type | Display logic |
| BR-028 | Relationship type lưu khi tạo connection | Data storage |
| BR-029 | Display format: "{Mối QH} ({Họ tên})", "khac"→"Người thân" | Display logic |

### Dashboard Rules (BR-DB-*)

| BR-ID | Category | Description | Priority |
|-------|----------|-------------|:--------:|
| BR-DB-001 | Chart | Line Chart 2 đường: Tâm thu (xanh lá), Tâm trương (xanh dương) | P0 |
| BR-DB-002 | Filter | Toggle Tuần/Tháng: Ưu tiên Tuần, fallback Tháng nếu empty | P0 |
| BR-DB-003 | Filter | Chip ngày: Swipe ngang, thứ tự cũ → mới | P1 |
| BR-DB-004 | Aggregation | 1 ngày nhiều lần đo → Hiển thị TRUNG BÌNH | P1 |
| BR-DB-005 | Interaction | Tap điểm dữ liệu → Hiển thị tooltip | P1 |
| BR-DB-006 | Navigation | Tap chip ngày cụ thể → Drill-down view theo GIỜ | P1 |
| BR-DB-007 | Navigation | "Xem báo cáo sức khỏe" → Navigate đến list báo cáo | P1 |
| BR-DB-008 | Permission | Permission #1 = ON → Xem TOÀN BỘ sections báo cáo | P0 |
| BR-DB-009 | Empty State | Không có data HA → Message "Không có đủ dữ liệu..." | P1 |
| BR-DB-010 | Empty State | Không có báo cáo → Message "Chưa có báo cáo nào..." | P1 |
| BR-DB-011 | Authorization | Permission #1 = OFF → Ẩn block HA và button Báo cáo | P0 |

### Report Rules (BR-RPT-*)

| BR-ID | Description | Priority |
|-------|-------------|:--------:|
| BR-RPT-001 | Block Báo cáo: Tối đa 3 báo cáo chưa đọc mới nhất mỗi loại | P0 |
| BR-RPT-002 | Màn danh sách: Header = "Báo cáo SK của [Danh xưng]" | P1 |

### Security Requirements (SEC-DB-*)

| SEC-ID | Description | Priority |
|--------|-------------|:--------:|
| SEC-DB-001 | API `/patients/{id}/health-overview` PHẢI check permission #1 ở server | P0 |
| SEC-DB-002 | Permission Revoke: API check mỗi lần gọi. Permission OFF → Return 403 | P0 |
| SEC-DB-003 | Deep Link Protection: Validate quyền trước khi render chi tiết báo cáo | P1 |

