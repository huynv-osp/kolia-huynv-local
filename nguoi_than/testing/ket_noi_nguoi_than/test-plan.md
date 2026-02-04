# Test Plan: US 1.1 - Kết nối Người thân

> **Version:** 1.0  
> **Date:** 2026-02-04  
> **Feature Spec:** [feature-spec.md](../features/ket_noi_nguoi_than/04_output/feature-spec.md)  
> **Coverage Target:** ≥85%

---

## 1. Test Scope

### 1.1 API Groups Under Test

| Group | Endpoints | Tests |
|-------|:---------:|:-----:|
| Invite Management | 6 | 35 |
| Connection Management | 6 | 30 |
| Lookup APIs | 2 | 5 |
| Dashboard APIs | 2 | 12 |
| **Total** | **16** | **82** |

### 1.2 Services Under Test

| Service | Component | Coverage |
|---------|-----------|:--------:|
| **user-service** | InviteService, ConnectionService, PermissionService | Unit + Integration |
| **api-gateway** | ConnectionHandler | API Tests |
| **schedule-service** | Invite notifications | Unit |
| **Mobile App** | Connection screens | Component |

---

## 2. Test Categories

| Category | Count | Priority |
|----------|:-----:|:--------:|
| Unit Tests | 55 | HIGH |
| API Integration | 32 | HIGH |
| Kafka Event Tests | 8 | HIGH |
| Business Rule Tests | 25 | CRITICAL |
| Permission Tests | 15 | CRITICAL |
| **Total** | **135** | - |

---

## 3. Business Rule Test Matrix

| BR-ID | Rule | Test Cases | Priority |
|:-----:|------|:----------:|:--------:|
| BR-001 | Bi-directional invites | 4 | HIGH |
| BR-004 | ZNS → SMS fallback (3x retry) | 4 | HIGH |
| BR-006 | No self-invite | 2 | CRITICAL |
| BR-007 | No duplicate pending invite | 3 | HIGH |
| BR-009 | Default permissions ALL ON | 2 | HIGH |
| BR-018 | Red warning for emergency OFF | 2 | MEDIUM |
| BR-026 | Profile selection persisted | 3 | HIGH |
| BR-031~034 | Update pending invite perms | 4 | HIGH |
| BR-035 | Inverse relationship code | 4 | CRITICAL |
| BR-036 | Perspective display standard | 4 | CRITICAL |

---

## 4. Invite API Tests

### 4.1 POST /api/v1/connections/invite

| Test ID | Scenario | Expected | Priority |
|:-------:|----------|:--------:|:--------:|
| API-INV-001 | Patient invites Caregiver | 201 Created | HIGH |
| API-INV-002 | Caregiver invites Patient | 201 Created | HIGH |
| API-INV-003 | Self-invite | 400 Bad Request | CRITICAL |
| API-INV-004 | Duplicate pending invite | 409 Conflict | HIGH |
| API-INV-005 | Invalid phone format | 400 Bad Request | MEDIUM |
| API-INV-006 | Missing relationship | 400 Bad Request | MEDIUM |

### 4.2 POST /api/v1/connections/invites/{id}/accept

| Test ID | Scenario | Expected | Priority |
|:-------:|----------|:--------:|:--------:|
| API-INV-007 | Accept valid invite | 200 OK | HIGH |
| API-INV-008 | Accept expired invite | 410 Gone | MEDIUM |
| API-INV-009 | Accept already accepted | 409 Conflict | MEDIUM |
| API-INV-010 | Accept rejected invite | 409 Conflict | MEDIUM |
| API-INV-011 | Inverse relationship mapping | 200 OK | CRITICAL |

### 4.3 PUT /api/v1/connections/invites/{id}/permissions

| Test ID | Scenario | Expected | Priority |
|:-------:|----------|:--------:|:--------:|
| API-INV-012 | Update pending permissions | 200 OK | HIGH |
| API-INV-013 | Update non-pending invite | 400 Bad Request | MEDIUM |
| API-INV-014 | Update by non-sender | 403 Forbidden | HIGH |

---

## 5. Connection API Tests

### 5.1 GET /api/v1/connections

| Test ID | Scenario | Expected | Priority |
|:-------:|----------|:--------:|:--------:|
| API-CONN-001 | Get as Patient | 200 OK (caregivers list) | HIGH |
| API-CONN-002 | Get as Caregiver | 200 OK (patients list) | HIGH |
| API-CONN-003 | Get as Hybrid | 200 OK (both sides) | HIGH |
| API-CONN-004 | Empty connections | 200 OK (empty list) | MEDIUM |

### 5.2 GET/PUT /api/v1/connections/{id}/permissions

| Test ID | Scenario | Expected | Priority |
|:-------:|----------|:--------:|:--------:|
| API-CONN-005 | Get permissions | 200 OK (6 flags) | HIGH |
| API-CONN-006 | Update permissions | 200 OK | HIGH |
| API-CONN-007 | Update by non-owner | 403 Forbidden | HIGH |
| API-CONN-008 | Toggle emergency OFF shows warning | 200 OK | MEDIUM |

### 5.3 GET/PUT /api/v1/connections/viewing

| Test ID | Scenario | Expected | Priority |
|:-------:|----------|:--------:|:--------:|
| API-CONN-009 | Get viewing patient | 200 OK | HIGH |
| API-CONN-010 | Set viewing patient | 200 OK | HIGH |
| API-CONN-011 | Clear viewing (DELETE) | 200 OK | HIGH |
| API-CONN-012 | Set invalid connection | 400 Bad Request | MEDIUM |

---

## 6. Unit Test Summary by Service

### 6.1 user-service (45 tests)

| Class | Method | Tests | Focus |
|-------|--------|:-----:|-------|
| InviteServiceImpl | createInvite | 10 | Validation, ZNS |
| InviteServiceImpl | acceptInvite | 8 | Status, inverse mapping |
| InviteServiceImpl | rejectInvite | 4 | Status flow |
| InviteServiceImpl | updatePendingPermissions | 4 | BR-031~034 |
| ConnectionServiceImpl | getConnections | 6 | Role-based query |
| ConnectionServiceImpl | disconnect | 4 | Cleanup |
| PermissionServiceImpl | getPermissions | 4 | 6-flag model |
| PermissionServiceImpl | updatePermissions | 5 | Validation |

### 6.2 schedule-service (10 tests)

| Module | Function | Tests | Focus |
|--------|----------|:-----:|-------|
| invite_consumer | handle_invite_created | 4 | ZNS/SMS send |
| invite_consumer | handle_invite_accepted | 3 | Welcome notification |
| invite_consumer | handle_invite_rejected | 3 | Rejection notification |

---

## 7. Permission Test Matrix

| Permission | ID | Tests |
|------------|:--:|:-----:|
| Health Overview | 1 | 3 |
| Emergency Alert | 2 | 4 |
| Task Config | 3 | 2 |
| Compliance Tracking | 4 | 2 |
| Proxy Execution | 5 | 2 |
| Encouragement | 6 | 2 |

---

## 8. Inverse Relationship Tests (BR-035, BR-036)

### 8.1 Mapping Logic Tests

| Direction | relationship_code | inverse_relationship_code |
|-----------|-------------------|---------------------------|
| patient_to_caregiver | "daughter" | "mother" |
| caregiver_to_patient | "son" | "father" |

```java
@Test
@DisplayName("Should correctly map inverse relationship on accept (patient_to_caregiver)")
void acceptInvite_patientToCaregiver_mapsInverseCorrectly() {
    // Given
    // Patient (Bà Lan - Mẹ) invites Caregiver (Cô Huy)
    // relationship_code = "daughter" (Patient says: "Con gái tôi")
    // inverse = "mother" (Caregiver says: "Mẹ tôi")
    
    ConnectionInvite invite = createInvite(
        PATIENT_UUID, CAREGIVER_UUID,
        "patient_to_caregiver", "daughter"
    );
    invite.setInverseRelationshipCode("mother");
    
    // When
    inviteService.acceptInvite(invite.getInviteId());
    
    // Then
    UserEmergencyContact contact = contactRepository.findByLinkedUser(CAREGIVER_UUID);
    assertThat(contact.getRelationshipCode()).isEqualTo("daughter");
    assertThat(contact.getInverseRelationshipCode()).isEqualTo("mother");
    assertThat(contact.getRelationshipDisplay()).isEqualTo("Con gái");
    assertThat(contact.getInverseRelationshipDisplay()).isEqualTo("Mẹ");
}
```

### 8.2 Perspective Display Tests

```java
@Test
@DisplayName("Should show relationship from Patient's perspective")
void getConnection_asPatient_showsPatientPerspective() {
    // Given - Patient viewing their Caregiver connection
    
    // When
    ConnectionDto result = connectionService.getConnection(PATIENT_UUID, CONNECTION_ID);
    
    // Then
    // Patient sees: "Con gái" (how Patient calls Caregiver)
    assertThat(result.getRelationshipDisplay()).isEqualTo("Con gái");
}

@Test
@DisplayName("Should show relationship from Caregiver's perspective")
void getConnection_asCaregiver_showsCaregiverPerspective() {
    // Given - Caregiver viewing their Patient connection
    
    // When
    ConnectionDto result = connectionService.getConnection(CAREGIVER_UUID, CONNECTION_ID);
    
    // Then
    // Caregiver sees: "Mẹ" (how Caregiver calls Patient)
    assertThat(result.getRelationshipDisplay()).isEqualTo("Mẹ");
}
```

---

## 9. Coverage Matrix

| Requirement | Test IDs | Coverage |
|-------------|----------|:--------:|
| Invite Create | API-INV-001~006 | 100% |
| Invite Accept | API-INV-007~011 | 100% |
| Connection CRUD | API-CONN-001~012 | 100% |
| Permission CRUD | UT-PERM-001~015 | 100% |
| Inverse Relationship | UT-INV-001~008 | 100% |
| ZNS/SMS Notification | UT-SCH-001~010 | 100% |

**Overall Coverage: 100%** ✅

---

## 10. Test Fixtures

### 10.1 User Fixtures

| ID | Name | Phone | Role |
|:--:|------|-------|:----:|
| USER-PT-001 | Bà Lan | 0901234567 | Patient |
| USER-CG-001 | Cô Huy | 0912345678 | Caregiver |
| USER-CG-002 | Anh Minh | 0923456789 | Caregiver |
| USER-HYB-001 | Ông Tùng | 0934567890 | Hybrid |

### 10.2 Invite Fixtures

| ID | Sender | Receiver | Direction | Status |
|:--:|:------:|:--------:|:---------:|:------:|
| INV-001 | USER-PT-001 | USER-CG-001 | patient_to_caregiver | PENDING |
| INV-002 | USER-CG-002 | USER-PT-001 | caregiver_to_patient | ACCEPTED |

### 10.3 Relationship Fixtures

| Code | Vietnamese | Inverse | Inverse Vi |
|------|------------|---------|------------|
| daughter | Con gái | mother | Mẹ |
| son | Con trai | father | Cha |
| grandson | Cháu trai | grandmother | Bà |
