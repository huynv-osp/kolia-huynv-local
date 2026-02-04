# API Integration Tests: US 1.1 - Kết nối Người thân

> **Version:** 1.0  
> **Date:** 2026-02-04  
> **Test Framework:** WebTestClient (Java)

---

## 1. Invite Management APIs

### POST /api/v1/connections/invite

#### API-INV-001: Patient invites Caregiver
```java
@Test
void createInvite_patientToCaregiver_returns201() {
    CreateInviteRequest request = CreateInviteRequest.builder()
        .phone("0912345678")
        .relationshipCode("daughter")
        .inviteType("patient_to_caregiver")
        .build();
    
    webTestClient.post()
        .uri("/api/v1/connections/invite")
        .header("Authorization", "Bearer " + patientToken)
        .contentType(MediaType.APPLICATION_JSON)
        .bodyValue(request)
        .exchange()
        .expectStatus().isCreated()
        .expectBody()
            .jsonPath("$.invite_id").isNotEmpty()
            .jsonPath("$.status").isEqualTo("PENDING")
            .jsonPath("$.inverse_relationship_code").isNotEmpty();
}
```

#### API-INV-002: Caregiver invites Patient
```java
@Test
void createInvite_caregiverToPatient_returns201() {
    CreateInviteRequest request = CreateInviteRequest.builder()
        .phone("0901234567")
        .relationshipCode("mother")
        .inviteType("caregiver_to_patient")
        .build();
    
    webTestClient.post()
        .uri("/api/v1/connections/invite")
        .header("Authorization", "Bearer " + caregiverToken)
        .contentType(MediaType.APPLICATION_JSON)
        .bodyValue(request)
        .exchange()
        .expectStatus().isCreated();
}
```

#### API-INV-003: Self-invite rejected (BR-006)
```java
@Test
void createInvite_selfInvite_returns400() {
    CreateInviteRequest request = CreateInviteRequest.builder()
        .phone(SENDER_PHONE)  // Same as token owner
        .relationshipCode("self")
        .build();
    
    webTestClient.post()
        .uri("/api/v1/connections/invite")
        .header("Authorization", "Bearer " + patientToken)
        .contentType(MediaType.APPLICATION_JSON)
        .bodyValue(request)
        .exchange()
        .expectStatus().isBadRequest()
        .expectBody()
            .jsonPath("$.error").isEqualTo("SELF_INVITE_NOT_ALLOWED");
}
```

#### API-INV-004: Duplicate pending invite (BR-007)
```java
@Test
void createInvite_duplicatePending_returns409() {
    // Given - Pending invite exists
    createPendingInvite("0912345678");
    
    CreateInviteRequest request = CreateInviteRequest.builder()
        .phone("0912345678")
        .relationshipCode("daughter")
        .build();
    
    webTestClient.post()
        .uri("/api/v1/connections/invite")
        .header("Authorization", "Bearer " + patientToken)
        .contentType(MediaType.APPLICATION_JSON)
        .bodyValue(request)
        .exchange()
        .expectStatus().isEqualTo(409);
}
```

---

### POST /api/v1/connections/invites/{id}/accept

#### API-INV-005: Accept invite creates connection
```java
@Test
void acceptInvite_valid_returns200() {
    // Given
    String inviteId = createTestInvite();
    
    webTestClient.post()
        .uri("/api/v1/connections/invites/" + inviteId + "/accept")
        .header("Authorization", "Bearer " + receiverToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
            .jsonPath("$.connection_id").isNotEmpty();
    
    // Verify connection created
    webTestClient.get()
        .uri("/api/v1/connections")
        .header("Authorization", "Bearer " + receiverToken)
        .exchange()
        .expectBody()
            .jsonPath("$.connections").isNotEmpty();
}
```

#### API-INV-006: Accept with inverse relationship mapping (BR-035)
```java
@Test
void acceptInvite_mapsInverseCorrectly() {
    // Given - Patient invites with relationship="daughter", inverse="mother"
    String inviteId = createTestInvite("daughter", "mother");
    
    webTestClient.post()
        .uri("/api/v1/connections/invites/" + inviteId + "/accept")
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectStatus().isOk();
    
    // Verify relationship mapping
    webTestClient.get()
        .uri("/api/v1/connections")
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectBody()
            .jsonPath("$.connections[0].relationship_display").isEqualTo("Mẹ");
}
```

#### API-INV-007: Accept expired invite
```java
@Test
void acceptInvite_expired_returns410() {
    String expiredInviteId = createExpiredInvite();
    
    webTestClient.post()
        .uri("/api/v1/connections/invites/" + expiredInviteId + "/accept")
        .header("Authorization", "Bearer " + receiverToken)
        .exchange()
        .expectStatus().isEqualTo(410);
}
```

---

### PUT /api/v1/connections/invites/{id}/permissions (BR-031~034)

#### API-INV-008: Update pending permissions
```java
@Test
void updatePendingPermissions_valid_returns200() {
    String inviteId = createTestInvite();
    List<Boolean> newPerms = List.of(true, true, false, false, true, true);
    
    webTestClient.put()
        .uri("/api/v1/connections/invites/" + inviteId + "/permissions")
        .header("Authorization", "Bearer " + senderToken)
        .contentType(MediaType.APPLICATION_JSON)
        .bodyValue(Map.of("permissions", newPerms))
        .exchange()
        .expectStatus().isOk();
}
```

#### API-INV-009: Update by non-sender fails (BR-033)
```java
@Test
void updatePendingPermissions_nonSender_returns403() {
    String inviteId = createTestInvite();
    
    webTestClient.put()
        .uri("/api/v1/connections/invites/" + inviteId + "/permissions")
        .header("Authorization", "Bearer " + otherUserToken)
        .contentType(MediaType.APPLICATION_JSON)
        .bodyValue(Map.of("permissions", List.of(true, true, true, true, true, true)))
        .exchange()
        .expectStatus().isForbidden();
}
```

---

## 2. Connection Management APIs

### GET /api/v1/connections

#### API-CONN-001: Get as Patient
```java
@Test
void getConnections_asPatient_returnsCaregivers() {
    webTestClient.get()
        .uri("/api/v1/connections")
        .header("Authorization", "Bearer " + patientToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
            .jsonPath("$.connections").isArray()
            .jsonPath("$.connections[0].role").isEqualTo("caregiver")
            .jsonPath("$.connections[0].relationship_display").isNotEmpty();
}
```

#### API-CONN-002: Get as Caregiver
```java
@Test
void getConnections_asCaregiver_returnsPatients() {
    webTestClient.get()
        .uri("/api/v1/connections")
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
            .jsonPath("$.connections[0].role").isEqualTo("patient")
            // Caregiver sees from their perspective (BR-036)
            .jsonPath("$.connections[0].relationship_display").isEqualTo("Mẹ");
}
```

---

### GET/PUT /api/v1/connections/{id}/permissions

#### API-CONN-003: Get permissions
```java
@Test
void getPermissions_returns6Flags() {
    webTestClient.get()
        .uri("/api/v1/connections/" + connectionId + "/permissions")
        .header("Authorization", "Bearer " + patientToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
            .jsonPath("$.health_overview").isBoolean()
            .jsonPath("$.emergency_alert").isBoolean()
            .jsonPath("$.task_config").isBoolean()
            .jsonPath("$.compliance_tracking").isBoolean()
            .jsonPath("$.proxy_execution").isBoolean()
            .jsonPath("$.encouragement").isBoolean();
}
```

#### API-CONN-004: Update permissions
```java
@Test
void updatePermissions_toggle_returns200() {
    UpdatePermissionRequest request = new UpdatePermissionRequest();
    request.setEmergencyAlert(false);  // Toggle OFF
    
    webTestClient.put()
        .uri("/api/v1/connections/" + connectionId + "/permissions")
        .header("Authorization", "Bearer " + patientToken)
        .contentType(MediaType.APPLICATION_JSON)
        .bodyValue(request)
        .exchange()
        .expectStatus().isOk();
}
```

---

### GET/PUT/DELETE /api/v1/connections/viewing (BR-026)

#### API-CONN-005: Get viewing patient
```java
@Test
void getViewingPatient_returns200() {
    webTestClient.get()
        .uri("/api/v1/connections/viewing")
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
            .jsonPath("$.patient_id").isNotEmpty();
}
```

#### API-CONN-006: Set viewing patient
```java
@Test
void setViewingPatient_persists() {
    webTestClient.put()
        .uri("/api/v1/connections/viewing")
        .header("Authorization", "Bearer " + caregiverToken)
        .contentType(MediaType.APPLICATION_JSON)
        .bodyValue(Map.of("connection_id", connectionId))
        .exchange()
        .expectStatus().isOk();
    
    // Verify persisted
    webTestClient.get()
        .uri("/api/v1/connections/viewing")
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectBody()
            .jsonPath("$.connection_id").isEqualTo(connectionId);
}
```

#### API-CONN-007: Clear viewing (DELETE)
```java
@Test
void clearViewingPatient_returns200() {
    webTestClient.delete()
        .uri("/api/v1/connections/viewing")
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectStatus().isOk();
}
```

---

## 3. Lookup APIs

### GET /api/v1/connection/relationship-types

#### API-LOOKUP-001: Get relationship types
```java
@Test
void getRelationshipTypes_returns17Types() {
    webTestClient.get()
        .uri("/api/v1/connection/relationship-types")
        .header("Authorization", "Bearer " + token)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
            .jsonPath("$.types").isArray()
            .jsonPath("$.types.length()").isEqualTo(17);
}
```

---

## 4. Test Summary

| API Group | Tests |
|-----------|:-----:|
| Invite Create | 4 |
| Invite Accept/Reject | 3 |
| Invite Permissions | 2 |
| Connection List | 2 |
| Connection Permissions | 2 |
| Viewing Patient | 3 |
| Lookup | 1 |
| **Total** | **17** |
