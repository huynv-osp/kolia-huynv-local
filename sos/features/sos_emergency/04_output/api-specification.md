# 📚 SOS Emergency API Specification

## Document Information

| Attribute | Value |
|-----------|-------|
| **Version** | 1.0 |
| **Date** | 2026-01-26 |
| **Author** | Analyst |
| **Status** | Final |
| **Base URL** | `/api` |
| **Authentication** | Bearer JWT Token |

---

## Table of Contents

1. [Overview](#1-overview)
2. [Authentication](#2-authentication)
3. [SOS Core APIs](#3-sos-core-apis)
   - 3.1 [Activate SOS](#31-activate-sos)
   - 3.2 [Bypass Cooldown](#32-bypass-cooldown)
   - 3.3 [Cancel SOS](#33-cancel-sos)
   - 3.4 [Get SOS Status](#34-get-sos-status)
4. [Emergency Contact APIs](#4-emergency-contact-apis)
   - 4.1 [List Contacts](#41-list-contacts)
   - 4.2 [Add Contact](#42-add-contact)
   - 4.3 [Update Contact](#43-update-contact)
   - 4.4 [Delete Contact](#44-delete-contact)
5. [Support APIs](#5-support-apis)
   - 5.1 [Get First Aid Content](#51-get-first-aid-content)
   - 5.2 [Confirm Escalation](#52-confirm-escalation)
6. [Error Codes](#6-error-codes)
7. [Data Models](#7-data-models)

---

# 1. Overview

## 1.1 API Summary

| Category | Count | Base Path |
|----------|:-----:|-----------|
| SOS Core | 4 | `/api/sos/` |
| Contact Management | 4 | `/api/sos/contacts/` |
| Support | 2 | `/api/sos/` |
| Location & Hospital | 2 | `/api/sos/` |
| Internal | 2 | `/internal/` |
| **TOTAL** | **14** | - |

## 1.2 Common Headers

| Header | Required | Description |
|--------|:--------:|-------------|
| `Authorization` | ✅ | Bearer JWT token |
| `Content-Type` | ✅ | `application/json` |
| `Accept` | ❌ | `application/json` (default) |
| `Accept-Language` | ❌ | `vi-VN` (default) |
| `X-Request-ID` | ❌ | UUID for request tracing |
| `X-Device-ID` | ❌ | Device identifier |

## 1.3 Common Response Format

### Success Response
```json
{
  "success": true,
  "data": { ... },
  "meta": {
    "timestamp": "2026-01-26T10:00:00Z",
    "request_id": "uuid"
  }
}
```

### Error Response
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable message in Vietnamese",
    "details": { ... }
  },
  "meta": {
    "timestamp": "2026-01-26T10:00:00Z",
    "request_id": "uuid"
  }
}
```

---

# 2. Authentication

## 2.1 JWT Token

Tất cả API yêu cầu JWT token trong header:

```http
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

## 2.2 Token Claims

```json
{
  "sub": "user_id",
  "iat": 1706241600,
  "exp": 1706328000,
  "iss": "alio-auth-service",
  "roles": ["PATIENT"]
}
```

## 2.3 Authentication Errors

| Code | Status | Description |
|------|:------:|-------------|
| `UNAUTHORIZED` | 401 | Token missing or invalid |
| `TOKEN_EXPIRED` | 401 | Token has expired |
| `INSUFFICIENT_PERMISSIONS` | 403 | User lacks required role |

---

# 3. SOS Core APIs

---

## 3.1 Activate SOS

### `POST /api/sos/activate`

**Mục đích:** Kích hoạt SOS và bắt đầu đếm ngược 30 giây (hoặc 10 giây nếu pin < 10%)

### SRS References
- **Kịch bản 1:** Kích hoạt SOS thành công (Happy Path)
- **Kịch bản 2:** Countdown hoàn thành - Gửi cảnh báo
- **BR-SOS-001:** Countdown bắt đầu ngay khi kích hoạt
- **BR-SOS-003:** ZNS gửi đồng thời đến TẤT CẢ người thân
- **BR-SOS-018:** Pin < 10%: Countdown rút ngắn 10 giây
- **BR-SOS-019:** Cooldown 30 phút sau gửi SOS thành công (no bypass per v1.8)
- **BR-SOS-024:** SOS allowed with 0 contacts (CSKH only)

### Request

| Field | Type | Required | Description | Validation |
|-------|------|:--------:|-------------|------------|
| `latitude` | number | ❌ | GPS latitude | -90 to 90 |
| `longitude` | number | ❌ | GPS longitude | -180 to 180 |
| `location_accuracy_m` | number | ❌ | Độ chính xác GPS (meters) | > 0 |
| `battery_level_percent` | integer | ❌ | Mức pin (%) | 0-100 |
| `is_offline_triggered` | boolean | ❌ | Đánh dấu kích hoạt offline | default: false |
| `device_info` | object | ❌ | Thông tin thiết bị | - |
| `device_info.platform` | string | ❌ | Platform | ios, android |
| `device_info.os_version` | string | ❌ | OS version | - |
| `device_info.app_version` | string | ❌ | App version | Semantic version |

### Request Example

```http
POST /api/sos/activate HTTP/1.1
Host: api.alio.vn
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "latitude": 10.762622,
  "longitude": 106.660172,
  "location_accuracy_m": 15.5,
  "battery_level_percent": 85,
  "is_offline_triggered": false,
  "device_info": {
    "platform": "ios",
    "os_version": "16.0",
    "app_version": "2.1.0"
  }
}
```

### Response - Success (200 OK)

| Field | Type | Description |
|-------|------|-------------|
| `event_id` | uuid | ID của SOS event |
| `countdown_seconds` | integer | Thời gian đếm ngược (30s hoặc 10s) |
| `countdown_started_at` | timestamp | Thời điểm bắt đầu đếm ngược (ISO 8601) |
| `status` | string | Trạng thái: `PENDING` |
| `contacts_count` | integer | Số người thân sẽ được thông báo |

```json
{
  "success": true,
  "data": {
    "event_id": "550e8400-e29b-41d4-a716-446655440000",
    "countdown_seconds": 30,
    "countdown_started_at": "2026-01-26T10:00:00Z",
    "status": "PENDING",
    "contacts_count": 3
  }
}
```

### Response - Cooldown Active (429 Too Many Requests)

Khi user đã gửi SOS trong vòng 30 phút.

```json
{
  "success": false,
  "error": {
    "code": "COOLDOWN_ACTIVE",
    "message": "Bạn đã gửi SOS cách đây 10 phút. Vui lòng chờ 20 phút.",
    "retry_after_seconds": 1200
  }
}
```

> **Note (SRS v1.8):** `bypass_allowed` removed - no bypass option, user must wait full 30 minutes.

### ~~Response - No Contacts (400 Bad Request)~~ (DEPRECATED in SRS v1.8)

> **Note:** Per BR-SOS-024, SOS is now allowed with 0 contacts. 
> System will send alert to CSKH only and show warning to user.

### Business Logic

```
1. Kiểm tra JWT token
2. Kiểm tra cooldown (30 phút)
   - Nếu cooldown active → redirect to Dashboard (no bypass per v1.8)
3. Get emergency contacts count
   - Nếu count = 0 → continue (CSKH only per BR-SOS-024)
4. Xác định countdown_seconds
   - Nếu battery_level_percent < 10 → 10 giây
   - Ngược lại → 30 giây
5. Tạo SOS event trong DB với status = PENDING
6. Publish ACTIVATED event lên Kafka
7. Trả về event_id và countdown info
```

### Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│                   POST /api/sos/activate                │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────┐    ┌──────────┐    ┌─────────────────┐    │
│  │ Validate │ → │ Check    │ → │ Check Contacts  │    │
│  │ JWT     │    │ Cooldown │    │ (min 1)         │    │
│  └─────────┘    └──────────┘    └─────────────────┘    │
│       │              │                   │              │
│       ↓              ↓                   ↓              │
│     401            429                 400              │
│                                                         │
│  ┌─────────────────┐    ┌─────────────────────────┐    │
│  │ Determine       │ → │ Create SOS Event        │    │
│  │ Countdown (30/10│    │ (DB + Kafka)            │    │
│  └─────────────────┘    └─────────────────────────┘    │
│                                   │                     │
│                                   ↓                     │
│                              200 OK                     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 3.2 ~~Bypass Cooldown~~ (DEPRECATED in SRS v1.8)

> [!CAUTION]
> **DEPRECATED:** This endpoint has been removed in SRS v1.8.
> Per BR-SOS-019: Cooldown is now 30 minutes with NO bypass option.
> User must wait full 30 minutes or use emergency actions from Dashboard (call 115/contacts directly).

---

## 3.3 Cancel SOS

### `POST /api/sos/cancel`

**Mục đích:** Hủy SOS trong khi countdown đang chạy (ấn nhầm)

### SRS References
- **Kịch bản 3:** Hủy SOS (Ấn nhầm)
- **BR-SOS-005:** Hủy SOS không áp dụng cooldown

### Request

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `event_id` | uuid | ✅ | ID của SOS event cần hủy |
| `cancellation_reason` | string | ❌ | Lý do hủy (default: "Ấn nhầm") |

### Request Example

```http
POST /api/sos/cancel HTTP/1.1
Host: api.alio.vn
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "cancellation_reason": "Ấn nhầm"
}
```

### Response - Success (200 OK)

```json
{
  "success": true,
  "data": {
    "event_id": "550e8400-e29b-41d4-a716-446655440000",
    "status": "CANCELLED",
    "cancelled_at": "2026-01-26T10:00:15Z"
  }
}
```

### Response - Event Not Found (404)

```json
{
  "success": false,
  "error": {
    "code": "EVENT_NOT_FOUND",
    "message": "Không tìm thấy sự kiện SOS."
  }
}
```

### Response - Already Completed (409)

```json
{
  "success": false,
  "error": {
    "code": "EVENT_ALREADY_COMPLETED",
    "message": "Không thể hủy SOS đã gửi."
  }
}
```

### Response - Already Cancelled (409)

```json
{
  "success": false,
  "error": {
    "code": "EVENT_ALREADY_CANCELLED",
    "message": "SOS đã được hủy trước đó."
  }
}
```

### Business Logic

```
1. Kiểm tra JWT token
2. Tìm SOS event theo event_id
   - Nếu không tìm thấy → return 404
   - Nếu không thuộc user hiện tại → return 403
3. Kiểm tra status
   - Nếu COMPLETED → return 409 EVENT_ALREADY_COMPLETED
   - Nếu CANCELLED → return 409 EVENT_ALREADY_CANCELLED
4. Cập nhật status = CANCELLED, cancelled_at = now()
5. Publish CANCELLED event lên Kafka
6. KHÔNG áp dụng cooldown
7. Trả về confirmation
```

### Important Notes

⚠️ **Không áp dụng cooldown:** Khi user hủy SOS, hệ thống KHÔNG áp dụng cooldown 5 phút vì chưa có thông báo nào được gửi đi.

---

## 3.4 Get SOS Status

### `GET /api/sos/status/{eventId}`

**Mục đích:** Lấy trạng thái hiện tại của SOS event (dùng cho sync countdown và hiển thị dashboard)

### SRS References
- **BR-SOS-020:** Server-client countdown tolerance: 5 giây

### Path Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `eventId` | uuid | ID của SOS event |

### Request Example

```http
GET /api/sos/status/550e8400-e29b-41d4-a716-446655440000 HTTP/1.1
Host: api.alio.vn
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Response - Pending (200 OK)

Khi countdown đang chạy:

```json
{
  "success": true,
  "data": {
    "event_id": "550e8400-e29b-41d4-a716-446655440000",
    "status": "PENDING",
    "countdown_started_at": "2026-01-26T10:00:00Z",
    "countdown_seconds": 30,
    "countdown_remaining_seconds": 15,
    "server_time": "2026-01-26T10:00:15Z"
  }
}
```

### Response - Completed (200 OK)

Khi SOS đã được gửi:

```json
{
  "success": true,
  "data": {
    "event_id": "550e8400-e29b-41d4-a716-446655440000",
    "status": "COMPLETED",
    "countdown_completed_at": "2026-01-26T10:00:30Z",
    "notifications": {
      "total": 5,
      "sent": 5,
      "delivered": 3,
      "failed": 0,
      "pending": 2
    },
    "escalation": {
      "status": "IN_PROGRESS",
      "current_contact_order": 2,
      "contacts_tried": 1,
      "connected_contact_id": null,
      "completed_at": null
    }
  }
}
```

### Response - Cancelled (200 OK)

Khi SOS đã bị hủy:

```json
{
  "success": true,
  "data": {
    "event_id": "550e8400-e29b-41d4-a716-446655440000",
    "status": "CANCELLED",
    "cancelled_at": "2026-01-26T10:00:15Z",
    "cancellation_reason": "Ấn nhầm"
  }
}
```

### Status Values

| Status | Description |
|--------|-------------|
| `PENDING` | Countdown đang chạy |
| `COMPLETED` | Đã gửi thông báo thành công |
| `CANCELLED` | Đã hủy bởi user |
| `FAILED` | Gửi thất bại sau tất cả retry |

### Escalation Status Values

| Status | Description |
|--------|-------------|
| `NOT_STARTED` | Chưa bắt đầu escalation |
| `IN_PROGRESS` | Đang gọi người thân |
| `CONNECTED` | Đã có người trả lời |
| `ALL_FAILED` | Tất cả người thân không trả lời |

### Use Cases

1. **Countdown Sync:** Mobile poll mỗi 5 giây để sync countdown với server
2. **Dashboard Display:** Hiển thị trạng thái sau khi SOS hoàn thành
3. **Escalation Tracking:** Theo dõi tiến trình gọi người thân

---

# 4. Emergency Contact APIs

---

## 4.1 List Contacts

### `GET /api/sos/contacts`

**Mục đích:** Lấy danh sách người thân khẩn cấp của user

### SRS References
- **Kịch bản 8:** Gọi người thân từ Contact List
- **BR-SOS-011:** User gọi người thân #X → Escalation skip #X

### Request Example

```http
GET /api/sos/contacts HTTP/1.1
Host: api.alio.vn
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Response - Success (200 OK)

```json
{
  "success": true,
  "data": {
    "contacts": [
      {
        "contact_id": "123e4567-e89b-12d3-a456-426614174000",
        "name": "Nguyễn Văn A",
        "phone": "0901234567",
        "relationship": "Con trai",
        "priority": 1,
        "is_active": true,
        "zalo_enabled": true
      },
      {
        "contact_id": "223e4567-e89b-12d3-a456-426614174001",
        "name": "Trần Thị B",
        "phone": "0912345678",
        "relationship": "Con gái",
        "priority": 2,
        "is_active": true,
        "zalo_enabled": false
      }
    ],
    "count": 2,
    "max_contacts": 5
  }
}
```

### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `contacts` | array | Danh sách người thân |
| `contacts[].contact_id` | uuid | ID của contact |
| `contacts[].name` | string | Tên người thân |
| `contacts[].phone` | string | Số điện thoại |
| `contacts[].relationship` | string | Mối quan hệ |
| `contacts[].priority` | integer | Thứ tự ưu tiên (1-5) |
| `contacts[].is_active` | boolean | Trạng thái active |
| `contacts[].zalo_enabled` | boolean | Có thể gọi Zalo Video |
| `count` | integer | Số lượng contacts hiện tại |
| `max_contacts` | integer | Số lượng tối đa (5) |

### Empty Response

```json
{
  "success": true,
  "data": {
    "contacts": [],
    "count": 0,
    "max_contacts": 5
  }
}
```

---

## 4.2 Add Contact

### `POST /api/sos/contacts`

**Mục đích:** Thêm người thân mới vào danh sách khẩn cấp (tối đa 5 người)

### Request

| Field | Type | Required | Description | Validation |
|-------|------|:--------:|-------------|------------|
| `name` | string | ✅ | Tên người thân | 1-100 chars |
| `phone` | string | ✅ | Số điện thoại | VN format (10-11 digits) |
| `relationship` | string | ❌ | Mối quan hệ | max 50 chars |
| `priority` | integer | ❌ | Thứ tự ưu tiên | 1-5, default: next available |
| `zalo_enabled` | boolean | ❌ | Có Zalo Video | default: false |

### Request Example

```http
POST /api/sos/contacts HTTP/1.1
Host: api.alio.vn
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "name": "Lê Văn C",
  "phone": "0923456789",
  "relationship": "Cháu",
  "priority": 3,
  "zalo_enabled": true
}
```

### Response - Created (201)

```json
{
  "success": true,
  "data": {
    "contact_id": "323e4567-e89b-12d3-a456-426614174002",
    "name": "Lê Văn C",
    "phone": "0923456789",
    "relationship": "Cháu",
    "priority": 3,
    "is_active": true,
    "zalo_enabled": true
  }
}
```

### Response - Max Contacts Reached (400)

```json
{
  "success": false,
  "error": {
    "code": "MAX_CONTACTS_REACHED",
    "message": "Bạn chỉ có thể thêm tối đa 5 người thân."
  }
}
```

### Response - Duplicate Phone (400)

```json
{
  "success": false,
  "error": {
    "code": "DUPLICATE_PHONE",
    "message": "Số điện thoại này đã được thêm vào danh sách."
  }
}
```

### Response - Invalid Phone Format (400)

```json
{
  "success": false,
  "error": {
    "code": "INVALID_PHONE_FORMAT",
    "message": "Số điện thoại không hợp lệ. Vui lòng nhập số điện thoại Việt Nam (10-11 số)."
  }
}
```

### Phone Validation Rules

| Pattern | Valid | Example |
|---------|:-----:|---------|
| `09xxxxxxxx` | ✅ | 0901234567 |
| `08xxxxxxxx` | ✅ | 0812345678 |
| `07xxxxxxxx` | ✅ | 0712345678 |
| `03xxxxxxxx` | ✅ | 0312345678 |
| `05xxxxxxxx` | ✅ | 0512345678 |
| `028xxxxxxx` | ✅ | 02812345678 |
| Không có 0 đầu | ❌ | 901234567 |
| Quá ngắn/dài | ❌ | 0901234, 09012345678 |

---

## 4.3 Update Contact

### `PUT /api/sos/contacts/{contactId}`

**Mục đích:** Cập nhật thông tin người thân

### Path Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `contactId` | uuid | ID của contact cần update |

### Request

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `name` | string | ❌ | Tên mới |
| `phone` | string | ❌ | Số điện thoại mới |
| `relationship` | string | ❌ | Mối quan hệ mới |
| `priority` | integer | ❌ | Thứ tự ưu tiên mới (1-5) |
| `zalo_enabled` | boolean | ❌ | Trạng thái Zalo |

### Request Example

```http
PUT /api/sos/contacts/323e4567-e89b-12d3-a456-426614174002 HTTP/1.1
Host: api.alio.vn
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "name": "Lê Văn C",
  "priority": 2,
  "zalo_enabled": false
}
```

### Response - Success (200 OK)

```json
{
  "success": true,
  "data": {
    "contact_id": "323e4567-e89b-12d3-a456-426614174002",
    "name": "Lê Văn C",
    "phone": "0923456789",
    "relationship": "Cháu",
    "priority": 2,
    "is_active": true,
    "zalo_enabled": false
  }
}
```

### Priority Reordering

Khi thay đổi priority, hệ thống tự động reorder các contacts khác:

```
Before: [1: A, 2: B, 3: C, 4: D]
Action: Set C to priority 2
After:  [1: A, 2: C, 3: B, 4: D]
```

---

## 4.4 Delete Contact

### `DELETE /api/sos/contacts/{contactId}`

**Mục đích:** Xóa người thân khỏi danh sách khẩn cấp

### Path Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `contactId` | uuid | ID của contact cần xóa |

### Request Example

```http
DELETE /api/sos/contacts/323e4567-e89b-12d3-a456-426614174002 HTTP/1.1
Host: api.alio.vn
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Response - Success (200 OK)

```json
{
  "success": true,
  "message": "Đã xóa người thân khỏi danh sách SOS."
}
```

### Response - Contact Not Found (404)

```json
{
  "success": false,
  "error": {
    "code": "CONTACT_NOT_FOUND",
    "message": "Không tìm thấy người thân trong danh sách."
  }
}
```

### Priority Reordering on Delete

Khi xóa contact, priorities được reorder:

```
Before: [1: A, 2: B, 3: C, 4: D]
Action: Delete B (priority 2)
After:  [1: A, 2: C, 3: D]
```

---

# 5. Support APIs

---

## 5.1 Get First Aid Content

### `GET /api/sos/first-aid`

**Mục đích:** Lấy nội dung hướng dẫn sơ cứu để cache offline

### SRS References
- **Kịch bản 10:** Xem hướng dẫn sơ cứu
- **BR-SOS-013:** First Aid content từ CMS, cached offline
- **BR-SOS-014:** Disclaimer bắt buộc hiển thị

### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `category` | string | ❌ | Filter theo category |
| `version_after` | integer | ❌ | Chỉ lấy updates sau version này |

### Request Example - Full Sync

```http
GET /api/sos/first-aid HTTP/1.1
Host: api.alio.vn
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Request Example - Incremental Sync

```http
GET /api/sos/first-aid?version_after=4 HTTP/1.1
Host: api.alio.vn
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Response - Success (200 OK)

```json
{
  "success": true,
  "data": {
    "version": 5,
    "updated_at": "2026-01-25T00:00:00Z",
    "categories": [
      {
        "category": "cpr",
        "title": "Hồi sinh tim phổi (CPR)",
        "icon_name": "heart_plus",
        "display_order": 1,
        "content": "## Hướng dẫn CPR\n\n### Bước 1: Kiểm tra phản ứng\n- Gọi to và lay vai người bệnh\n\n### Bước 2: Gọi cấp cứu\n- Gọi 115 ngay lập tức\n\n### Bước 3: Ép ngực\n- Đặt 2 tay chồng lên nhau giữa ngực\n- Ép sâu 5-6cm, tốc độ 100-120 lần/phút"
      },
      {
        "category": "stroke",
        "title": "Đột quỵ (F.A.S.T)",
        "icon_name": "brain",
        "display_order": 2,
        "content": "## Nhận biết đột quỵ - F.A.S.T\n\n### F - Face (Mặt)\n- Một bên mặt bị xệ xuống?\n\n### A - Arms (Tay)\n- Một cánh tay yếu hoặc không nâng lên được?\n\n### S - Speech (Nói)\n- Nói không rõ, khó hiểu?\n\n### T - Time (Thời gian)\n- GỌI 115 NGAY LẬP TỨC!"
      },
      {
        "category": "low_sugar",
        "title": "Hạ đường huyết",
        "icon_name": "sugar",
        "display_order": 3,
        "content": "## Xử lý hạ đường huyết\n\n### Dấu hiệu\n- Đổ mồ hôi, run tay\n- Chóng mặt, tim đập nhanh\n- Đói, yếu sức\n\n### Xử lý ngay\n1. Cho uống nước đường hoặc nước trái cây\n2. Cho ăn bánh, kẹo\n3. Nếu không tỉnh - GỌI 115"
      },
      {
        "category": "fall",
        "title": "Té ngã",
        "icon_name": "fall",
        "display_order": 4,
        "content": "## Xử lý khi té ngã\n\n### ĐỪNG\n- Đừng di chuyển người bệnh ngay\n- Đừng cho uống nước nếu không tỉnh\n\n### NÊN\n1. Kiểm tra ý thức\n2. Kiểm tra vùng đau: đầu, cổ, lưng, tay chân\n3. Nếu nghi gãy xương - KHÔNG di chuyển\n4. GỌI 115"
      }
    ],
    "disclaimer": "⚠️ THÔNG TIN CHỈ MANG TÍNH THAM KHẢO\n\nHướng dẫn sơ cứu này không thay thế sự chăm sóc y tế chuyên nghiệp.\nTrong trường hợp khẩn cấp, hãy gọi 115 ngay lập tức."
  }
}
```

### Content Format

- `content` field sử dụng Markdown format
- Mobile app render Markdown thành styled text
- Disclaimer PHẢI được hiển thị ở đầu hoặc cuối màn hình

### Caching Strategy

```
Mobile App:
1. Sync full content on first install
2. Store content in SQLite với version number
3. Periodic check (mỗi 24h) với version_after parameter
4. Only replace if server version > local version
```

---

## 5.2 Confirm Escalation

### `POST /api/sos/escalation/confirm`

**Mục đích:** Xác nhận người thân đã trả lời cuộc gọi, dừng escalation

### SRS References
- **Kịch bản 6:** Escalation thành công
- **BR-SOS-009:** Call Connected → Dừng escalation

### Authentication

API này hỗ trợ 2 loại authentication:
1. **JWT Token:** Khi gọi từ mobile app của người nhận
2. **API Key:** Khi gọi từ CSKH system

### Request

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `event_id` | uuid | ✅ | ID của SOS event |
| `contact_id` | uuid | ✅ | ID của contact đã trả lời |
| `confirmation_type` | string | ✅ | Loại xác nhận |

### Confirmation Types

| Type | Description |
|------|-------------|
| `ANSWERED_CALL` | Người thân trả lời cuộc gọi |
| `ACKNOWLEDGED` | CSKH xác nhận đã liên lạc được |

### Request Example

```http
POST /api/sos/escalation/confirm HTTP/1.1
Host: api.alio.vn
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "contact_id": "123e4567-e89b-12d3-a456-426614174000",
  "confirmation_type": "ANSWERED_CALL"
}
```

### Response - Success (200 OK)

```json
{
  "success": true,
  "data": {
    "escalation_stopped": true,
    "message": "Escalation đã dừng."
  }
}
```

### Response - Escalation Already Stopped (200 OK)

```json
{
  "success": true,
  "data": {
    "escalation_stopped": false,
    "message": "Escalation đã được dừng trước đó."
  }
}
```

### Business Logic

```
1. Xác thực request (JWT hoặc API Key)
2. Tìm SOS event
3. Tìm escalation call record cho contact
4. Cập nhật call status = CONNECTED
5. Dừng tất cả pending escalation tasks
6. Cập nhật escalation status = CONNECTED
7. Trả về confirmation
```

---

# 6. Error Codes

## 6.1 Complete Error Code Reference

| Code | HTTP | Category | Description | User Message (VI) |
|------|:----:|----------|-------------|-------------------|
| `UNAUTHORIZED` | 401 | Auth | Token missing/invalid | Phiên đăng nhập hết hạn |
| `TOKEN_EXPIRED` | 401 | Auth | Token expired | Phiên đăng nhập hết hạn |
| `INSUFFICIENT_PERMISSIONS` | 403 | Auth | User lacks permission | Bạn không có quyền thực hiện |
| `COOLDOWN_ACTIVE` | 429 | SOS | Recent SOS < 30 min | Vui lòng chờ {X} phút |
| ~~`CONTACTS_REQUIRED`~~ | ~~400~~ | ~~SOS~~ | ~~No contacts~~ | ~~DEPRECATED in v1.8~~ |
| `EVENT_NOT_FOUND` | 404 | SOS | Event ID not found | Không tìm thấy sự kiện SOS |
| `EVENT_ALREADY_COMPLETED` | 409 | SOS | Cannot cancel | Không thể hủy SOS đã gửi |
| `EVENT_ALREADY_CANCELLED` | 409 | SOS | Already cancelled | SOS đã được hủy |
| `MAX_CONTACTS_REACHED` | 400 | Contact | Max 5 contacts | Tối đa 5 người thân |
| `DUPLICATE_PHONE` | 400 | Contact | Phone exists | Số điện thoại đã tồn tại |
| `INVALID_PHONE_FORMAT` | 400 | Contact | Invalid VN phone | Số điện thoại không hợp lệ |
| `CONTACT_NOT_FOUND` | 404 | Contact | Contact not found | Không tìm thấy người thân |
| `VALIDATION_ERROR` | 400 | General | Invalid request data | Dữ liệu không hợp lệ |
| `SERVER_ERROR` | 500 | General | Internal error | Có lỗi xảy ra |
| `SERVICE_UNAVAILABLE` | 503 | General | Maintenance | Hệ thống đang bảo trì |

## 6.2 Error Response Structure

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable message in Vietnamese",
    "details": {
      "field": "field_name",
      "reason": "specific_reason"
    },
    "retry_after_seconds": 120,
    "bypass_allowed": true
  }
}
```

---

# 7. Data Models

## 7.1 SOS Event

```json
{
  "event_id": "uuid",
  "user_id": "uuid",
  "triggered_at": "timestamp",
  "trigger_source": "manual|low_battery",
  "latitude": "number",
  "longitude": "number",
  "location_accuracy_m": "number",
  "location_source": "gps|cell_tower|last_known",
  "countdown_seconds": "integer (10|30)",
  "countdown_started_at": "timestamp",
  "countdown_completed_at": "timestamp|null",
  "status": "PENDING|COMPLETED|CANCELLED|FAILED",
  "cancelled_at": "timestamp|null",
  "cancellation_reason": "string|null",
  "is_offline_triggered": "boolean",
  "cooldown_bypassed": "boolean",
  "battery_level_percent": "integer|null",
  "device_info": "object|null"
}
```

## 7.2 Emergency Contact

```json
{
  "contact_id": "uuid",
  "user_id": "uuid",
  "name": "string (1-100)",
  "phone": "string (10-11 digits)",
  "relationship": "string|null",
  "priority": "integer (1-5)",
  "is_active": "boolean",
  "zalo_enabled": "boolean"
}
```

## 7.3 Notification

```json
{
  "notification_id": "uuid",
  "event_id": "uuid",
  "contact_id": "uuid|null",
  "recipient_name": "string",
  "recipient_phone": "string",
  "recipient_type": "family|cskh",
  "channel": "zns|sms|push|call",
  "template_id": "string",
  "status": "PENDING|SENT|DELIVERED|FAILED|RETRY_PENDING",
  "retry_count": "integer (0-3)",
  "error_code": "string|null"
}
```

## 7.4 Escalation Call

```json
{
  "call_id": "uuid",
  "event_id": "uuid",
  "contact_id": "uuid",
  "escalation_order": "integer (1-5)",
  "call_type": "auto_call|manual_call|115_call",
  "status": "PENDING|CALLING|CONNECTED|NO_ANSWER|BUSY|REJECTED|FAILED|SKIPPED",
  "initiated_at": "timestamp",
  "connected_at": "timestamp|null",
  "duration_seconds": "integer|null"
}
```

## 7.5 First Aid Content

```json
{
  "content_id": "uuid",
  "category": "cpr|stroke|low_sugar|fall",
  "title": "string",
  "content": "markdown string",
  "icon_name": "string",
  "display_order": "integer",
  "version": "integer"
}
```

---

# 6. Location & Hospital APIs

---

## 6.1 Get Hospitals Nearby

### `GET /api/sos/hospitals/nearby`

**Mục đích:** Tìm bệnh viện gần vị trí hiện tại của user

### SRS References
- **Kịch bản 9:** Xem bệnh viện gần nhất
- **BR-SOS-012:** Hospital Map sử dụng Google Maps Places API

### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `lat` | double | ✅ | Latitude |
| `lng` | double | ✅ | Longitude |
| `radius_km` | integer | ❌ | Bán kính tìm kiếm (default: 10) |
| `limit` | integer | ❌ | Số lượng kết quả (default: 10, max: 20) |

### Request Example

```http
GET /api/sos/hospitals/nearby?lat=10.762622&lng=106.660172&radius_km=10 HTTP/1.1
Host: api.alio.vn
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Response - Success (200 OK)

```json
{
  "success": true,
  "data": {
    "hospitals": [
      {
        "place_id": "ChIJN1t_tDeuEmsRUsoyG83frY4",
        "name": "Bệnh viện Chợ Rẫy",
        "address": "201B Nguyễn Chí Thanh, Phường 12, Quận 5, Thành phố Hồ Chí Minh",
        "latitude": 10.7577,
        "longitude": 106.6592,
        "distance_km": 2.3,
        "rating": 4.5,
        "total_ratings": 1250,
        "is_open": true,
        "phone": "02838554137",
        "maps_url": "https://maps.google.com/?place_id=ChIJN1t_tDeuEmsRUsoyG83frY4"
      },
      {
        "place_id": "ChIJN1t_tDeuEmsRUsoyG83frY5",
        "name": "Bệnh viện Đại học Y Dược",
        "address": "215 Hồng Bàng, Phường 11, Quận 5, Thành phố Hồ Chí Minh",
        "latitude": 10.7560,
        "longitude": 106.6610,
        "distance_km": 2.8,
        "rating": 4.3,
        "total_ratings": 890,
        "is_open": true,
        "phone": "02838554138",
        "maps_url": "https://maps.google.com/?place_id=ChIJN1t_tDeuEmsRUsoyG83frY5"
      }
    ],
    "count": 2,
    "search_location": {
      "latitude": 10.762622,
      "longitude": 106.660172
    },
    "radius_km": 10
  }
}
```

### Response - No Hospitals Found (200 OK)

```json
{
  "success": true,
  "data": {
    "hospitals": [],
    "count": 0,
    "message": "Không tìm thấy bệnh viện trong bán kính 10km"
  }
}
```

---

## 6.2 Update Event Location

### `POST /api/sos/events/{eventId}/location`

**Mục đích:** Cập nhật vị trí mới cho SOS event (dùng khi offline queue retry)

### SRS References
- **Kịch bản 11:** SOS khi offline - Queue + Auto-retry
- **BR-SOS-015:** Offline: Queue + Auto-retry khi có mạng

### Path Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `eventId` | uuid | ID của SOS event |

### Request

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `latitude` | double | ✅ | Vĩ độ mới |
| `longitude` | double | ✅ | Kinh độ mới |
| `location_accuracy_m` | double | ❌ | Độ chính xác GPS (mét) |
| `location_source` | string | ❌ | Nguồn: `gps`, `cell_tower`, `wifi` |
| `timestamp` | timestamp | ❌ | Thời điểm xác định vị trí |

### Request Example

```http
POST /api/sos/events/550e8400-e29b-41d4-a716-446655440000/location HTTP/1.1
Host: api.alio.vn
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "latitude": 10.765000,
  "longitude": 106.661000,
  "location_accuracy_m": 8.5,
  "location_source": "gps",
  "timestamp": "2026-01-26T10:05:00Z"
}
```

### Response - Success (200 OK)

```json
{
  "success": true,
  "data": {
    "event_id": "550e8400-e29b-41d4-a716-446655440000",
    "location_updated": true,
    "previous_location": {
      "latitude": 10.762622,
      "longitude": 106.660172
    },
    "new_location": {
      "latitude": 10.765000,
      "longitude": 106.661000
    }
  }
}
```

### Business Logic

1. Chỉ cho phép cập nhật nếu event status = PENDING hoặc COMPLETED
2. Không cho phép cập nhật nếu đã CANCELLED
3. Ghi log location history nếu cần audit

---

## 6.3 Report Manual Call

### `POST /api/sos/events/{eventId}/manual-call`

**Mục đích:** Thông báo user đang gọi người thân để escalation skip

### SRS References
- **Kịch bản 8:** Gọi người thân từ Contact List
- **BR-SOS-011:** User gọi người thân #X → Escalation skip #X

### Path Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `eventId` | uuid | ID của SOS event |

### Request

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `contact_id` | uuid | ✅ | ID của contact đang được gọi |
| `call_started_at` | timestamp | ❌ | Thời điểm bắt đầu gọi |

### Request Example

```http
POST /api/sos/events/550e8400-e29b-41d4-a716-446655440000/manual-call HTTP/1.1
Host: api.alio.vn
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "contact_id": "123e4567-e89b-12d3-a456-426614174000",
  "call_started_at": "2026-01-26T10:00:30Z"
}
```

### Response - Success (200 OK)

```json
{
  "success": true,
  "data": {
    "escalation_updated": true,
    "skipped_contact_id": "123e4567-e89b-12d3-a456-426614174000",
    "skipped_contact_name": "Nguyễn Văn A",
    "message": "Escalation sẽ bỏ qua người thân này"
  }
}
```

### Business Logic

1. Nhận thông báo user đang gọi người thân #X
2. Cập nhật escalation service để skip #X
3. Nếu escalation đang gọi #X:
   - Dừng cuộc gọi auto hiện tại
   - Chuyển sang người thân tiếp theo
4. Ghi log manual call

---

# 7. Internal APIs

> **Note:** Internal APIs chỉ được gọi giữa các services, không expose ra mobile app.

---

## 7.1 CSKH Alert

### `POST /internal/cskh/alerts`

**Mục đích:** Gửi alert đến hệ thống CSKH khi SOS triggered hoặc escalation failed

### SRS References
- **Kịch bản 2:** Countdown = 0 → Gửi alert đến CSKH
- **Kịch bản 5:** Tất cả 5 người thân không trả lời → Alert CSKH
- **BR-SOS-004, BR-SOS-008**

### Authentication

API sử dụng Internal API Key:

```http
X-Internal-API-Key: {internal_api_key}
```

### Request

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `alert_type` | string | ✅ | Loại alert |
| `event_id` | uuid | ✅ | ID của SOS event |
| `user_id` | uuid | ✅ | ID của user |
| `user_name` | string | ✅ | Tên user |
| `user_phone` | string | ✅ | SĐT user |
| `location` | object | ❌ | Vị trí GPS |
| `contacts_status` | array | ❌ | Trạng thái các cuộc gọi |
| `triggered_at` | timestamp | ✅ | Thời điểm trigger |

### Alert Types

| Type | Description | Trigger |
|------|-------------|---------|
| `SOS_TRIGGERED` | SOS đã được kích hoạt | Countdown = 0 |
| `ESCALATION_FAILED` | Không ai trả lời | 5 contacts failed |
| `ZNS_FAILED` | ZNS gửi thất bại sau 3 retry | ZNS retry exhausted |

### Request Example - SOS Triggered

```http
POST /internal/cskh/alerts HTTP/1.1
Host: api.alio.vn
X-Internal-API-Key: {internal_api_key}
Content-Type: application/json

{
  "alert_type": "SOS_TRIGGERED",
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "123e4567-e89b-12d3-a456-426614174000",
  "user_name": "Nguyễn Văn A",
  "user_phone": "0901234567",
  "location": {
    "latitude": 10.762622,
    "longitude": 106.660172,
    "maps_link": "https://maps.google.com/?q=10.762622,106.660172"
  },
  "triggered_at": "2026-01-26T10:00:00Z"
}
```

### Request Example - Escalation Failed

```http
POST /internal/cskh/alerts HTTP/1.1
Host: api.alio.vn
X-Internal-API-Key: {internal_api_key}
Content-Type: application/json

{
  "alert_type": "ESCALATION_FAILED",
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "123e4567-e89b-12d3-a456-426614174000",
  "user_name": "Nguyễn Văn A",
  "user_phone": "0901234567",
  "location": {
    "latitude": 10.762622,
    "longitude": 106.660172,
    "maps_link": "https://maps.google.com/?q=10.762622,106.660172"
  },
  "contacts_status": [
    {"name": "Người thân 1", "phone": "0912345678", "status": "NO_ANSWER"},
    {"name": "Người thân 2", "phone": "0923456789", "status": "BUSY"},
    {"name": "Người thân 3", "phone": "0934567890", "status": "NO_ANSWER"}
  ],
  "triggered_at": "2026-01-26T10:00:00Z"
}
```

### Response - Success (200 OK)

```json
{
  "success": true,
  "data": {
    "ticket_id": "CSKH-2026-0001",
    "assigned_to": "CSKH Team",
    "priority": "HIGH"
  }
}
```

### Integration with CSKH System

1. **Option A:** Webhook to external CSKH system
2. **Option B:** Internal ticketing table + Dashboard
3. **Option C:** Integration với CRM (Freshdesk, Zendesk, etc.)

> **Pending:** Cần CSKH team confirm integration method

---

# Appendix

## A. API Versioning

API version được include trong path nếu cần:
- Current: `/api/sos/...` (v1)
- Future: `/api/v2/sos/...`

## B. Rate Limits

| Endpoint | Limit |
|----------|-------|
| `/api/sos/activate` | 1 req/5min (with bypass) |
| `/api/sos/status` | 100 req/min |
| `/api/sos/contacts` | 60 req/min |
| `/api/sos/first-aid` | 10 req/min |

## C. Change Log

| Version | Date | Changes |
|---------|------|---------|
| 1.1 | 2026-01-26 | Added 4 new APIs: Hospital Nearby, Location Update, Manual Call, CSKH Alert |
| 1.0 | 2026-01-26 | Initial specification |

---

**Document Version:** 1.1  
**Generated:** 2026-01-26T12:05:00+07:00  
**Author:** Analyst
