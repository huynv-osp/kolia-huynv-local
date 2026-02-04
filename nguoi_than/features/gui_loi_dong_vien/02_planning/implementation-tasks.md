# Implementation Tasks: US 1.3 - Gửi Lời Động Viên

> **Phase:** 5 - Task Generation  
> **Date:** 2026-02-04  
> **Total Tasks:** 15  
> **Total Effort:** 54 hours

---

## Task Summary by Service

| Service | Tasks | Effort | Priority |
|---------|:-----:|:------:|:--------:|
| user-service | 6 | 24h | P0-P1 |
| api-gateway | 3 | 10h | P1 |
| schedule-service | 2 | 4h | P1 |
| Mobile App | 4 | 16h | P1-P2 |

---

## Phase 1: Database & Proto (6h)

### Task: DB-001 - Create encouragement_messages Table

**Service:** user-service  
**Priority:** P0 - Blocker  
**Estimated:** 2h  
**Dependencies:** None

#### Description
Create database migration for the encouragement_messages table with all columns, constraints, and indexes.

#### Technical Scope
- [ ] Migration file `V2026.02.04.1__create_encouragement_messages.sql`
- [ ] Table with 14 columns
- [ ] 4 indexes (patient_unread, patient_recent, quota, sender)
- [ ] Constraints (content_length, different_users)
- [ ] Trigger for updated_at

#### Acceptance Criteria
- [ ] Migration runs successfully
- [ ] All indexes created
- [ ] Constraints enforced

---

### Task: PROTO-001 - Define EncouragementService Proto

**Service:** user-service  
**Priority:** P0 - Blocker  
**Estimated:** 2h  
**Dependencies:** None

#### Description
Create gRPC proto definition for EncouragementService with 4 RPC methods.

#### Technical Scope
- [ ] File: `src/main/proto/encouragement_service.proto`
- [ ] RPC: CreateEncouragement, GetEncouragementList, MarkAsRead, GetQuota
- [ ] Messages: Request/Response for each method
- [ ] Sync to api-gateway-service

#### API Contract
```protobuf
service EncouragementService {
  rpc CreateEncouragement(CreateEncouragementRequest) returns (EncouragementResponse);
  rpc GetEncouragementList(GetEncouragementListRequest) returns (EncouragementListResponse);
  rpc MarkAsRead(MarkAsReadRequest) returns (google.protobuf.Empty);
  rpc GetQuota(GetQuotaRequest) returns (QuotaResponse);
}
```

---

### Task: PROTO-002 - Sync Proto to API Gateway

**Service:** api-gateway-service  
**Priority:** P0 - Blocker  
**Estimated:** 1h  
**Dependencies:** PROTO-001

#### Description
Copy proto file to api-gateway-service and generate gRPC stubs.

#### Technical Scope
- [ ] Copy proto to `api-gateway-service/src/main/proto/user/`
- [ ] Run protoc compile
- [ ] Verify stub generation

---

## Phase 2: user-service Core (16h)

### Task: ENTITY-001 - Create EncouragementMessage Entity

**Service:** user-service  
**Priority:** P0  
**Estimated:** 3h  
**Dependencies:** DB-001

#### Description
Create JPA entity for encouragement_messages table.

#### Technical Scope
- [ ] File: `entity/EncouragementMessage.java`
- [ ] All 14 fields with JPA annotations
- [ ] Relationships to User entities
- [ ] Builder pattern

---

### Task: REPO-001 - Create EncouragementRepository

**Service:** user-service  
**Priority:** P0  
**Estimated:** 3h  
**Dependencies:** ENTITY-001

#### Description
Create repository with custom queries for quota check, unread list, etc.

#### Technical Scope
- [ ] File: `repository/EncouragementRepository.java`
- [ ] Query: countTodayByPatient (quota)
- [ ] Query: findByPatientUnread24h (patient modal)
- [ ] Query: batchMarkRead

---

### Task: SVC-001 - Create EncouragementService

**Service:** user-service  
**Priority:** P0  
**Estimated:** 6h  
**Dependencies:** REPO-001

#### Description
Implement business logic for encouragement messages.

#### Technical Scope
- [ ] Interface: `service/EncouragementService.java`
- [ ] Impl: `service/impl/EncouragementServiceImpl.java`
- [ ] Method: createEncouragement (permission check, quota check, save, Kafka)
- [ ] Method: getEncouragementList (24h filter)
- [ ] Method: markAsRead (batch update)
- [ ] Method: getQuota (count today)

#### Business Rules
- [ ] BR-001: Quota 10/day
- [ ] BR-002: Content ≤150 chars
- [ ] BR-003: Permission #6 check

---

### Task: GRPC-001 - Create gRPC Handler

**Service:** user-service  
**Priority:** P0  
**Estimated:** 4h  
**Dependencies:** SVC-001, PROTO-001

#### Description
Implement gRPC handler that delegates to EncouragementService.

#### Technical Scope
- [ ] File: `handler/EncouragementServiceGrpcImpl.java`
- [ ] Implement 4 RPC methods
- [ ] Register in GrpcServerConfig
- [ ] Error handling (INVALID_ARGUMENT, PERMISSION_DENIED, RESOURCE_EXHAUSTED)

---

## Phase 3: api-gateway-service (10h)

### Task: CLIENT-001 - Create gRPC Client

**Service:** api-gateway-service  
**Priority:** P1  
**Estimated:** 3h  
**Dependencies:** PROTO-002

#### Description
Create gRPC client stub for EncouragementService.

#### Technical Scope
- [ ] File: `client/EncouragementServiceClient.java`
- [ ] Method: createEncouragement, getList, markRead, getQuota
- [ ] Channel management
- [ ] Timeout configuration (5s)

---

### Task: HANDLER-001 - Create REST Handler

**Service:** api-gateway-service  
**Priority:** P1  
**Estimated:** 5h  
**Dependencies:** CLIENT-001

#### Description
Create REST handler for 4 endpoints.

#### Technical Scope
- [ ] File: `handler/EncouragementHandler.java`
- [ ] POST /api/v1/encouragements
- [ ] GET /api/v1/encouragements
- [ ] POST /api/v1/encouragements/mark-read
- [ ] GET /api/v1/encouragements/quota
- [ ] DTOs: CreateRequest, MarkReadRequest, Response classes

---

### Task: ROUTE-001 - Configure Routes

**Service:** api-gateway-service  
**Priority:** P1  
**Estimated:** 2h  
**Dependencies:** HANDLER-001

#### Description
Add routes to RouteConfig and Swagger documentation.

#### Technical Scope
- [ ] Modify: `config/RouteConfig.java`
- [ ] Add 4 routes with auth middleware
- [ ] Swagger: `swagger/encouragement.yaml`

---

## Phase 4: schedule-service (4h)

### Task: KAFKA-001 - Create Kafka Consumer

**Service:** schedule-service  
**Priority:** P1  
**Estimated:** 2h  
**Dependencies:** SVC-001

#### Description
Create Kafka consumer for encouragement events.

#### Technical Scope
- [ ] File: `consumers/encouragement_consumer.py`
- [ ] Subscribe: `topic-encouragement-created`
- [ ] Parse event, call push task

---

### Task: PUSH-001 - Create Push Notification Task

**Service:** schedule-service  
**Priority:** P1  
**Estimated:** 2h  
**Dependencies:** KAFKA-001

#### Description
Create Celery task to send FCM push notification.

#### Technical Scope
- [ ] File: `tasks/encouragement/send_notification.py`
- [ ] Template: `constants/encouragement_templates.py`
- [ ] FCM payload with deeplink
- [ ] Error handling, retry

---

## Phase 5: Mobile App (16h)

### Task: MOBILE-001 - Create Store & Service

**Service:** Mobile App  
**Priority:** P1  
**Estimated:** 4h  
**Dependencies:** ROUTE-001

#### Description
Create Zustand store and API service.

#### Technical Scope
- [ ] File: `stores/encouragementStore.ts`
- [ ] File: `services/encouragement.service.ts`
- [ ] File: `types/encouragement.types.ts`
- [ ] Methods: send, getList, markRead, getQuota

---

### Task: MOBILE-002 - Create Caregiver Widget

**Service:** Mobile App  
**Priority:** P1  
**Estimated:** 6h  
**Dependencies:** MOBILE-001

#### Description
Create compose widget for Caregiver to send messages.

#### Technical Scope
- [ ] File: `components/encouragement/EncouragementWidget.tsx`
- [ ] TextInput with 150 char limit
- [ ] CharCounter component
- [ ] Send button (disabled when empty)
- [ ] Quota display

---

### Task: MOBILE-003 - Create Patient Modal

**Service:** Mobile App  
**Priority:** P1  
**Estimated:** 4h  
**Dependencies:** MOBILE-001

#### Description
Create modal for Patient to view encouragement messages.

#### Technical Scope
- [ ] File: `components/encouragement/EncouragementModal.tsx`
- [ ] File: `components/encouragement/EncouragementCard.tsx`
- [ ] 24h window display
- [ ] Mark all as read on close
- [ ] Empty state

---

### Task: MOBILE-004 - Push Handling

**Service:** Mobile App  
**Priority:** P2  
**Estimated:** 2h  
**Dependencies:** MOBILE-003

#### Description
Handle push notification deeplink.

#### Technical Scope
- [ ] Modify: `navigation/DeepLinkHandler.ts`
- [ ] Handle `kolia://home?show_encouragement=true`
- [ ] Open modal on push tap

---

## Next Phase

➡️ Proceed to Phase 6: Dependency & Sequence Planning
