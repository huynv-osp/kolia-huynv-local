# API Mapping

## Analysis Context
| Item | Value |
|------|-------|
| **Analysis Name** | `sos_emergency` |
| **Mapping Date** | 2026-01-26 |
| **Last Updated** | 2026-01-27 (synced with SRS v2.1) |

> **📝 Note:** `zalo_enabled` field trong Emergency Contacts được giữ lại cho future compatibility, tuy nhiên **Zalo Video Call đã bị loại khỏi scope** trong SRS v2.1 do không có public API/deep link.

---

## 1. REST API Specifications

### 1.1 SOS Core APIs (4 endpoints)

---

#### POST /api/v1/sos/trigger

**Purpose:** Kích hoạt SOS countdown và queue alert sending

| Attribute | Value |
|-----------|-------|
| **Method** | POST |
| **Auth** | JWT Required |
| **Rate Limit** | 1 req/30min per user (cooldown) |

**Request:**
```json
{
  "trigger_source": "button",
  "latitude": 10.762622,
  "longitude": 106.660172,
  "location_accuracy_m": 10.5,
  "battery_level_percent": 85,
  "bypass_cooldown": false
}
```

| trigger_source | enum | ✅ | button, voice, shake, widget |
| latitude | double | ✅ | Vĩ độ |
| longitude | double | ✅ | Kinh độ |
| location_accuracy_m | double | ❌ | Độ chính xác (mét) |
| battery_level_percent | int | ❌ | Pin (0-100) |

> **Note:** `bypass_cooldown` removed in SRS v1.8 - no bypass allowed

**Response (200 OK):**
```json
{
  "status": 200,
  "message": "SOS triggered successfully",
  "data": {
    "event_id": "550e8400-e29b-41d4-a716-446655440000",
    "countdown_seconds": 30,
    "countdown_started_at": "2026-01-26T10:00:00Z",
    "status": "countdown_started"
  }
}
```

**Response (400 - Cooldown Active):**
```json
{
  "status": 400,
  "message": "Bạn đã gửi SOS cách đây 10 phút. Vui lòng chờ 20 phút.",
  "error_code": "COOLDOWN_ACTIVE",
  "retry_after_seconds": 1200
}
```

> **Note:** CONTACTS_REQUIRED removed in SRS v1.8 per BR-SOS-024 - SOS allowed with 0 contacts (CSKH only)

---

#### POST /api/v1/sos/cancel

**Purpose:** Hủy SOS trong thời gian countdown

| Attribute | Value |
|-----------|-------|
| **Method** | POST |
| **Auth** | JWT Required |

**Request:**
```json
{
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "reason": "Nhầm lẫn"
}
```

**Response (200 OK):**
```json
{
  "status": 200,
  "message": "SOS cancelled successfully",
  "data": {
    "event_id": "550e8400-e29b-41d4-a716-446655440000",
    "status": "cancelled",
    "cancelled_at": "2026-01-26T10:00:15Z"
  }
}
```

---

#### GET /api/v1/sos/status

**Purpose:** Lấy trạng thái SOS hiện tại

| Attribute | Value |
|-----------|-------|
| **Method** | GET |
| **Auth** | JWT Required |

**Query Parameters:**
| Param | Type | Required | Description |
|-------|------|:--------:|-------------|
| event_id | uuid | ❌ | Event ID (nếu không có, lấy event mới nhất) |

**Response (200 OK):**
```json
{
  "status": 200,
  "message": "Success",
  "data": {
    "event_id": "550e8400-e29b-41d4-a716-446655440000",
    "status": "pending",
    "triggered_at": "2026-01-26T10:00:00Z",
    "countdown_seconds": 30,
    "latitude": 10.762622,
    "longitude": 106.660172,
    "cooldown_active": true,
    "cooldown_remaining_seconds": 120
  }
}
```

---

#### GET /api/v1/sos/history

**Purpose:** Lấy lịch sử SOS events

| Attribute | Value |
|-----------|-------|
| **Method** | GET |
| **Auth** | JWT Required |

**Query Parameters:**
| Param | Type | Default | Description |
|-------|------|:-------:|-------------|
| page | int | 1 | Trang |
| size | int | 10 | Số items mỗi trang |

**Response (200 OK):**
```json
{
  "status": 200,
  "data": {
    "events": [
      {
        "event_id": "uuid",
        "status": "completed",
        "triggered_at": "2026-01-26T10:00:00Z",
        "latitude": 10.762622,
        "longitude": 106.660172
      }
    ],
    "total": 5,
    "page": 1,
    "size": 10
  }
}
```

---

### 1.2 Emergency Contact APIs (5 endpoints)

---

#### GET /api/v1/emergency-contacts

**Purpose:** Lấy danh sách liên hệ khẩn cấp

| Attribute | Value |
|-----------|-------|
| **Method** | GET |
| **Auth** | JWT Required |

**Query Parameters:**
| Param | Type | Default | Description |
|-------|------|:-------:|-------------|
| active_only | bool | true | Chỉ lấy contacts active |

**Response (200 OK):**
```json
{
  "status": 200,
  "data": {
    "contacts": [
      {
        "contact_id": "123e4567-e89b-12d3-a456-426614174000",
        "user_id": "uuid",
        "name": "Nguyễn Văn A",
        "phone": "0901234567",
        "relationship": "Con trai",
        "priority": 1,
        "is_active": true,
        "zalo_enabled": true,
        "created_at": "2026-01-26T10:00:00Z"
      }
    ],
    "total": 2
  }
}
```

---

#### POST /api/v1/emergency-contacts

**Purpose:** Thêm liên hệ khẩn cấp mới

| Attribute | Value |
|-----------|-------|
| **Method** | POST |
| **Auth** | JWT Required |

**Request:**
```json
{
  "name": "Lê Văn C",
  "phone": "0923456789",
  "relationship": "Cháu",
  "priority": 3,
  "zalo_enabled": true
}
```

| Field | Type | Required | Validation |
|-------|------|:--------:|------------|
| name | string | ✅ | Max 100 chars |
| phone | string | ✅ | VN format: `^(0|\+84)[0-9]{9,10}$` |
| relationship | string | ❌ | |
| priority | int | ❌ | 1-5 |
| zalo_enabled | bool | ❌ | Default: true |

**Response (201 Created):**
```json
{
  "status": 201,
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

**Response (400 - Max Contacts):**
```json
{
  "status": 400,
  "message": "Đã đạt giới hạn 5 người thân.",
  "error_code": "MAX_CONTACTS_REACHED"
}
```

---

#### PUT /api/v1/emergency-contacts/{contact_id}

**Purpose:** Cập nhật liên hệ khẩn cấp

| Attribute | Value |
|-----------|-------|
| **Method** | PUT |
| **Auth** | JWT Required |

**Path Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| contact_id | uuid | Contact ID |

**Request:**
```json
{
  "name": "Lê Văn C",
  "phone": "0923456789",
  "relationship": "Cháu",
  "priority": 2,
  "is_active": true,
  "zalo_enabled": false
}
```

**Response (200 OK):**
```json
{
  "status": 200,
  "data": { ... }
}
```

---

#### DELETE /api/v1/emergency-contacts/{contact_id}

**Purpose:** Xóa liên hệ khẩn cấp

| Attribute | Value |
|-----------|-------|
| **Method** | DELETE |
| **Auth** | JWT Required |

**Response (200 OK):**
```json
{
  "status": 200,
  "message": "Đã xóa người thân khỏi danh sách SOS."
}
```

---

#### POST /api/v1/emergency-contacts/reorder

**Purpose:** Sắp xếp lại thứ tự ưu tiên liên hệ

| Attribute | Value |
|-----------|-------|
| **Method** | POST |
| **Auth** | JWT Required |

**Request:**
```json
{
  "priorities": [
    { "contact_id": "uuid-1", "priority": 1 },
    { "contact_id": "uuid-2", "priority": 2 },
    { "contact_id": "uuid-3", "priority": 3 }
  ]
}
```

**Response (200 OK):**
```json
{
  "status": 200,
  "message": "Đã cập nhật thứ tự liên hệ."
}
```

---

### 1.3 First Aid APIs (3 endpoints)

---

#### GET /api/v1/first-aid/categories

**Purpose:** Lấy danh sách danh mục sơ cứu

| Attribute | Value |
|-----------|-------|
| **Method** | GET |
| **Auth** | Not Required |

**Response (200 OK):**
```json
{
  "status": 200,
  "data": {
    "categories": [
      { "category": "cpr", "icon_name": "heart_plus", "content_count": 1 },
      { "category": "stroke", "icon_name": "brain", "content_count": 1 },
      { "category": "low_sugar", "icon_name": "sugar", "content_count": 1 },
      { "category": "fall", "icon_name": "fall", "content_count": 1 }
    ]
  }
}
```

---

#### GET /api/v1/first-aid/categories/{category}

**Purpose:** Lấy nội dung sơ cứu theo danh mục

| Attribute | Value |
|-----------|-------|
| **Method** | GET |
| **Auth** | Not Required |

**Path Parameters:**
| Param | Type | Values |
|-------|------|--------|
| category | enum | cpr, stroke, low_sugar, fall |

**Response (200 OK):**
```json
{
  "status": 200,
  "data": {
    "category": "cpr",
    "contents": [
      {
        "content_id": "uuid",
        "category": "cpr",
        "title": "Hồi sinh tim phổi (CPR)",
        "content": "## Hướng dẫn CPR...",
        "display_order": 1,
        "icon_name": "heart_plus",
        "version": 1
      }
    ]
  }
}
```

---

#### GET /api/v1/first-aid/content

**Purpose:** Lấy tất cả nội dung sơ cứu (grouped by category)

| Attribute | Value |
|-----------|-------|
| **Method** | GET |
| **Auth** | Not Required |

**Response (200 OK):**
```json
{
  "status": 200,
  "data": {
    "content": {
      "cpr": [ { "title": "...", "content": "..." } ],
      "stroke": [ ... ],
      "low_sugar": [ ... ],
      "fall": [ ... ]
    }
  }
}
```

---

### 1.4 Hospital APIs (1 endpoint)

---

#### GET /api/v1/hospitals/nearby

**Purpose:** Tìm bệnh viện gần nhất (via Google Places API)

| Attribute | Value |
|-----------|-------|
| **Method** | GET |
| **Auth** | JWT Required |

**Query Parameters:**
| Param | Type | Required | Default | Description |
|-------|------|:--------:|:-------:|-------------|
| latitude | double | ✅ | - | Vĩ độ |
| longitude | double | ✅ | - | Kinh độ |
| radius | int | ❌ | 5000 | Bán kính (mét) |
| limit | int | ❌ | 10 | Số kết quả tối đa |

**Response (200 OK):**
```json
{
  "status": 200,
  "data": {
    "hospitals": [
      {
        "place_id": "ChIJ...",
        "name": "Bệnh viện Chợ Rẫy",
        "address": "201B Nguyễn Chí Thanh, Q.5, HCM",
        "latitude": 10.758,
        "longitude": 106.658,
        "distance_meters": 1200,
        "rating": 4.2,
        "open_now": true,
        "phone": "028 3855 4137"
      }
    ],
    "total": 10,
    "search_latitude": 10.762622,
    "search_longitude": 106.660172
  }
}
```

---

## 2. Error Codes Reference

| Code | HTTP Status | Description |
|------|:-----------:|-------------|
| `COOLDOWN_ACTIVE` | 429 | SOS đã gửi trong 30 phút trước |
| ~~`CONTACTS_REQUIRED`~~ | - | ~~DEPRECATED in v1.8 (per BR-SOS-024)~~ |
| `EVENT_NOT_FOUND` | 404 | Không tìm thấy SOS event |
| `EVENT_ALREADY_COMPLETED` | 400 | Không thể hủy SOS đã hoàn thành |
| `EVENT_ALREADY_CANCELLED` | 400 | SOS đã bị hủy |
| `MAX_CONTACTS_REACHED` | 400 | Đã đạt giới hạn 5 contacts |
| `DUPLICATE_PHONE` | 400 | SĐT đã tồn tại |
| `INVALID_PHONE_FORMAT` | 400 | SĐT không hợp lệ |
| `CONTACT_NOT_FOUND` | 404 | Contact không tồn tại |
| `UNAUTHORIZED` | 401 | JWT không hợp lệ |
| `SERVER_ERROR` | 500 | Lỗi server |

---

## 3. API Summary

| Category | Endpoints | Auth Required |
|----------|:---------:|:-------------:|
| SOS Core | 4 | ✅ |
| Emergency Contacts | 5 | ✅ |
| First Aid | 3 | ❌ |
| Hospitals | 1 | ✅ |
| **TOTAL** | **13** | - |

---

## Next Phase

✅ **Phase 4: API Mapping** - COMPLETE (Updated)

➡️ **Phase 5: Feasibility Assessment**
