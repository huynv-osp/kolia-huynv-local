# Service Mapping: Kết nối Người thân (v4.0)

> **Phase:** 4 - Architecture Mapping & Analysis  
> **Date:** 2026-02-13  
> **Standard:** SA-002 (Service-Level Impact Detailing)

---

## Overview

| Service | Impact | Effort | Role in KCNT v4.0 |
|---------|:------:|:------:|-------------------|
| user-service | 🔴 HIGH | ~30h | Core: Family Group, connections, permissions |
| api-gateway-service | 🔴 HIGH | ~20h | REST endpoints, request routing |
| payment-service | 🟡 MEDIUM | ~10h | Slot check, subscription info |
| schedule-service | 🟡 MEDIUM | ~10h | Member broadcast notifications |
| auth-service | 🟢 LOW | ~5h | Backfill receiver_id |
| **Mobile App** | 🔴 HIGH | ~25h | UI screens, state management |

**Total Backend Effort:** ~75-80h

---

## Service: user-service

### Impact Level: 🔴 HIGH

### Code Changes Required

| Layer | File | Type | Description |
|-------|------|------|-------------|
| Entity | `entity/FamilyGroup.java` | NEW | Family group entity |
| Entity | `entity/FamilyGroupMember.java` | NEW | Group membership entity |
| Entity | `entity/UserEmergencyContact.java` | MODIFY | +permission_revoked, +family_group_id |
| Entity | `entity/ConnectionInvite.java` | MODIFY | invite_type enum update |
| Repository | `repository/FamilyGroupRepository.java` | NEW | Family group CRUD |
| Repository | `repository/FamilyGroupMemberRepository.java` | NEW | Membership queries |
| Service | `service/FamilyGroupService.java` | NEW | Group lifecycle management |
| Service | `service/ConnectionService.java` | MODIFY | Admin-only invite, auto-connect, soft disconnect |
| gRPC | `grpc/ConnectionServiceGrpcImpl.java` | MODIFY | New RPCs: FamilyGroup CRUD, permission revoke/restore |
| Client | `client/PaymentServiceClient.java` | NEW | gRPC client to payment-service |
| Config | `config/PaymentServiceConfig.java` | NEW | gRPC channel config |

### Database Changes

| Table | Change | Details |
|-------|--------|---------|
| `family_groups` | CREATE | Admin, subscription, status |
| `family_group_members` | CREATE | User, role, status, exclusive constraint |
| `user_emergency_contacts` | ALTER | +permission_revoked, +family_group_id |
| `connection_invites` | ALTER | invite_type CHECK constraint |

### Integration Points

| Service | Protocol | Purpose |
|---------|----------|---------|
| payment-service | gRPC | Slot check, GetSubscription, SyncMembers |
| schedule-service | Kafka | Member broadcast events |
| auth-service | gRPC (inbound) | Backfill receiver_id |

### Key Business Logic
- **Admin-only invite (BR-041):** Validate sender is Admin before creating invite
- **Slot pre-check (BR-033):** Call payment-service before invite
- **Auto-connect (BR-045):** On CG accept → create connections to ALL patients
- **Soft disconnect (BR-040):** Set permission_revoked=true, keep connection active
- **Exclusive group (BR-057):** Check user not in another group before invite

---

## Service: api-gateway-service

### Impact Level: 🔴 HIGH

### Code Changes Required

| Layer | File | Type | Description |
|-------|------|------|-------------|
| Handler | `handler/FamilyGroupHandler.java` | NEW | Family group REST endpoints |
| Handler | `handler/ConnectionHandler.java` | MODIFY | Updated invite/accept contracts |
| DTO | `dto/request/CreateFamilyGroupRequest.java` | NEW | |
| DTO | `dto/request/RemoveMemberRequest.java` | NEW | |
| DTO | `dto/response/FamilyGroupResponse.java` | NEW | |
| DTO | `dto/request/CreateInviteRequest.java` | MODIFY | Simplified (phone only) |
| DTO | `dto/request/RevokePermissionRequest.java` | NEW | |
| DTO | `dto/request/UpdateRelationshipRequest.java` | NEW | |
| Client | `client/ConnectionServiceClient.java` | MODIFY | New gRPC methods |

### New REST Endpoints

| Method | Path | Description |
|:------:|------|-------------|
| GET | `/api/v1/family-groups` | Get user's family group info |
| DELETE | `/api/v1/family-groups/members/:memberId` | Admin remove member |
| PUT | `/api/v1/connections/:contactId/revoke` | Tắt quyền theo dõi |
| PUT | `/api/v1/connections/:contactId/restore` | Mở lại quyền theo dõi |
| PUT | `/api/v1/connections/:contactId/relationship` | Update MQH |
| POST | `/api/v1/family-groups/leave` | Non-Admin rời nhóm |

### Updated Endpoints

| Method | Path | Change |
|:------:|------|--------|
| POST | `/api/v1/connections/invite` | Simplified: phone only, Admin-only |
| POST | `/api/v1/connections/invites/:id/accept` | Auto-connect response |
| ~~DELETE~~ | ~~`/api/v1/connections/:id`~~ | **DEPRECATED** → use revoke/remove |

> ⚠️ ARCH-001: api-gateway-service is THIN — no business logic. All logic delegated to user-service via gRPC.

---

## Service: payment-service

### Impact Level: 🟡 MEDIUM

### Code Changes Required

| Layer | File | Type | Description |
|-------|------|------|-------------|
| gRPC | `grpc/PaymentServiceGrpcImpl.java` | MODIFY | Ensure GetSubscription returns slot info |
| Service | `service/SubscriptionService.java` | VERIFY | Slot count/availability queries |

### Integration Points

| Service | Protocol | Direction | Purpose |
|---------|----------|:---------:|---------|
| user-service | gRPC | Inbound | GetSubscription, slot validation |
| user-service | gRPC | Outbound | SyncMembers (optional) |

### Key Requirements
- `GetSubscription` RPC must return: package_name, total_patient_slots, total_caregiver_slots, used_slots, expiry_date
- Slot race condition prevention (pessimistic locking or versioned updates)
- Subscription expiry → block new invites (BR-037)

---

## Service: schedule-service

### Impact Level: 🟡 MEDIUM

### Code Changes Required

| Layer | File | Type | Description |
|-------|------|------|-------------|
| Task | `tasks/member_broadcast_task.py` | NEW | Push notification to group members |
| Consumer | `consumers/connection_events.py` | MODIFY | Handle new Kafka events |

### Kafka Events Consumed

| Topic | Event | Action |
|-------|-------|--------|
| `connection.member.accepted` | New member joined | Push to ALL existing members (BR-052) |
| `connection.member.removed` | Member removed/left | Push to removed member |
| `connection.invite.created` | New invite sent | Push + ZNS to invitee |

### Key Requirements
- Member broadcast: push to all group members except new member + Admin (BR-052)
- Respect notification preferences
- ZNS template management for `add_patient`, `add_caregiver`

---

## Service: auth-service

### Impact Level: 🟢 LOW

### Code Changes Required

| Layer | File | Type | Description |
|-------|------|------|-------------|
| UseCase | `usecase/AuthUseCase.java` | VERIFY | backfillPendingInviteReceiverIds existing |

### Key Requirements
- Existing: After OTP verify → backfill `receiver_id` on pending invites matching phone
- No new code needed, verify existing logic handles `add_patient`/`add_caregiver` types
- Fire-and-forget with warning logging (existing pattern)

---

## Cross-Service Communication Map

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
