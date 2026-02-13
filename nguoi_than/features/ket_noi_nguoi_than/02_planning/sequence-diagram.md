# Sequence Diagrams: KOLIA-1517 - Kết nối Người thân

> **Phase:** 2 - Architecture Planning  
> **Date:** 2026-02-13  
> **SRS Version:** v4.0  
> **Revision:** v4.0 - Admin-only flows, auto-connect, soft disconnect, leave group

---

## 1. Send Invite (Admin-Only) — v4.0

```mermaid
sequenceDiagram
    participant Admin as Admin (Mobile)
    participant GW as api-gateway
    participant US as user-service
    participant PS as payment-service
    participant SS as schedule-service
    participant R as Recipient

    Admin->>GW: POST /connections/invite {phone, type}
    GW->>US: gRPC CreateInvite
    
    Note over US: Validate: sender is Admin (BR-041)
    alt Sender is NOT Admin
        US-->>GW: Error: NOT_ADMIN
        GW-->>Admin: 403 Forbidden
    end

    US->>PS: gRPC GetSubscription
    PS-->>US: {slots, expiry}
    
    alt Package expired (BR-037)
        US-->>GW: Error: PACKAGE_EXPIRED
        GW-->>Admin: 400 "Gói đã hết hạn"
    end
    
    alt Slot full (BR-059)
        US-->>GW: Error: SLOT_FULL
        GW-->>Admin: 400 "Đã đạt giới hạn"
    end

    Note over US: Check exclusive group (BR-057)
    alt Recipient in another group
        US-->>GW: Error: ALREADY_IN_GROUP
        GW-->>Admin: 400 "Người này đã tham gia nhóm khác"
    end

    US->>US: Create invite (status=pending, consume slot)
    US-->>GW: InviteCreated
    GW-->>Admin: 200 "Đã gửi lời mời"
    
    US-)SS: Kafka: connection.invite.created
    
    alt Recipient has Kolia account
        SS->>R: ZNS + Push Notification
    else Recipient is new
        SS->>R: ZNS with Deep Link
    end
```

---

## 2. Accept Invite + Auto-Connect — v4.0

```mermaid
sequenceDiagram
    participant User as Recipient (Mobile)
    participant GW as api-gateway
    participant US as user-service
    participant PS as payment-service
    participant SS as schedule-service

    User->>GW: POST /connections/invites/:id/accept
    GW->>US: gRPC AcceptInvite

    Note over US: Update invite status → accepted

    alt invite_type = add_caregiver (BR-045)
        US->>US: Find ALL patients in family_group
        loop Each Patient in group
            US->>US: Create connection (CG→Patient, ALL ON)
        end
        Note over US: Auto-connect: CG follows ALL patients
    else invite_type = add_patient
        US->>US: Create connections with ALL existing CGs
        Note over US: All CGs auto-follow new Patient
    end

    US->>US: Add to family_group_members
    US-->>GW: AcceptResult {connections_created: N}
    GW-->>User: 200 "Đã kết nối"

    US-)SS: Kafka: connection.member.accepted
    SS->>SS: Push to ALL existing members (BR-052)
    SS-->>SS: "👋 {Tên} đã vào nhóm"
```

---

## 3. Reject Invite — v4.0

```mermaid
sequenceDiagram
    participant User as Recipient (Mobile)
    participant GW as api-gateway
    participant US as user-service
    participant SS as schedule-service

    User->>GW: POST /connections/invites/:id/reject
    GW->>US: gRPC RejectInvite
    US->>US: Update invite status → rejected
    US->>US: Release slot (BR-036)
    US-->>GW: RejectResult
    GW-->>User: 200 "Đã từ chối"
    
    US-)SS: Kafka: notify Admin
    SS-->>SS: Push to Admin: "{Tên} đã từ chối"
```

---

## 4. Permission Revoke (Tắt quyền theo dõi) — v4.0

```mermaid
sequenceDiagram
    participant P as Patient (Mobile)
    participant GW as api-gateway
    participant US as user-service

    P->>GW: PUT /connections/:contactId/revoke
    GW->>US: gRPC RevokePermission
    
    US->>US: Set ALL 5 permissions OFF
    US->>US: Set permission_revoked = true
    Note over US: Connection status unchanged (active)
    Note over US: NO notification to CG (BR-056)
    
    US-->>GW: RevokeResult
    GW-->>P: 200 "Đã tắt quyền theo dõi"
    
    Note over P: Patient UI: badge "🚫 Bị tắt quyền theo dõi"
    Note over US: CG UI: Patient disappears from list
```

---

## 5. Permission Restore (Mở lại quyền) — v4.0

```mermaid
sequenceDiagram
    participant P as Patient (Mobile)
    participant GW as api-gateway
    participant US as user-service

    P->>GW: PUT /connections/:contactId/restore
    GW->>US: gRPC RestorePermission
    
    Note over P: Patient navigates to SCR-05, toggles permissions ON
    US->>US: Update individual permissions
    
    alt At least 1 permission ON
        US->>US: Set permission_revoked = false
    end
    
    Note over US: NO notification to CG (BR-056)
    US-->>GW: RestoreResult
    GW-->>P: 200 "Đã mở lại quyền"
    
    Note over US: CG UI: Patient reappears in list
```

---

## 6. Leave Group (Non-Admin) — v4.0

```mermaid
sequenceDiagram
    participant User as Member (Mobile)
    participant GW as api-gateway
    participant US as user-service
    participant PS as payment-service
    participant SS as schedule-service

    User->>GW: POST /family-groups/leave
    GW->>US: gRPC LeaveGroup
    
    Note over US: Validate: user is NOT Admin (BR-058)
    
    US->>US: Cancel all connections
    US->>US: Remove from family_group_members
    US->>PS: Release slot(s) (BR-036)
    
    US-->>GW: LeaveResult
    GW-->>User: 200 "Bạn đã rời khỏi nhóm"
    
    US-)SS: Kafka: connection.member.removed
    SS-->>SS: Push to Admin: "{Tên} đã rời khỏi nhóm"
```

---

## 7. Admin Remove Member — v4.0

```mermaid
sequenceDiagram
    participant A as Admin (Mobile)
    participant GW as api-gateway
    participant US as user-service
    participant PS as payment-service
    participant SS as schedule-service

    A->>GW: DELETE /family-groups/members/:memberId
    GW->>US: gRPC RemoveMember
    
    Note over US: Validate: sender is Admin
    Note over US: Validate: target ≠ Admin (BR-058)
    
    US->>US: Cancel all connections of target
    US->>US: Remove from family_group_members
    US->>PS: Release slot(s) (BR-036)
    
    US-->>GW: RemoveResult
    GW-->>A: 200 "Đã xoá {Tên} khỏi nhóm"
    
    US-)SS: Kafka: connection.member.removed
    SS-->>SS: Push to removed member: "Bạn đã bị xoá khỏi nhóm"
```

---

## 8. Admin Self-Add — v4.0

```mermaid
sequenceDiagram
    participant A as Admin (Mobile)
    participant GW as api-gateway
    participant US as user-service

    A->>GW: POST /connections/invite {phone: self, type}
    GW->>US: gRPC CreateInvite
    
    Note over US: Detect self-invite from Admin (BR-049)
    
    alt Adding as Patient (P-slot)
        US->>US: Auto-accept, create connection immediately
        US->>US: Add to family_group_members as PATIENT
    else Adding as Caregiver (CG-slot)
        US->>US: Check ≥1 Patient exists in group (BR-048)
        alt No other Patient
            US-->>GW: Error: NEED_PATIENT_FIRST
            GW-->>A: 400 "Cần có ít nhất 1 Người bệnh khác"
        else Has Patient
            US->>US: Auto-accept, auto-connect to ALL patients
        end
    end
    
    US-->>GW: SelfAddResult
    GW-->>A: 200 "Đã thêm thành công"
```

---

## 9. Update Relationship (MQH) — v5.2

```mermaid
sequenceDiagram
    participant CG as Caregiver (Mobile)
    participant GW as api-gateway
    participant US as user-service

    CG->>GW: PUT /connections/:contactId/relationship {code: "me"}
    GW->>US: gRPC UpdateRelationship
    
    US->>US: Validate relationship_code in enum
    US->>US: Update user_emergency_contacts.relationship_code
    
    US-->>GW: UpdateResult
    GW-->>CG: 200 "Đã cập nhật mối quan hệ"
```

---

## 10. State Machines

### 10.1 Invite Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Pending: Admin sends invite
    Pending --> Accepted: Recipient accepts
    Pending --> Rejected: Recipient rejects
    Pending --> Cancelled: Admin/Sender cancels
    Accepted --> [*]: Connection(s) created + auto-connect
    Rejected --> [*]: Slot released, can re-invite
    Cancelled --> [*]: Slot released
```

### 10.2 Connection Lifecycle — v4.0

```mermaid
stateDiagram-v2
    [*] --> Active: Accept invite (auto-connect)
    Active --> Revoked: Patient tắt quyền (BR-040)
    Revoked --> Active: Patient mở lại quyền
    Active --> Removed: Admin remove OR Leave group
    Revoked --> Removed: Admin remove OR Leave group
    Removed --> [*]: Slot released
    
    note right of Revoked
        connection.status = active
        permission_revoked = true
        ALL permissions OFF
        CG cannot see Patient
    end note
```

### 10.3 Slot Lifecycle — v4.0

```mermaid
stateDiagram-v2
    [*] --> Available: Package activated
    Available --> Pending: Invite sent (BR-033)
    Pending --> Consumed: Invite accepted
    Pending --> Available: Invite rejected/cancelled (BR-036)
    Consumed --> Available: Member removed/left (BR-036)
```

---

## References

- [SRS v4.0 §6](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/srs_input_documents/srs_nguoi_than_nhom_gia_dinh.md) — Flow Diagrams
- [SA Service Mapping v4.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/ket_noi_nguoi_than/04_mapping/service_mapping.md)
