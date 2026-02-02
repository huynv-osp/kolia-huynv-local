# Service Decomposition: KOLIA-1517 - Kết nối Người thân

> **Phase:** 4 - Service Decomposition  
> **Date:** 2026-01-30  
> **Applies Rule:** FA-002 (Service-Specific Change Documentation)  
> **Revision:** v2.14 - Added Mark Report as Read API

---

## Service: user-service

### Impact Level: 🔴 HIGH

### Detailed Changes

| Layer | File Path | Type | Description |
|-------|-----------|:----:|-------------|
| **Proto** | `proto/connection_service.proto` | NEW | 13 gRPC methods definition |
| **Entity** | `entity/ConnectionInvite.java` | NEW | Invite record entity |
| **Entity** | `entity/UserConnection.java` | NEW | Connection entity |
| **Entity** | `entity/ConnectionPermission.java` | NEW | Permission flag entity |
| **Entity** | `entity/ConnectionPermissionType.java` | NEW | Permission type lookup entity |
| **Entity** | `entity/InviteNotification.java` | NEW | Notification tracking |
| **Repository** | `repository/ConnectionInviteRepository.java` | NEW | Invite data access |
| **Repository** | `repository/UserConnectionRepository.java` | NEW | Connection data access |
| **Repository** | `repository/ConnectionPermissionRepository.java` | NEW | Permission data access |
| **Repository** | `repository/ConnectionPermissionTypeRepository.java` | NEW | Permission type lookup |
| **Entity** | `entity/RelationshipType.java` | NEW | Relationship type lookup entity |
| **Repository** | `repository/RelationshipTypeRepository.java` | NEW | Relationship type lookup |
| **Service** | `service/InviteService.java` | NEW | Invite lifecycle logic |
| **Service** | `service/ConnectionService.java` | NEW | Connection management |
| **Service** | `service/PermissionService.java` | NEW | RBAC logic |
| **Handler** | `handler/ConnectionHandler.java` | NEW | gRPC handler |
| **DTO** | `dto/request/CreateInviteRequest.java` | NEW | Create invite request |
| **DTO** | `dto/request/AcceptInviteRequest.java` | NEW | Accept with permissions |
| **DTO** | `dto/request/UpdatePermissionsRequest.java` | NEW | Update RBAC flags |
| **DTO** | `dto/response/InviteResponse.java` | NEW | Invite details |
| **DTO** | `dto/response/ConnectionResponse.java` | NEW | Connection details + `relationship_display`, `last_active` |
| **DTO** | `dto/response/PermissionsResponse.java` | NEW | Permission flags |
| **Constant** | `constant/InviteType.java` | NEW | Enum (2 values) |
| **Constant** | `constant/InviteStatus.java` | NEW | Enum (4 values) |
| **Constant** | `constant/ConnectionStatus.java` | NEW | Enum (2 values) |
| **Constant** | `constant/RelationshipType.java` | NEW | Enum (14 values) |
| **Constant** | `constant/PermissionType.java` | NEW | Enum (6 values) |
| **Config** | `config/KafkaProducerConfig.java` | MODIFY | Add 3 topics |
| **Service** | `service/ViewingPatientService.java` | NEW | Get/Set viewing patient logic |
| **Repository** | `repository/ViewingPatientRepository.java` | NEW | is_viewing queries |
| **DTO** | `dto/request/SetViewingPatientRequest.java` | NEW | Set viewing patient |
| **DTO** | `dto/response/ViewingPatientResponse.java` | NEW | Viewing patient info |
| **Service** | `service/PatientReportService.java` | NEW | Dashboard data + read tracking |
| **Repository** | `repository/CaregiverReportViewRepository.java` | NEW | Report read status |
| **Entity** | `entity/CaregiverReportView.java` | NEW | Report view tracking entity |

### Database Changes (v2.1 Optimized Schema)

| Table | Status | Details |
|-------|:------:|--------|
| `relationships` | ✅ NEW | 17 relationship types lookup |
| `connection_permission_types` | ✅ NEW | 6 permission types lookup |
| `connection_invites` | ✅ NEW | 11 columns, 5 indexes |
| `user_emergency_contacts` | 🔄 EXTEND | +5 columns (linked_user_id, contact_type, relationship_code, invite_id, **is_viewing**) |
| `connection_permissions` | ✅ NEW | 6 columns, 2 indexes (FK to connection_permission_types) |
| `invite_notifications` | ✅ NEW | 10 columns, 3 indexes |
| **`caregiver_report_views`** | ✅ **NEW** | 4 columns, 3 indexes - Report read tracking |

> **Note:** `user_connections` từ v1.0 đã được merge vào `user_emergency_contacts` với `contact_type='caregiver'`

### gRPC Methods

| Method | Request | Response |
|--------|---------|----------|
| `CreateInvite` | CreateInviteRequest | InviteResponse |
| `GetInvite` | GetInviteRequest | InviteResponse |
| `ListInvites` | ListInvitesRequest | ListInvitesResponse |
| `AcceptInvite` | AcceptInviteRequest | ConnectionResponse |
| `RejectInvite` | RejectInviteRequest | InviteResponse |
| `CancelInvite` | CancelInviteRequest | InviteResponse |
| `ListConnections` | ListConnectionsRequest | ListConnectionsResponse |
| `Disconnect` | DisconnectRequest | ConnectionResponse |
| `GetPermissions` | GetPermissionsRequest | PermissionsResponse |
| `UpdatePermissions` | UpdatePermissionsRequest | PermissionsResponse |
| `ListPermissionTypes` | Empty | PermissionTypesResponse |
| `ListRelationshipTypes` | Empty | RelationshipTypesResponse |
| `GetViewingPatient` | GetViewingPatientRequest | ViewingPatientResponse |
| `SetViewingPatient` | SetViewingPatientRequest | ViewingPatientResponse |
| **`GetBloodPressureChart`** | GetBloodPressureChartRequest | BloodPressureChartResponse |
| **`GetPatientReports`** | GetPatientReportsRequest | PatientReportsResponse |
| **`MarkReportAsRead`** | MarkReportAsReadRequest | MarkReportAsReadResponse | (v2.14)

### Integration Points

| Service | Protocol | Method | Purpose |
|---------|----------|--------|---------|
| schedule-service | Kafka | connection.invite.created | Trigger notifications |
| schedule-service | Kafka | connection.status.changed | Status updates |
| schedule-service | Kafka | connection.permission.changed | Permission changes |

### Estimated Effort: 50 hours

### Authorization Flow (SEC-DB-001)

```
Step 1: Check connection → user_emergency_contacts (is_active=TRUE, linked_user_id=caregiver)
Step 2: Check permission → connection_permissions (permission_code='health_overview', is_enabled=TRUE)
Step 3: Fetch data → patient_id only
Any step FAIL → 403 Forbidden
```

---

## Service: api-gateway-service

### Impact Level: 🟡 MEDIUM

### Detailed Changes

| Layer | File Path | Type | Description |
|-------|-----------|:----:|-------------|
| **Handler** | `handler/InviteHandler.java` | NEW | 4 REST endpoints |
| **Handler** | `handler/ConnectionHandler.java` | NEW | 7 REST endpoints (incl. viewing) |
| **Client** | `client/ConnectionServiceClient.java` | NEW | gRPC client |
| **DTO** | `dto/request/CreateInviteRequest.java` | NEW | REST request |
| **DTO** | `dto/request/AcceptInviteRequest.java` | NEW | REST request |
| **DTO** | `dto/request/UpdatePermissionsRequest.java` | NEW | REST request |
| **DTO** | `dto/response/InviteResponse.java` | NEW | REST response |
| **DTO** | `dto/response/ConnectionResponse.java` | NEW | REST response |
| **DTO** | `dto/response/PermissionsResponse.java` | NEW | REST response |
| **DTO** | `dto/response/PermissionTypesResponse.java` | NEW | Permission types list |
| **DTO** | `dto/response/RelationshipTypesResponse.java` | NEW | Relationship types list |
| **DTO** | `dto/request/SetViewingPatientRequest.java` | NEW | Set viewing patient |
| **DTO** | `dto/response/ViewingPatientResponse.java` | NEW | Viewing patient info |
| **Config** | `config/RouteConfig.java` | MODIFY | Add 12 routes |
| **Swagger** | Handler annotations | MODIFY | API documentation |

### REST Endpoints

| Method | Path | Handler Method |
|:------:|------|----------------|
| POST | `/api/v1/invites` | InviteHandler.create |
| GET | `/api/v1/invites` | InviteHandler.list |
| DELETE | `/api/v1/invites/{id}` | InviteHandler.cancel |
| POST | `/api/v1/invites/{id}/accept` | InviteHandler.accept |
| POST | `/api/v1/invites/{id}/reject` | InviteHandler.reject |
| GET | `/api/v1/connections` | ConnectionHandler.list |
| DELETE | `/api/v1/connections/{id}` | ConnectionHandler.disconnect |
| GET | `/api/v1/connections/{id}/permissions` | ConnectionHandler.getPermissions |
| PUT | `/api/v1/connections/{id}/permissions` | ConnectionHandler.updatePermissions |
| GET | `/api/v1/connection/permission-types` | ConnectionHandler.listPermissionTypes |
| GET | `/api/v1/connection/relationship-types` | ConnectionHandler.listRelationshipTypes |
| GET | `/api/v1/connections/viewing` | ConnectionHandler.getViewingPatient |
| PUT | `/api/v1/connections/viewing` | ConnectionHandler.setViewingPatient |
| **GET** | **`/api/v1/patients/{id}/blood-pressure-chart`** | PatientHandler.getBloodPressureChart |
| **GET** | **`/api/v1/patients/{id}/periodic-reports`** | PatientHandler.getPeriodicReports |
| **POST** | **`/api/v1/patients/{id}/periodic-reports/{reportId}/mark-read`** | PatientHandler.markReportAsRead | (v2.14)

### Integration Points

| Service | Protocol | Purpose |
|---------|----------|---------|
| user-service | gRPC | All connection operations |

### ⚠️ Gateway Compliance (ARCH-001)

```
✅ ALLOWED:
- Handler (REST → gRPC forwarding)
- DTO (Request/Response classes)
- Client (gRPC client)

❌ NOT ALLOWED:
- Service layer logic
- Repository/database access
- Entity definitions
```

### Estimated Effort: 22 hours

---

## Service: schedule-service

### Impact Level: 🟡 MEDIUM

### Detailed Changes

| Layer | File Path | Type | Description |
|-------|-----------|:----:|-------------|
| **Task** | `tasks/connection/invite_notification.py` | NEW | ZNS/SMS dispatch |
| **Task** | `tasks/connection/connection_notification.py` | NEW | Push dispatch |
| **Consumer** | `consumers/connection_consumer.py` | NEW | Kafka consumer |
| **Config** | `config.py` | MODIFY | Add ZNS templates |
| **Constant** | `constants/zns_templates.py` | NEW | Template IDs |

### Celery Tasks

| Task | Trigger | Action |
|------|---------|--------|
| `send_invite_notification` | `connection.invite.created` | ZNS → SMS fallback |
| `notify_connection_change` | `connection.status.changed` | Push notification |
| `notify_permission_change` | `connection.permission.changed` | Push notification |

### Kafka Consumers

| Topic | Consumer | Handler |
|-------|----------|---------|
| `connection.invite.created` | ConnectionConsumer | handle_invite_created |
| `connection.status.changed` | ConnectionConsumer | handle_status_changed |
| `connection.permission.changed` | ConnectionConsumer | handle_permission_changed |

### Integration Points

| Service | Protocol | Purpose |
|---------|----------|---------|
| Zalo ZNS | HTTP | Send invitation messages |
| SMS Gateway | HTTP | Fallback messaging |
| FCM | HTTP | Push notifications |

### Retry Logic (BR-004)

```python
MAX_RETRIES = 3
RETRY_INTERVAL = 30  # seconds

# If ZNS fails → try SMS with same retry logic
```

### Estimated Effort: 8 hours

---

## Summary

| Service | Impact | Files | Effort |
|---------|:------:|:-----:|:------:|
| user-service | 🔴 HIGH | ~35 | 50h |
| api-gateway-service | 🟡 MEDIUM | ~18 | 22h |
| schedule-service | 🟡 MEDIUM | ~5 | 8h |
| **Total** | | **~58** | **80h** |
