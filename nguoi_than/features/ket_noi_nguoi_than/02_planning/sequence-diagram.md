# Sequence Diagrams: KOLIA-1517 - Kết nối Người thân

> **Feature:** Connection Flow (Patient ↔ Caregiver)  
> **Date:** 2026-01-28

---

## 1. Send Invite Flow

```mermaid
sequenceDiagram
    autonumber
    participant User as Patient/Caregiver
    participant App as Mobile App
    participant GW as api-gateway
    participant US as user-service
    participant DB as PostgreSQL
    participant Kafka as Kafka
    participant SCH as schedule-service
    participant ZNS as ZNS/SMS

    User->>App: Nhập SĐT + Nhấn "Gửi lời mời"
    App->>GW: POST /api/v1/invites
    Note over GW: InviteHandler.createInvite()
    
    GW->>US: gRPC CreateInvite()
    Note over US: InviteService.createInvite()
    
    US->>DB: Check sender != receiver (BR-006)
    DB-->>US: Validation OK
    
    US->>DB: Check no pending invite (BR-007)
    DB-->>US: Validation OK
    
    US->>DB: Check phone exists?
    alt User exists
        DB-->>US: receiver_id = {uuid}
    else User not exists
        DB-->>US: receiver_id = NULL
    end
    
    US->>DB: INSERT connection_invites
    DB-->>US: invite_id = {uuid}
    
    US->>Kafka: Publish connection.invite.created
    
    US-->>GW: InviteResponse
    GW-->>App: 201 Created
    App-->>User: "Đã gửi lời mời thành công"
    
    Note over Kafka,SCH: Async Processing
    Kafka-->>SCH: connection.invite.created
    SCH->>SCH: send_invite_notification task
    
    alt ZNS Success
        SCH->>ZNS: Send ZNS notification
        ZNS-->>SCH: Success
        SCH->>DB: UPDATE invite_notifications SET status=2
    else ZNS Failed
        SCH->>ZNS: Send SMS (fallback)
        Note over SCH: Retry up to 3x, 30s interval (BR-004)
    end
```

---

## 2. Accept Invite Flow (Caregiver accepts Patient invite)

```mermaid
sequenceDiagram
    autonumber
    participant CG as Caregiver
    participant App as Mobile App
    participant GW as api-gateway
    participant US as user-service
    participant DB as PostgreSQL
    participant Kafka as Kafka

    CG->>App: Tap ✓ Accept on invite
    App->>GW: POST /api/v1/invites/{id}/accept
    Note over GW: InviteHandler.acceptInvite()
    
    GW->>US: gRPC AcceptInvite()
    Note over US: ConnectionService.acceptInvite()
    
    rect rgb(240, 248, 255)
        Note over US,DB: Transaction Start
        
        US->>DB: UPDATE connection_invites SET status=1
        DB-->>US: OK
        
        US->>DB: INSERT user_connections
        Note over US,DB: patient_id, caregiver_id, relationship
        DB-->>US: connection_id = {uuid}
        
        US->>DB: Trigger creates 6 permissions (BR-009)
        Note over DB: create_default_connection_permissions()
        DB-->>US: 6 permissions created
        
        Note over US,DB: Transaction Commit
    end
    
    US->>Kafka: Publish connection.status.changed
    
    US-->>GW: ConnectionResponse
    GW-->>App: 200 OK
    App-->>CG: "Đã kết nối với {Tên}"
    
    Note over Kafka: Notify Patient
    Kafka-->>Kafka: Push to Patient: "{Tên} đã chấp nhận"
```

---

## 3. Accept Invite Flow (Patient accepts Caregiver invite - with permission config)

```mermaid
sequenceDiagram
    autonumber
    participant PT as Patient
    participant App as Mobile App
    participant GW as api-gateway
    participant US as user-service
    participant DB as PostgreSQL
    participant Kafka as Kafka

    PT->>App: Tap ✓ Accept on invite
    App->>App: Navigate to SCR-02B-ACCEPT
    Note over App: Show 6 permission toggles (default ALL ON)
    
    PT->>App: Configure permissions + Tap "Xác nhận"
    App->>GW: POST /api/v1/invites/{id}/accept
    Note over GW: Body: {permissions: [...]}
    
    GW->>US: gRPC AcceptInvite(permissions)
    
    rect rgb(240, 248, 255)
        Note over US,DB: Transaction Start
        
        US->>DB: UPDATE connection_invites SET status=1
        
        US->>DB: INSERT user_connections
        DB-->>US: connection_id
        
        US->>DB: INSERT 6 connection_permissions
        Note over DB: Using permissions from request (not default)
        
        Note over US,DB: Transaction Commit
    end
    
    US->>Kafka: Publish connection.status.changed
    
    US-->>GW: ConnectionResponse
    GW-->>App: 200 OK
    App-->>PT: Navigate back to SCR-01
    
    Note over Kafka: Notify Caregiver
    Kafka-->>Kafka: Push to Caregiver: "{Tên} đã chấp nhận"
```

---

## 4. Reject Invite Flow

```mermaid
sequenceDiagram
    autonumber
    participant User as Patient/Caregiver
    participant App as Mobile App
    participant GW as api-gateway
    participant US as user-service
    participant DB as PostgreSQL
    participant Kafka as Kafka

    User->>App: Tap ✗ Reject on invite
    App->>GW: POST /api/v1/invites/{id}/reject
    
    GW->>US: gRPC RejectInvite()
    US->>DB: UPDATE connection_invites SET status=2
    DB-->>US: OK
    
    US->>Kafka: Publish connection.status.changed
    
    US-->>GW: InviteResponse
    GW-->>App: 200 OK
    App-->>User: "Đã từ chối lời mời"
    
    Note over Kafka: Notify Sender (BR-010)
    Kafka-->>Kafka: Push to Sender: "{Tên} đã từ chối"
```

---

## 5. Update Permission Flow

```mermaid
sequenceDiagram
    autonumber
    participant PT as Patient
    participant App as Mobile App
    participant GW as api-gateway
    participant US as user-service
    participant DB as PostgreSQL
    participant Kafka as Kafka
    participant CG as Caregiver App

    PT->>App: Navigate to Quyền truy cập (SCR-05)
    App->>GW: GET /api/v1/connections/{id}/permissions
    GW->>US: gRPC GetPermissions()
    US->>DB: SELECT FROM connection_permissions
    DB-->>US: 6 permission flags
    US-->>GW: PermissionsResponse
    GW-->>App: Current permissions
    
    PT->>App: Toggle permission OFF
    App->>App: Show confirmation popup (BR-024)
    
    alt Emergency Alert toggle OFF
        App->>App: Show RED warning popup (BR-018)
        Note over App: "Nếu tắt, {Tên} sẽ KHÔNG nhận cảnh báo nguy hiểm"
    end
    
    PT->>App: Confirm "Xác nhận"
    App->>GW: PUT /api/v1/connections/{id}/permissions
    Note over GW: Body: {permission_type, is_enabled: false}
    
    GW->>US: gRPC UpdatePermissions()
    US->>DB: UPDATE connection_permissions SET is_enabled=false
    DB-->>US: OK
    
    US->>Kafka: Publish connection.permission.changed
    
    US-->>GW: PermissionsResponse
    GW-->>App: Updated permissions
    App-->>PT: "Đã tắt quyền {Tên quyền}"
    
    Note over Kafka,CG: Real-time update (BR-017)
    Kafka-->>CG: Push: "Quyền của bạn đã thay đổi"
    CG->>CG: Hide corresponding UI block
```

---

## 6. Disconnect Flow

```mermaid
sequenceDiagram
    autonumber
    participant User as Patient/Caregiver
    participant App as Mobile App
    participant GW as api-gateway
    participant US as user-service
    participant DB as PostgreSQL
    participant Kafka as Kafka
    participant Other as Other Party App

    User->>App: Tap ❌ Hủy kết nối / Ngừng theo dõi
    App->>App: Show confirmation popup
    User->>App: Confirm "Hủy kết nối"
    
    App->>GW: DELETE /api/v1/connections/{id}
    
    GW->>US: gRPC Disconnect()
    
    rect rgb(255, 240, 240)
        Note over US,DB: Soft Delete
        US->>DB: UPDATE user_connections SET status=0
        Note over DB: Permissions remain but connection inactive
        DB-->>US: OK
    end
    
    US->>Kafka: Publish connection.status.changed
    
    US-->>GW: ConnectionResponse
    GW-->>App: 200 OK
    App-->>User: "Đã hủy kết nối với {Tên}"
    
    Note over Kafka,Other: Notify other party (BR-019/BR-020)
    Kafka-->>Other: Push: "{Tên} đã hủy kết nối"
    Other->>Other: Remove from connection list
```

---

## 7. List Connections Flow

```mermaid
sequenceDiagram
    autonumber
    participant User as Patient/Caregiver
    participant App as Mobile App
    participant GW as api-gateway
    participant US as user-service
    participant DB as PostgreSQL

    User->>App: Open "Kết nối Người thân" (SCR-01)
    
    par Fetch connections
        App->>GW: GET /api/v1/connections
        GW->>US: gRPC ListConnections()
        US->>DB: SELECT FROM user_connections WHERE status=1
        Note over DB: Join with users for names, avatars, last_active
        DB-->>US: List of connections
        US-->>GW: ListConnectionsResponse
        GW-->>App: Connections grouped by role
    and Fetch pending invites
        App->>GW: GET /api/v1/invites?status=pending
        GW->>US: gRPC ListInvites()
        US->>DB: SELECT FROM connection_invites WHERE status=0
        DB-->>US: List of pending invites
        US-->>GW: ListInvitesResponse
        GW-->>App: Pending invites
    end
    
    App->>App: Render UI
    Note over App: Section 1: Tôi đang theo dõi
    Note over App: Section 2: Người đang theo dõi tôi
    Note over App: Block: Lời mời mới (if pending)
```

---

## 8. ZNS Fallback Flow (Async)

```mermaid
sequenceDiagram
    autonumber
    participant Kafka as Kafka
    participant SCH as schedule-service
    participant ZNS as Zalo ZNS
    participant SMS as SMS Gateway
    participant DB as PostgreSQL

    Kafka->>SCH: connection.invite.created
    SCH->>SCH: send_invite_notification task
    
    SCH->>DB: INSERT invite_notifications (channel=ZNS, status=0)
    
    SCH->>ZNS: Send ZNS message
    
    alt ZNS Success
        ZNS-->>SCH: 200 OK
        SCH->>DB: UPDATE status=2 (delivered)
    else ZNS Failed (no Zalo account)
        ZNS-->>SCH: Error
        SCH->>DB: UPDATE status=3 (failed)
        
        loop Retry up to 3 times (BR-004)
            SCH->>SCH: Wait 30s
            SCH->>DB: INSERT invite_notifications (channel=SMS)
            SCH->>SMS: Send SMS with deep link
            
            alt SMS Success
                SMS-->>SCH: Delivered
                SCH->>DB: UPDATE status=2
                Note over SCH: Break loop
            else SMS Failed
                SMS-->>SCH: Error
                SCH->>DB: UPDATE status=3, retry_count++
            end
        end
    end
```

---

## State Machine: Invite Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Pending: User sends invite
    
    Pending --> Accepted: Recipient accepts
    Pending --> Rejected: Recipient rejects
    Pending --> Cancelled: Sender cancels
    
    Accepted --> [*]: Connection created
    Rejected --> [*]: Can re-invite later
    Cancelled --> [*]: Invite removed
    
    note right of Pending
        - Notification sent
        - Shows in recipient's list
        - Badge count updated
    end note
    
    note right of Accepted
        - Connection record created
        - 6 permissions initialized
        - Both parties notified
    end note
```

---

## State Machine: Connection Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Active: Invite accepted
    
    Active --> Disconnected: Either party disconnects
    
    Disconnected --> [*]: Soft delete complete
    
    note right of Active
        - Both can view each other
        - Permissions can be modified
        - Real-time data sync
    end note
    
    note right of Disconnected
        - No longer visible in lists
        - Historical data preserved
        - Can create new connection
    end note
```
