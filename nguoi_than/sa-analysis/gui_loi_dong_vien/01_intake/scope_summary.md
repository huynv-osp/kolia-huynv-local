# Scope Summary: US 1.3 - Gửi Lời Động Viên

> **Phase:** 1 - Document Intake & Classification  
> **Date:** 2026-02-04  

---

## In Scope

### Caregiver Features

| Feature | Description | Priority |
|---------|-------------|:--------:|
| **Send Encouragement** | Soạn và gửi lời động viên | P0 |
| ~~AI Suggestions~~ | ⏸️ DEFERRED | - |
| ~~Refresh Suggestions~~ | ⏸️ DEFERRED | - |
| **Voice Input** | Voice-to-Text nhập nội dung | P2 |
| **Quota Display** | Hiển thị số tin nhắn còn lại | P1 |

### Patient Features

| Feature | Description | Priority |
|---------|-------------|:--------:|
| **Receive Modal** | Modal hiển thị lời động viên chưa đọc (24h) | P0 |
| **View List** | Xem danh sách lời động viên trong MHC | P1 |
| **Mark as Read** | Đánh dấu đã đọc (batch) | P0 |

### System Features

| Feature | Description | Priority |
|---------|-------------|:--------:|
| **Permission Check** | Kiểm tra Permission #6 (encouragement) | P0 |
| **Quota Enforcement** | Giới hạn 10 tin/ngày/Patient | P0 |
| **Push Notification** | Thông báo đến Patient khi nhận lời động viên | P1 |

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| **Patient Response** | Giao tiếp một chiều (Caregiver → Patient) |
| **Chat Free-style** | Không phải tính năng chat |
| **Content Moderation** | Caregiver tự chịu trách nhiệm nội dung |
| **Message History (Full)** | Chỉ hiển thị 24h gần nhất |
| **Edit/Delete Message** | Không hỗ trợ sửa/xóa sau khi gửi |

---

## Key Constraints

| Constraint | Value | BR Reference |
|------------|-------|--------------|
| **Max Messages/Day** | 10 tin/Patient | BR-001 |
| **Max Characters** | 150 Unicode chars | BR-002 |
| **Permission Required** | #6 (encouragement) = ON | BR-003 |

---

## Affected Systems

| System | Impact | Changes |
|--------|:------:|---------|
| **api-gateway-service** | 🟡 | 4 new REST endpoints |
| **user-service** | 🟡 | New EncouragementService |
| **schedule-service** | 🟢 | Push notification task |
| **Mobile App** | 🟡 | Widget + Modal + List |
| **Database** | 🟢 | 1 new table |

---

## Dependencies

| Dependency | Type | Status |
|------------|------|:------:|
| Kết nối Người thân (US 1.1) | Hard | ✅ Completed |
| Permission #6 (encouragement) | Hard | ✅ Exists in DB |
| Push Notification Infrastructure | Hard | ✅ Available |

---

## Success Criteria

1. ✅ Caregiver có thể gửi lời động viên thành công
2. ✅ Patient nhận được push notification
3. ✅ Patient thấy modal với danh sách lời động viên chưa đọc
4. ✅ Patient có thể đánh dấu đã đọc
5. ✅ Quota 10 tin/ngày được enforce
6. ✅ Permission #6 được kiểm tra real-time
