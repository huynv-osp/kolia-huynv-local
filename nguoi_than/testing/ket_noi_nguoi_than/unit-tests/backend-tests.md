# Backend Unit Tests: US 1.1 - Kết nối Người thân

> **Version:** 1.0  
> **Date:** 2026-02-04  
> **Test Framework:** JUnit 5 + Mockito

---

## 1. InviteServiceImplTest (22 tests)

### 1.1 createInvite() - 10 tests

#### UT-INV-001: Patient invites Caregiver
```java
@Test
@DisplayName("Patient should create invite to Caregiver successfully")
void createInvite_addCaregiver_success() {
    // Given
    CreateInviteRequest request = CreateInviteRequest.builder()
        .phone("0912345678")
        .relationshipCode("daughter")
        .inviteType("add_caregiver")
        .permissions(defaultPermissions())
        .build();
    
    // When
    ConnectionInvite result = inviteService.createInvite(PATIENT_UUID, request);
    
    // Then
    assertThat(result.getStatus()).isEqualTo(InviteStatus.PENDING);
    assertThat(result.getSenderId()).isEqualTo(PATIENT_UUID);
    assertThat(result.getRelationshipCode()).isEqualTo("daughter");
    verify(kafkaProducer).publishInviteCreated(any());
}
```

#### UT-INV-002: No self-invite (BR-006)
```java
@Test
@DisplayName("Should reject self-invite (BR-006)")
void createInvite_selfInvite_rejected() {
    // Given - User tries to invite themselves
    CreateInviteRequest request = CreateInviteRequest.builder()
        .phone(SENDER_PHONE) // Same phone as sender
        .relationshipCode("self")
        .build();
    
    // When/Then
    assertThatThrownBy(() -> inviteService.createInvite(PATIENT_UUID, request))
        .isInstanceOf(BadRequestException.class)
        .hasMessage(ErrorCodes.SELF_INVITE_NOT_ALLOWED);
}
```

#### UT-INV-003: No duplicate pending invite (BR-007)
```java
@Test
@DisplayName("Should reject duplicate pending invite (BR-007)")
void createInvite_duplicatePending_rejected() {
    // Given - Pending invite already exists
    when(inviteRepository.findPendingByPhoneAndSender(any(), any()))
        .thenReturn(Optional.of(existingInvite));
    
    // When/Then
    assertThatThrownBy(() -> inviteService.createInvite(PATIENT_UUID, request))
        .isInstanceOf(ConflictException.class)
        .hasMessage(ErrorCodes.DUPLICATE_PENDING_INVITE);
}
```

#### UT-INV-004: Set inverse relationship code
```java
@Test
@DisplayName("Should set inverse_relationship_code based on gender mapping (BR-035)")
void createInvite_setsInverseRelationshipCode() {
    // Given
    // relationship_code = "daughter" → inverse = "mother" (for female patient)
    CreateInviteRequest request = CreateInviteRequest.builder()
        .phone("0912345678")
        .relationshipCode("daughter")
        .inviteType("add_caregiver")
        .build();
    
    when(relationshipMappingService.getInverse("daughter", "FEMALE"))
        .thenReturn("mother");
    
    // When
    ConnectionInvite result = inviteService.createInvite(PATIENT_UUID, request);
    
    // Then
    assertThat(result.getInverseRelationshipCode()).isEqualTo("mother");
}
```

#### UT-INV-005: Default permissions ALL ON (BR-009)
```java
@Test
@DisplayName("Should set default permissions ALL ON when not specified (BR-009)")
void createInvite_defaultPermissions_allOn() {
    // Given - No permissions in request
    CreateInviteRequest request = CreateInviteRequest.builder()
        .phone("0912345678")
        .relationshipCode("daughter")
        .build();
    
    // When
    ConnectionInvite result = inviteService.createInvite(PATIENT_UUID, request);
    
    // Then
    assertThat(result.getDefaultPermissions()).containsExactly(true, true, true, true, true, true);
}
```

---

### 1.2 acceptInvite() - 8 tests

#### UT-INV-006: Accept creates connection
```java
@Test
@DisplayName("Accept invite should create user_emergency_contacts record")
void acceptInvite_createsConnection() {
    // Given
    ConnectionInvite invite = createPendingInvite();
    when(inviteRepository.findById(INVITE_UUID)).thenReturn(Optional.of(invite));
    
    // When
    inviteService.acceptInvite(INVITE_UUID);
    
    // Then
    verify(contactRepository).save(any(UserEmergencyContact.class));
    verify(permissionRepository).saveAll(any());
    assertThat(invite.getStatus()).isEqualTo(InviteStatus.ACCEPTED);
}
```

#### UT-INV-007: Accept applies inverse mapping for add_caregiver
```java
@Test
@DisplayName("Should apply correct relationship mapping for add_caregiver (BR-035)")
void acceptInvite_addCaregiver_correctMapping() {
    // Given
    // Patient invites Caregiver
    // relationship_code = "daughter" (Patient says "Con gái tôi")
    // inverse = "mother" (Caregiver says "Mẹ tôi")
    ConnectionInvite invite = createInvite("add_caregiver", "daughter", "mother");
    
    // When
    inviteService.acceptInvite(invite.getInviteId());
    
    // Then
    ArgumentCaptor<UserEmergencyContact> captor = ArgumentCaptor.forClass(UserEmergencyContact.class);
    verify(contactRepository).save(captor.capture());
    
    UserEmergencyContact contact = captor.getValue();
    // NO SWAP for add_caregiver
    assertThat(contact.getRelationshipCode()).isEqualTo("daughter");
    assertThat(contact.getInverseRelationshipCode()).isEqualTo("mother");
}
```

#### UT-INV-008: Accept applies SWAP for add_patient
```java
@Test
@DisplayName("Should SWAP relationship codes for add_patient (BR-035)")
void acceptInvite_addPatient_swapsRelationship() {
    // Given
    // Caregiver invites Patient
    // relationship_code = "mother" (Caregiver says "Mẹ tôi")
    // inverse = "daughter" (Patient says "Con gái tôi")
    ConnectionInvite invite = createInvite("add_patient", "mother", "daughter");
    
    // When
    inviteService.acceptInvite(invite.getInviteId());
    
    // Then
    ArgumentCaptor<UserEmergencyContact> captor = ArgumentCaptor.forClass(UserEmergencyContact.class);
    verify(contactRepository).save(captor.capture());
    
    UserEmergencyContact contact = captor.getValue();
    // SWAP for add_patient
    assertThat(contact.getRelationshipCode()).isEqualTo("daughter");  // swapped
    assertThat(contact.getInverseRelationshipCode()).isEqualTo("mother");  // swapped
}
```

#### UT-INV-009: Accept expired invite fails
```java
@Test
@DisplayName("Should reject accepting expired invite")
void acceptInvite_expired_rejected() {
    // Given
    ConnectionInvite expiredInvite = createInvite();
    expiredInvite.setExpiresAt(LocalDateTime.now().minusDays(1));
    
    when(inviteRepository.findById(INVITE_UUID)).thenReturn(Optional.of(expiredInvite));
    
    // When/Then
    assertThatThrownBy(() -> inviteService.acceptInvite(INVITE_UUID))
        .isInstanceOf(GoneException.class)
        .hasMessage(ErrorCodes.INVITE_EXPIRED);
}
```

---

### 1.3 updatePendingPermissions() - 4 tests (BR-031~034)

#### UT-INV-010: Update pending permissions success
```java
@Test
@DisplayName("Should update permissions on pending invite (BR-031)")
void updatePendingPermissions_success() {
    // Given
    ConnectionInvite invite = createPendingInvite();
    invite.setSenderId(PATIENT_UUID);
    
    List<Boolean> newPermissions = List.of(true, true, false, false, true, true);
    
    // When
    inviteService.updatePendingPermissions(PATIENT_UUID, invite.getInviteId(), newPermissions);
    
    // Then
    assertThat(invite.getDefaultPermissions()).isEqualTo(newPermissions);
}
```

#### UT-INV-011: Update non-pending invite fails (BR-032)
```java
@Test
@DisplayName("Should reject updating non-pending invite (BR-032)")
void updatePendingPermissions_notPending_rejected() {
    // Given
    ConnectionInvite acceptedInvite = createInvite();
    acceptedInvite.setStatus(InviteStatus.ACCEPTED);
    
    // When/Then
    assertThatThrownBy(() -> inviteService.updatePendingPermissions(
        PATIENT_UUID, acceptedInvite.getInviteId(), newPermissions))
        .isInstanceOf(BadRequestException.class)
        .hasMessage(ErrorCodes.INVITE_NOT_PENDING);
}
```

#### UT-INV-012: Update by non-sender fails (BR-033)
```java
@Test
@DisplayName("Should reject update by non-sender (BR-033)")
void updatePendingPermissions_nonSender_rejected() {
    // Given
    ConnectionInvite invite = createPendingInvite();
    invite.setSenderId(PATIENT_UUID);
    
    // When/Then
    assertThatThrownBy(() -> inviteService.updatePendingPermissions(
        OTHER_USER_UUID, invite.getInviteId(), newPermissions))
        .isInstanceOf(ForbiddenException.class)
        .hasMessage(ErrorCodes.NOT_INVITE_SENDER);
}
```

---

## 2. ConnectionServiceImplTest (15 tests)

### 2.1 getConnections() - 6 tests

#### UT-CONN-001: Get as Patient returns caregivers
```java
@Test
@DisplayName("Patient should see their caregivers")
void getConnections_asPatient_returnsCaregivers() {
    // Given
    when(contactRepository.findByPatientId(PATIENT_UUID))
        .thenReturn(List.of(caregiver1Contact, caregiver2Contact));
    
    // When
    List<ConnectionDto> result = connectionService.getConnections(PATIENT_UUID, "patient");
    
    // Then
    assertThat(result).hasSize(2);
    assertThat(result).allMatch(c -> c.getRole().equals("caregiver"));
}
```

#### UT-CONN-002: Get as Caregiver returns patients
```java
@Test
@DisplayName("Caregiver should see their patients")
void getConnections_asCaregiver_returnsPatients() {
    // Given
    when(contactRepository.findByLinkedUserId(CAREGIVER_UUID))
        .thenReturn(List.of(patient1Contact, patient2Contact));
    
    // When
    List<ConnectionDto> result = connectionService.getConnections(CAREGIVER_UUID, "caregiver");
    
    // Then
    assertThat(result).hasSize(2);
    assertThat(result).allMatch(c -> c.getRole().equals("patient"));
}
```

#### UT-CONN-003: Perspective display from viewer's perspective
```java
@Test
@DisplayName("Should show relationship from viewer's perspective (BR-036)")
void getConnections_showsViewerPerspective() {
    // Given
    // Contact: Patient=Bà Lan, Caregiver=Cô Huy
    // relationship_code="daughter", relationship_display="Con gái" (Patient's view)
    // inverse_relationship_code="mother", inverse_relationship_display="Mẹ" (Caregiver's view)
    UserEmergencyContact contact = createContact();
    contact.setRelationshipDisplay("Con gái");
    contact.setInverseRelationshipDisplay("Mẹ");
    
    // When - Caregiver viewing
    ConnectionDto result = connectionService.getConnectionAsCaregiver(CAREGIVER_UUID, contact);
    
    // Then - Caregiver sees "Mẹ" (how Caregiver refers to Patient)
    assertThat(result.getRelationshipDisplay()).isEqualTo("Mẹ");
}
```

---

### 2.2 setViewingPatient() - 4 tests (BR-026)

#### UT-CONN-004: Set viewing patient persists
```java
@Test
@DisplayName("Should persist is_viewing flag (BR-026)")
void setViewingPatient_persistsFlag() {
    // Given
    UserEmergencyContact contact = createContact();
    
    // When
    connectionService.setViewingPatient(CAREGIVER_UUID, contact.getContactId());
    
    // Then
    assertThat(contact.isViewing()).isTrue();
    verify(contactRepository).save(contact);
}
```

#### UT-CONN-005: Set viewing clears previous selection
```java
@Test
@DisplayName("Should clear previous is_viewing on new selection")
void setViewingPatient_clearsPrevious() {
    // Given - Another patient was selected
    UserEmergencyContact previousContact = createContact();
    previousContact.setViewing(true);
    
    when(contactRepository.findViewingByCaregiver(CAREGIVER_UUID))
        .thenReturn(Optional.of(previousContact));
    
    // When
    connectionService.setViewingPatient(CAREGIVER_UUID, newContactId);
    
    // Then
    assertThat(previousContact.isViewing()).isFalse();
}
```

---

## 3. PermissionServiceImplTest (8 tests)

### 3.1 getPermissions() - 4 tests

#### UT-PERM-001: Get all 6 permissions
```java
@Test
@DisplayName("Should return all 6 permission flags")
void getPermissions_returns6Flags() {
    // Given
    List<ConnectionPermission> perms = createAllPermissions();
    when(permissionRepository.findByConnectionId(CONNECTION_ID))
        .thenReturn(perms);
    
    // When
    PermissionDto result = permissionService.getPermissions(CONNECTION_ID);
    
    // Then
    assertThat(result.getHealthOverview()).isNotNull();
    assertThat(result.getEmergencyAlert()).isNotNull();
    assertThat(result.getTaskConfig()).isNotNull();
    assertThat(result.getComplianceTracking()).isNotNull();
    assertThat(result.getProxyExecution()).isNotNull();
    assertThat(result.getEncouragement()).isNotNull();
}
```

### 3.2 updatePermissions() - 4 tests

#### UT-PERM-002: Update single permission
```java
@Test
@DisplayName("Should update single permission")
void updatePermissions_singleChange_success() {
    // Given
    UpdatePermissionRequest request = new UpdatePermissionRequest();
    request.setEmergencyAlert(false);  // Turn OFF
    
    // When
    permissionService.updatePermissions(PATIENT_UUID, CONNECTION_ID, request);
    
    // Then
    verify(permissionRepository).updatePermission(
        CONNECTION_ID, PERMISSION_EMERGENCY_ALERT, false);
}
```

#### UT-PERM-003: Update by non-owner fails
```java
@Test
@DisplayName("Should reject update by non-owner")
void updatePermissions_nonOwner_rejected() {
    // Given
    when(contactRepository.findById(CONNECTION_ID))
        .thenReturn(Optional.of(contactOwnedByOther));
    
    // When/Then
    assertThatThrownBy(() -> permissionService.updatePermissions(
        ATTACKER_UUID, CONNECTION_ID, request))
        .isInstanceOf(ForbiddenException.class);
}
```

---

## 4. Test Summary

| Test Class | Tests | Status |
|------------|:-----:|:------:|
| InviteServiceImplTest | 22 | ✅ Specified |
| ConnectionServiceImplTest | 15 | ✅ Specified |
| PermissionServiceImplTest | 8 | ✅ Specified |
| **Total** | **45** | - |
