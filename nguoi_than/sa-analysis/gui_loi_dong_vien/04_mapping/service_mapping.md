# Service Mapping: US 1.3 - Gửi Lời Động Viên

> **Phase:** 4 - Architecture Mapping & Analysis  
> **Date:** 2026-02-04  
> **Revision:** v1.0  
> **Source:** SRS-Gửi-Lời-Động-Viên_v1.3  
> **Applies Rule:** SA-002 (Service-Level Impact Detailing)

---

## Service: user-service

### Impact Level: 🟡 MEDIUM

### Code Changes Required

| Layer | File | Type | Description |
|-------|------|:----:|-------------|
| Proto | `proto/encouragement_service.proto` | NEW | 4 gRPC methods |
| Entity | `entity/EncouragementMessage.java` | NEW | Message entity |
| Repository | `repository/EncouragementRepository.java` | NEW | Data access |
| Service | `service/EncouragementService.java` | NEW | Interface |
| Service | `service/impl/EncouragementServiceImpl.java` | NEW | Implementation |
| Handler | `handler/EncouragementServiceGrpcImpl.java` | NEW | gRPC handler |
| Producer | `kafka/EncouragementKafkaProducer.java` | NEW | Push notification event |
| DTO | `dto/request/CreateEncouragementRequest.java` | NEW | Create request |
| DTO | `dto/request/MarkEncouragementReadRequest.java` | NEW | Batch mark read |
| DTO | `dto/response/EncouragementInfo.java` | NEW | Message info |
| DTO | `dto/response/QuotaInfo.java` | NEW | Quota status |
| Constants | `constants/EncouragementConstants.java` | NEW | Quota limits |

### gRPC Methods (encouragement_service.proto)

| RPC | Request | Response | Description |
|-----|---------|----------|-------------|
| CreateEncouragement | CreateEncouragementRequest | EncouragementResponse | Tạo lời động viên |
| GetEncouragementList | GetEncouragementListRequest | EncouragementListResponse | Lấy list (Patient view, 24h) |
| MarkAsRead | MarkAsReadRequest | Empty | Batch mark IDs as read |
| GetQuota | GetQuotaRequest | QuotaResponse | Check remaining quota |

### Proto Definition (4 methods)

```protobuf
syntax = "proto3";
package alio.user.encouragement;

import "google/protobuf/empty.proto";

service EncouragementService {
  rpc CreateEncouragement(CreateEncouragementRequest) returns (EncouragementResponse);
  rpc GetEncouragementList(GetEncouragementListRequest) returns (EncouragementListResponse);
  rpc MarkAsRead(MarkAsReadRequest) returns (google.protobuf.Empty);
  rpc GetQuota(GetQuotaRequest) returns (QuotaResponse);
}

message CreateEncouragementRequest {
  string sender_id = 1;       // Caregiver UUID
  string patient_id = 2;      // Patient UUID
  string contact_id = 3;      // Connection UUID
  string content = 4;         // Max 150 chars
}

message EncouragementResponse {
  string encouragement_id = 1;
  int32 remaining_quota = 2;  // Quota còn lại
  string message = 3;         // Success message
}

message GetEncouragementListRequest {
  string patient_id = 1;
  bool unread_only = 2;       // Default true for modal
  int32 hours = 3;            // Default 24
}

message EncouragementListResponse {
  repeated EncouragementInfo messages = 1;
  int32 unread_count = 2;
  int32 total_count = 3;
}

message EncouragementInfo {
  string encouragement_id = 1;
  string sender_id = 2;
  string sender_name = 3;     // e.g., "HuyA"
  string relationship_display = 4;  // e.g., "Con gái" (Patient's perspective)
  string content = 5;
  int64 sent_at = 6;          // Epoch millis
  bool is_read = 7;
}

message MarkAsReadRequest {
  string patient_id = 1;
  repeated string encouragement_ids = 2;  // Batch IDs
}

message GetQuotaRequest {
  string sender_id = 1;
  string patient_id = 2;
}

message QuotaResponse {
  int32 remaining = 1;        // 0-10
  int32 limit = 2;            // 10
  int64 reset_at = 3;         // Next midnight epoch
}
```

### Database Changes

| Table | Change | Details |
|-------|:------:|---------| 
| encouragement_messages | CREATE | 12 columns, 3 indexes |

### Integration Points

| Service | Protocol | Purpose |
|---------|----------|---------|
| schedule-service | Kafka | Push notification event |
| connection_permissions | Internal | Permission check |

### Business Logic

1. **Permission Check (BR-003):**
   ```java
   boolean hasPermission = connectionPermissionRepository
       .checkPermission(contactId, "encouragement");
   if (!hasPermission) throw new ForbiddenException("PERMISSION_DENIED");
   ```

2. **Quota Check (BR-001):**
   ```java
   int todayCount = encouragementRepository
       .countByPatientAndDate(patientId, LocalDate.now());
   if (todayCount >= 10) throw new LimitExceededException("QUOTA_EXCEEDED");
   ```

3. **Content Validation (BR-002):**
   ```java
   if (content.isEmpty()) throw new BadRequestException("EMPTY_CONTENT");
   if (content.length() > 150) throw new BadRequestException("CONTENT_TOO_LONG");
   ```

### Estimated Effort: 24 hours

---

## Service: api-gateway-service

### Impact Level: 🟡 MEDIUM

### Code Changes Required

| Layer | File | Type | Description |
|-------|------|:----:|-------------|
| Handler | `handler/EncouragementHandler.java` | NEW | REST endpoints |
| Client | `client/EncouragementServiceClient.java` | NEW | gRPC client |
| DTO | `dto/request/CreateEncouragementRequest.java` | NEW | Create DTO |
| DTO | `dto/request/MarkAsReadRequest.java` | NEW | Mark read DTO |
| DTO | `dto/response/EncouragementListResponse.java` | NEW | List response |
| DTO | `dto/response/QuotaResponse.java` | NEW | Quota response |
| Config | `RouteConfig.java` | MODIFY | Add 4 routes |

### REST Endpoints

| Method | Path | Description | Auth |
|:------:|------|-------------|:----:|
| POST | `/api/v1/encouragements` | Gửi lời động viên | ✅ |
| GET | `/api/v1/encouragements` | List messages (24h) | ✅ |
| POST | `/api/v1/encouragements/mark-read` | Batch mark as read | ✅ |
| GET | `/api/v1/encouragements/quota` | Check quota | ✅ |

### Gateway Compliance (ARCH-001)

```
✅ COMPLIANT - No business logic in gateway
   - handler/    ✅ REST forwarding
   - dto/        ✅ Request/Response mapping
   - client/     ✅ gRPC client
   
❌ NOT PRESENT (as expected):
   - service/    ✅ Not added
   - repository/ ✅ Not added
   - entity/     ✅ Not added
```

### Estimated Effort: 10 hours

---

## Service: agents-service [⏸️ DEFERRED]

> **Status:** Scope removed - AI Suggestions deferred to future release

---

## Service: schedule-service

### Impact Level: 🟢 LOW

### Code Changes Required

| Layer | File | Type | Description |
|-------|------|:----:|-------------|
| Consumer | `kafka/encouragement_consumer.py` | NEW | Event consumer |
| Task | `tasks/send_encouragement_notification.py` | NEW | Push task |
| Templates | `templates/encouragement.py` | NEW | Push templates |

### Kafka Topics

| Topic | Direction | Purpose |
|-------|:---------:|---------| 
| topic-encouragement-created | IN | Receive new message event |

### Push Notification Template

```python
ENCOURAGEMENT_TEMPLATE = {
    "title": "💬 Lời động viên từ {sender_name}",
    "body": "{content_preview}...",
    "data": {
        "type": "ENCOURAGEMENT",
        "encouragement_id": "{id}",
        "deeplink": "kolia://home?show_encouragement=true"
    }
}
```

### Estimated Effort: 4 hours

---

## Service: Mobile App (React Native)

### Impact Level: 🟡 MEDIUM

### Code Changes Required

| Layer | File | Type | Description |
|-------|------|:----:|-------------|
| Component | `EncouragementWidget.tsx` | NEW | Send widget |
| Component | `SuggestionChips.tsx` | NEW | AI chips |
| Component | `EncouragementModal.tsx` | NEW | Patient modal |
| Hook | `useEncouragement.ts` | NEW | API integration |
| Store | `encouragementStore.ts` | NEW | State management |
| Service | `encouragementService.ts` | NEW | API client |

### UI Components

| Screen/Component | Complexity | New Components |
|------------------|:----------:|----------------|
| SCR-ENG-01 (Widget) | Medium | EncouragementWidget, SuggestionChips, CharCounter |
| Patient Modal | Medium | EncouragementModal, MessageList |

### Estimated Effort: 16 hours

---

## Summary

| Service | Impact | Files | Effort |
|---------|:------:|:-----:|:------:|
| user-service | 🟡 MEDIUM | ~12 | 24h |
| api-gateway-service | 🟡 MEDIUM | ~7 | 10h |
| agents-service | ⏸️ DEFERRED | - | - |
| schedule-service | 🟢 LOW | ~3 | 4h |
| Mobile App | 🟡 MEDIUM | ~6 | 16h |
| **Total** | | **~28** | **54h** |

---

## Cross-Feature Dependencies

| Feature | Dependency Type | Data/Events |
|---------|----------------|-------------|
| Kết nối Người thân | Read connections | contact_id, permission #6 |
| User Profile | Read user info | patient name, feeling |
| Medication Schedule | Read pending tasks | For AI context |
| BP Schedule | Read pending tasks | For AI context |
