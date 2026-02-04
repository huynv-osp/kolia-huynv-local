# Service Decomposition: US 1.3 - Gửi Lời Động Viên

> **Phase:** 4 - Service Decomposition  
> **Date:** 2026-02-04  
> **SA Reference:** [service_mapping.md](../../sa-analysis/gui_loi_dong_vien/04_mapping/service_mapping.md)

---

## 1. Service Ownership Summary

| Service | Responsibility | Impact Level |
|---------|----------------|:------------:|
| **user-service** | Business logic, DB, Kafka producer | 🟡 MEDIUM |
| **api-gateway-service** | REST endpoints, gRPC client | 🟡 MEDIUM |
| **schedule-service** | Push notification | 🟢 LOW |
| **Mobile App** | UI components | 🟡 MEDIUM |

---

## 2. user-service (FA-002)

### Impact Level: 🟡 MEDIUM
### Estimated Effort: 24 hours

### 2.1 Detailed Changes

| Layer | File Path | Type | Description |
|-------|-----------|:----:|-------------|
| Proto | `src/main/proto/encouragement_service.proto` | NEW | 4 gRPC methods |
| Entity | `entity/EncouragementMessage.java` | NEW | Domain object |
| Repository | `repository/EncouragementRepository.java` | NEW | Data access layer |
| Service | `service/EncouragementService.java` | NEW | Service interface |
| Service | `service/impl/EncouragementServiceImpl.java` | NEW | Business logic |
| Handler | `handler/EncouragementServiceGrpcImpl.java` | NEW | gRPC endpoint |
| Kafka | `kafka/EncouragementKafkaProducer.java` | NEW | Event publisher |
| DTO | `dto/EncouragementMessageDto.java` | NEW | Transfer object |
| Config | `config/GrpcServerConfig.java` | MODIFY | Register service |
| Constant | `constant/ErrorCodes.java` | MODIFY | Add error codes |

### 2.2 Proto Definition

```protobuf
service EncouragementService {
  rpc CreateEncouragement(CreateEncouragementRequest) returns (EncouragementResponse);
  rpc GetEncouragementList(GetEncouragementListRequest) returns (EncouragementListResponse);
  rpc MarkAsRead(MarkAsReadRequest) returns (google.protobuf.Empty);
  rpc GetQuota(GetQuotaRequest) returns (QuotaResponse);
}
```

### 2.3 Database Changes

| Table | Change | Details |
|-------|:------:|---------|
| `encouragement_messages` | CREATE | 14 columns, 4 indexes |

### 2.4 Integration Points

| Service | Protocol | Method | Purpose |
|---------|:--------:|--------|---------|
| api-gateway | gRPC | All 4 methods | Receive requests |
| schedule-service | Kafka | Publish event | Trigger push |
| PostgreSQL | SQL | CRUD | Data persistence |

---

## 3. api-gateway-service (FA-002 + FA-003)

### Impact Level: 🟡 MEDIUM
### Estimated Effort: 10 hours

> ⚠️ **ARCH-001 Compliance**: This service only handles REST→gRPC forwarding.  
> No business logic, no database access.

### 3.1 Detailed Changes

| Layer | File Path | Type | Description |
|-------|-----------|:----:|-------------|
| Handler | `handler/EncouragementHandler.java` | NEW | 4 REST endpoints |
| Client | `client/EncouragementServiceClient.java` | NEW | gRPC client stub |
| DTO | `dto/request/CreateEncouragementRequest.java` | NEW | POST body |
| DTO | `dto/request/MarkAsReadRequest.java` | NEW | Batch read body |
| DTO | `dto/response/EncouragementResponse.java` | NEW | Create response |
| DTO | `dto/response/QuotaResponse.java` | NEW | Quota response |
| Config | `config/RouteConfig.java` | MODIFY | Add 4 routes |

### 3.2 Endpoints

| Method | Path | Handler Method |
|:------:|------|----------------|
| POST | `/api/v1/encouragements` | `createEncouragement()` |
| GET | `/api/v1/encouragements` | `getEncouragementList()` |
| POST | `/api/v1/encouragements/mark-read` | `markAsRead()` |
| GET | `/api/v1/encouragements/quota` | `getQuota()` |

### 3.3 Integration Points

| Service | Protocol | Method | Purpose |
|---------|:--------:|--------|---------|
| user-service | gRPC | 4 methods | Business logic |

---

## 4. schedule-service (FA-002)

### Impact Level: 🟢 LOW
### Estimated Effort: 4 hours

### 4.1 Detailed Changes

| Layer | File Path | Type | Description |
|-------|-----------|:----:|-------------|
| Consumer | `consumers/encouragement_consumer.py` | NEW | Kafka listener |
| Task | `tasks/encouragement/send_notification.py` | NEW | Celery task |
| Template | `constants/encouragement_templates.py` | NEW | FCM payloads |

### 4.2 Kafka Consumer

```python
# Topic: topic-encouragement-created
{
    "event_type": "ENCOURAGEMENT_CREATED",
    "encouragement_id": "uuid",
    "sender_name": "HuyA",
    "patient_id": "uuid",
    "relationship_display": "Con gái",
    "content": "Mẹ ơi..."
}
```

### 4.3 Push Notification Template

```python
{
    "notification": {
        "title": "💬 Lời động viên từ {sender_name}",
        "body": "{content}"
    },
    "data": {
        "type": "ENCOURAGEMENT",
        "encouragement_id": "{id}",
        "deeplink": "kolia://home?show_encouragement=true"
    }
}
```

---

## 5. Mobile App (FA-002)

### Impact Level: 🟡 MEDIUM
### Estimated Effort: 16 hours

### 5.1 Detailed Changes

| Layer | File Path | Type | Description |
|-------|-----------|:----:|-------------|
| Store | `stores/encouragementStore.ts` | NEW | Zustand state |
| Service | `services/encouragement.service.ts` | NEW | API client |
| Types | `types/encouragement.types.ts` | NEW | TypeScript types |
| Widget | `components/encouragement/EncouragementWidget.tsx` | NEW | Caregiver compose |
| Modal | `components/encouragement/EncouragementModal.tsx` | NEW | Patient view |
| Card | `components/encouragement/EncouragementCard.tsx` | NEW | List item |
| Hook | `hooks/useEncouragement.ts` | NEW | React hook |
| Screen | `screens/PatientDashboard.tsx` | MODIFY | Add widget |
| Nav | `navigation/DeepLinkHandler.ts` | MODIFY | Handle push |

### 5.2 Component Hierarchy

```
PatientDashboard.tsx
└── EncouragementWidget.tsx (Caregiver)
    ├── AIChips.tsx ⏸️ DEFERRED
    ├── TextInput (150 chars)
    ├── CharCounter.tsx
    └── SendButton.tsx

HomeScreen.tsx
└── EncouragementModal.tsx (Patient)
    └── EncouragementCard.tsx (list)
```

---

## 6. Summary

| Service | Files | Lines (est.) | Hours |
|---------|:-----:|:------------:|:-----:|
| user-service | 10 | ~800 | 24h |
| api-gateway | 7 | ~400 | 10h |
| schedule-service | 3 | ~150 | 4h |
| Mobile App | 9 | ~600 | 16h |
| **Total** | **29** | **~1950** | **54h** |

---

## Next Phase

➡️ Proceed to Phase 5: Task Generation
