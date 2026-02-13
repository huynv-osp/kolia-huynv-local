# Service Decomposition: KOLIA-1517 - Kết nối Người thân

> **Phase:** 2 - Architecture Planning  
> **Date:** 2026-02-13  
> **SRS Version:** v4.0  
> **Revision:** v4.0 - 5-service architecture (was 3)

---

## Overview

| Service | Impact | Effort | v4.0 Δ |
|---------|:------:|:------:|:------:|
| user-service | 🔴 HIGH | ~30h | Major: Family Group, auto-connect, soft disconnect |
| api-gateway-service | 🔴 HIGH | ~20h | +6 new endpoints, deprecated DELETE |
| payment-service | 🟡 MEDIUM | ~10h | ⚠️ NEW: Slot check, GetSubscription |
| schedule-service | 🟡 MEDIUM | ~10h | Member broadcast, new Kafka events |
| auth-service | 🟢 LOW | ~5h | ⚠️ NEW: Verify backfill for new invite types |
| **Total Backend** | | **~75-80h** | |

---

## 1. user-service (🔴 HIGH)

### 1.1 Code Changes

| Layer | File/Path | Type | Description |
|-------|-----------|:----:|-------------|
| Entity | `entity/FamilyGroup.java` | NEW | Family group entity: admin_user_id, subscription_id, name, status |
| Entity | `entity/FamilyGroupMember.java` | NEW | Group membership: user_id (UNIQUE), role, status |
| Entity | `entity/UserEmergencyContact.java` | MODIFY | +permission_revoked BOOLEAN, +family_group_id UUID FK |
| Entity | `entity/ConnectionInvite.java` | MODIFY | invite_type enum: `add_patient`/`add_caregiver` |
| Repository | `repository/FamilyGroupRepository.java` | NEW | findByAdminUserId, findBySubscriptionId |
| Repository | `repository/FamilyGroupMemberRepository.java` | NEW | findByUserId, findByFamilyGroupId, existsByUserId |
| Service | `service/FamilyGroupService.java` | NEW | Group lifecycle: create, addMember, removeMember, getGroup |
| Service | `service/ConnectionService.java` | MODIFY | Admin-only invite, auto-connect, slot pre-check, soft disconnect |
| gRPC | `grpc/ConnectionServiceGrpcImpl.java` | MODIFY | New RPCs: CreateFamilyGroup, GetFamilyGroup, RemoveMember, RevokePermission, RestorePermission, UpdateRelationship, LeaveGroup |
| Client | `client/PaymentServiceClient.java` | NEW | gRPC client → payment-service GetSubscription |
| Config | `config/PaymentServiceConfig.java` | NEW | gRPC channel config for payment-service |

### 1.2 Database Changes

| Table | Change | SQL |
|-------|--------|-----|
| `family_groups` | CREATE | id, admin_user_id, subscription_id, name, status, created_at, updated_at |
| `family_group_members` | CREATE | id, family_group_id, user_id, role, status, joined_at, created_at |
| `user_emergency_contacts` | ALTER ADD | permission_revoked BOOLEAN DEFAULT false |
| `user_emergency_contacts` | ALTER ADD | family_group_id UUID REFERENCES family_groups(id) |
| `connection_invites` | ALTER CHECK | invite_type IN ('add_patient', 'add_caregiver') |

### 1.3 Key Business Logic

| Logic | BR Reference | Complexity |
|-------|:-------------|:----------:|
| Admin-only invite validation | BR-041 | Medium |
| Slot pre-check via payment gRPC | BR-033 | High |
| Auto-connect on CG accept | BR-045 | High |
| Soft disconnect (permission_revoked) | BR-040 | Medium |
| Exclusive group constraint | BR-057 | Medium |
| Leave group with slot release | BR-061 | Medium |
| Admin self-add auto-accept | BR-049 | Low |
| Dual-role support | BR-048 | Medium |

### 1.4 Integration Points

| Target | Protocol | Direction | Purpose |
|--------|----------|:---------:|---------|
| payment-service | gRPC | Outbound | GetSubscription, slot validation |
| schedule-service | Kafka | Outbound | member.accepted, member.removed, invite.created |
| auth-service | gRPC | Inbound | Backfill receiver_id |
| api-gateway-service | gRPC | Inbound | All REST→gRPC routing |

---

## 2. api-gateway-service (🔴 HIGH)

### 2.1 Code Changes

| Layer | File/Path | Type | Description |
|-------|-----------|:----:|-------------|
| Handler | `handler/FamilyGroupHandler.java` | NEW | REST handlers for /family-groups |
| Handler | `handler/ConnectionHandler.java` | MODIFY | Simplified invite, revoke/restore, relationship |
| DTO | `dto/request/CreateInviteRequest.java` | MODIFY | Simplified: phone only (removed name, relationship, permissions) |
| DTO | `dto/request/RemoveMemberRequest.java` | NEW | memberId |
| DTO | `dto/request/RevokePermissionRequest.java` | NEW | contactId |
| DTO | `dto/request/UpdateRelationshipRequest.java` | NEW | contactId, relationship_code |
| DTO | `dto/response/FamilyGroupResponse.java` | NEW | Group info + package + slots |
| Client | `client/ConnectionServiceClient.java` | MODIFY | Add new gRPC method stubs |

### 2.2 REST Endpoints

#### New Endpoints (6)

| Method | Path | Auth | Handler |
|:------:|------|:----:|---------|
| GET | `/api/v1/family-groups` | User | FamilyGroupHandler |
| DELETE | `/api/v1/family-groups/members/:memberId` | Admin | FamilyGroupHandler |
| PUT | `/api/v1/connections/:contactId/revoke` | Patient | ConnectionHandler |
| PUT | `/api/v1/connections/:contactId/restore` | Patient | ConnectionHandler |
| PUT | `/api/v1/connections/:contactId/relationship` | CG | ConnectionHandler |
| POST | `/api/v1/family-groups/leave` | Non-Admin | FamilyGroupHandler |

#### Modified Endpoints

| Method | Path | Change |
|:------:|------|--------|
| POST | `/api/v1/connections/invite` | Simplified body (phone only), Admin-only auth |
| POST | `/api/v1/connections/invites/:id/accept` | Auto-connect response shape |

#### Deprecated Endpoints

| Method | Path | Replacement |
|:------:|------|-------------|
| ~~DELETE~~ | ~~`/api/v1/connections/:id`~~ | Use revoke (Patient) or remove (Admin) |

> ⚠️ **ARCH-001:** api-gateway-service is THIN — no business logic. All logic delegated to user-service via gRPC.

---

## 3. payment-service (🟡 MEDIUM) — NEW v4.0

### 3.1 Code Changes

| Layer | File/Path | Type | Description |
|-------|-----------|:----:|-------------|
| gRPC | `grpc/PaymentServiceGrpcImpl.java` | VERIFY | GetSubscription returns slot info |
| Service | `service/SubscriptionService.java` | VERIFY | Slot count/availability queries |

### 3.2 gRPC Interface

**GetSubscription Response must include:**
- `package_name` — Tên gói
- `total_patient_slots` — Tổng slot người bệnh
- `total_caregiver_slots` — Tổng slot người thân
- `used_patient_slots` — Slot đã dùng
- `used_caregiver_slots` — Slot đã dùng
- `expiry_date` — Ngày hết hạn
- `is_expired` — Boolean

### 3.3 Key Requirements

| Requirement | BR | Priority |
|-------------|:--:|:--------:|
| Slot race condition prevention | BR-033 | P0 |
| Subscription expiry → block invites | BR-037 | P0 |
| Slot release on disconnect/leave | BR-036 | P0 |

---

## 4. schedule-service (🟡 MEDIUM)

### 4.1 Code Changes

| Layer | File/Path | Type | Description |
|-------|-----------|:----:|-------------|
| Task | `tasks/member_broadcast_task.py` | NEW | Push to all group members |
| Consumer | `consumers/connection_events.py` | MODIFY | Handle new Kafka events |
| Template | `templates/invite_zns.py` | MODIFY | ZNS for `add_patient`, `add_caregiver` |

### 4.2 Kafka Events Consumed

| Topic | Event | Action |
|-------|-------|--------|
| `connection.invite.created` | New invite sent | ZNS + Push to invitee |
| `connection.member.accepted` | New member joined | Push to ALL existing members (BR-052) |
| `connection.member.removed` | Member removed/left | Push to removed member |

### 4.3 Notification Templates

| invite_type | ZNS Content |
|-------------|-------------|
| `add_patient` | "{Tên Admin} mời bạn vào nhóm gia đình với vai trò Người bệnh" |
| `add_caregiver` | "{Tên Admin} mời bạn vào nhóm gia đình với vai trò Người thân" |

---

## 5. auth-service (🟢 LOW) — NEW v4.0

### 5.1 Code Changes

| Layer | File/Path | Type | Description |
|-------|-----------|:----:|-------------|
| UseCase | `usecase/AuthUseCase.java` | VERIFY | backfillPendingInviteReceiverIds |

### 5.2 Key Verification

- Existing `backfillPendingInviteReceiverIds` runs after OTP verify
- Must handle both `add_patient` and `add_caregiver` invite_type values
- Fire-and-forget pattern with warning logging (existing)
- No new code expected — only verification needed

---

## 6. Cross-Service Communication

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
- [FA Context Mapping v4.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/features/ket_noi_nguoi_than/01_analysis/context-mapping.md)
