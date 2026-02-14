# Context Mapping: KOLIA-1517 - Kết nối Người thân

> **Phase:** 1 - Requirement Intake & Classification  
> **Date:** 2026-02-13  
> **SRS Version:** v4.0  
> **Revision:** v4.0 - 5-service architecture, Family Group model, payment integration

---

## 1. Service Architecture Context

> **v4.0:** Expanded from 3 → 5 services. Added payment-service (slot management) and auth-service (backfill). Cross-ref: [SA Service Mapping v4.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/ket_noi_nguoi_than/04_mapping/service_mapping.md)

### 1.1 Primary: user-service (🔴 HIGH, ~30h)

- **Role:** Core business logic — Family Group, connections, permissions
- **Changes:** Entity, Repository, Service layer → Family Group CRUD, Admin-only invite, auto-connect, soft disconnect
- **Stack:** Vert.x / Java / PostgreSQL
- **Key Entities:** FamilyGroup, FamilyGroupMember, UserEmergencyContact (extended), ConnectionInvite (updated)

### 1.2 api-gateway-service (🔴 HIGH, ~20h)

- **Role:** REST endpoints → gRPC routing (Thin Gateway, ARCH-001)
- **Changes:** 6 new REST endpoints, simplified invite request, deprecated DELETE
- **Stack:** Vert.x / Java
- **Pattern:** No business logic — all delegated to user-service via gRPC

### 1.3 payment-service (🟡 MEDIUM, ~10h) — NEW v4.0

- **Role:** Slot check, subscription info, package validation
- **Changes:** Ensure GetSubscription RPC returns slot info
- **Stack:** Spring Boot / Java / PostgreSQL
- **Integration:** user-service → payment-service via gRPC (inbound calls)
- **Key RPCs:** GetSubscription (returns package_name, slots, expiry)

### 1.4 schedule-service (🟡 MEDIUM, ~10h)

- **Role:** Notification broadcast, ZNS/SMS sending
- **Changes:** New Kafka event handlers for member join/remove, group broadcast
- **Stack:** Python / Kafka consumer
- **Kafka Events:** `connection.member.accepted`, `connection.member.removed`, `connection.invite.created`

### 1.5 auth-service (🟢 LOW, ~5h) — NEW v4.0

- **Role:** Backfill `receiver_id` on pending invites when new user registers
- **Changes:** Verify existing `backfillPendingInviteReceiverIds` handles `add_patient`/`add_caregiver` types
- **Stack:** Vert.x / Java
- **Pattern:** Fire-and-forget with warning logging (existing)

---

## 2. Database Context

### 2.1 Schema Changes Summary

| Table | Type | Service | v4.0 Notes |
|-------|:----:|---------|------------|
| `family_groups` | **NEW** | user-service | Admin, subscription_id, status |
| `family_group_members` | **NEW** | user-service | User, role, status, UNIQUE(user_id) |
| `relationships` | Existing | user-service | Unchanged |
| `relationship_inverse_mapping` | Existing | user-service | Unchanged |
| `connection_permission_types` | Existing | user-service | Unchanged |
| `connection_invites` | MODIFY | user-service | invite_type: `add_patient`/`add_caregiver` |
| `connection_permissions` | Existing | user-service | Unchanged |
| `user_emergency_contacts` | MODIFY | user-service | +permission_revoked, +family_group_id |
| `invite_notifications` | Existing | user-service | Unchanged |
| `caregiver_report_views` | Existing | user-service | Unchanged |

### 2.2 Key Schema Decisions

| Decision | Rationale |
|----------|-----------|
| `family_groups` linked to `subscription_id` | Payment SRS sync, slot management |
| `family_group_members` with UNIQUE(user_id) | Enforce exclusive group constraint (BR-057) |
| `permission_revoked` BOOLEAN on UEC | Soft disconnect — keep connection, toggle access |
| `invite_type` enum update | `add_patient`/`add_caregiver` replaces `add_caregiver`/`add_patient` |

---

## 3. Integration Points

### 3.1 gRPC (Service-to-Service)

| Caller → Target | Protocol | Purpose | v4.0 |
|-----------------|----------|---------|:----:|
| api-gateway → user-service | gRPC | All connection/group operations | Existing |
| user-service → payment-service | gRPC | **GetSubscription, slot validation** | ⚠️ NEW |
| auth-service → user-service | gRPC | Backfill receiver_id | Existing |

### 3.2 Kafka (Event-Driven)

| Producer | Topic | Consumer | Purpose |
|----------|-------|----------|---------|
| user-service | `connection.invite.created` | schedule-service | Send ZNS/Push to invitee |
| user-service | `connection.member.accepted` | schedule-service | **Broadcast to ALL members** (BR-052) |
| user-service | `connection.member.removed` | schedule-service | Notify removed member |

### 3.3 REST (Mobile → Gateway)

| Endpoint | Method | v4.0 Status |
|----------|:------:|:-----------:|
| `/api/v1/connections/invite` | POST | Updated (Admin-only, phone only) |
| `/api/v1/connections/invites/:id/accept` | POST | Updated (auto-connect response) |
| `/api/v1/connections/invites/:id/reject` | POST | Unchanged |
| `/api/v1/connections` | GET | Unchanged |
| `/api/v1/family-groups` | GET | ⚠️ NEW |
| `/api/v1/family-groups/members/:memberId` | DELETE | ⚠️ NEW (Admin remove) |
| `/api/v1/connections/:contactId/revoke` | PUT | ⚠️ NEW (tắt quyền) |
| `/api/v1/connections/:contactId/restore` | PUT | ⚠️ NEW (mở lại quyền) |
| `/api/v1/connections/:contactId/relationship` | PUT | ⚠️ NEW (update MQH) |
| `/api/v1/family-groups/leave` | POST | ⚠️ NEW (rời nhóm) |
| ~~`/api/v1/connections/:id`~~ | ~~DELETE~~ | ❌ DEPRECATED |

---

## 4. Technology Stack Alignment

| Component | Technology | Status |
|-----------|------------|:------:|
| Backend Services | Vert.x (Java) + Spring Boot | ✅ Existing |
| API Protocol | gRPC (Protobuf) | ✅ Existing |
| Database | PostgreSQL | ✅ Existing |
| Message Queue | Apache Kafka | ✅ Existing |
| Notification | ZNS + SMS + Push | ✅ Existing |
| Mobile | React Native + Expo | ✅ Existing |
| **Circuit Breaker** | **Resilience4j** (payment dependency) | ⚠️ NEW consideration |

---

## 5. Cross-Service Communication Map

```
┌──────────────┐  REST   ┌────────────────┐  gRPC  ┌───────────────┐
│   Mobile App │ ──────→ │ api-gateway    │ ─────→ │ user-service  │
└──────────────┘         └────────────────┘        └───────┬───────┘
                                                           │ gRPC
                                                    ┌──────▼───────┐
                                                    │payment-service│
                                                    └──────────────┘
                                                           │ Kafka
                         ┌────────────────┐        ┌──────▼───────┐
                         │ auth-service   │ ─gRPC→ │schedule-service│
                         │ (backfill)     │        │ (notifications)│
                         └────────────────┘        └──────────────┘
```

---

## References

- [SA Service Mapping v4.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/ket_noi_nguoi_than/04_mapping/service_mapping.md)
- [SA Architecture Snapshot v4.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/ket_noi_nguoi_than/02_context/architecture_snapshot.md)
- [SA Database Mapping v4.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/ket_noi_nguoi_than/04_mapping/database_mapping.md)
