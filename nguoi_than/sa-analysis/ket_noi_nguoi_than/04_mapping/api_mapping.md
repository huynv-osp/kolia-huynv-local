# API Mapping: KOLIA-1517 - Kết nối Người thân

> **Phase:** 4 - Architecture Mapping & Analysis  
> **Date:** 2026-01-30  
> **Revision:** v2.13 - Patient BP Thresholds added to Blood Pressure Chart API

---

## 1. REST API (api-gateway-service)

### Invite Management

| Method | Path | Description |
|:------:|------|-------------|
| POST | `/api/v1/connections/invite` | Create bi-directional invite |
| GET | `/api/v1/connections/invites` | List sent/received invites |
| GET | `/api/v1/connections/invites/:inviteId` | Get invite details |
| DELETE | `/api/v1/connections/invites/:inviteId` | Cancel pending invite |
| POST | `/api/v1/connections/invites/:inviteId/accept` | Accept invite |
| POST | `/api/v1/connections/invites/:inviteId/reject` | Reject invite |

### Connection Management

| Method | Path | Description |
|:------:|------|-------------|
| GET | `/api/v1/connections` | List active connections |
| DELETE | `/api/v1/connections/:connectionId` | Disconnect |
| GET | `/api/v1/connections/:connectionId/permissions` | Get permissions for connection |
| PUT | `/api/v1/connections/:connectionId/permissions` | Update permissions |

### Profile Selection (NEW - v2.7)

| Method | Path | Description |
|:------:|------|-------------|
| GET | `/api/v1/connections/viewing` | Get currently viewing patient |
| PUT | `/api/v1/connections/viewing` | Set viewing patient |

### Lookup APIs (NEW - v2.1, v2.8)

| Method | Path | Description |
|:------:|------|-------------|
| GET | `/api/v1/connection/permission-types` | List all active permission types |
| GET | `/api/v1/connection/relationship-types` | List all active relationship types |

### Dashboard APIs (NEW - v2.11, v2.14)

| Method | Path | Description |
|:------:|------|-------------|
| GET | `/api/v1/patients/:patientId/blood-pressure-chart` | Blood pressure chart data |
| GET | `/api/v1/patients/:patientId/periodic-reports` | Patient periodic reports |
| POST | `/api/v1/patients/:patientId/periodic-reports/:reportId/mark-read` | Mark report as read (v2.14) |

---

## 2. API Contracts

### POST /api/v1/connections/invite

**Request:**
```json
{
  "receiver_phone": "0912345678",
  "receiver_name": "Nguyễn Văn A",
  "relationship": "con_trai",
  "invite_type": "patient_to_caregiver",
  "permissions": {
    "health_overview": true,
    "emergency_alert": true,
    "task_config": true,
    "compliance_tracking": true,
    "proxy_execution": true,
    "encouragement": true
  }
}
```

**Response (201):**
```json
{
  "invite_id": "uuid",
  "status": "pending",
  "created_at": "2026-01-28T10:00:00Z"
}
```

---

### POST /api/v1/connections/invites/:inviteId/accept

> **SRS Reference:** A2.1 (SCR-02B-ACCEPT) + B2.1  
> **⚠️ Patient nhận invite từ Caregiver PHẢI config permissions trước khi accept**

**Request (Patient accepting from Caregiver - SCR-02B-ACCEPT):**
```json
{
  "permissions": {
    "health_overview": true,
    "emergency_alert": true,
    "task_config": false,
    "compliance_tracking": true,
    "proxy_execution": false,
    "encouragement": true
  }
}
```

**Request (Caregiver accepting from Patient - quick accept):**
```json
{}
```
> Note: Caregiver không config permissions - sử dụng permissions đã config bởi Patient trong invite

**Response (200):**
```json
{
  "connection_id": "uuid",
  "patient": { "id": "uuid", "name": "..." },
  "caregiver": { "id": "uuid", "name": "..." },
  "relationship": "con_trai",
  "status": "active"
}
```

**Side Effects (BR-010):**
- Notify sender: Push notification "{Tên} đã chấp nhận lời mời"

---

### POST /api/v1/connections/invites/:inviteId/reject

> **SRS Reference:** A2.2, B2.2 (BR-011)

**Request:** No body required

**Response (200):**
```json
{
  "invite_id": "uuid",
  "status": "rejected",
  "rejected_at": "2026-01-28T10:00:00Z"
}
```

**Side Effects (BR-011):**
- Notify sender: Push notification "{Tên} đã từ chối lời mời của bạn"
- Sender có thể gửi lại invite mới (re-invite allowed)

---

### DELETE /api/v1/connections/invites/:inviteId

> **SRS Reference:** A3.2b, B3.2b - Cancel pending invite (sender only)

**Request:** No body required

**Authorization:** Chỉ sender của invite mới được cancel

**Response (200):**
```json
{
  "invite_id": "uuid",
  "status": "cancelled",
  "cancelled_at": "2026-01-28T10:00:00Z"
}
```

**Business Logic:**
- Chỉ áp dụng cho invite có status = `pending`
- Không gửi notification đến receiver khi cancel
- Invite record được soft delete hoặc update status = `cancelled`

---

### GET /api/v1/connections/invites/:inviteId (NEW - v2.12)

> **Purpose:** Get single invite details by ID

**Response (200):**
```json
{
  "invite_id": "uuid",
  "sender": { "id": "uuid", "name": "...", "phone": "..." },
  "receiver": { "id": "uuid", "name": "...", "phone": "..." },
  "invite_type": "patient_to_caregiver",
  "relationship_code": "con_trai",
  "status": "pending",
  "permissions": [...],
  "created_at": "2026-01-28T10:00:00Z",
  "expires_at": "2026-02-04T10:00:00Z"
}
```

**Error Responses:**
- `404 NOT_FOUND`: Invite không tồn tại hoặc không có quyền xem

---

### GET /api/v1/connections/invites

> **SRS Reference:** A1.5, A3.2, B2.4 (BR-013, BR-023)

**Query Params:**
- `type`: `sent` | `received` | `all` (default: `all`)
- `status`: `pending` | `rejected` | `all` (default: `pending`)

**Response (200):**
```json
{
  "sent": [
    {
      "invite_id": "uuid",
      "receiver": { "phone": "0912***678", "name": "Nguyễn Văn A" },
      "relationship": "con_trai",
      "invite_type": "patient_to_caregiver",
      "status": "pending",
      "created_at": "2026-01-28T10:00:00Z"
    }
  ],
  "received": [
    {
      "invite_id": "uuid",
      "sender": { "id": "uuid", "name": "Nguyễn Văn B", "avatar": "..." },
      "relationship": "me",
      "invite_type": "caregiver_to_patient",
      "status": "pending",
      "created_at": "2026-01-28T09:00:00Z"
    }
  ],
  "total_pending": 2
}
```

---

### GET /api/v1/connections

**Response (200):**
```json
{
  "monitoring": [
    {
      "connection_id": "uuid",
      "patient": { "id": "uuid", "name": "...", "avatar": "..." },
      "relationship": "me",
      "relationship_display": "Mẹ (Nguyễn Thị B)",
      "last_active": "2026-01-28T09:00:00Z"
    }
  ],
  "monitored_by": [
    {
      "connection_id": "uuid",
      "caregiver": { "id": "uuid", "name": "..." },
      "relationship": "con_trai",
      "relationship_display": "Con trai (Nguyễn Văn A)",
      "last_active": "2026-01-28T08:30:00Z"
    }
  ]
}
```

> **BR-029:** `relationship_display` format: `{Mối quan hệ} ({Họ tên})`. Nếu `relationship = "khac"` → thay "Khác" bằng "Người thân" (VD: "Người thân (Nguyễn Văn A)")
>
> **BR-014:** `last_active` = user's last online timestamp từ `users.last_active_at`

---

### DELETE /api/v1/connections/{id}

> **SRS Reference:** A5.1, B5.1 (BR-019, BR-020)

**Request:** No body required

**Response (200):**
```json
{
  "connection_id": "uuid",
  "status": "disconnected",
  "disconnected_at": "2026-01-28T10:00:00Z",
  "disconnected_by": "patient"
}
```

**Side Effects:**
- **BR-019** (Patient disconnect): Notify Caregiver "{Tên Patient} đã hủy kết nối"
- **BR-020** (Caregiver exit): Notify Patient "{Tên Caregiver} đã ngừng theo dõi bạn"

---

### GET /api/v1/connections/{id}/permissions

> **SRS Reference:** A4.1 (BR-017)

**Response (200):**
```json
{
  "connection_id": "uuid",
  "caregiver": { "id": "uuid", "name": "Nguyễn Văn A" },
  "permissions": [
    { "code": "health_overview", "name_vi": "Xem tổng quan sức khỏe", "icon": "heart", "is_enabled": true },
    { "code": "emergency_alert", "name_vi": "Nhận cảnh báo khẩn cấp", "icon": "bell", "is_enabled": true },
    { "code": "task_config", "name_vi": "Cấu hình nhiệm vụ", "icon": "settings", "is_enabled": false },
    { "code": "compliance_tracking", "name_vi": "Theo dõi tuân thủ", "icon": "check-circle", "is_enabled": true },
    { "code": "proxy_execution", "name_vi": "Thực hiện thay mặt", "icon": "user-check", "is_enabled": false },
    { "code": "encouragement", "name_vi": "Gửi động viên", "icon": "message-heart", "is_enabled": true }
  ]
}
```

---

### PUT /api/v1/connections/{id}/permissions

**Request:**
```json
{
  "permission_type": "emergency_alert",
  "is_enabled": false
}
```

**Response (200):**
```json
{
  "permissions": [
    { "code": "health_overview", "is_enabled": true },
    { "code": "emergency_alert", "is_enabled": false },
    { "code": "task_config", "is_enabled": true },
    { "code": "compliance_tracking", "is_enabled": true },
    { "code": "proxy_execution", "is_enabled": false },
    { "code": "encouragement", "is_enabled": true }
  ]
}
```

---

### GET /api/v1/connection/permission-types (NEW - v2.1)

> **Purpose:** Lấy danh sách tất cả permission types để hiển thị UI

**Response (200):**
```json
{
  "permission_types": [
    {
      "code": "health_overview",
      "name_vi": "Xem tổng quan sức khỏe",
      "name_en": "View Health Overview",
      "icon": "heart",
      "description": "Cho phép xem các chỉ số sức khỏe",
      "display_order": 1
    },
    {
      "code": "emergency_alert",
      "name_vi": "Nhận cảnh báo khẩn cấp",
      "name_en": "Receive Emergency Alerts", 
      "icon": "bell",
      "description": "Nhận thông báo khi có SOS",
      "display_order": 2
    },
    {
      "code": "task_config",
      "name_vi": "Cấu hình nhiệm vụ",
      "name_en": "Configure Tasks",
      "icon": "settings",
      "description": "Thiết lập nhiệm vụ tuân thủ",
      "display_order": 3
    },
    {
      "code": "compliance_tracking",
      "name_vi": "Theo dõi tuân thủ",
      "name_en": "Track Compliance",
      "icon": "check-circle",
      "description": "Xem kết quả tuân thủ nhiệm vụ",
      "display_order": 4
    },
    {
      "code": "proxy_execution",
      "name_vi": "Thực hiện thay mặt",
      "name_en": "Proxy Execution",
      "icon": "user-check",
      "description": "Thực hiện nhiệm vụ thay Patient",
      "display_order": 5
    },
    {
      "code": "encouragement",
      "name_vi": "Gửi động viên",
      "name_en": "Send Encouragement",
      "icon": "message-heart",
      "description": "Gửi lời động viên đến Patient",
      "display_order": 6
    }
  ]
}
```

**Caching:**
- Response có thể cache tại client (TTL: 24h)
- Data thay đổi rất hiếm (chỉ khi thêm/sửa permission types)

**Use Cases:**
- Create invite: Hiển thị danh sách permissions để chọn
- Edit permissions: Hiển thị full list với toggle states

---

### GET /api/v1/connection/relationship-types (NEW - v2.8)

> **Purpose:** Lấy danh sách tất cả relationship types để hiển thị UI picker

**Response (200):**
```json
{
  "relationship_types": [
    {
      "code": "con_trai",
      "name_vi": "Con trai",
      "name_en": "Son",
      "category": "family",
      "display_order": 1
    },
    {
      "code": "con_gai",
      "name_vi": "Con gái",
      "name_en": "Daughter",
      "category": "family",
      "display_order": 2
    },
    {
      "code": "bo",
      "name_vi": "Bố",
      "name_en": "Father",
      "category": "family",
      "display_order": 9
    },
    {
      "code": "me",
      "name_vi": "Mẹ",
      "name_en": "Mother",
      "category": "family",
      "display_order": 10
    },
    {
      "code": "vo",
      "name_vi": "Vợ",
      "name_en": "Wife",
      "category": "spouse",
      "display_order": 15
    },
    {
      "code": "chong",
      "name_vi": "Chồng",
      "name_en": "Husband",
      "category": "spouse",
      "display_order": 16
    },
    {
      "code": "khac",
      "name_vi": "Khác",
      "name_en": "Other",
      "category": "other",
      "display_order": 99
    }
  ]
}
```

**Response Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `code` | string | Unique relationship code (matches `relationships.relationship_code`) |
| `name_vi` | string | Vietnamese display name |
| `name_en` | string | English display name |
| `category` | enum | `family`, `spouse`, `other` |
| `display_order` | int | Sort order for UI display |

**Caching:**
- Response có thể cache tại client (TTL: 24h)
- Data thay đổi rất hiếm (chỉ khi thêm/sửa relationship types)

**Use Cases:**
- Create invite: Hiển thị danh sách relationships để chọn
- Edit connection: Hiển thị relationship options

---

### GET /api/v1/connections/viewing (NEW - v2.7)

> **Purpose:** Lấy thông tin Patient đang được chọn xem (BR-026)
> **SRS Reference:** BR-026  

**Response (200):**
```json
{
  "viewing_patient": {
    "connection_id": "uuid",
    "patient_id": "uuid",
    "patient_name": "Nguyễn Thị Cúc",
    "patient_avatar": "...",
    "relationship_display": "Mẹ (Nguyễn Thị Cúc)",
    "last_active": "2026-01-29T14:30:00Z"
  }
}
```

**Response (200 - No Selection):**
```json
{
  "viewing_patient": null
}
```

---

### PUT /api/v1/connections/viewing (NEW - v2.7)

> **Purpose:** Đổi Patient đang được chọn xem
> **Constraint:** Chỉ có thể chọn 1 patient tại 1 thời điểm

**Request:**
```json
{
  "connection_id": "uuid"  // null = clear selection
}
```

**Response (200):**
```json
{
  "viewing_patient": {
    "connection_id": "uuid",
    "patient_id": "uuid",
    "patient_name": "Nguyễn Thị Cúc",
    "patient_avatar": "...",
    "relationship_display": "Mẹ (Nguyễn Thị Cúc)",
    "last_active": "2026-01-29T14:30:00Z"
  },
  "updated_at": "2026-01-29T15:00:00Z"
}
```

**Business Logic:**
- Validate `connection_id` thuộc `monitoring[]` của user (chỉ Caregiver mới xem Patient)
- Cập nhật `is_viewing = FALSE` cho row cũ (nếu có)
- Cập nhật `is_viewing = TRUE` cho row mới
- Return 404 nếu `connection_id` không hợp lệ

**Error Codes:**
| Code | Description |
|------|-------------|
| 404 | Connection not found or not in monitoring list |
| 400 | Cannot view own profile (patient_id = user_id) |

---

## 3. gRPC API (user-service)

```protobuf
service ConnectionService {
  // Invites
  rpc CreateInvite(CreateInviteRequest) returns (InviteResponse);
  rpc GetInvite(GetInviteRequest) returns (InviteResponse);
  rpc ListInvites(ListInvitesRequest) returns (ListInvitesResponse);
  rpc AcceptInvite(AcceptInviteRequest) returns (ConnectionResponse);
  rpc RejectInvite(RejectInviteRequest) returns (InviteResponse);
  
  // Connections
  rpc ListConnections(ListConnectionsRequest) returns (ListConnectionsResponse);
  rpc Disconnect(DisconnectRequest) returns (ConnectionResponse);
  
  // Permissions
  rpc GetPermissions(GetPermissionsRequest) returns (PermissionsResponse);
  rpc UpdatePermissions(UpdatePermissionsRequest) returns (PermissionsResponse);
  
  // Lookup (NEW - v2.1, v2.8)
  rpc ListPermissionTypes(Empty) returns (PermissionTypesResponse);
  rpc ListRelationshipTypes(Empty) returns (RelationshipTypesResponse);
  
  // Profile Selection (NEW - v2.7)
  rpc GetViewingPatient(GetViewingPatientRequest) returns (ViewingPatientResponse);
  rpc SetViewingPatient(SetViewingPatientRequest) returns (ViewingPatientResponse);
}

// NEW - v2.7
message GetViewingPatientRequest {
  string user_id = 1;
}

message SetViewingPatientRequest {
  string user_id = 1;
  string connection_id = 2;  // nullable - empty = clear
}

message ViewingPatientResponse {
  ViewingPatient viewing_patient = 1;
  string updated_at = 2;
}

message ViewingPatient {
  string connection_id = 1;
  string patient_id = 2;
  string patient_name = 3;
  string patient_avatar = 4;
  string relationship_display = 5;
  string last_active = 6;
}

// NEW - v2.8
message RelationshipType {
  string code = 1;
  string name_vi = 2;
  string name_en = 3;
  string category = 4;
  int32 display_order = 5;
}

message RelationshipTypesResponse {
  repeated RelationshipType relationship_types = 1;
}
```

---

## 4. Kafka Topics

| Topic | Publisher | Consumer | Payload |
|-------|-----------|----------|---------|
| `connection.invite.created` | user-service | schedule-service | invite_id, sender, receiver |
| `connection.invite.accepted` | user-service | schedule-service | invite_id, connection_id, sender_id (BR-010) |
| `connection.invite.rejected` | user-service | schedule-service | invite_id, sender_id (BR-011) |
| `connection.status.changed` | user-service | schedule-service | connection_id, status, affected_users |
| `connection.permission.changed` | user-service | schedule-service | connection_id, permission_type, caregiver_id |

---

## 4.1 Notification Payloads (BR-010, BR-011)

### Invite Accepted (BR-010)
```json
{
  "event": "invite.accepted",
  "invite_id": "uuid",
  "sender_id": "uuid",
  "acceptor_name": "Nguyễn Văn A",
  "notification": {
    "title": "Lời mời được chấp nhận",
    "body": "{Tên} đã chấp nhận lời mời của bạn",
    "channels": ["PUSH"]
  }
}
```

### Invite Rejected (BR-011)
```json
{
  "event": "invite.rejected",
  "invite_id": "uuid",
  "sender_id": "uuid",
  "rejector_name": "Nguyễn Văn A",
  "allow_reinvite": true,
  "notification": {
    "title": "Lời mời bị từ chối",
    "body": "{Tên} đã từ chối lời mời của bạn",
    "channels": ["PUSH"]
  }
}
```

### Re-invite Flow (BR-011)
> Sau khi invite bị reject, sender có thể gửi lại invite.
> - Invite cũ status = `rejected`
> - Sender gọi POST /api/v1/connections/invite với cùng receiver_phone
> - System tạo invite mới (invite_id mới)

### Permission Changed (BR-016)
```json
{
  "event": "permission.changed",
  "connection_id": "uuid",
  "caregiver_id": "uuid",
  "permission_type": "emergency_alert",
  "is_enabled": false,
  "changed_by": "patient",
  "notification": {
    "title": "Quyền của bạn đã thay đổi",
    "body": "{Tên Patient} đã tắt quyền 'Nhận cảnh báo khẩn cấp'",
    "channels": ["PUSH"]
  }
}
```

### Connection Disconnect (BR-019, BR-020)
```json
{
  "event": "connection.disconnected",
  "connection_id": "uuid",
  "disconnected_by": "patient",
  "affected_user_id": "uuid",
  "notification": {
    "title": "Kết nối đã bị hủy",
    "body": "{Tên} đã hủy kết nối với bạn",
    "channels": ["PUSH"]
  }
}
```

> **BR-019**: Patient disconnect → Notify Caregiver  
> **BR-020**: Caregiver exit → Notify Patient

---

## 4.2 ZNS/SMS Fallback Flow (BR-004)

> **SRS Reference:** SYS.1 - ZNS fail → SMS fallback

### Invite Notification Flow
```
┌─────────────────────────────────────────────────────────────────┐
│                     NOTIFICATION FLOW                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   user-service                                                   │
│       │                                                          │
│       ▼ Kafka: connection.invite.created                         │
│   schedule-service                                               │
│       │                                                          │
│       ▼ Check receiver_has_zalo?                                 │
│       │                                                          │
│   ┌───┴───────────────────────────────────────┐                  │
│   │ YES                                       │ NO               │
│   ▼                                           ▼                  │
│ ZNS API                                   SMS Gateway            │
│   │                                           │                  │
│   ▼ Success?                                  ▼ Success?         │
│   │                                           │                  │
│ ┌─┴─────────┐                             ┌───┴─────────┐        │
│ │ YES → END │                             │ YES → END   │        │
│ └───────────┘                             └─────────────┘        │
│   │ NO                                        │ NO               │
│   ▼                                           ▼                  │
│ Retry counter++                           Retry counter++        │
│ (max 3, interval 30s)                     (max 3, interval 30s)  │
│   │                                           │                  │
│   ▼ Exhausted?                                ▼ Exhausted?       │
│   │ YES → SMS Fallback                        │ YES → Log Error  │
│   │ NO  → Retry ZNS                           │ NO  → Retry SMS  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Kafka Payload for Notification Service
```json
{
  "topic": "notification.send",
  "payload": {
    "notification_id": "uuid",
    "type": "CONNECTION_INVITE",
    "receiver_phone": "0912345678",
    "receiver_user_id": "uuid",
    "template": "CONNECTION_INVITE_NEW",
    "params": {
      "sender_name": "Nguyễn Văn A",
      "invite_type": "patient_to_caregiver",
      "deep_link": "kolia://invite?id={invite_id}"
    },
    "channels": ["ZNS", "PUSH"],
    "fallback": {
      "channel": "SMS",
      "retry_count": 3,
      "retry_interval_seconds": 30
    }
  }
}
```

### Deep Link Format
```
kolia://invite?id={invite_id}
kolia://connection?id={connection_id}
```

---

## 5. Error Codes

| Code | HTTP | Description |
|------|:----:|-------------|
| SELF_INVITE | 400 | Cannot invite yourself |
| DUPLICATE_PENDING | 400 | Already has pending invite |
| ALREADY_CONNECTED | 400 | Connection already exists |
| INVITE_NOT_FOUND | 404 | Invite not found |
| CONNECTION_NOT_FOUND | 404 | Connection not found |
| NOT_AUTHORIZED | 403 | Not allowed to modify |
| INVALID_PERMISSION_TYPE | 400 | Permission type not recognized |
| ZNS_SEND_FAILED | 503 | ZNS service unavailable |
| SMS_SEND_FAILED | 503 | SMS gateway unavailable |
| PERMISSION_DENIED | 403 | Permission #1 is OFF (SEC-DB-002) |

---

## 6. Security Requirements (SEC-DB-*)

> **SRS Reference:** Security Requirements section (Line 683-689)  
> **Revision:** v2.11 - Detailed Authorization Flow per User Confirmation

### 6.1 Authorization Flow Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│                    CAREGIVER API AUTHORIZATION                         │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  INPUT: caregiver_id (from JWT) + patient_id (from URL path)           │
│                                                                        │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ STEP 1: Check Connection Exists (đúng người theo dõi)           │   │
│  ├─────────────────────────────────────────────────────────────────┤   │
│  │ SELECT id AS contact_id FROM user_emergency_contacts            │   │
│  │ WHERE user_id = {patient_id}           ← Patient mình theo dõi  │   │
│  │   AND linked_user_id = {caregiver_id}  ← Chính mình             │   │
│  │   AND is_active = TRUE                 ← Connection còn active  │   │
│  │                                                                 │   │
│  │ ❌ NOT FOUND → 403 "Bạn không theo dõi người bệnh này"          │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                          │                                             │
│                          ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ STEP 2: Check Permission Enabled (có quyền tương ứng)           │   │
│  ├─────────────────────────────────────────────────────────────────┤   │
│  │ SELECT is_enabled FROM connection_permissions                   │   │
│  │ WHERE contact_id = {contact_id}        ← Từ Step 1              │   │
│  │   AND permission_code = 'health_overview'  ← Quyền cụ thể       │   │
│  │                                                                 │   │
│  │ ❌ is_enabled = FALSE → 403 "Quyền xem sức khỏe đã bị tắt"      │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                          │                                             │
│                          ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ STEP 3: Fetch Data (chỉ data của patient_id)                    │   │
│  ├─────────────────────────────────────────────────────────────────┤   │
│  │ - Blood pressure từ patient_id ONLY                             │   │
│  │ - Periodic reports của patient_id ONLY                          │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Database Schema Reference

```sql
-- Table 1: Connection relationship
user_emergency_contacts
├── id (contact_id)
├── user_id          ← Patient được theo dõi
├── linked_user_id   ← Caregiver đang theo dõi  
├── is_active        ← TRUE = connection còn hoạt động
└── ...

-- Table 2: Permission settings per connection
connection_permissions
├── contact_id       ← FK → user_emergency_contacts.id
├── permission_code  ← 'health_overview', 'emergency_alert', etc.
├── is_enabled       ← TRUE/FALSE
└── ...

-- Table 3: Permission types (lookup reference)
connection_permission_types
├── code             ← 'health_overview'
├── name             ← 'Xem tổng quan sức khỏe'
└── ...
```

### 6.3 SEC-DB-001: API Authorization

| Endpoint | Permission Required | Check Location |
|----------|---------------------|----------------|
| `GET /api/v1/patients/{id}/blood-pressure-chart` | `health_overview` | user-service |
| `GET /api/v1/patients/{id}/periodic-reports` | `health_overview` | user-service |

### 6.4 SEC-DB-002: Permission Revoke Handling

```
Policy: NO CACHING of permission state
- Check permission từ DB mỗi lần gọi API
- Permission OFF → Return 403 PERMISSION_DENIED immediately
- Client phải handle 403 và refresh UI
```

### 6.5 SEC-DB-003: Deep Link Protection

| Deep Link | Validation |
|-----------|------------|
| `kolia://patient/{id}/report/{reportId}` | Validate connection + permission #1 |
| `kolia://patient/{id}/health` | Validate connection + permission #1 |

---

## 7. Dashboard API (US 1.1) - v2.11

> **Revision:** v2.11 - Date range params, reuse periodic reports structure, read tracking

### 7.1 GET /api/v1/patients/:patientId/blood-pressure-chart

> **Purpose:** Lấy data huyết áp cho biểu đồ xu hướng
> **v2.13:** Added `patient_target_thresholds` - Patient's BP target thresholds from health_profile

**Path Params:**
- `patientId`: UUID - ID của Patient được theo dõi

**Query Params:**
- `mode`: `week` | `month` (default: `week`) - Khoảng thời gian hiển thị
  - `week`: 7 ngày gần nhất
  - `month`: 30 ngày gần nhất

**Response (200):**
```json
{
  "status": 200,
  "message": "Success",
  "data": {
    "patient_id": "patient_uuid",
    "mode": "week",
    "period_start": "2026-01-27",
    "period_end": "2026-01-30",
    "empty_state": false,
    "measurements": [
      {
        "systolic": 130,
        "diastolic": 85,
        "heart_rate": 72,
        "measurement_time": "2026-01-30T10:15:30+07:00"
      },
      {
        "systolic": 128,
        "diastolic": 82,
        "heart_rate": 70,
        "measurement_time": "2026-01-30T08:00:00+07:00"
      }
    ],
    "patient_target_thresholds": {
      "systolic_threshold_lower": 90,
      "systolic_threshold_upper": 140,
      "diastolic_threshold_lower": 60,
      "diastolic_threshold_upper": 90
    }
  }
}
```

**New Fields (v2.13):**
| Field | Type | Description |
|-------|------|-------------|
| `patient_target_thresholds` | object | Patient's BP target thresholds from `health_profile` table |
| `patient_target_thresholds.systolic_threshold_lower` | int | Lower bound for normal systolic BP |
| `patient_target_thresholds.systolic_threshold_upper` | int | Upper bound for normal systolic BP |
| `patient_target_thresholds.diastolic_threshold_lower` | int | Lower bound for normal diastolic BP |
| `patient_target_thresholds.diastolic_threshold_upper` | int | Upper bound for normal diastolic BP |

> **Note:** `patient_target_thresholds` may be `null` if patient has not set thresholds in their health profile.

**Error Responses:**
| Code | Error | Condition |
|:----:|-------|-----------|
| 400 | INVALID_MODE | `mode` không phải `week` hoặc `month` |
| 403 | NOT_CONNECTED | Connection không tồn tại hoặc inactive |
| 403 | PERMISSION_DENIED | Permission `health_overview` = OFF |

**Authorization:** SEC-DB-001 (Permission #1 check)

---

### 7.2 GET /api/v1/patients/:patientId/periodic-reports

> **Purpose:** Lấy danh sách báo cáo định kỳ của Patient (reuse existing structure)

**Path Params:**
- `patient_id`: UUID - ID của Patient được theo dõi

**Query Params:**
- `report_type`: `1` (weekly) | `2` (monthly) | `4` (daily) |null (all) - Default: null
- `page`: number - Default: 1
- `size`: number - Default: 10

**Response (200):**
```json
{
  "status": 200,
  "message": "Success",
  "data": {
    "list_data": [
      {
        "report_id": 1001,
        "user_id": "patient_uuid",
        "user_info": { "name": "Nguyễn Văn A", "avatar_id": "uuid" },
        "start_date": "2026-01-20",
        "end_date": "2026-01-26",
        "report_type": 1,
        "user_blood_pressure_info": [...],
        "agent_summary": {...},
        "created_at": "2026-01-27T00:00:00Z",
        "is_read": false
      }
    ],
    "total_count": 50,
    "unread_count": 3,
    "page": 1,
    "size": 10
  }
}
```

**New Fields:**
| Field | Description |
|-------|-------------|
| `is_read` | `true` nếu caregiver đã xem báo cáo này |
| `unread_count` | Tổng số báo cáo chưa đọc |

**Authorization:** SEC-DB-001 (Permission #1 check)

---

### 7.3 Report Read Tracking

> **NEW TABLE:** `caregiver_report_views`

```sql
CREATE TABLE caregiver_report_views (
    id BIGSERIAL PRIMARY KEY,
    caregiver_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    report_id BIGINT NOT NULL REFERENCES report_periodic(report_id) ON DELETE CASCADE,
    viewed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT idx_unique_caregiver_report UNIQUE (caregiver_id, report_id)
);

CREATE INDEX idx_crv_caregiver_id ON caregiver_report_views(caregiver_id);
CREATE INDEX idx_crv_report_id ON caregiver_report_views(report_id);
```

**Read Status Query:**
```sql
-- Check if report is read
SELECT EXISTS (
    SELECT 1 FROM caregiver_report_views 
    WHERE caregiver_id = {caregiver_id} AND report_id = {report_id}
) AS is_read;

-- Mark as read (auto on GET detail)
INSERT INTO caregiver_report_views (caregiver_id, report_id)
VALUES ({caregiver_id}, {report_id})
ON CONFLICT (caregiver_id, report_id) DO NOTHING;

-- Get unread count
SELECT COUNT(*) FROM report_periodic pr
WHERE pr.user_id = {patient_id}
AND NOT EXISTS (
    SELECT 1 FROM caregiver_report_views crv 
    WHERE crv.report_id = pr.id AND crv.caregiver_id = {caregiver_id}
);
```

