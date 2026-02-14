# 🔌 API Integration Tests - KOLIA-1517 Kết nối Người thân

> **Version:** 2.19  
> **Date:** 2026-02-04  
> **Coverage Target:** 100% Endpoints  
> **Total Test Cases:** ~139 (+9 Inverse Relationship v2.19)

---

## Table of Contents

1. [Invite APIs](#1-invite-apis)
2. [Connection APIs](#2-connection-apis)
3. [Permission APIs](#3-permission-apis)
4. [Lookup APIs](#4-lookup-apis)
5. [Profile Selection APIs](#5-profile-selection-apis)
6. [Dashboard APIs (v2.11)](#6-dashboard-apis-v211)
7. [Error Handling](#7-error-handling)
8. [End-to-End Scenarios](#8-end-to-end-scenarios)

---

# 1. Invite APIs

## 1.1 POST /api/v1/connections/invite - Create Invite

### Happy Path Tests

| Test ID | Scenario | Expected | BR | Priority |
|---------|----------|----------|:--:|:--------:|
| TC-INT-INV-001 | Patient mời Caregiver (existing user) | 201 Created, invite_id returned | BR-001 | 🔴 P0 |
| TC-INT-INV-002 | Caregiver mời Patient (existing user) | 201 Created, invite_id returned | BR-001 | 🔴 P0 |
| TC-INT-INV-003 | Patient mời Caregiver (new user) | 201 Created, invite_id returned | BR-003 | 🔴 P0 |
| TC-INT-INV-004 | Invite với 6 permissions configured | 201 Created, permissions saved | BR-009 | 🔴 P0 |
| TC-INT-INV-005 | Invite với relationship "con_trai" | 201, relationship stored | BR-028 | 🔴 P0 |
| TC-INT-INV-006 | Invite với relationship "khac" | 201, relationship stored | BR-028 | 🟡 P1 |

### Error Cases

| Test ID | Scenario | Expected | BR | Priority |
|---------|----------|----------|:--:|:--------:|
| TC-INT-INV-007 | Self invite (same phone) | 400 SELF_INVITE | BR-006 | 🔴 P0 |
| TC-INT-INV-008 | Duplicate pending invite | 400 DUPLICATE_PENDING | BR-007 | 🔴 P0 |
| TC-INT-INV-009 | Already connected | 400 ALREADY_CONNECTED | BR-007 | 🟡 P1 |
| TC-INT-INV-010 | Invalid phone format | 400 Validation Error | - | 🟡 P1 |
| TC-INT-INV-011 | Missing phone | 400 Validation Error | - | 🟡 P1 |
| TC-INT-INV-012 | Invalid relationship code | 400 Validation Error | BR-028 | 🟡 P1 |
| TC-INT-INV-013 | Invalid invite_type | 400 Validation Error | - | 🟡 P1 |
| TC-INT-INV-014 | Unauthorized (no token) | 401 Unauthorized | - | 🟡 P1 |

### Test Implementation

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class InviteApiIntegrationTest {

    @Autowired
    private WebTestClient webClient;
    
    @MockBean
    private ConnectionGrpcClient grpcClient;
    
    @Autowired
    private JwtTokenProvider tokenProvider;

    // TC-INT-INV-001: Patient invites Caregiver (existing user)
    @Test
    void testCreateInvite_PatientToCaregiver_ExistingUser_Success() {
        // Given
        String token = generatePatientToken();
        CreateInviteRequestDTO request = CreateInviteRequestDTO.builder()
            .receiverPhone("0912345678")
            .receiverName("Nguyễn Văn Caregiver")
            .relationship("con_trai")
            .inviteType("add_caregiver")
            .permissions(Map.of(
                "health_overview", true,
                "emergency_alert", true,
                "task_config", true,
                "compliance_tracking", true,
                "proxy_execution", true,
                "encouragement", true
            ))
            .build();
            
        when(grpcClient.createInvite(any())).thenReturn(
            InviteResponse.newBuilder()
                .setInviteId("uuid-123")
                .setStatus("pending")
                .setCreatedAt("2026-01-28T10:00:00Z")
                .build()
        );
        
        // When/Then
        webClient.post()
            .uri("/api/v1/connections/invite")
            .header("Authorization", "Bearer " + token)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(request)
            .exchange()
            .expectStatus().isCreated()
            .expectBody()
            .jsonPath("$.invite_id").isEqualTo("uuid-123")
            .jsonPath("$.status").isEqualTo("pending")
            .jsonPath("$.created_at").isNotEmpty();
    }

    // TC-INT-INV-007: Self invite blocked
    @Test
    void testCreateInvite_SelfInvite_Returns400() {
        // Given
        String token = generatePatientToken("0901234567");
        CreateInviteRequestDTO request = CreateInviteRequestDTO.builder()
            .receiverPhone("0901234567")  // Same as patient's phone
            .receiverName("Self")
            .relationship("khac")
            .inviteType("add_caregiver")
            .build();
            
        when(grpcClient.createInvite(any())).thenThrow(
            new GrpcStatusException(Status.INVALID_ARGUMENT
                .withDescription("SELF_INVITE"))
        );
        
        // When/Then
        webClient.post()
            .uri("/api/v1/connections/invite")
            .header("Authorization", "Bearer " + token)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(request)
            .exchange()
            .expectStatus().isBadRequest()
            .expectBody()
            .jsonPath("$.error_code").isEqualTo("SELF_INVITE")
            .jsonPath("$.message").isEqualTo("Bạn không thể mời chính mình");
    }

    // TC-INT-INV-008: Duplicate pending blocked
    @Test
    void testCreateInvite_DuplicatePending_Returns400() {
        // Given
        String token = generatePatientToken();
        CreateInviteRequestDTO request = CreateInviteRequestDTO.builder()
            .receiverPhone("0912345678")
            .inviteType("add_caregiver")
            .build();
            
        when(grpcClient.createInvite(any())).thenThrow(
            new GrpcStatusException(Status.ALREADY_EXISTS
                .withDescription("DUPLICATE_PENDING"))
        );
        
        // When/Then
        webClient.post()
            .uri("/api/v1/connections/invite")
            .header("Authorization", "Bearer " + token)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(request)
            .exchange()
            .expectStatus().isBadRequest()
            .expectBody()
            .jsonPath("$.error_code").isEqualTo("DUPLICATE_PENDING")
            .jsonPath("$.message").isEqualTo("Bạn đã gửi lời mời. Đang chờ phản hồi.");
    }
}
```

---

## 1.2 GET /api/v1/connections/invites - List Invites

| Test ID | Scenario | Expected | BR | Priority |
|---------|----------|----------|:--:|:--------:|
| TC-INT-INV-015 | List all invites (default) | 200, sent + received arrays | - | 🟡 P1 |
| TC-INT-INV-016 | Filter by type=sent | 200, only sent invites | - | 🟢 P2 |
| TC-INT-INV-017 | Filter by type=received | 200, only received invites | - | 🟢 P2 |
| TC-INT-INV-018 | Filter by status=pending | 200, only pending | - | 🟢 P2 |
| TC-INT-INV-019 | Multiple pending (FIFO order) | 200, oldest first | BR-013 | 🟢 P2 |
| TC-INT-INV-020 | total_pending count correct | 200, count matches | BR-023 | 🟡 P1 |
| TC-INT-INV-021 | Empty invites | 200, empty arrays | BR-015 | 🟢 P2 |
| TC-INT-INV-022 | Masked phone in response | Phone: 0912***678 | - | 🟡 P1 |

```java
    // TC-INT-INV-019: FIFO order
    @Test
    void testListInvites_MultiplePending_FIFOOrder() {
        // Given
        String token = generateUserToken();
        when(grpcClient.listInvites(any())).thenReturn(
            ListInvitesResponse.newBuilder()
                .addReceived(inviteAt("2026-01-28T08:00:00Z"))
                .addReceived(inviteAt("2026-01-28T09:00:00Z"))
                .addReceived(inviteAt("2026-01-28T10:00:00Z"))
                .setTotalPending(3)
                .build()
        );
        
        // When/Then
        webClient.get()
            .uri("/api/v1/connections/invites?type=received&status=pending")
            .header("Authorization", "Bearer " + token)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.received.length()").isEqualTo(3)
            .jsonPath("$.received[0].created_at").isEqualTo("2026-01-28T08:00:00Z")
            .jsonPath("$.total_pending").isEqualTo(3);
    }
```

---

## 1.3 POST /api/v1/connections/invites/{id}/accept - Accept Invite

| Test ID | Scenario | Expected | BR | Priority |
|---------|----------|----------|:--:|:--------:|
| TC-INT-INV-023 | Caregiver quick accept | 200, connection created | BR-008 | 🔴 P0 |
| TC-INT-INV-024 | Patient accept with permissions | 200, permissions applied | BR-008 | 🔴 P0 |
| TC-INT-INV-025 | Accept with partial permissions | 200, custom permissions | - | 🟡 P1 |
| TC-INT-INV-026 | Invite not found | 404 INVITE_NOT_FOUND | - | 🟡 P1 |
| TC-INT-INV-027 | Not the receiver | 403 NOT_AUTHORIZED | - | 🟡 P1 |
| TC-INT-INV-028 | Already accepted | 400 ALREADY_ACCEPTED | - | 🟡 P1 |
| TC-INT-INV-029 | Response includes connection_id | 200, connection_id present | - | 🔴 P0 |
| TC-INT-INV-030 | Response includes relationship | 200, relationship present | BR-028 | 🟡 P1 |
| TC-INT-INV-080 | Response includes inverse_relationship_code (v2.19) | 200, inverse_relationship_code present | BR-036 | 🔴 P0 |
| TC-INT-INV-081 | Response includes inverse_relationship_name (v2.19) | 200, inverse_relationship_name present | BR-036 | 🔴 P0 |

```java
    // TC-INT-INV-024: Patient accept with permissions
    @Test
    void testAcceptInvite_PatientWithPermissions_Success() {
        // Given
        String token = generatePatientToken();
        String inviteId = "uuid-invite-123";
        
        AcceptInviteRequestDTO request = AcceptInviteRequestDTO.builder()
            .permissions(Map.of(
                "health_overview", true,
                "emergency_alert", true,
                "task_config", false,  // Custom: OFF
                "compliance_tracking", true,
                "proxy_execution", false,  // Custom: OFF
                "encouragement", true
            ))
            .build();
            
        when(grpcClient.acceptInvite(any())).thenReturn(
            ConnectionResponse.newBuilder()
                .setConnectionId("uuid-connection-123")
                .setPatient(UserInfo.newBuilder().setId("patient-id").setName("Patient"))
                .setCaregiver(UserInfo.newBuilder().setId("caregiver-id").setName("Caregiver"))
                .setRelationship("con_trai")
                .setStatus("active")
                .build()
        );
        
        // When/Then
        webClient.post()
            .uri("/api/v1/connections/invites/{id}/accept", inviteId)
            .header("Authorization", "Bearer " + token)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(request)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.connection_id").isEqualTo("uuid-connection-123")
            .jsonPath("$.status").isEqualTo("active")
            .jsonPath("$.relationship").isEqualTo("con_trai");
    }
```

---

## 1.4 POST /api/v1/connections/invites/{id}/reject - Reject Invite

| Test ID | Scenario | Expected | BR | Priority |
|---------|----------|----------|:--:|:--------:|
| TC-INT-INV-031 | Reject invite success | 200, status=rejected | BR-011 | 🟡 P1 |
| TC-INT-INV-032 | Invite not found | 404 INVITE_NOT_FOUND | - | 🟡 P1 |
| TC-INT-INV-033 | Not the receiver | 403 NOT_AUTHORIZED | - | 🟡 P1 |
| TC-INT-INV-034 | Already rejected | 400 error | - | 🟢 P2 |
| TC-INT-INV-035 | Re-invite allowed after reject | Can create new invite | BR-011 | 🟡 P1 |

---

## 1.5 DELETE /api/v1/connections/invites/{id} - Cancel Invite

| Test ID | Scenario | Expected | BR | Priority |
|---------|----------|----------|:--:|:--------:|
| TC-INT-INV-036 | Cancel pending invite success | 200, status=cancelled | - | 🔴 P0 |
| TC-INT-INV-037 | Cancel by sender only | 200, cancelled | - | 🔴 P0 |
| TC-INT-INV-038 | Invite not found | 404 INVITE_NOT_FOUND | - | 🟡 P1 |
| TC-INT-INV-039 | Not the sender | 403 NOT_AUTHORIZED | - | 🟡 P1 |
| TC-INT-INV-040 | Already accepted | 400 CANNOT_CANCEL | - | 🟡 P1 |
| TC-INT-INV-041 | Already rejected | 400 CANNOT_CANCEL | - | 🟡 P1 |
| TC-INT-INV-042 | Already cancelled | 400 ALREADY_CANCELLED | - | 🟢 P2 |

```java
    // TC-INT-INV-036: Cancel pending invite success
    @Test
    void testCancelInvite_PendingSender_Returns200() {
        // Given
        String token = generateSenderToken();
        String inviteId = "uuid-invite-123";
        
        when(grpcClient.cancelInvite(any())).thenReturn(
            InviteResponse.newBuilder()
                .setInviteId(inviteId)
                .setStatus("cancelled")
                .build()
        );
        
        // When/Then
        webClient.delete()
            .uri("/api/v1/connections/invites/{id}", inviteId)
            .header("Authorization", "Bearer " + token)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.invite_id").isEqualTo(inviteId)
            .jsonPath("$.status").isEqualTo("cancelled");
    }

    // TC-INT-INV-039: Not the sender
    @Test
    void testCancelInvite_NotSender_Returns403() {
        // Given
        String token = generateOtherUserToken();
        String inviteId = "uuid-invite-123";
        
        when(grpcClient.cancelInvite(any())).thenThrow(
            new GrpcException(Status.PERMISSION_DENIED, "NOT_AUTHORIZED")
        );
        
        // When/Then
        webClient.delete()
            .uri("/api/v1/connections/invites/{id}", inviteId)
            .header("Authorization", "Bearer " + token)
            .exchange()
            .expectStatus().isForbidden()
            .expectBody()
            .jsonPath("$.error_code").isEqualTo("NOT_AUTHORIZED");
    }
```

---

# 2. Connection APIs

## 2.1 GET /api/v1/connections - List Connections

| Test ID | Scenario | Expected | BR | Priority |
|---------|----------|----------|:--:|:--------:|
| TC-INT-CON-001 | List all connections | 200, monitoring + monitored_by | - | 🟡 P1 |
| TC-INT-CON-002 | Only monitoring (Caregiver view) | 200, monitoring array | - | 🟡 P1 |
| TC-INT-CON-003 | Only monitored_by (Patient view) | 200, monitored_by array | - | 🟡 P1 |
| TC-INT-CON-004 | relationship_display formatted | "{Mối QH} ({Tên})" | BR-029 | 🟡 P1 |
| TC-INT-CON-005 | relationship "khac" → "Người thân" | "Người thân (Tên)" | BR-029 | 🟡 P1 |
| TC-INT-CON-006 | last_active included | Timestamp present | BR-014 | 🟡 P1 |
| TC-INT-CON-007 | Empty connections | 200, empty arrays | BR-015 | 🟢 P2 |
| TC-INT-CON-008 | No limit on connections | All connections returned | BR-021 | 🟡 P1 |

```java
    // TC-INT-CON-005: "khac" → "Người thân"
    @Test
    void testListConnections_RelationshipKhac_DisplayNguoiThan() {
        // Given
        String token = generatePatientToken();
        when(grpcClient.listConnections(any())).thenReturn(
            ListConnectionsResponse.newBuilder()
                .addMonitoredBy(ConnectionInfo.newBuilder()
                    .setConnectionId("uuid-123")
                    .setCaregiver(UserInfo.newBuilder()
                        .setId("caregiver-id")
                        .setName("Nguyễn Văn A"))
                    .setRelationship("khac")
                    .setRelationshipDisplay("Người thân (Nguyễn Văn A)")
                    .setLastActive("2026-01-28T10:00:00Z"))
                .build()
        );
        
        // When/Then
        webClient.get()
            .uri("/api/v1/connections")
            .header("Authorization", "Bearer " + token)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.monitored_by[0].relationship").isEqualTo("khac")
            .jsonPath("$.monitored_by[0].relationship_display")
                .isEqualTo("Người thân (Nguyễn Văn A)");
    }
```

---

## 2.2 DELETE /api/v1/connections/{id} - Disconnect

| Test ID | Scenario | Expected | BR | Priority |
|---------|----------|----------|:--:|:--------:|
| TC-INT-CON-009 | Patient disconnects | 200, status=disconnected | BR-019 | 🟡 P1 |
| TC-INT-CON-010 | Caregiver exits | 200, status=disconnected | BR-020 | 🟡 P1 |
| TC-INT-CON-011 | Response includes disconnected_by | 200, role identified | - | 🟡 P1 |
| TC-INT-CON-012 | Connection not found | 404 CONNECTION_NOT_FOUND | - | 🟡 P1 |
| TC-INT-CON-013 | Not a participant | 403 NOT_AUTHORIZED | - | 🟡 P1 |
| TC-INT-CON-014 | Already disconnected | 400 error | - | 🟢 P2 |

---

# 3. Permission APIs

## 3.1 GET /api/v1/connections/{id}/permissions

| Test ID | Scenario | Expected | BR | Priority |
|---------|----------|----------|:--:|:--------:|
| TC-INT-PRM-001 | Get 6 permissions | 200, 6 permission objects | - | 🟡 P1 |
| TC-INT-PRM-002 | Permission includes name_vi | Each has Vietnamese name | - | 🟡 P1 |
| TC-INT-PRM-003 | Connection not found | 404 CONNECTION_NOT_FOUND | - | 🟡 P1 |
| TC-INT-PRM-004 | Not participant | 403 NOT_AUTHORIZED | - | 🟡 P1 |
| TC-INT-PRM-005 | Caregiver can view (limited) | 200, but sees own permissions | BR-017 | 🟡 P1 |

```java
    // TC-INT-PRM-001: Get 6 permissions
    @Test
    void testGetPermissions_Returns6Permissions() {
        // Given
        String token = generatePatientToken();
        String connectionId = "uuid-connection-123";
        
        when(grpcClient.getPermissions(any())).thenReturn(
            PermissionsResponse.newBuilder()
                .setConnectionId(connectionId)
                .addPermissions(permission("health_overview", "Xem tổng quan sức khỏe", true))
                .addPermissions(permission("emergency_alert", "Nhận cảnh báo khẩn cấp", true))
                .addPermissions(permission("task_config", "Thiết lập nhiệm vụ tuân thủ", false))
                .addPermissions(permission("compliance_tracking", "Theo dõi kết quả tuân thủ", true))
                .addPermissions(permission("proxy_execution", "Thực hiện nhiệm vụ thay", false))
                .addPermissions(permission("encouragement", "Gửi lời động viên", true))
                .build()
        );
        
        // When/Then
        webClient.get()
            .uri("/api/v1/connections/{id}/permissions", connectionId)
            .header("Authorization", "Bearer " + token)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.connection_id").isEqualTo(connectionId)
            .jsonPath("$.permissions.length()").isEqualTo(6)
            .jsonPath("$.permissions[0].type").isEqualTo("health_overview")
            .jsonPath("$.permissions[0].name").isEqualTo("Xem tổng quan sức khỏe")
            .jsonPath("$.permissions[0].enabled").isEqualTo(true);
    }
```

---

## 3.2 PUT /api/v1/connections/{id}/permissions

| Test ID | Scenario | Expected | BR | Priority |
|---------|----------|----------|:--:|:--------:|
| TC-INT-PRM-006 | Toggle permission ON | 200, updated | BR-016 | 🔴 P0 |
| TC-INT-PRM-007 | Toggle permission OFF | 200, updated | BR-016 | 🔴 P0 |
| TC-INT-PRM-008 | Toggle emergency_alert OFF | 200, with warning flag | BR-018 | 🔴 P0 |
| TC-INT-PRM-009 | Invalid permission type | 400 INVALID_PERMISSION_TYPE | - | 🟡 P1 |
| TC-INT-PRM-010 | Not the Patient | 403 NOT_AUTHORIZED | - | 🟡 P1 |
| TC-INT-PRM-011 | Connection not found | 404 CONNECTION_NOT_FOUND | - | 🟡 P1 |
| TC-INT-PRM-012 | Response includes all permissions | 200, updated array | - | 🟡 P1 |

```java
    // TC-INT-PRM-008: Emergency alert OFF with warning
    @Test
    void testUpdatePermission_EmergencyOff_WithWarning() {
        // Given
        String token = generatePatientToken();
        String connectionId = "uuid-connection-123";
        
        UpdatePermissionRequestDTO request = UpdatePermissionRequestDTO.builder()
            .permissionType("emergency_alert")
            .isEnabled(false)
            .build();
            
        when(grpcClient.updatePermission(any())).thenReturn(
            PermissionsResponse.newBuilder()
                .setConnectionId(connectionId)
                .addAllPermissions(updatedPermissions("emergency_alert", false))
                .build()
        );
        
        // When/Then
        webClient.put()
            .uri("/api/v1/connections/{id}/permissions", connectionId)
            .header("Authorization", "Bearer " + token)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(request)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.permissions[?(@.type=='emergency_alert')].enabled")
                .isEqualTo(false);
    }
```

---

# 4. Permission Types API (v2.6)

## 4.1 GET /api/v1/connection/permission-types - List Permission Types

| Test ID | Scenario | Expected | BR | Priority |
|---------|----------|----------|:--:|:--------:|
| TC-INT-PTY-001 | Get all permission types | 200, 6 permission types | - | 🟡 P1 |
| TC-INT-PTY-002 | Response includes code field | Each has code | - | 🟡 P1 |
| TC-INT-PTY-003 | Response includes name_vi | Each has Vietnamese name | - | 🟡 P1 |
| TC-INT-PTY-004 | Response includes icon | Each has icon string | - | 🟠 P2 |
| TC-INT-PTY-005 | Response ordered by display_order | Correct ordering | - | 🟠 P2 |
| TC-INT-PTY-006 | Unauthorized request | 401 Unauthorized | - | 🟡 P1 |

```java
    // TC-INT-PTY-001: Get all permission types
    @Test
    void testListPermissionTypes_Returns6Types() {
        // Given
        String token = generateUserToken();
        
        when(grpcClient.listPermissionTypes()).thenReturn(
            PermissionTypesResponse.newBuilder()
                .addPermissionTypes(permissionType("health_overview", "Xem tổng quan sức khỏe", "health", 1))
                .addPermissionTypes(permissionType("emergency_alert", "Nhận cảnh báo khẩn cấp", "alert", 2))
                .addPermissionTypes(permissionType("task_config", "Thiết lập nhiệm vụ", "task", 3))
                .addPermissionTypes(permissionType("compliance_tracking", "Theo dõi tuân thủ", "chart", 4))
                .addPermissionTypes(permissionType("proxy_execution", "Thực hiện thay", "user", 5))
                .addPermissionTypes(permissionType("encouragement", "Gửi động viên", "heart", 6))
                .build()
        );
        
        // When/Then
        webClient.get()
            .uri("/api/v1/connection/permission-types")
            .header("Authorization", "Bearer " + token)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.permission_types.length()").isEqualTo(6)
            .jsonPath("$.permission_types[0].code").isEqualTo("health_overview")
            .jsonPath("$.permission_types[0].name_vi").isEqualTo("Xem tổng quan sức khỏe")
            .jsonPath("$.permission_types[0].icon").isEqualTo("health")
            .jsonPath("$.permission_types[0].display_order").isEqualTo(1);
    }
```

---

# 4.2 Relationship Types API (v2.8)

## GET /api/v1/connection/relationship-types - List Relationship Types

| Test ID | Scenario | Expected | BR | Priority |
|---------|----------|----------|:--:|:--------:|
| TC-INT-RTY-001 | Get all relationship types | 200, 14 relationship types (v2.22) | - | 🟡 P1 |
| TC-INT-RTY-002 | Response includes code field | Each has relationship_code | - | 🟡 P1 |
| TC-INT-RTY-003 | Response includes name_vi | Each has Vietnamese name | - | 🟡 P1 |
| TC-INT-RTY-004 | Response includes category | family/other categories | - | 🟢 P2 |
| TC-INT-RTY-005 | Response ordered by display_order | Correct ordering | - | 🟢 P2 |
| TC-INT-RTY-006 | Unauthorized request | 401 Unauthorized | - | 🟡 P1 |

```java
    // TC-INT-RTY-001: Get all relationship types
    @Test
    void testListRelationshipTypes_Returns14Types() {
        // Given
        String token = generateUserToken();
        
        when(grpcClient.listRelationshipTypes()).thenReturn(
            RelationshipTypesResponse.newBuilder()
                .addRelationshipTypes(relationshipType("con_trai", "Con trai", "Con trai", "family", 1))
                .addRelationshipTypes(relationshipType("con_gai", "Con gái", "Con gái", "family", 2))
                .addRelationshipTypes(relationshipType("bo", "Bố", "Bố", "family", 3))
                .addRelationshipTypes(relationshipType("me", "Mẹ", "Mẹ", "family", 4))
                // ... other relationship types
                .addRelationshipTypes(relationshipType("khac", "Khác", "Người thân", "other", 99))
                .build()
        );
        
        // When/Then
        webClient.get()
            .uri("/api/v1/connection/relationship-types")
            .header("Authorization", "Bearer " + token)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.relationship_types.length()").isEqualTo(14)
            .jsonPath("$.relationship_types[0].code").isEqualTo("con_trai")
            .jsonPath("$.relationship_types[0].name_vi").isEqualTo("Con trai")
            .jsonPath("$.relationship_types[0].category").isEqualTo("family")
            .jsonPath("$.relationship_types[0].display_order").isEqualTo(1);
    }
    
    // TC-INT-RTY-006: Unauthorized
    @Test
    void testListRelationshipTypes_Unauthorized_Returns401() {
        // When/Then
        webClient.get()
            .uri("/api/v1/connection/relationship-types")
            .exchange()
            .expectStatus().isUnauthorized();
    }
```

## 5.1 GET /api/v1/connections/viewing - Get Currently Viewing Patient

| Test ID | Scenario | Expected | BR | Priority |
|---------|----------|----------|:--:|:--------:|
| TC-API-VW-001 | Get viewing patient (has selection) | 200, patient info returned | BR-026 | 🔴 P0 |
| TC-API-VW-002 | Get viewing patient (no selection) | 200, null/empty response | BR-026 | 🟡 P1 |
| TC-API-VW-003 | User is pure Patient (no caregivers) | 200, returns self info | - | 🟡 P1 |
| TC-API-VW-004 | Response includes patient details | 200, name, avatar, phone | - | 🟡 P1 |
| TC-API-VW-005 | Unauthorized request | 401 Unauthorized | - | 🟡 P1 |

```java
    // TC-API-VW-001: Get viewing patient success
    @Test
    void testGetViewingPatient_HasSelection_Returns200() {
        // Given
        String token = generateCaregiverToken();
        
        when(grpcClient.getViewingPatient(any())).thenReturn(
            ViewingPatientResponse.newBuilder()
                .setPatient(PatientInfo.newBuilder()
                    .setId("uuid-patient-123")
                    .setName("Nguyễn Thị Patient")
                    .setPhone("0901***567")
                    .setAvatar("https://storage.kolia.vn/avatars/patient.jpg"))
                .setConnectionId("uuid-connection-123")
                .build()
        );
        
        // When/Then
        webClient.get()
            .uri("/api/v1/connections/viewing")
            .header("Authorization", "Bearer " + token)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.patient.id").isEqualTo("uuid-patient-123")
            .jsonPath("$.patient.name").isEqualTo("Nguyễn Thị Patient")
            .jsonPath("$.connection_id").isNotEmpty();
    }

    // TC-API-VW-002: No viewing patient selected
    @Test
    void testGetViewingPatient_NoSelection_ReturnsEmpty() {
        // Given
        String token = generateCaregiverToken();
        
        when(grpcClient.getViewingPatient(any())).thenReturn(
            ViewingPatientResponse.newBuilder().build()  // Empty
        );
        
        // When/Then
        webClient.get()
            .uri("/api/v1/connections/viewing")
            .header("Authorization", "Bearer " + token)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.patient").doesNotExist();
    }
```

---

## 5.2 PUT /api/v1/connections/viewing - Set Viewing Patient

| Test ID | Scenario | Expected | BR | Priority |
|---------|----------|----------|:--:|:--------:|
| TC-API-VW-006 | Set viewing patient success | 200, updated selection | BR-026 | 🔴 P0 |
| TC-API-VW-007 | Switch to different patient | 200, new patient set | BR-026 | 🔴 P0 |
| TC-API-VW-008 | Patient not in connections | 400/404 PATIENT_NOT_CONNECTED | - | 🟡 P1 |
| TC-API-VW-009 | Invalid patient_id format | 400 Validation Error | - | 🟡 P1 |
| TC-API-VW-010 | User is pure Patient | 403 NOT_CAREGIVER | - | 🟡 P1 |
| TC-API-VW-011 | Unauthorized request | 401 Unauthorized | - | 🟡 P1 |
| TC-API-VW-012 | Atomic update (prev cleared) | 200, only one is_viewing=true | BR-026 | 🔴 P0 |

```java
    // TC-API-VW-006: Set viewing patient success
    @Test
    void testSetViewingPatient_ValidRequest_Returns200() {
        // Given
        String token = generateCaregiverToken();
        SetViewingPatientRequest request = SetViewingPatientRequest.builder()
            .patientId("uuid-patient-123")
            .build();
            
        when(grpcClient.setViewingPatient(any())).thenReturn(
            ViewingPatientResponse.newBuilder()
                .setPatient(PatientInfo.newBuilder()
                    .setId("uuid-patient-123")
                    .setName("Nguyễn Thị Patient"))
                .setConnectionId("uuid-connection-123")
                .build()
        );
        
        // When/Then
        webClient.put()
            .uri("/api/v1/connections/viewing")
            .header("Authorization", "Bearer " + token)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(request)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.patient.id").isEqualTo("uuid-patient-123");
    }

    // TC-API-VW-007: Switch viewing patient
    @Test
    void testSetViewingPatient_SwitchPatient_Returns200() {
        // Given
        String token = generateCaregiverToken();
        
        // First patient was uuid-patient-111, now switching to 222
        SetViewingPatientRequest request = SetViewingPatientRequest.builder()
            .patientId("uuid-patient-222")
            .build();
            
        when(grpcClient.setViewingPatient(any())).thenReturn(
            ViewingPatientResponse.newBuilder()
                .setPatient(PatientInfo.newBuilder()
                    .setId("uuid-patient-222")
                    .setName("Trần Văn Patient2"))
                .build()
        );
        
        // When/Then
        webClient.put()
            .uri("/api/v1/connections/viewing")
            .header("Authorization", "Bearer " + token)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(request)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.patient.id").isEqualTo("uuid-patient-222");
    }

    // TC-API-VW-008: Patient not connected
    @Test
    void testSetViewingPatient_NotConnected_Returns400() {
        // Given
        String token = generateCaregiverToken();
        SetViewingPatientRequest request = SetViewingPatientRequest.builder()
            .patientId("uuid-unknown-patient")
            .build();
            
        when(grpcClient.setViewingPatient(any())).thenThrow(
            new GrpcException(Status.NOT_FOUND, "PATIENT_NOT_CONNECTED")
        );
        
        // When/Then
        webClient.put()
            .uri("/api/v1/connections/viewing")
            .header("Authorization", "Bearer " + token)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(request)
            .exchange()
            .expectStatus().isBadRequest()
            .expectBody()
            .jsonPath("$.error_code").isEqualTo("PATIENT_NOT_CONNECTED");
    }
```

---

# 6. Dashboard APIs (v2.11)

## 6.1 GET /api/v1/patients/{id}/blood-pressure-chart - Blood Pressure Chart

| Test ID | Scenario | Expected | BR | Priority |
|---------|----------|----------|:--:|:--------:|
| TC-API-BP-001 | Get BP chart (week mode) | 200, measurements list (Mon→today) | BR-DB-006 | 🔴 P0 |
| TC-API-BP-002 | Get BP chart (month mode) | 200, measurements list (1st→today) | BR-DB-006 | 🔴 P0 |
| TC-API-BP-003 | Response includes systolic value | Per measurement | BR-DB-001 | 🔴 P0 |
| TC-API-BP-004 | Response includes diastolic value | Per measurement | BR-DB-001 | 🔴 P0 |
| TC-API-BP-005 | Response includes heart_rate | Per measurement | - | 🟡 P1 |
| TC-API-BP-006 | Empty data state | 200, empty_state: true, measurements: [] | BR-DB-007 | 🟡 P1 |
| TC-API-BP-007 | **No connection** | **404 NOT_FOUND** | SEC-DB-001 | 🔴 P0 |
| TC-API-BP-008 | **Connection inactive** | **403 FORBIDDEN** | SEC-DB-001 | 🔴 P0 |
| TC-API-BP-009 | **health_overview OFF** | **403 PERMISSION_DENIED** | SEC-DB-002 | 🔴 P0 |
| TC-API-BP-010 | **v2.13: patient_target_thresholds** | **200, thresholds from user_health_profiles** | DB-SCHEMA-001 | 🔴 P0 |

```java
    // TC-API-BP-001: Get BP chart week mode - Flat measurements list
    @Test
    void testGetBloodPressureChart_WeekMode_Success() {
        // Given
        String token = generateCaregiverToken();
        String patientId = "uuid-patient-123";
        
        when(grpcClient.getBloodPressureChart(any())).thenReturn(
            BloodPressureChartResponse.newBuilder()
                .setData(BloodPressureChartData.newBuilder()
                    .setPatientId(patientId)
                    .setMode("week")
                    .addMeasurements(measurement("2026-01-30T10:15:30+07:00", 130, 85, 72))
                    .addMeasurements(measurement("2026-01-30T08:00:00+07:00", 128, 82, 70))
                    .addMeasurements(measurement("2026-01-29T09:30:00+07:00", 125, 80, 68))
                    .setEmptyState(false)
                    .setPeriodStart("2026-01-27")
                    .setPeriodEnd("2026-01-30")
                    .build())
                .build()
        );
        
        // When/Then
        webClient.get()
            .uri("/api/v1/patients/{id}/blood-pressure-chart?mode=week", patientId)
            .header("Authorization", "Bearer " + token)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.data.mode").isEqualTo("week")
            .jsonPath("$.data.measurements.length()").isEqualTo(3)
            .jsonPath("$.data.measurements[0].systolic").isEqualTo(130)
            .jsonPath("$.data.measurements[0].diastolic").isEqualTo(85)
            .jsonPath("$.data.measurements[0].heart_rate").isEqualTo(72)
            .jsonPath("$.data.measurements[0].measurement_time").isNotEmpty()
            .jsonPath("$.data.period_start").isEqualTo("2026-01-27")
            .jsonPath("$.data.period_end").isEqualTo("2026-01-30");
    }
    
    // Helper method for measurements
    private BloodPressureMeasurement measurement(String time, int sys, int dia, int hr) {
        return BloodPressureMeasurement.newBuilder()
            .setMeasurementTime(time)
            .setSystolic(sys)
            .setDiastolic(dia)
            .setHeartRate(hr)
            .build();
    }

    // TC-API-BP-007: No connection - Triple Check Authorization Step 1
    @Test
    void testGetBloodPressureChart_NoConnection_Returns404() {
        // Given
        String token = generateCaregiverToken();  // Not connected to this patient
        String patientId = "uuid-unknown-patient";
        
        when(grpcClient.getBloodPressureChart(any())).thenThrow(
            new GrpcException(Status.NOT_FOUND, "NO_CONNECTION")
        );
        
        // When/Then
        webClient.get()
            .uri("/api/v1/patients/{id}/blood-pressure-chart?mode=week", patientId)
            .header("Authorization", "Bearer " + token)
            .exchange()
            .expectStatus().isNotFound()
            .expectBody()
            .jsonPath("$.error_code").isEqualTo("NO_CONNECTION");
    }

    // TC-API-BP-009: Permission denied - Triple Check Authorization Step 3
    @Test
    void testGetBloodPressureChart_HealthOverviewOff_Returns403() {
        // Given: Caregiver connected but health_overview permission = OFF
        String token = generateCaregiverToken();
        String patientId = "uuid-patient-123";
        
        when(grpcClient.getBloodPressureChart(any())).thenThrow(
            new GrpcException(Status.PERMISSION_DENIED, "PERMISSION_DENIED")
        );
        
        // When/Then
        webClient.get()
            .uri("/api/v1/patients/{id}/blood-pressure-chart?mode=week", patientId)
            .header("Authorization", "Bearer " + token)
            .exchange()
            .expectStatus().isForbidden()
            .expectBody()
            .jsonPath("$.error_code").isEqualTo("PERMISSION_DENIED")
            .jsonPath("$.message").isEqualTo("Bạn không có quyền xem thông tin này");
    }
```

---

## 6.2 GET /api/v1/patients/{id}/periodic-reports - Periodic Reports

| Test ID | Scenario | Expected | BR | Priority |
|---------|----------|----------|:--:|:--------:|
| TC-API-RPT-001 | List reports with is_read status | 200, reports with is_read | BR-RPT-001 | 🔴 P0 |
| TC-API-RPT-002 | Header format "Báo cáo {type} - {period}" | Correct formatting | BR-RPT-002 | 🟡 P1 |
| TC-API-RPT-003 | Unread reports (is_read: false) | 200, is_read: false | BR-RPT-001 | 🔴 P0 |
| TC-API-RPT-004 | Mark as read after viewing | 200, is_read: true | BR-RPT-001 | 🔴 P0 |
| TC-API-RPT-005 | Empty reports list | 200, empty array | - | 🟡 P1 |
| TC-API-RPT-006 | **No connection** | **404 NOT_FOUND** | SEC-DB-001 | 🔴 P0 |
| TC-API-RPT-007 | **Connection inactive** | **403 FORBIDDEN** | SEC-DB-001 | 🔴 P0 |
| TC-API-RPT-008 | **health_overview OFF** | **403 PERMISSION_DENIED** | SEC-DB-002 | 🔴 P0 |

```java
    // TC-API-RPT-001: List reports with is_read status
    @Test
    void testGetPatientReports_WithIsReadStatus_Success() {
        // Given
        String token = generateCaregiverToken();
        String patientId = "uuid-patient-123";
        
        when(grpcClient.getPatientReports(any())).thenReturn(
            PatientReportsResponse.newBuilder()
                .addReports(ReportInfo.newBuilder()
                    .setReportId("report-001")
                    .setType("weekly")
                    .setPeriod("20-26/01/2026")
                    .setTitle("Báo cáo tuần - 20-26/01/2026")
                    .setIsRead(false)
                    .setCreatedAt("2026-01-27T08:00:00Z"))
                .addReports(ReportInfo.newBuilder()
                    .setReportId("report-002")
                    .setType("monthly")
                    .setPeriod("12/2025")
                    .setTitle("Báo cáo tháng - 12/2025")
                    .setIsRead(true)
                    .setCreatedAt("2026-01-01T08:00:00Z"))
                .build()
        );
        
        // When/Then
        webClient.get()
            .uri("/api/v1/patients/{id}/periodic-reports", patientId)
            .header("Authorization", "Bearer " + token)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.reports.length()").isEqualTo(2)
            .jsonPath("$.reports[0].is_read").isEqualTo(false)
            .jsonPath("$.reports[0].title").isEqualTo("Báo cáo tuần - 20-26/01/2026")
            .jsonPath("$.reports[1].is_read").isEqualTo(true);
    }

    // TC-API-RPT-006: No connection - Authorization Flow
    @Test
    void testGetPatientReports_NoConnection_Returns404() {
        // Given
        String token = generateCaregiverToken();
        String patientId = "uuid-unknown-patient";
        
        when(grpcClient.getPatientReports(any())).thenThrow(
            new GrpcException(Status.NOT_FOUND, "NO_CONNECTION")
        );
        
        // When/Then
        webClient.get()
            .uri("/api/v1/patients/{id}/periodic-reports", patientId)
            .header("Authorization", "Bearer " + token)
            .exchange()
            .expectStatus().isNotFound();
    }
```

---

## 6.3 POST /api/v1/patients/{id}/periodic-reports/{reportId}/mark-read - Mark Report as Read (v2.14)

| Test ID | Scenario | Expected | BR | Priority |
|---------|----------|----------|:--:|:--------:|
| TC-API-MRR-001 | Mark report as read (first time) | 200, marked_at returned | BR-RPT-003 | 🔴 P0 |
| TC-API-MRR-002 | Mark already-read report (idempotent) | 200, no error | BR-RPT-003 | 🔴 P0 |
| TC-API-MRR-003 | Report belongs to patient | 200, success | SEC-DB-001 | 🔴 P0 |
| TC-API-MRR-004 | **Report NOT belongs to patient** | **404 REPORT_NOT_FOUND** | SEC-DB-001 | 🔴 P0 |
| TC-API-MRR-005 | **No connection** | **403 NOT_CONNECTED** | SEC-DB-001 | 🔴 P0 |
| TC-API-MRR-006 | **Connection inactive** | **403 FORBIDDEN** | SEC-DB-001 | 🔴 P0 |
| TC-API-MRR-007 | **health_overview OFF** | **403 PERMISSION_DENIED** | SEC-DB-002 | 🔴 P0 |
| TC-API-MRR-008 | Invalid report_id format | 400 Validation Error | - | 🟡 P1 |
| TC-API-MRR-009 | Unauthorized request | 401 Unauthorized | - | 🟡 P1 |

```java
    // TC-API-MRR-001: Mark report as read success
    @Test
    void testMarkReportAsRead_FirstTime_Success() {
        // Given
        String token = generateCaregiverToken();
        String patientId = "uuid-patient-123";
        Long reportId = 1001L;
        
        when(grpcClient.markReportAsRead(any())).thenReturn(
            MarkReportAsReadResponse.newBuilder()
                .setReportId(reportId)
                .setMarkedAt("2026-01-30T23:15:00Z")
                .build()
        );
        
        // When/Then
        webClient.post()
            .uri("/api/v1/patients/{patientId}/periodic-reports/{reportId}/mark-read", 
                 patientId, reportId)
            .header("Authorization", "Bearer " + token)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.report_id").isEqualTo(reportId)
            .jsonPath("$.marked_at").isNotEmpty();
    }

    // TC-API-MRR-002: Idempotent - mark already-read report
    @Test
    void testMarkReportAsRead_AlreadyRead_Returns200() {
        // Given
        String token = generateCaregiverToken();
        String patientId = "uuid-patient-123";
        Long reportId = 1001L;
        
        when(grpcClient.markReportAsRead(any())).thenReturn(
            MarkReportAsReadResponse.newBuilder()
                .setReportId(reportId)
                .setMarkedAt("2026-01-30T23:00:00Z") // Original time
                .build()
        );
        
        // When/Then - Should succeed without error
        webClient.post()
            .uri("/api/v1/patients/{patientId}/periodic-reports/{reportId}/mark-read", 
                 patientId, reportId)
            .header("Authorization", "Bearer " + token)
            .exchange()
            .expectStatus().isOk();
    }

    // TC-API-MRR-004: Report not belongs to patient
    @Test
    void testMarkReportAsRead_WrongPatient_Returns404() {
        // Given
        String token = generateCaregiverToken();
        String patientId = "uuid-patient-123";
        Long reportId = 9999L; // Report belongs to different patient
        
        when(grpcClient.markReportAsRead(any())).thenThrow(
            new GrpcException(Status.NOT_FOUND, "REPORT_NOT_FOUND")
        );
        
        // When/Then
        webClient.post()
            .uri("/api/v1/patients/{patientId}/periodic-reports/{reportId}/mark-read", 
                 patientId, reportId)
            .header("Authorization", "Bearer " + token)
            .exchange()
            .expectStatus().isNotFound()
            .expectBody()
            .jsonPath("$.error_code").isEqualTo("REPORT_NOT_FOUND");
    }

    // TC-API-MRR-005: No connection
    @Test
    void testMarkReportAsRead_NoConnection_Returns403() {
        // Given
        String token = generateCaregiverToken();
        String patientId = "uuid-unknown-patient";
        Long reportId = 1001L;
        
        when(grpcClient.markReportAsRead(any())).thenThrow(
            new GrpcException(Status.NOT_FOUND, "NOT_CONNECTED")
        );
        
        // When/Then
        webClient.post()
            .uri("/api/v1/patients/{patientId}/periodic-reports/{reportId}/mark-read", 
                 patientId, reportId)
            .header("Authorization", "Bearer " + token)
            .exchange()
            .expectStatus().isForbidden();
    }

    // TC-API-MRR-007: Permission denied
    @Test
    void testMarkReportAsRead_PermissionOff_Returns403() {
        // Given
        String token = generateCaregiverToken();
        String patientId = "uuid-patient-123";
        Long reportId = 1001L;
        
        when(grpcClient.markReportAsRead(any())).thenThrow(
            new GrpcException(Status.PERMISSION_DENIED, "PERMISSION_DENIED")
        );
        
        // When/Then
        webClient.post()
            .uri("/api/v1/patients/{patientId}/periodic-reports/{reportId}/mark-read", 
                 patientId, reportId)
            .header("Authorization", "Bearer " + token)
            .exchange()
            .expectStatus().isForbidden()
            .expectBody()
            .jsonPath("$.error_code").isEqualTo("PERMISSION_DENIED");
    }
```

---

# 7. Error Handling

## 7.1 Error Response Format

```json
{
  "error_code": "SELF_INVITE",
  "message": "Bạn không thể mời chính mình",
  "timestamp": "2026-01-28T10:00:00Z",
  "path": "/api/v1/connections/invite"
}
```

## 4.2 Error Code Tests

| Test ID | Error Code | HTTP | Message | Priority |
|---------|------------|:----:|---------|:--------:|
| TC-ERR-001 | SELF_INVITE | 400 | Bạn không thể mời chính mình | 🔴 P0 |
| TC-ERR-002 | DUPLICATE_PENDING | 400 | Bạn đã gửi lời mời. Đang chờ phản hồi. | 🔴 P0 |
| TC-ERR-003 | ALREADY_CONNECTED | 400 | Bạn đã kết nối với người này | 🟡 P1 |
| TC-ERR-004 | INVITE_NOT_FOUND | 404 | Lời mời không tồn tại | 🟡 P1 |
| TC-ERR-005 | CONNECTION_NOT_FOUND | 404 | Kết nối không tồn tại | 🟡 P1 |
| TC-ERR-006 | NOT_AUTHORIZED | 403 | Bạn không có quyền thực hiện | 🟡 P1 |
| TC-ERR-007 | INVALID_PERMISSION_TYPE | 400 | Loại quyền không hợp lệ | 🟡 P1 |
| TC-ERR-008 | ZNS_SEND_FAILED | 503 | Không thể gửi thông báo | 🟡 P1 |
| TC-ERR-009 | SMS_SEND_FAILED | 503 | Không thể gửi SMS | 🟡 P1 |

---

# 7. End-to-End Scenarios

## 7.1 Complete Invite Flow (Patient → Caregiver)

| Step | Action | API | Expected |
|:----:|--------|-----|----------|
| 1 | Patient creates invite | POST /invites | 201, invite_id |
| 2 | Caregiver lists invites | GET /invites | 200, received[0] matches |
| 3 | Caregiver accepts | POST /invites/{id}/accept | 200, connection_id |
| 4 | Patient lists connections | GET /connections | 200, monitored_by includes Caregiver |
| 5 | Caregiver lists connections | GET /connections | 200, monitoring includes Patient |

```java
@Test
void testE2E_PatientInvitesCaregiver_FullFlow() {
    // Step 1: Patient creates invite
    String patientToken = generatePatientToken();
    String inviteId = webClient.post()
        .uri("/api/v1/connections/invite")
        .header("Authorization", "Bearer " + patientToken)
        .bodyValue(createInviteRequest())
        .exchange()
        .expectStatus().isCreated()
        .returnResult(CreateInviteResponse.class)
        .getResponseBody()
        .blockFirst()
        .getInviteId();
        
    // Step 2: Caregiver lists invites
    String caregiverToken = generateCaregiverToken();
    webClient.get()
        .uri("/api/v1/connections/invites?type=received")
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
        .jsonPath("$.received[0].invite_id").isEqualTo(inviteId);
        
    // Step 3: Caregiver accepts
    String connectionId = webClient.post()
        .uri("/api/v1/connections/invites/{id}/accept", inviteId)
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectStatus().isOk()
        .returnResult(AcceptInviteResponse.class)
        .getResponseBody()
        .blockFirst()
        .getConnectionId();
        
    // Step 4: Patient lists connections
    webClient.get()
        .uri("/api/v1/connections")
        .header("Authorization", "Bearer " + patientToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
        .jsonPath("$.monitored_by[0].connection_id").isEqualTo(connectionId);
        
    // Step 5: Caregiver lists connections
    webClient.get()
        .uri("/api/v1/connections")
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
        .jsonPath("$.monitoring[0].connection_id").isEqualTo(connectionId);
}
```

---

## 7.2 Complete Permission Update Flow

| Step | Action | API | Expected |
|:----:|--------|-----|----------|
| 1 | Patient gets permissions | GET /connections/{id}/permissions | 200, 6 permissions |
| 2 | Patient toggles OFF | PUT /connections/{id}/permissions | 200, updated |
| 3 | Verify Caregiver view | GET /connections/{id}/permissions | 200, reflects change |
| 4 | Patient toggles ON | PUT /connections/{id}/permissions | 200, restored |

---

## 7.3 Disconnect Flow

| Step | Action | API | Expected |
|:----:|--------|-----|----------|
| 1 | List connections | GET /connections | 200, has connection |
| 2 | Disconnect | DELETE /connections/{id} | 200, disconnected |
| 3 | Verify removed | GET /connections | 200, empty/missing |
| 4 | Re-invite possible | POST /invites | 201, new invite |

---

## Summary

| Category | Test Cases | Priority Breakdown |
|----------|:----------:|:------------------:|
| Invite APIs (POST/GET/accept/reject/cancel) | 42 | 🔴 12, 🟡 22, 🟠 8 |
| Connection APIs (GET/DELETE) | 14 | 🔴 2, 🟡 10, 🟠 2 |
| Permission APIs (GET/PUT) | 12 | 🔴 3, 🟡 9, 🟠 0 |
| Permission Types API (v2.6) | 6 | 🔴 0, 🟡 4, 🟠 2 |
| Relationship Types API (v2.8) | 6 | 🔴 0, 🟡 4, 🟠 2 |
| Profile Selection APIs (v2.7) | 12 | 🔴 4, 🟡 8, 🟠 0 |
| **Dashboard APIs (v2.11)** | **17** | **🔴 10, 🟡 7, 🟠 0** |
| Error Handling | 9 | 🔴 2, 🟡 7, 🟠 0 |
| E2E Scenarios | 3 | 🔴 3, 🟡 0, 🟠 0 |
| **Total** | **~121** | **🔴 36, 🟡 71, 🟠 14** |

> **v2.11 Changes:** Added Dashboard APIs (Blood Pressure Chart + Periodic Reports) with SEC-DB-* Authorization tests

---

**Generated:** 2026-01-30T15:00:00+07:00  
**Workflow:** `/alio-testing` (v2.11)
