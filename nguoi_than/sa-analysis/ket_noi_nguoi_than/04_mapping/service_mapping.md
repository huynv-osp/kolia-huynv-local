# Service Mapping: KOLIA-1517 - Kết nối Người thân

> **Phase:** 4 - Architecture Mapping & Analysis  
> **Date:** 2026-02-04  
> **Revision:** v2.23 - Added inverse_relationship_display for perspective display (BR-036)
> **Applies Rule:** SA-002 (Service-Level Impact Detailing)

---

## Service: user-service

### Impact Level: 🔴 HIGH

### Code Changes Required

| Layer | File | Type | Description |
|-------|------|:----:|-------------|
| Proto | `proto/connection_service.proto` | NEW | 13 gRPC methods (incl. viewing, relationships) |
| Entity | `entity/ConnectionInvite.java` | NEW | Invite entity |
| Entity | `entity/UserConnection.java` | NEW | Connection entity |
| Entity | `entity/ConnectionPermission.java` | NEW | Permission entity |
| Entity | `entity/ConnectionPermissionType.java` | NEW | Permission type lookup |
| Entity | `entity/InviteNotification.java` | NEW | Notification tracking |
| Repository | `repository/ConnectionInviteRepository.java` | NEW | Invite data access |
| Repository | `repository/UserConnectionRepository.java` | NEW | Connection access |
| Repository | `repository/ConnectionPermissionRepository.java` | NEW | Permission access |
| Repository | `repository/ConnectionPermissionTypeRepository.java` | NEW | Permission type lookup |
| Entity | `entity/RelationshipType.java` | NEW | Relationship lookup entity |
| Repository | `repository/RelationshipTypeRepository.java` | NEW | Relationship type lookup |
| Service | `service/InviteService.java` | NEW | Invite lifecycle |
| Service | `service/ConnectionServiceImpl.java` | NEW | Connection logic |
| Service | `service/PermissionService.java` | NEW | RBAC logic |
| Handler | `handler/ConnectionHandler.java` | NEW | gRPC handler |
| DTO | `dto/request/*.java` | NEW | 8 request DTOs |
| DTO | `dto/response/*.java` | NEW | 6 response DTOs |
| Constant | `constant/InviteType.java` | NEW | Enum (2 values) |
| Constant | `constant/InviteStatus.java` | NEW | Enum (4 values) |
| Constant | `constant/ConnectionStatus.java` | NEW | Enum (2 values) |
| Constant | `constant/RelationshipType.java` | NEW | Enum (14 values) |
| Constant | `constant/PermissionType.java` | NEW | Enum (6 values) |
| Config | `config/KafkaProducerConfig.java` | MODIFY | Add 3 topics |
| Service | `service/ViewingPatientService.java` | NEW | Get/Set viewing logic |
| Repository | `repository/ViewingPatientRepository.java` | NEW | is_viewing queries |
| Event | `event/ConnectionEvent.java` | NEW | Kafka payload |

### Database Changes

| Table | Change | Details |
|-------|:------:|---------|
| connection_permission_types | CREATE | 8 columns, lookup table |
| connection_invites | CREATE | 11 columns, 5 indexes |
| user_emergency_contacts | ALTER | **+6 columns** (incl. is_viewing, inverse_relationship_code) |
| connection_permissions | CREATE | 5 columns, 2 indexes (FK) |
| relationships | CREATE | 7 columns, lookup table (v2.8) |
| invite_notifications | CREATE | 9 columns, 3 indexes |

### Integration Points

| Service | Protocol | Purpose |
|---------|----------|---------|
| schedule-service | Kafka | Notification triggers |

### Estimated Effort: 42 hours

---

## Service: api-gateway-service

### Impact Level: 🟡 MEDIUM

### Code Changes Required

| Layer | File | Type | Description |
|-------|------|:----:|-------------|
| Handler | `handler/InviteHandler.java` | NEW | 4 REST endpoints |
| Handler | `handler/ConnectionHandler.java` | NEW | 7 REST endpoints (incl. viewing) |
| Client | `client/ConnectionServiceClient.java` | NEW | gRPC client |
| DTO | `dto/request/CreateInviteRequest.java` | NEW | Create invite |
| DTO | `dto/request/AcceptInviteRequest.java` | NEW | Accept invite |
| DTO | `dto/request/UpdatePermissionsRequest.java` | NEW | Update perms |
| DTO | `dto/response/InviteResponse.java` | NEW | Invite details |
| DTO | `dto/response/ConnectionResponse.java` | NEW | Connection info |
| DTO | `dto/response/PermissionsResponse.java` | NEW | Permission flags |
| DTO | `dto/response/PermissionTypesResponse.java` | NEW | Permission types list |
| DTO | `dto/response/RelationshipTypesResponse.java` | NEW | Relationship types list |
| DTO | `dto/request/SetViewingPatientRequest.java` | NEW | Set viewing patient |
| DTO | `dto/response/ViewingPatientResponse.java` | NEW | Viewing patient info |
| Config | `config/RouteConfig.java` | MODIFY | 12 new routes |
| Swagger | Handler annotations | MODIFY | API docs |

### Gateway Compliance (ARCH-001)

```
✅ COMPLIANT - No business logic in gateway
   - handler/    ✅ REST forwarding
   - dto/        ✅ Request/Response
   - client/     ✅ gRPC client
   - config/     ✅ Routes
   
❌ NOT PRESENT (as expected):
   - service/    ✅ Not added
   - repository/ ✅ Not added
   - entity/     ✅ Not added
```

### Integration Points

| Service | Protocol | Purpose |
|---------|----------|---------|
| user-service | gRPC | All operations |

### Estimated Effort: 16 hours

---

## Service: schedule-service

### Impact Level: 🟡 MEDIUM

### Code Changes Required

| Layer | File | Type | Description |
|-------|------|:----:|-------------|
| Task | `tasks/connection/invite_notification.py` | NEW | ZNS/SMS dispatch |
| Task | `tasks/connection/connection_notification.py` | NEW | Push dispatch |
| Consumer | `consumers/connection_consumer.py` | NEW | Kafka consumer |
| Config | `config.py` | MODIFY | ZNS templates |
| Constant | `constants/zns_templates.py` | NEW | Template IDs |

### Integration Points

| Service | Protocol | Purpose |
|---------|----------|---------|
| Zalo ZNS | HTTP | Invitation messages |
| SMS Gateway | HTTP | Fallback |
| FCM | HTTP | Push notifications |
| user-service | Kafka | Event source |

### Estimated Effort: 8 hours

---

## Summary

| Service | Impact | Files | Effort |
|---------|:------:|:-----:|:------:|
| user-service | 🔴 HIGH | ~28 | 42h |
| api-gateway-service | 🟡 MEDIUM | ~14 | 18h |
| schedule-service | 🟡 MEDIUM | ~5 | 8h |
| **Total** | | **~47** | **68h** |
