# Implementation Tasks: KOLIA-1517 - Kết nối Người thân

> **Feature:** Connection Flow (Patient ↔ Caregiver)  
> **Version:** v2.7 - Added Profile Selection  
> **Total Tasks:** 35  
> **Estimated Effort:** 75 hours

---

## Task Dependencies Graph

```
DB-001 ──▶ ENTITY-001~004 ──▶ REPO-001~003 ──▶ SVC-001~003 ──┐
                                                              │
PROTO-001 ──▶ PROTO-002 ──▶ CLIENT-001 ─────────────────────┤
                                                              ▼
                                              HANDLER-001 ──▶ GW-HANDLER-001~002 ──▶ TEST-001~003
                                                              │
KAFKA-001 ──▶ SCHED-001~002 ◄─────────────────────────────────┘
```

---

## Phase 1: Database & Core Entities

### DB-001: Database Migration Script
| Field | Value |
|-------|-------|
| **Service** | database |
| **Priority** | P0 - Critical |
| **Estimated** | 2h |
| **Dependencies** | None |

**Description:**
Tạo migration script cho 4 tables mới: `connection_invites`, `user_connections`, `connection_permissions`, `invite_notifications`.

**Files:**
- `api-gateway-service/database/migrations/v12_connection_flow.sql`

**Acceptance Criteria:**
- [ ] Migration chạy thành công không lỗi
- [ ] Rollback script hoạt động
- [ ] Indexes được tạo đúng

---

### ENTITY-001: ConnectionInvite Entity
| Field | Value |
|-------|-------|
| **Service** | user-service |
| **Priority** | P0 |
| **Estimated** | 1h |
| **Dependencies** | DB-001 |

**Description:**
JPA Entity cho table `connection_invites` với các fields: sender_id, receiver_phone, receiver_id, receiver_name, invite_type, relationship, initial_permissions, status.

**Files:**
- `user-service/src/main/java/com/company/userservice/entity/ConnectionInvite.java`

**Acceptance Criteria:**
- [ ] Entity mapping đúng với DB schema
- [ ] Enum types cho invite_type và relationship
- [ ] JSONB mapping cho initial_permissions

---

### ENTITY-002: UserConnection Entity
| Field | Value |
|-------|-------|
| **Service** | user-service |
| **Priority** | P0 |
| **Estimated** | 1h |
| **Dependencies** | DB-001 |

**Description:**
JPA Entity cho table `user_connections` với patient_id, caregiver_id, relationship, status, created_from_invite_id.

**Files:**
- `user-service/src/main/java/com/company/userservice/entity/UserConnection.java`

---

### ENTITY-003: ConnectionPermission Entity
| Field | Value |
|-------|-------|
| **Service** | user-service |
| **Priority** | P0 |
| **Estimated** | 1h |
| **Dependencies** | DB-001, ENTITY-002 |

**Description:**
JPA Entity cho table `connection_permissions` với connection_id, permission_type, is_enabled.

**Files:**
- `user-service/src/main/java/com/company/userservice/entity/ConnectionPermission.java`

---

### ENTITY-004: InviteNotification Entity
| Field | Value |
|-------|-------|
| **Service** | user-service |
| **Priority** | P1 |
| **Estimated** | 1h |
| **Dependencies** | DB-001, ENTITY-001 |

**Description:**
JPA Entity cho table `invite_notifications` để tracking ZNS/SMS delivery.

**Files:**
- `user-service/src/main/java/com/company/userservice/entity/InviteNotification.java`

---

## Phase 1: Repositories

### REPO-001: ConnectionInviteRepository
| Field | Value |
|-------|-------|
| **Service** | user-service |
| **Priority** | P0 |
| **Estimated** | 2h |
| **Dependencies** | ENTITY-001 |

**Description:**
Repository interface với các methods:
- `findBySenderIdAndStatus(UUID, InviteStatus)`
- `findByReceiverIdAndStatus(UUID, InviteStatus)`
- `findByReceiverPhoneAndStatus(String, InviteStatus)`
- `existsPendingInvite(UUID senderId, String receiverPhone)`

**Files:**
- `user-service/src/main/java/com/company/userservice/repository/ConnectionInviteRepository.java`

---

### REPO-002: UserConnectionRepository
| Field | Value |
|-------|-------|
| **Service** | user-service |
| **Priority** | P0 |
| **Estimated** | 2h |
| **Dependencies** | ENTITY-002 |

**Description:**
Repository với methods:
- `findByPatientIdAndStatus(UUID, ConnectionStatus)`
- `findByCaregiverIdAndStatus(UUID, ConnectionStatus)`
- `existsActiveConnection(UUID patientId, UUID caregiverId)`

**Files:**
- `user-service/src/main/java/com/company/userservice/repository/UserConnectionRepository.java`

---

### REPO-003: ConnectionPermissionRepository
| Field | Value |
|-------|-------|
| **Service** | user-service |
| **Priority** | P0 |
| **Estimated** | 1h |
| **Dependencies** | ENTITY-003 |

**Description:**
Repository với methods:
- `findByConnectionId(UUID)`
- `findByConnectionIdAndPermissionType(UUID, PermissionType)`

**Files:**
- `user-service/src/main/java/com/company/userservice/repository/ConnectionPermissionRepository.java`

---

## Phase 1: Proto & gRPC

### PROTO-001: ConnectionService Proto Definition
| Field | Value |
|-------|-------|
| **Service** | user-service |
| **Priority** | P0 |
| **Estimated** | 2h |
| **Dependencies** | None |

**Description:**
Proto file định nghĩa:
- Messages: CreateInviteRequest, AcceptInviteRequest, ListConnectionsRequest, UpdatePermissionsRequest, etc.
- Service: ConnectionService với 12 RPC methods (incl. GetViewingPatient, SetViewingPatient)

**Files:**
- `user-service/src/main/proto/connection_service.proto`

**API Contract:**
```protobuf
service ConnectionService {
  rpc CreateInvite(CreateInviteRequest) returns (InviteResponse);
  rpc GetInvite(GetInviteRequest) returns (InviteResponse);
  rpc ListInvites(ListInvitesRequest) returns (ListInvitesResponse);
  rpc AcceptInvite(AcceptInviteRequest) returns (ConnectionResponse);
  rpc RejectInvite(RejectInviteRequest) returns (InviteResponse);
  rpc ListConnections(ListConnectionsRequest) returns (ListConnectionsResponse);
  rpc Disconnect(DisconnectRequest) returns (ConnectionResponse);
  rpc GetPermissions(GetPermissionsRequest) returns (PermissionsResponse);
  rpc UpdatePermissions(UpdatePermissionsRequest) returns (PermissionsResponse);
  // Profile Selection (v2.7)
  rpc GetViewingPatient(GetViewingPatientRequest) returns (ViewingPatientResponse);
  rpc SetViewingPatient(SetViewingPatientRequest) returns (ViewingPatientResponse);
}
```

---

### PROTO-002: Proto Compilation
| Field | Value |
|-------|-------|
| **Service** | user-service, api-gateway |
| **Priority** | P0 |
| **Estimated** | 1h |
| **Dependencies** | PROTO-001 |

**Description:**
Compile proto và copy generated files sang api-gateway-service.

**Commands:**
```bash
cd user-service && mvn clean generate-sources
cp -r target/generated-sources/protobuf ../api-gateway-service/src/main/proto-generated/
```

---

## Phase 1: Service Layer

### SVC-001: InviteService
| Field | Value |
|-------|-------|
| **Service** | user-service |
| **Priority** | P0 |
| **Estimated** | 4h |
| **Dependencies** | REPO-001, ENTITY-001 |

**Description:**
Business logic cho invite lifecycle:
- `createInvite()`: Validation (BR-006, BR-007), create record, publish Kafka event
- `getInvite()`: Fetch by ID
- `listInvites()`: List sent/received with filters
- `rejectInvite()`: Update status to rejected
- `cancelInvite()`: Cancel pending invite (sender only)

**Files:**
- `user-service/src/main/java/com/company/userservice/service/InviteService.java`

**Business Rules:**
- BR-006: No self-invite
- BR-007: No duplicate pending invite

---

### SVC-002: ConnectionService
| Field | Value |
|-------|-------|
| **Service** | user-service |
| **Priority** | P0 |
| **Estimated** | 4h |
| **Dependencies** | REPO-002, SVC-001, SVC-003 |

**Description:**
Business logic cho connection:
- `acceptInvite()`: Transaction - create connection + 6 permissions + update invite
- `listConnections()`: Group by role (patients vs caregivers)
- `disconnect()`: Update status, publish Kafka event

**Files:**
- `user-service/src/main/java/com/company/userservice/service/ConnectionServiceImpl.java`

---

### SVC-003: PermissionService
| Field | Value |
|-------|-------|
| **Service** | user-service |
| **Priority** | P0 |
| **Estimated** | 3h |
| **Dependencies** | REPO-003, ENTITY-003 |

**Description:**
RBAC permission management:
- `createDefaultPermissions()`: Create 6 permissions with default ON
- `getPermissions()`: Get current permission flags
- `updatePermissions()`: Toggle flags, publish Kafka event

**Files:**
- `user-service/src/main/java/com/company/userservice/service/PermissionService.java`

---

### SVC-004: ViewingPatientService (NEW v2.7)
| Field | Value |
|-------|-------|
| **Service** | user-service |
| **Priority** | P0 |
| **Estimated** | 3h |
| **Dependencies** | REPO-002 |

**Description:**
Profile selection management (BR-026):
- `getViewingPatient()`: Get currently selected patient from is_viewing=true
- `setViewingPatient()`: Update is_viewing flags (transaction: clear old + set new)

**Files:**
- `user-service/src/main/java/com/company/userservice/service/ViewingPatientService.java`
- `user-service/src/main/java/com/company/userservice/repository/ViewingPatientRepository.java`

**Database:**
- Read/Write `user_emergency_contacts.is_viewing`
- Unique constraint: Only 1 row per user can have `is_viewing=true`

**Business Rules:**
- Validate connection_id belongs to user's monitoring[] list
- Auto-clear previous selection on new selection

---

### HANDLER-001: ConnectionHandler (gRPC)
| Field | Value |
|-------|-------|
| **Service** | user-service |
| **Priority** | P0 |
| **Estimated** | 3h |
| **Dependencies** | SVC-001, SVC-002, SVC-003 |

**Description:**
gRPC handler implementing ConnectionService proto interface.

**Files:**
- `user-service/src/main/java/com/company/userservice/handler/ConnectionHandler.java`

---

## Phase 1: API Gateway

### CLIENT-001: ConnectionServiceClient
| Field | Value |
|-------|-------|
| **Service** | api-gateway-service |
| **Priority** | P0 |
| **Estimated** | 2h |
| **Dependencies** | PROTO-002 |

**Description:**
gRPC client để call user-service ConnectionService.

**Files:**
- `api-gateway-service/src/main/java/com/company/apiservice/client/ConnectionServiceClient.java`

---

### GW-HANDLER-001: InviteHandler (REST)
| Field | Value |
|-------|-------|
| **Service** | api-gateway-service |
| **Priority** | P0 |
| **Estimated** | 3h |
| **Dependencies** | CLIENT-001 |

**Description:**
REST endpoints:
- POST `/api/v1/invites`
- GET `/api/v1/invites`
- POST `/api/v1/invites/{id}/accept`
- POST `/api/v1/invites/{id}/reject`

**Files:**
- `api-gateway-service/src/main/java/com/company/apiservice/handler/InviteHandler.java`

---

### GW-HANDLER-002: ConnectionHandler (REST)
| Field | Value |
|-------|-------|
| **Service** | api-gateway-service |
| **Priority** | P0 |
| **Estimated** | 3h |
| **Dependencies** | CLIENT-001 |

**Description:**
REST endpoints:
- GET `/api/v1/connections`
- DELETE `/api/v1/connections/{id}`
- GET `/api/v1/connections/{id}/permissions`
- PUT `/api/v1/connections/{id}/permissions`
- GET `/api/v1/connection/permission-types`
- GET `/api/v1/connections/viewing` (NEW v2.7)
- PUT `/api/v1/connections/viewing` (NEW v2.7)

**Files:**
- `api-gateway-service/src/main/java/com/company/apiservice/handler/ConnectionHandler.java`

---

## Phase 2: Async & Notifications

### KAFKA-001: Kafka Producer Setup
| Field | Value |
|-------|-------|
| **Service** | user-service |
| **Priority** | P1 |
| **Estimated** | 2h |
| **Dependencies** | SVC-001, SVC-002, SVC-003 |

**Description:**
Configure Kafka producer cho 3 topics:
- `connection.invite.created`
- `connection.status.changed`
- `connection.permission.changed`

**Files:**
- `user-service/src/main/java/com/company/userservice/config/KafkaProducerConfig.java`
- `user-service/src/main/java/com/company/userservice/event/ConnectionEvent.java`

---

### SCHED-001: Invite Notification Task
| Field | Value |
|-------|-------|
| **Service** | schedule-service |
| **Priority** | P1 |
| **Estimated** | 4h |
| **Dependencies** | KAFKA-001 |

**Description:**
Celery task xử lý:
- Consume `connection.invite.created`
- Send ZNS/Push notification
- Fallback to SMS if ZNS fails (3x retry, 30s interval)

**Files:**
- `schedule-service/schedule_service/tasks/connection/invite_notification.py`

---

### SCHED-002: Connection Notification Task
| Field | Value |
|-------|-------|
| **Service** | schedule-service |
| **Priority** | P1 |
| **Estimated** | 3h |
| **Dependencies** | KAFKA-001 |

**Description:**
Celery task xử lý:
- Consume `connection.status.changed` và `connection.permission.changed`
- Send Push notification to affected users

**Files:**
- `schedule-service/schedule_service/tasks/connection/connection_notification.py`

---

## Phase 3: Testing

### TEST-001: InviteService Unit Tests
| Field | Value |
|-------|-------|
| **Service** | user-service |
| **Priority** | P1 |
| **Estimated** | 3h |
| **Dependencies** | SVC-001 |

**Description:**
Unit tests cho InviteService với các test cases:
- Happy path: create invite
- Edge case: self-invite (BR-006)
- Edge case: duplicate pending (BR-007)
- Edge case: already connected

**Files:**
- `user-service/src/test/java/com/company/userservice/service/InviteServiceTest.java`

**Run Command:**
```bash
cd user-service && mvn test -Dtest=InviteServiceTest
```

---

### TEST-002: ConnectionService Unit Tests
| Field | Value |
|-------|-------|
| **Service** | user-service |
| **Priority** | P1 |
| **Estimated** | 3h |
| **Dependencies** | SVC-002 |

**Description:**
Unit tests cho ConnectionService:
- Happy path: accept invite → create connection
- Happy path: disconnect
- Verify 6 default permissions created

**Files:**
- `user-service/src/test/java/com/company/userservice/service/ConnectionServiceTest.java`

**Run Command:**
```bash
cd user-service && mvn test -Dtest=ConnectionServiceTest
```

---

### TEST-002B: PermissionService Unit Tests
| Field | Value |
|-------|-------|
| **Service** | user-service |
| **Priority** | P1 |
| **Estimated** | 3h |
| **Dependencies** | SVC-003 |

**Description:**
Unit tests cho PermissionService với các test cases:
- Happy path: toggle permission ON/OFF
- Edge case: toggle emergency_alert OFF → verify warning required (BR-018)
- Happy path: get all 6 permissions for connection
- Kafka event published on permission change (BR-016)

**Files:**
- `user-service/src/test/java/com/company/userservice/service/PermissionServiceTest.java`

**Run Command:**
```bash
cd user-service && mvn test -Dtest=PermissionServiceTest
```

---

### TEST-003: API Gateway Handler Tests
| Field | Value |
|-------|-------|
| **Service** | api-gateway-service |
| **Priority** | P1 |
| **Estimated** | 3h |
| **Dependencies** | GW-HANDLER-001, GW-HANDLER-002 |

**Description:**
Unit tests cho REST handlers với mocked gRPC client.

**Files:**
- `api-gateway-service/src/test/java/com/company/apiservice/handler/InviteHandlerTest.java`
- `api-gateway-service/src/test/java/com/company/apiservice/handler/ConnectionHandlerTest.java`

**Run Command:**
```bash
cd api-gateway-service && mvn test -Dtest=*HandlerTest
```

---

### TEST-004: Integration Tests
| Field | Value |
|-------|-------|
| **Service** | all |
| **Priority** | P2 |
| **Estimated** | 4h |
| **Dependencies** | All tasks |

**Description:**
End-to-end integration tests:
1. Create invite → Accept → Verify connection exists
2. Update permission → Verify Kafka event published
3. Disconnect → Verify cascade updates

**Run Command:**
```bash
mvn verify -Pintegration-test
```

---

## Summary by Service

| Service | Tasks | Estimated Hours |
|---------|-------|-----------------|
| database | 1 | 2h |
| user-service | 18 | 38h |
| api-gateway-service | 6 | 14h |
| schedule-service | 2 | 7h |
| testing | 6 | 16h |
| **TOTAL** | **33** | **77h** |
