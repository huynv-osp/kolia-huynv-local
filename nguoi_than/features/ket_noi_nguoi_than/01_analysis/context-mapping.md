# Context Mapping: KOLIA-1517 - Kết nối Người thân

> **Phase:** 2 - System Context Mapping  
> **Date:** 2026-01-29  
> **Revision:** v2.6 - Added ListPermissionTypes API

---

## 1. ALIO Services Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      CLIENT (Web/Mobile)                         │
└───────────────────────────────┬─────────────────────────────────┘
                                │ HTTP/REST
┌───────────────────────────────▼─────────────────────────────────┐
│                      API GATEWAY                                 │
│  api-gateway-service (Java 17, Vert.x, port 8080)               │
│  - 9 new REST endpoints (incl. permission-types)                 │
│  - gRPC client to user-service                                   │
└──────┬──────────────────────────────────────────────────────────┘
       │ gRPC
┌──────▼─────────┐              ┌────────────────────────────────┐
│  user-service  │──────────────▶  schedule-service              │
│  (Vert.x)      │   Kafka      │  (Celery)                      │
│  - Connections │              │  - ZNS/SMS notifications       │
│  - Permissions │              │  - Retry logic                 │
│  - Invites     │              │                                │
└────────────────┘              └────────────────────────────────┘
```

---

## 2. Service Mapping

| Service | Role in Feature | Tech Stack |
|---------|-----------------|------------|
| **api-gateway-service** | REST entry point, gRPC client | Java 17, Vert.x |
| **user-service** | Business logic, data access | Java 17, Vert.x |
| **schedule-service** | Async notifications | Python, Celery |

---

## 3. Database Context (v2.1 Optimized Schema)

### Current Schema Analysis

Existing tables being **EXTENDED**:
- `user_emergency_contacts` - ✅ EXTEND for caregiver connections
- `users` - Core user data (referenced)

### Schema Changes

| Table | Status | Purpose |
|-------|:------:|---------|
| `relationships` | ✅ NEW | Lookup table (14 types, v2.22) |
| `connection_permission_types` | ✅ NEW | Permission lookup (6 types) |
| `connection_invites` | ✅ NEW | Bi-directional invite tracking |
| `user_emergency_contacts` | 🔄 EXTEND | +4 columns for caregiver support |
| `connection_permissions` | ✅ NEW | 6 RBAC permission flags (FK) |
| `invite_notifications` | ✅ NEW | ZNS/SMS delivery tracking |

### Entity Relationships (v2.0)

```
relationships (lookup)
       │ FK
users ─┼─< connection_invites (sender_id)
       │         │ FK
       │         ├──> user_emergency_contacts.invite_id
       │         └──< invite_notifications
       │
       └─< user_emergency_contacts (user_id)
                 │ FK
                 ├──> linked_user_id (caregiver's user_id)
                 └─< connection_permissions (contact_id)
```

> **Note:** `user_connections` table từ v1.0 đã được merge vào `user_emergency_contacts.contact_type='caregiver'`

---

## 4. Integration Points

### Internal Services

| From | To | Protocol | Purpose |
|------|-----|----------|---------|
| api-gateway | user-service | gRPC | All connection operations |
| user-service | schedule-service | Kafka | Notification triggers |

### External Services

| Service | Protocol | Purpose |
|---------|----------|---------|
| Zalo ZNS | HTTP | Send invitation messages |
| SMS Gateway | HTTP | Fallback messaging |
| FCM | HTTP | Push notifications |

### Kafka Topics

| Topic | Publisher | Consumer |
|-------|-----------|----------|
| `connection.invite.created` | user-service | schedule-service |
| `connection.status.changed` | user-service | schedule-service |
| `connection.permission.changed` | user-service | schedule-service |

---

## 5. Cross-Feature Dependencies

| Feature | Dependency Type | Notes |
|---------|-----------------|-------|
| Bản tin Hành động | Extends | Add `INVITE_CONNECTION` action type |
| Notification System | Uses | 5 new notification scenarios |
| Bottom Navigation | Uses | Slot #4 available |
| SOS Emergency | Future | Emergency alerts to Caregivers |

---

## 6. Technology Stack Alignment

| Component | Standard | This Feature |
|-----------|----------|--------------|
| REST API | Vert.x Handlers | ✅ Aligned |
| gRPC | Protobuf 3 | ✅ Aligned |
| Database | PostgreSQL 14 | ✅ Aligned |
| Async | Kafka + Celery | ✅ Aligned |
| Notifications | ZNS → SMS → Push | ✅ Aligned |

---

## 7. Security Considerations

| Aspect | Implementation |
|--------|----------------|
| Authentication | JWT token validation |
| Authorization | User can only modify own invites/permissions |
| Data Privacy | Permissions control data visibility |
| Audit | invite_notifications tracks delivery |

---

## References

- [ALIO Services Catalog](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/api-gateway-service/database/Alio_database_create.sql)
