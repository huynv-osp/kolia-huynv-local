# Task Breakdown: KOLIA-1517 - Kết nối Người thân

> **Phase:** 4 - Output  
> **Date:** 2026-02-13  
> **SRS Version:** v4.0  
> **Revision:** v4.0 - 20 tasks, ~80h, 5 services

---

## Summary

| Category | Tasks | Effort | Services |
|----------|:-----:|:------:|:--------:|
| Database & Foundation | 3 | 12h | user-service |
| Core Business Logic | 5 | 18h | user-service |
| API Layer | 4 | 20h | api-gateway |
| Cross-Service Integration | 4 | 15h | payment, schedule, auth |
| Testing & Verification | 4 | 15h | All |
| **Total** | **20** | **~80h** | **5** |

---

## Database & Foundation (3 tasks, ~12h)

### TASK-001: Database Migration
- **Service:** user-service | **Effort:** 4h | **Priority:** P0
- **Deliverables:**
  - CREATE TABLE `family_groups`
  - CREATE TABLE `family_group_members` (UNIQUE user_id)
  - ALTER `user_emergency_contacts` (+permission_revoked, +family_group_id)
  - ALTER `connection_invites` CHECK constraint (invite_type)
  - Rollback script
  - Data migration for existing invite_type values

### TASK-002: Family Group Entities & Repositories
- **Service:** user-service | **Effort:** 4h | **Priority:** P0
- **Depends:** TASK-001
- **Deliverables:**
  - `FamilyGroup.java`, `FamilyGroupMember.java` entities
  - `FamilyGroupRepository.java`, `FamilyGroupMemberRepository.java`
  - `UserEmergencyContact.java` updated (new fields)
  - `ConnectionInvite.java` updated (invite_type enum)

### TASK-003: Family Group Service
- **Service:** user-service | **Effort:** 4h | **Priority:** P0
- **Depends:** TASK-002
- **Deliverables:**
  - `FamilyGroupService.java` — createGroup, addMember, removeMember, getGroup, leaveGroup
  - Exclusive group validation (BR-057)
  - Slot release integration (BR-036)

---

## Core Business Logic (5 tasks, ~18h)

### TASK-004: Admin-Only Invite
- **Service:** user-service | **Effort:** 3h | **Priority:** P0
- **Depends:** TASK-003
- **Deliverables:**
  - Admin role validation in ConnectionService (BR-041)
  - Admin self-add auto-accept (BR-049)
  - Phone-only invite (BR-055, no MQH, no permissions config)

### TASK-005: Payment Service Client
- **Service:** user-service | **Effort:** 3h | **Priority:** P0
- **Depends:** TASK-002
- **Deliverables:**
  - `PaymentServiceClient.java` — gRPC client
  - `PaymentServiceConfig.java` — channel config
  - Slot pre-check logic (BR-033, BR-059)
  - Graceful fallback for payment unavailability

### TASK-006: Auto-Connect
- **Service:** user-service | **Effort:** 4h | **Priority:** P0
- **Depends:** TASK-004, TASK-005
- **Deliverables:**
  - CG accept → auto-create connections to ALL patients (BR-045)
  - Patient accept → auto-connect with ALL existing CGs
  - Transaction-based, rollback on failure
  - Kafka event: `connection.member.accepted`

### TASK-007: Soft Disconnect
- **Service:** user-service | **Effort:** 4h | **Priority:** P0
- **Depends:** TASK-002
- **Deliverables:**
  - Revoke: permission_revoked=true, ALL permissions OFF (BR-040)
  - Restore: ≥1 permission ON → permission_revoked=false
  - Silent operation, no notification (BR-056)
  - Connection status unchanged

### TASK-008: Leave & Remove
- **Service:** user-service | **Effort:** 4h | **Priority:** P0
- **Depends:** TASK-003, TASK-005
- **Deliverables:**
  - Non-Admin leave group (BR-061)
  - Admin remove member (BR-058, cannot remove self)
  - Slot release + connection cancellation
  - Kafka event: `connection.member.removed`

---

## API Layer (4 tasks, ~20h)

### TASK-009: Family Group Endpoints
- **Service:** api-gateway | **Effort:** 6h | **Priority:** P0
- **Depends:** TASK-003
- **Deliverables:**
  - `FamilyGroupHandler.java`
  - GET /family-groups, DELETE /members/:id, POST /leave
  - FamilyGroupResponse DTO

### TASK-010: Connection Endpoints Update
- **Service:** api-gateway | **Effort:** 6h | **Priority:** P0
- **Depends:** TASK-004, TASK-007
- **Deliverables:**
  - Simplified POST /invite (phone only)
  - PUT /revoke, PUT /restore, PUT /relationship
  - Updated AcceptResponse with auto-connect info

### TASK-011: Deprecated DELETE Endpoint
- **Service:** api-gateway | **Effort:** 2h | **Priority:** P1
- **Depends:** TASK-010
- **Deliverables:**
  - DELETE /connections/:id → 410 GONE
  - Swagger deprecation notice
  - Feature flag for gradual removal

### TASK-012: DTO & Proto Updates
- **Service:** api-gateway | **Effort:** 6h | **Priority:** P0
- **Depends:** TASK-009, TASK-010
- **Deliverables:**
  - CreateInviteRequest simplified
  - RemoveMemberRequest, RevokePermissionRequest, UpdateRelationshipRequest
  - Proto file updates for all new gRPC methods

---

## Cross-Service Integration (4 tasks, ~15h)

### TASK-013: Member Broadcast (schedule-service)
- **Effort:** 5h | **Priority:** P0 | **Depends:** TASK-006
- **Deliverables:**
  - `member_broadcast_task.py` — push to ALL members (BR-052)
  - Kafka consumer for `connection.member.accepted/removed`
  - Exclude new member + Admin from broadcast

### TASK-014: ZNS Templates (schedule-service)
- **Effort:** 3h | **Priority:** P0 | **Depends:** TASK-004
- **Deliverables:**
  - Template `add_patient`: "{Admin} mời bạn... Người bệnh"
  - Template `add_caregiver`: "{Admin} mời bạn... Người thân"
  - ZNS → SMS fallback (BR-004)

### TASK-015: Auth Backfill Verification (auth-service)
- **Effort:** 2h | **Priority:** P1 | **Depends:** TASK-001
- **Deliverables:**
  - Verify backfillPendingInviteReceiverIds handles `add_patient`/`add_caregiver`
  - No regression test

### TASK-016: Payment GetSubscription Verify (payment-service)
- **Effort:** 5h | **Priority:** P0 | **Depends:** None
- **Deliverables:**
  - GetSubscription returns slot info (total, used, expiry)
  - Pessimistic locking for slot race condition

---

## Testing & Verification (4 tasks, ~15h)

### TASK-017: Unit Tests
- **Effort:** 5h | **Priority:** P0
- Admin invite validation, auto-connect, soft disconnect, exclusive group, slots

### TASK-018: Integration Tests
- **Effort:** 5h | **Priority:** P0
- E2E invite flow, payment integration, notification delivery, leave group

### TASK-019: Regression Tests
- **Effort:** 3h | **Priority:** P0
- SOS contact unchanged, existing connections, profile selector, dashboard permissions

### TASK-020: Data Migration Tests
- **Effort:** 2h | **Priority:** P0
- invite_type migration, rollback script, data integrity

---

## References

- [FA Implementation Tasks v4.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/features/ket_noi_nguoi_than/02_planning/implementation-tasks.md)
- [FA Service Decomposition v4.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/features/ket_noi_nguoi_than/02_planning/service-decomposition.md)
