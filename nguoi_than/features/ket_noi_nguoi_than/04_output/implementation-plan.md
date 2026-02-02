# Implementation Plan: KOLIA-1517 - Kết nối Người thân

> **SRS Version:** v2.14 + Mark Report as Read API  
> **Date:** 2026-01-30  
> **Feasibility Score:** **88/100** ✅ FEASIBLE (improved from 84)  
> **Impact Level:** 🟢 **LOW** (reduced from MEDIUM)  
> **Estimated Duration:** 4 weeks (3 phases)  
> **Schema:** v2.14 Optimized + Dashboard APIs + Mark Report Read

---

## 1. Executive Summary

Tính năng **Kết nối Người thân** cho phép Patient và Caregiver thiết lập mối quan hệ bi-directional để giám sát sức khỏe từ xa với 6-permission RBAC system.

### Key Metrics
| Metric | Value |
|--------|-------|
| Services Affected | 3 (user-service, api-gateway, schedule-service) |
| New Database Tables | **6 NEW + 1 ALTER** |
| New REST Endpoints | **17** (v2.14: +1 Mark Report Read) |
| New gRPC Methods | **16** |
| New Celery Tasks | 3 |

---

## 2. Proposed Changes

### 2.1 Database Schema (v2.0 Optimized)

> **Key Change:** Reuse `user_emergency_contacts` instead of creating separate `user_connections` table

---

#### [NEW] relationships (Lookup Table)
```sql
CREATE TABLE IF NOT EXISTS relationships (
    relationship_code VARCHAR(30) PRIMARY KEY,
    name_vi VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    category VARCHAR(30) DEFAULT 'family',
    display_order SMALLINT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE
);
-- Seed data: 17 relationship types
```

---

#### [NEW] connection_permission_types (v2.1)
```sql
CREATE TABLE IF NOT EXISTS connection_permission_types (
    permission_code VARCHAR(30) PRIMARY KEY,
    name_vi VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    description TEXT,
    icon VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    display_order SMALLINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
-- Seed data: 6 permission types (health_overview, emergency_alert, task_config, compliance_tracking, proxy_execution, encouragement)
```

#### [NEW] connection_invites
```sql
CREATE TABLE IF NOT EXISTS connection_invites (
    invite_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    receiver_phone VARCHAR(20) NOT NULL,
    receiver_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
    receiver_name VARCHAR(100),
    invite_type VARCHAR(30) NOT NULL, -- 'patient_to_caregiver', 'caregiver_to_patient'
    relationship_code VARCHAR(30) REFERENCES relationships(relationship_code),
    initial_permissions JSONB DEFAULT '{...}'::jsonb,
    status SMALLINT DEFAULT 0, -- 0:pending, 1:accepted, 2:rejected, 3:cancelled
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_no_self_invite CHECK (sender_id != receiver_id)
);
-- Create new constraint với invite_type
CREATE UNIQUE INDEX idx_unique_pending_invite 
    ON connection_invites (sender_id, receiver_phone, invite_type) 
    WHERE status = 0;
```

---

#### [🔄 EXTEND] user_emergency_contacts
```sql
-- Add 4 new columns to existing table
ALTER TABLE user_emergency_contacts 
ADD COLUMN IF NOT EXISTS linked_user_id UUID REFERENCES users(user_id);

ALTER TABLE user_emergency_contacts 
ADD COLUMN IF NOT EXISTS contact_type VARCHAR(20) DEFAULT 'emergency';
-- Values: 'emergency' (SOS), 'caregiver' (connection), 'both'

ALTER TABLE user_emergency_contacts 
ADD COLUMN IF NOT EXISTS relationship_code VARCHAR(30) REFERENCES relationships(relationship_code);

ALTER TABLE user_emergency_contacts 
ADD COLUMN IF NOT EXISTS invite_id UUID REFERENCES connection_invites(invite_id);
```

> **SOS Backward Compatibility:** Existing contacts with `contact_type='emergency'` remain unchanged

---

#### [NEW] connection_permissions (RBAC)
```sql
CREATE TABLE IF NOT EXISTS connection_permissions (
    permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID NOT NULL REFERENCES user_emergency_contacts(contact_id) ON DELETE CASCADE,
    permission_code VARCHAR(30) NOT NULL REFERENCES connection_permission_types(permission_code),
    is_enabled BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID REFERENCES users(user_id),
    CONSTRAINT uq_permission_per_contact UNIQUE (contact_id, permission_code)
);
```

---

#### [NEW] invite_notifications
```sql
CREATE TABLE invite_notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invite_id UUID NOT NULL REFERENCES connection_invites(invite_id) ON DELETE CASCADE,
    channel VARCHAR(10) NOT NULL, -- 'ZNS', 'SMS', 'PUSH'
    status SMALLINT DEFAULT 0, -- 0:pending, 1:sent, 2:delivered, 3:failed
    retry_count SMALLINT DEFAULT 0,
    sent_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_channel CHECK (channel IN ('ZNS', 'SMS', 'PUSH')),
    CONSTRAINT chk_retry_count CHECK (retry_count <= 3)
);

CREATE INDEX idx_invite_notifications_invite ON invite_notifications(invite_id);
CREATE INDEX idx_invite_notifications_pending ON invite_notifications(status) WHERE status = 0;
```

---

#### [NEW] caregiver_report_views (v2.11)
```sql
CREATE TABLE caregiver_report_views (
    id BIGSERIAL PRIMARY KEY,
    caregiver_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    report_id BIGINT NOT NULL REFERENCES report_periodic(report_id) ON DELETE CASCADE,
    viewed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT idx_unique_caregiver_report UNIQUE (caregiver_id, report_id)
);

-- Indexes for efficient lookup
CREATE INDEX idx_crv_caregiver_id ON caregiver_report_views(caregiver_id);
CREATE INDEX idx_crv_report_id ON caregiver_report_views(report_id);
```

---

### 2.2 Service: user-service (Impact: 🔴 HIGH)

| Layer | File | Type | Description |
|-------|------|------|-------------|
| **Proto** | `proto/connection_service.proto` | NEW | gRPC contract: 9 methods |
| **Entity** | `entity/ConnectionInvite.java` | NEW | JPA Entity for invites |
| **Entity** | `entity/UserConnection.java` | NEW | JPA Entity for connections |
| **Entity** | `entity/ConnectionPermission.java` | NEW | JPA Entity for permissions |
| **Entity** | `entity/ConnectionPermissionType.java` | NEW | JPA Entity for permission types lookup |
| **Entity** | `entity/InviteNotification.java` | NEW | JPA Entity for notification log |
| **Repository** | `repository/ConnectionInviteRepository.java` | NEW | Data access for invites |
| **Repository** | `repository/UserConnectionRepository.java` | NEW | Data access for connections |
| **Repository** | `repository/ConnectionPermissionRepository.java` | NEW | Data access for permissions |
| **Repository** | `repository/ConnectionPermissionTypeRepository.java` | NEW | Data access for permission types |
| **Service** | `service/InviteService.java` | NEW | Invite lifecycle logic |
| **Service** | `service/ConnectionService.java` | NEW | Connection management logic |
| **Service** | `service/PermissionService.java` | NEW | RBAC permission logic |
| **Handler** | `handler/ConnectionHandler.java` | NEW | gRPC handler implementation |
| **DTO** | `dto/request/*.java` | NEW | 8 request DTOs |
| **DTO** | `dto/response/*.java` | NEW | 6 response DTOs |
| **Constant** | `constant/RelationshipType.java` | NEW | 14-value enum |
| **Constant** | `constant/PermissionType.java` | NEW | 6-value enum |
| **Constant** | `constant/InviteStatus.java` | NEW | 4-value enum |
| **Constant** | `constant/ConnectionStatus.java` | NEW | 2-value enum |
| **Config** | `config/KafkaProducerConfig.java` | MODIFY | Add connection topics |

**Estimated Effort:** 40 hours

---

### 2.3 Service: api-gateway-service (Impact: 🟡 MEDIUM)

| Layer | File | Type | Description |
|-------|------|------|-------------|
| **Handler** | `handler/InviteHandler.java` | NEW | REST → gRPC forwarding |
| **Handler** | `handler/ConnectionHandler.java` | NEW | REST → gRPC forwarding |
| **DTO** | `dto/request/CreateInviteRequest.java` | NEW | Create invite request |
| **DTO** | `dto/request/AcceptInviteRequest.java` | NEW | Accept invite with permissions |
| **DTO** | `dto/request/UpdatePermissionsRequest.java` | NEW | Update RBAC flags |
| **DTO** | `dto/response/InviteResponse.java` | NEW | Invite details |
| **DTO** | `dto/response/ConnectionResponse.java` | NEW | Connection details |
| **DTO** | `dto/response/PermissionsResponse.java` | NEW | Permission flags |
| **Client** | `client/ConnectionServiceClient.java` | NEW | gRPC client to user-service |
| **Config** | `config/RouteConfig.java` | MODIFY | Add 8 new routes |
| **Swagger** | Annotations | MODIFY | Document new APIs |

**Estimated Effort:** 16 hours

---

### 2.4 Service: schedule-service (Impact: 🟡 MEDIUM)

| Layer | File | Type | Description |
|-------|------|------|-------------|
| **Task** | `tasks/connection/invite_notification.py` | NEW | ZNS/SMS dispatch |
| **Task** | `tasks/connection/connection_notification.py` | NEW | State change notifications |
| **Config** | `config.py` | MODIFY | Add ZNS templates |
| **Constant** | `constants/zns_templates.py` | NEW | ZNS template IDs |

**Estimated Effort:** 8 hours

---

## 3. REST API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/connections/invite` | Create bi-directional invite |
| GET | `/api/v1/connections/invites` | List sent/received invites |
| GET | `/api/v1/connections/invites/:inviteId` | Get invite details |
| DELETE | `/api/v1/connections/invites/:inviteId` | Cancel pending invite |
| POST | `/api/v1/connections/invites/:inviteId/accept` | Accept invite with permissions |
| POST | `/api/v1/connections/invites/:inviteId/reject` | Reject invite |
| GET | `/api/v1/connections` | List active connections |
| DELETE | `/api/v1/connections/:connectionId` | Disconnect |
| GET | `/api/v1/connections/:connectionId/permissions` | Get RBAC flags |
| PUT | `/api/v1/connections/:connectionId/permissions` | Update RBAC flags |
| GET | `/api/v1/connection/permission-types` | List all permission types |
| GET | `/api/v1/connection/relationship-types` | List all relationship types (v2.8) |
| GET | `/api/v1/connections/viewing` | Get viewing patient (v2.7) |
| PUT | `/api/v1/connections/viewing` | Set viewing patient (v2.7) |
| **GET** | **`/api/v1/patients/:patientId/blood-pressure-chart`** | Blood pressure chart (v2.11) |
| **GET** | **`/api/v1/patients/:patientId/periodic-reports`** | Patient reports (v2.11) |
| **POST** | **`/api/v1/patients/:patientId/periodic-reports/:reportId/mark-read`** | Mark report as read (v2.14) |

---

## 4. gRPC Methods (user-service)

```protobuf
service ConnectionService {
  // Invites
  rpc CreateInvite(CreateInviteRequest) returns (InviteResponse);
  rpc GetInvite(GetInviteRequest) returns (InviteResponse);
  rpc ListInvites(ListInvitesRequest) returns (ListInvitesResponse);
  rpc AcceptInvite(AcceptInviteRequest) returns (ConnectionResponse);
  rpc RejectInvite(RejectInviteRequest) returns (InviteResponse);
  rpc CancelInvite(CancelInviteRequest) returns (InviteResponse);
  
  // Connections
  rpc ListConnections(ListConnectionsRequest) returns (ListConnectionsResponse);
  rpc Disconnect(DisconnectRequest) returns (ConnectionResponse);
  
  // Permissions
  rpc GetPermissions(GetPermissionsRequest) returns (PermissionsResponse);
  rpc UpdatePermissions(UpdatePermissionsRequest) returns (PermissionsResponse);
  rpc ListPermissionTypes(ListPermissionTypesRequest) returns (PermissionTypesResponse);
  
  // Discovery API (v2.8)
  rpc ListRelationshipTypes(ListRelationshipTypesRequest) returns (RelationshipTypesResponse);
  
  // Profile Selection (v2.7)
  rpc GetViewingPatient(GetViewingPatientRequest) returns (ViewingPatientResponse);
  rpc SetViewingPatient(SetViewingPatientRequest) returns (ViewingPatientResponse);
  
  // Dashboard APIs (v2.13, v2.14)
  rpc GetBloodPressureChart(GetBloodPressureChartRequest) returns (BloodPressureChartResponse);
  // Response includes: patient_id, mode, measurements[], patient_target_thresholds (v2.13)
  rpc GetPatientReports(GetPatientReportsRequest) returns (PatientReportsResponse);
  rpc MarkReportAsRead(MarkReportAsReadRequest) returns (MarkReportAsReadResponse); // v2.14
}
```

---

## 4.1 Authorization Flow (SEC-DB-001)

> **All patient APIs require 3-step authorization**

```sql
-- Step 1: Check connection exists
SELECT id FROM user_emergency_contacts 
WHERE user_id = {patient_id} 
AND linked_user_id = {caregiver_id} 
AND is_active = TRUE

-- Step 2: Check permission enabled
SELECT is_enabled FROM connection_permissions 
WHERE contact_id = {contact_id} 
AND permission_code = 'health_overview'

-- Step 3: Fetch data for patient_id only
-- Any step FAIL → 403 Forbidden
```

---

## 5. Kafka Topics

| Topic | Publisher | Consumer | Purpose |
|-------|-----------|----------|---------|
| `connection.invite.created` | user-service | schedule-service | Trigger ZNS/Push |
| `connection.status.changed` | user-service | schedule-service | Notify participants |
| `connection.permission.changed` | user-service | schedule-service | Notify Caregiver |

---

## 6. Implementation Roadmap (4 Weeks)

### Phase 1: Core Foundation (Weeks 1-2)
- [ ] DB-001: Database migration script
- [ ] ENTITY-001~004: JPA Entities
- [ ] REPO-001~003: Repositories
- [ ] PROTO-001: Proto file definition
- [ ] SVC-001~003: user-service logic
- [ ] HANDLER-001: user-service gRPC handler
- [ ] CLIENT-001: api-gateway gRPC client
- [ ] GW-HANDLER-001~002: api-gateway REST handlers

### Phase 2: Permissions & Async (Week 3)
- [ ] PERM-001: Permission service logic
- [ ] KAFKA-001: Kafka producer setup
- [ ] SCHED-001~002: schedule-service tasks
- [ ] ZNS-001: ZNS template registration

### Phase 3: Advanced UX & Testing (Week 4)
- [ ] TEST-001~003: Unit tests
- [ ] TEST-004: Integration tests
- [ ] DOC-001: API documentation
- [ ] UAT: User acceptance testing

---

## 7. Verification Plan

### 7.1 Unit Tests

| Service | Command | Coverage Target |
|---------|---------|-----------------|
| user-service | `mvn test -Dtest=*ConnectionTest` | >80% |
| api-gateway-service | `mvn test -Dtest=*ConnectionTest` | >70% |
| schedule-service | `pytest tests/tasks/connection/` | >70% |

### 7.2 Integration Tests

```bash
# Run integration tests after deploying to dev environment
mvn verify -Pintegration-test -DskipTests=false
```

### 7.3 Manual Testing

1. **Invite Flow**: Patient gửi invite → Caregiver nhận notification → Accept/Reject
2. **Permission Toggle**: Patient toggle permission → Verify notification đến Caregiver
3. **Disconnect**: Verify cascade delete và notification

---

## 8. Technical Risks & Mitigation

| Risk | Severity | Mitigation |
|------|----------|------------|
| ZNS Approval Delay | 🟡 Med | SMS fallback ready from Day 1 |
| Deep Link Infrastructure | 🔴 High | Verify availability in Week 1 |
| Permission Desync | 🟡 Med | Server as Source of Truth |

---

## 9. Business Rules Reference

| BR-ID | Description | Implementation |
|-------|-------------|----------------|
| BR-001 | Bi-directional invites | `invite_type` field |
| BR-004 | ZNS → SMS fallback (3x) | schedule-service retry logic |
| BR-006 | No self-invite | DB constraint + service validation |
| BR-007 | No duplicate pending | Unique partial index |
| BR-008 | Accept → Create connection | Transaction in AcceptInvite |
| BR-017 | Permission OFF → Hide UI | Real-time permission check |
| BR-018 | Red warning for emergency | Frontend validation |

---

## Appendix: Relationship Types (14 values)

| Code | Vietnamese |
|------|------------|
| `con_trai` | Con trai |
| `con_gai` | Con gái |
| `chau_trai` | Cháu trai |
| `chau_gai` | Cháu gái |
| `em_trai` | Em trai |
| `em_gai` | Em gái |
| `bo` | Bố |
| `me` | Mẹ |
| `ong_noi` | Ông nội |
| `ba_noi` | Bà nội |
| `ong_ngoai` | Ông ngoại |
| `ba_ngoai` | Bà ngoại |
| `vo` | Vợ |
| `chong` | Chồng |
| `khac` | Khác |
