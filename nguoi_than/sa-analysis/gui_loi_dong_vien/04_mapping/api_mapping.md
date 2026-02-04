# API Mapping: US 1.3 - Gửi Lời Động Viên

> **Phase:** 4 - Architecture Mapping & Analysis  
> **Date:** 2026-02-04  
> **Revision:** v1.0  
> **Source:** SRS-Gửi-Lời-Động-Viên_v1.3

---

## REST API Endpoints (api-gateway-service)

### Caregiver APIs

#### 1. Create Encouragement

| Method | Path | Description | Auth |
|:------:|------|-------------|:----:|
| POST | `/api/v1/encouragements` | Send encouragement message | ✅ |

**Request Body:**
```json
{
  "patient_id": "uuid-patient",
  "contact_id": "uuid-connection",
  "content": "Mẹ ơi, con chúc mẹ ngày mới an lành!"
}
```

**Response (201 Created):**
```json
{
  "encouragement_id": "uuid-new-message",
  "remaining_quota": 9,
  "message": "Đã gửi lời động viên cho Mẹ"
}
```

**Error Responses:**
| Code | Error | Description |
|:----:|-------|-------------|
| 400 | EMPTY_CONTENT | Content is empty or whitespace |
| 400 | CONTENT_TOO_LONG | Content > 150 chars |
| 403 | PERMISSION_DENIED | Permission #6 OFF |
| 429 | QUOTA_EXCEEDED | 10 messages sent today |

---

#### 2. Get Quota

| Method | Path | Description | Auth |
|:------:|------|-------------|:----:|
| GET | `/api/v1/encouragements/quota` | Check remaining quota | ✅ |

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|:--------:|-------------|
| patient_id | UUID | ✅ | Target patient |

**Request:**
```
GET /api/v1/encouragements/quota?patient_id=abc-123
Authorization: Bearer {access_token}
```

**Response (200 OK):**
```json
{
  "remaining": 7,
  "limit": 10,
  "reset_at": 1707091200000
}
```

---

### Patient APIs

#### 3. Get Encouragement List

| Method | Path | Description | Auth |
|:------:|------|-------------|:----:|
| GET | `/api/v1/encouragements` | Get messages in 24h window | ✅ |

**Query Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| unread_only | bool | true | Filter unread only |
| hours | int | 24 | Time window in hours |

**Request:**
```
GET /api/v1/encouragements?unread_only=true
Authorization: Bearer {access_token}
```

**Response (200 OK):**
```json
{
  "messages": [
    {
      "encouragement_id": "uuid-1",
      "sender_name": "HuyA",
      "sender_avatar_url": "https://storage.kolia.vn/avatars/uuid-huyA.jpg",
      "relationship_display": "Con gái",
      "content": "Mẹ ơi, con chúc mẹ ngày mới an lành!",
      "sent_at": "2026-02-04T08:30:00+07:00",
      "is_read": false
    },
    {
      "encouragement_id": "uuid-2",
      "sender_name": "MinhB",
      "sender_avatar_url": null,
      "relationship_display": "Con trai",
      "content": "Bố nhớ uống thuốc nha!",
      "sent_at": "2026-02-04T07:15:00+07:00",
      "is_read": false
    }
  ],
  "unread_count": 2,
  "total_count": 5
}
```

> **Note:** Response sorted by `sent_at DESC` (newest first)

---

#### 4. Mark As Read (Batch)

| Method | Path | Description | Auth |
|:------:|------|-------------|:----:|
| POST | `/api/v1/encouragements/mark-read` | Batch mark as read | ✅ |

**Request Body:**
```json
{
  "encouragement_ids": [
    "uuid-1",
    "uuid-2",
    "uuid-3"
  ]
}
```

**Response (200 OK):**
```json
{
  "marked_count": 3,
  "message": "Đã đánh dấu đọc"
}
```

**Error Responses:**
| Code | Error | Description |
|:----:|-------|-------------|
| 400 | INVALID_IDS | Empty or invalid ID list |
| 403 | FORBIDDEN | Not your messages |

---

## gRPC Methods (encouragement_service.proto)

### user-service → EncouragementService

```protobuf
service EncouragementService {
  // Create new encouragement (Caregiver)
  rpc CreateEncouragement(CreateEncouragementRequest) returns (EncouragementResponse);
  
  // Get message list (Patient)
  rpc GetEncouragementList(GetEncouragementListRequest) returns (EncouragementListResponse);
  
  // Batch mark as read (Patient)
  rpc MarkAsRead(MarkAsReadRequest) returns (google.protobuf.Empty);
  
  // Get quota info (Caregiver)
  rpc GetQuota(GetQuotaRequest) returns (QuotaResponse);
}
```

---

## Kafka Events

### Encouragement Created Event

**Topic:** `topic-encouragement-created`

**Producer:** user-service  
**Consumer:** schedule-service

**Payload:**
```json
{
  "event_type": "ENCOURAGEMENT_CREATED",
  "encouragement_id": "uuid",
  "sender_id": "uuid",
  "sender_name": "HuyA",
  "patient_id": "uuid",
  "relationship_display": "Con gái",
  "content": "Mẹ ơi, con chúc mẹ ngày mới an lành!",
  "sent_at": "2026-02-04T08:30:00+07:00"
}
```

---

## Push Notification Payload

### Standard Encouragement

```json
{
  "notification": {
    "title": "💬 Lời động viên từ HuyA",
    "body": "Mẹ ơi, con chúc mẹ ngày mới an lành!"
  },
  "data": {
    "type": "ENCOURAGEMENT",
    "encouragement_id": "uuid",
    "deeplink": "kolia://home?show_encouragement=true"
  },
  "android": {
    "priority": "high"
  },
  "apns": {
    "headers": {
      "apns-priority": "10"
    },
    "payload": {
      "aps": {
        "badge": 1,
        "content-available": 1
      }
    }
  }
}
```

---

## API Flow Diagrams

### Create Encouragement Flow

```
┌────────────┐     ┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│   Mobile   │────▶│  API Gateway    │────▶│ user-service │────▶│ schedule-service│
│   (CG)     │     │  POST /enc...   │     │  gRPC        │     │  Kafka          │
└────────────┘     └─────────────────┘     └──────────────┘     └─────────────────┘
                                                  │                     │
                                                  ▼                     ▼
                                           ┌──────────────┐      ┌─────────────┐
                                           │  PostgreSQL  │      │    FCM      │
                                           │  (save)      │      │  (push)     │
                                           └──────────────┘      └─────────────┘
```

---

## Security Considerations

| Aspect | Implementation |
|--------|----------------|
| Authentication | JWT Bearer token validation |
| Authorization | Permission #6 check per request |
| Rate Limiting | 60 req/min per user |
| Input Validation | Content length, XSS sanitization |
| Quota Enforcement | Server-side counting only |

---

## Error Codes Summary

| HTTP | gRPC | Error Code | Description |
|:----:|:----:|------------|-------------|
| 400 | INVALID_ARGUMENT | EMPTY_CONTENT | Content is empty |
| 400 | INVALID_ARGUMENT | CONTENT_TOO_LONG | Content > 150 chars |
| 401 | UNAUTHENTICATED | UNAUTHORIZED | Invalid token |
| 403 | PERMISSION_DENIED | PERMISSION_DENIED | Permission #6 OFF |
| 429 | RESOURCE_EXHAUSTED | QUOTA_EXCEEDED | 10/day limit reached |
| 500 | INTERNAL | INTERNAL_ERROR | Server error |
