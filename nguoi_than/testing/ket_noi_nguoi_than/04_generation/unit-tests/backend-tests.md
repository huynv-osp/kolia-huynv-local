# 🧪 Backend Unit Tests - KOLIA-1517 Kết nối Người thân

> **Version:** 1.4  
> **Date:** 2026-01-30  
> **Coverage Target:** ≥85%  
> **Total Test Cases:** ~190 (+8 DashboardService v2.13)

---

## Table of Contents

1. [user-service Tests](#1-user-service-tests)
2. [api-gateway-service Tests](#2-api-gateway-service-tests)
3. [schedule-service Tests](#3-schedule-service-tests)

---

# 1. user-service Tests (Java/Vert.x)

> **Package:** `com.company.userservice.connection`  
> **Framework:** JUnit 5 + Mockito  
> **Coverage Target:** ≥85%

---

## 1.1 InviteService Tests

### File: `InviteServiceTest.java`

#### Test Suite: createInvite()

| Test ID | Test Name | Description | BR | Priority |
|---------|-----------|-------------|:--:|:--------:|
| TC-INV-001 | testCreateInvite_PatientToCaregiver_ExistingUser_Success | Patient gửi invite cho Caregiver có tài khoản | BR-001 | 🔴 P0 |
| TC-INV-002 | testCreateInvite_CaregiverToPatient_ExistingUser_Success | Caregiver gửi invite cho Patient có tài khoản | BR-001 | 🔴 P0 |
| TC-INV-003 | testCreateInvite_PatientToCaregiver_NewUser_Success | Patient gửi invite cho người chưa có tài khoản | BR-003 | 🔴 P0 |
| TC-INV-004 | testCreateInvite_CaregiverToPatient_NewUser_Success | Caregiver gửi invite cho người chưa có tài khoản | BR-003 | 🔴 P0 |
| TC-INV-005 | testCreateInvite_SelfInvite_ThrowException | Mời chính mình → SELF_INVITE error | BR-006 | 🔴 P0 |
| TC-INV-006 | testCreateInvite_DuplicatePending_ThrowException | Đã có pending invite → DUPLICATE_PENDING | BR-007 | 🔴 P0 |
| TC-INV-007 | testCreateInvite_AlreadyConnected_ThrowException | Đã kết nối → ALREADY_CONNECTED | BR-007 | 🟡 P1 |
| TC-INV-008 | testCreateInvite_WithPermissions_PermissionsSaved | Permissions được lưu vào invite | BR-009 | 🔴 P0 |
| TC-INV-009 | testCreateInvite_PublishKafkaEvent_Success | Kafka event connection.invite.created published | - | 🟡 P1 |
| TC-INV-010 | testCreateInvite_InvalidPhone_ThrowValidationException | SĐT không hợp lệ → 400 | - | 🟡 P1 |
| TC-INV-011 | testCreateInvite_InvalidRelationship_ThrowValidationException | Relationship không hợp lệ → 400 | BR-028 | 🟡 P1 |
| TC-INV-012 | testCreateInvite_AfterReject_Success | Gửi lại sau khi bị reject → OK | BR-011 | 🟡 P1 |

#### Test Suite: cancelInvite()

| Test ID | Test Name | Description | BR | Priority |
|---------|-----------|-------------|:--:|:--------:|
| TC-INV-020 | testCancelInvite_BySender_Success | Hủy lời mời bởi sender | - | 🔴 P0 |
| TC-INV-021 | testCancelInvite_NotSender_ThrowException | Không phải sender → 403 | - | 🟡 P1 |
| TC-INV-022 | testCancelInvite_InviteNotFound_ThrowException | Invite không tồn tại | - | 🟡 P1 |
| TC-INV-023 | testCancelInvite_AlreadyAccepted_ThrowException | Đã accept → 400 | - | 🟡 P1 |
| TC-INV-024 | testCancelInvite_PublishKafkaEvent_Success | Kafka event invite.cancelled published | - | 🟡 P1 |

```java
@ExtendWith(MockitoExtension.class)
class InviteServiceTest {

    @Mock
    private InviteRepository inviteRepository;
    
    @Mock
    private ConnectionRepository connectionRepository;
    
    @Mock
    private UserRepository userRepository;
    
    @Mock
    private KafkaTemplate<String, Object> kafkaTemplate;
    
    @InjectMocks
    private InviteService inviteService;

    // TC-INV-001: Patient gửi invite cho Caregiver có tài khoản
    @Test
    void testCreateInvite_PatientToCaregiver_ExistingUser_Success() {
        // Given
        UUID senderId = UUID.randomUUID();
        String receiverPhone = "0912345678";
        UUID receiverId = UUID.randomUUID();
        
        CreateInviteRequest request = CreateInviteRequest.builder()
            .senderUserId(senderId)
            .receiverPhone(receiverPhone)
            .receiverName("Nguyễn Văn A")
            .relationship("con_trai")
            .inviteType(InviteType.PATIENT_TO_CAREGIVER)
            .permissions(defaultPermissions())
            .build();
            
        when(userRepository.findByPhone(receiverPhone))
            .thenReturn(Optional.of(new User(receiverId, "Nguyễn Văn A", receiverPhone)));
        when(inviteRepository.existsPendingInvite(senderId, receiverPhone))
            .thenReturn(false);
        when(connectionRepository.existsConnection(senderId, receiverPhone))
            .thenReturn(false);
            
        // When
        InviteResponse response = inviteService.createInvite(request);
        
        // Then
        assertNotNull(response.getInviteId());
        assertEquals("pending", response.getStatus());
        verify(inviteRepository).save(any(ConnectionInvite.class));
        verify(kafkaTemplate).send(eq("connection.invite.created"), any());
    }

    // TC-INV-005: Self-invite blocked
    @Test
    void testCreateInvite_SelfInvite_ThrowException() {
        // Given
        UUID userId = UUID.randomUUID();
        when(userRepository.findByPhone("0912345678"))
            .thenReturn(Optional.of(new User(userId, "Self", "0912345678")));
            
        CreateInviteRequest request = CreateInviteRequest.builder()
            .senderUserId(userId)
            .receiverPhone("0912345678")
            .inviteType(InviteType.PATIENT_TO_CAREGIVER)
            .build();
        
        // When/Then
        BusinessException ex = assertThrows(BusinessException.class,
            () -> inviteService.createInvite(request));
        assertEquals("SELF_INVITE", ex.getErrorCode());
    }

    // TC-INV-006: Duplicate pending blocked
    @Test
    void testCreateInvite_DuplicatePending_ThrowException() {
        // Given
        UUID senderId = UUID.randomUUID();
        when(inviteRepository.existsPendingInvite(senderId, "0912345678"))
            .thenReturn(true);
            
        CreateInviteRequest request = CreateInviteRequest.builder()
            .senderUserId(senderId)
            .receiverPhone("0912345678")
            .inviteType(InviteType.PATIENT_TO_CAREGIVER)
            .build();
        
        // When/Then
        BusinessException ex = assertThrows(BusinessException.class,
            () -> inviteService.createInvite(request));
        assertEquals("DUPLICATE_PENDING", ex.getErrorCode());
    }

    // TC-INV-012: Re-invite after reject
    @Test
    void testCreateInvite_AfterReject_Success() {
        // Given
        UUID senderId = UUID.randomUUID();
        String receiverPhone = "0912345678";
        
        // Previous invite was rejected
        when(inviteRepository.existsPendingInvite(senderId, receiverPhone))
            .thenReturn(false);
        when(connectionRepository.existsConnection(senderId, receiverPhone))
            .thenReturn(false);
        when(inviteRepository.findRejectedInvite(senderId, receiverPhone))
            .thenReturn(Optional.of(rejectedInvite()));
            
        CreateInviteRequest request = CreateInviteRequest.builder()
            .senderUserId(senderId)
            .receiverPhone(receiverPhone)
            .inviteType(InviteType.PATIENT_TO_CAREGIVER)
            .build();
        
        // When
        InviteResponse response = inviteService.createInvite(request);
        
        // Then
        assertNotNull(response.getInviteId());
        assertEquals("pending", response.getStatus());
    }
}
```

#### Test Suite: listInvites()

| Test ID | Test Name | Description | BR | Priority |
|---------|-----------|-------------|:--:|:--------:|
| TC-INV-013 | testListInvites_SentPending_ReturnsCorrectList | Lấy danh sách invite đã gửi (pending) | - | 🟡 P1 |
| TC-INV-014 | testListInvites_ReceivedPending_ReturnsCorrectList | Lấy danh sách invite nhận được (pending) | - | 🟡 P1 |
| TC-INV-015 | testListInvites_MultipleInvites_FIFOOrder | Multiple invites sắp xếp FIFO | BR-013 | 🟢 P2 |
| TC-INV-016 | testListInvites_FilterByType_Works | Filter theo invite_type | - | 🟢 P2 |
| TC-INV-017 | testListInvites_FilterByStatus_Works | Filter theo status | - | 🟢 P2 |
| TC-INV-018 | testListInvites_Empty_ReturnEmptyList | Không có invite nào | BR-015 | 🟢 P2 |
| TC-INV-019 | testListInvites_TotalPendingCount_Correct | total_pending đếm đúng | BR-023 | 🟡 P1 |

```java
    // TC-INV-015: FIFO order
    @Test
    void testListInvites_MultipleInvites_FIFOOrder() {
        // Given
        UUID userId = UUID.randomUUID();
        List<ConnectionInvite> invites = Arrays.asList(
            inviteWithCreatedAt(userId, LocalDateTime.now().minusHours(2)),
            inviteWithCreatedAt(userId, LocalDateTime.now().minusHours(1)),
            inviteWithCreatedAt(userId, LocalDateTime.now())
        );
        when(inviteRepository.findReceivedByUserId(userId, InviteStatus.PENDING))
            .thenReturn(invites);
        
        // When
        ListInvitesResponse response = inviteService.listInvites(userId, "received", "pending");
        
        // Then
        assertEquals(3, response.getReceived().size());
        // FIFO = oldest first
        assertTrue(response.getReceived().get(0).getCreatedAt()
            .isBefore(response.getReceived().get(1).getCreatedAt()));
    }
```

---

## 1.2 ConnectionService Tests

### File: `ConnectionServiceTest.java`

#### Test Suite: acceptInvite()

| Test ID | Test Name | Description | BR | Priority |
|---------|-----------|-------------|:--:|:--------:|
| TC-CON-001 | testAcceptInvite_PatientAcceptsFromCaregiver_WithPermissions | Patient accept và config permissions | BR-008 | 🔴 P0 |
| TC-CON-002 | testAcceptInvite_CaregiverAcceptsFromPatient_QuickAccept | Caregiver quick accept (no permission config) | BR-009 | 🔴 P0 |
| TC-CON-003 | testAcceptInvite_CreateConnectionRecord_Success | Connection record được tạo | BR-008 | 🔴 P0 |
| TC-CON-004 | testAcceptInvite_Create6Permissions_Success | 6 permissions được tạo | BR-009 | 🔴 P0 |
| TC-CON-005 | testAcceptInvite_ExtendUserEmergencyContact_Success | user_emergency_contacts được extend | - | 🔴 P0 |
| TC-CON-006 | testAcceptInvite_PublishKafkaEvent_Success | Kafka event invite.accepted published | BR-010 | 🟡 P1 |
| TC-CON-007 | testAcceptInvite_InviteNotFound_ThrowException | Invite không tồn tại | - | 🟡 P1 |
| TC-CON-008 | testAcceptInvite_NotAuthorized_ThrowException | Không phải receiver | - | 🟡 P1 |
| TC-CON-009 | testAcceptInvite_AlreadyAccepted_ThrowException | Invite đã accept | - | 🟡 P1 |
| TC-CON-010 | testAcceptInvite_RelationshipStored_Success | Relationship được lưu vào connection | BR-028 | 🔴 P0 |

```java
@ExtendWith(MockitoExtension.class)
class ConnectionServiceTest {

    @Mock
    private InviteRepository inviteRepository;
    
    @Mock
    private ConnectionRepository connectionRepository;
    
    @Mock
    private PermissionRepository permissionRepository;
    
    @Mock
    private EmergencyContactRepository emergencyContactRepository;
    
    @Mock
    private KafkaTemplate<String, Object> kafkaTemplate;
    
    @InjectMocks
    private ConnectionService connectionService;

    // TC-CON-001: Patient accepts with permissions
    @Test
    void testAcceptInvite_PatientAcceptsFromCaregiver_WithPermissions() {
        // Given
        UUID inviteId = UUID.randomUUID();
        UUID patientId = UUID.randomUUID();
        UUID caregiverId = UUID.randomUUID();
        
        ConnectionInvite invite = ConnectionInvite.builder()
            .inviteId(inviteId)
            .senderId(caregiverId)  // Caregiver sent
            .receiverId(patientId)  // Patient receives
            .inviteType(InviteType.CAREGIVER_TO_PATIENT)
            .status(InviteStatus.PENDING)
            .relationshipCode("con_trai")
            .build();
            
        Map<String, Boolean> customPermissions = Map.of(
            "health_overview", true,
            "emergency_alert", true,
            "task_config", false,
            "compliance_tracking", true,
            "proxy_execution", false,
            "encouragement", true
        );
        
        AcceptInviteRequest request = AcceptInviteRequest.builder()
            .inviteId(inviteId)
            .acceptorId(patientId)
            .permissions(customPermissions)
            .build();
            
        when(inviteRepository.findById(inviteId))
            .thenReturn(Optional.of(invite));
            
        // When
        ConnectionResponse response = connectionService.acceptInvite(request);
        
        // Then
        assertNotNull(response.getConnectionId());
        assertEquals("active", response.getStatus());
        verify(permissionRepository, times(6)).save(any(ConnectionPermission.class));
        verify(kafkaTemplate).send(eq("connection.invite.accepted"), any());
    }

    // TC-CON-002: Caregiver quick accept
    @Test
    void testAcceptInvite_CaregiverAcceptsFromPatient_QuickAccept() {
        // Given
        UUID inviteId = UUID.randomUUID();
        UUID patientId = UUID.randomUUID();
        UUID caregiverId = UUID.randomUUID();
        
        Map<String, Boolean> presetPermissions = Map.of(
            "health_overview", true,
            "emergency_alert", true,
            "task_config", true,
            "compliance_tracking", true,
            "proxy_execution", true,
            "encouragement", true
        );
        
        ConnectionInvite invite = ConnectionInvite.builder()
            .inviteId(inviteId)
            .senderId(patientId)  // Patient sent
            .receiverId(caregiverId)  // Caregiver receives
            .inviteType(InviteType.PATIENT_TO_CAREGIVER)
            .status(InviteStatus.PENDING)
            .initialPermissions(JsonUtil.toJson(presetPermissions))
            .build();
            
        AcceptInviteRequest request = AcceptInviteRequest.builder()
            .inviteId(inviteId)
            .acceptorId(caregiverId)
            // No permissions - use preset from invite
            .build();
            
        when(inviteRepository.findById(inviteId))
            .thenReturn(Optional.of(invite));
            
        // When
        ConnectionResponse response = connectionService.acceptInvite(request);
        
        // Then
        // Uses permissions from invite (preset by Patient)
        verify(permissionRepository, times(6)).save(any(ConnectionPermission.class));
    }

    // TC-CON-010: Relationship stored
    @Test
    void testAcceptInvite_RelationshipStored_Success() {
        // Given
        ConnectionInvite invite = inviteWithRelationship("me");
        when(inviteRepository.findById(any())).thenReturn(Optional.of(invite));
        
        // When
        ConnectionResponse response = connectionService.acceptInvite(defaultAcceptRequest());
        
        // Then
        ArgumentCaptor<UserEmergencyContact> captor = 
            ArgumentCaptor.forClass(UserEmergencyContact.class);
        verify(emergencyContactRepository).save(captor.capture());
        assertEquals("me", captor.getValue().getRelationshipCode());
    }
}
```

#### Test Suite: listConnections()

| Test ID | Test Name | Description | BR | Priority |
|---------|-----------|-------------|:--:|:--------:|
| TC-CON-011 | testListConnections_Monitoring_ReturnsPatients | Danh sách Patients đang theo dõi | BR-014 | 🟡 P1 |
| TC-CON-012 | testListConnections_MonitoredBy_ReturnsCaregivers | Danh sách Caregivers đang theo dõi mình | BR-014 | 🟡 P1 |
| TC-CON-013 | testListConnections_IncludesLastActive | last_active được include | BR-014 | 🟡 P1 |
| TC-CON-014 | testListConnections_RelationshipDisplay_Formatted | relationship_display format đúng | BR-029 | 🟡 P1 |
| TC-CON-015 | testListConnections_RelationshipKhac_DisplayNguoiThan | "khac" → "Người thân" | BR-029 | 🟡 P1 |
| TC-CON-016 | testListConnections_Empty_ReturnsEmptyLists | Không có connection nào | BR-015 | 🟢 P2 |
| TC-CON-017 | testListConnections_NoLimit_ReturnsAll | Phase 1: Không giới hạn | BR-021 | 🟡 P1 |

```java
    // TC-CON-015: "khac" → "Người thân"
    @Test
    void testListConnections_RelationshipKhac_DisplayNguoiThan() {
        // Given
        UUID userId = UUID.randomUUID();
        UserEmergencyContact contact = UserEmergencyContact.builder()
            .contactId(UUID.randomUUID())
            .userId(userId)
            .linkedUserId(UUID.randomUUID())
            .name("Nguyễn Văn A")
            .relationshipCode("khac")
            .contactType(ContactType.CAREGIVER)
            .build();
            
        when(emergencyContactRepository.findCaregiversByUserId(userId))
            .thenReturn(List.of(contact));
        
        // When
        ListConnectionsResponse response = connectionService.listConnections(userId);
        
        // Then
        assertEquals(1, response.getMonitoredBy().size());
        // BR-029: "khac" → "Người thân (Tên)"
        assertEquals("Người thân (Nguyễn Văn A)", 
            response.getMonitoredBy().get(0).getRelationshipDisplay());
    }
```

#### Test Suite: disconnect()

| Test ID | Test Name | Description | BR | Priority |
|---------|-----------|-------------|:--:|:--------:|
| TC-CON-018 | testDisconnect_PatientDisconnects_Success | Patient hủy kết nối | BR-019 | 🟡 P1 |
| TC-CON-019 | testDisconnect_CaregiverExits_Success | Caregiver ngừng theo dõi | BR-020 | 🟡 P1 |
| TC-CON-020 | testDisconnect_PublishKafkaEvent_Success | Kafka event published | BR-019 | 🟡 P1 |
| TC-CON-021 | testDisconnect_NotFound_ThrowException | Connection không tồn tại | - | 🟡 P1 |
| TC-CON-022 | testDisconnect_NotAuthorized_ThrowException | Không phải participant | - | 🟡 P1 |
| TC-CON-023 | testDisconnect_CascadeDeletePermissions | Permissions bị xóa | - | 🟡 P1 |

---

## 1.4 ViewingPatientService Tests (v2.7)

### File: `ViewingPatientServiceTest.java`

| Test ID | Test Name | Description | BR | Priority |
|---------|-----------|-------------|:--:|:--------:|
| TC-VW-001 | testGetViewingPatient_HasSelection_Success | Có patient đang được chọn | BR-026 | 🔴 P0 |
| TC-VW-002 | testGetViewingPatient_NoSelection_ReturnsNull | Chưa chọn patient nào | BR-026 | 🟡 P1 |
| TC-VW-003 | testGetViewingPatient_IsPurePatient_ReturnsSelf | User là Patient thuần | - | 🟡 P1 |
| TC-VW-004 | testSetViewingPatient_FirstSelection_Success | Lần đầu chọn patient | BR-026 | 🔴 P0 |
| TC-VW-005 | testSetViewingPatient_Switch_ClearsPrevious | Đổi sang patient khác | BR-026 | 🔴 P0 |
| TC-VW-006 | testSetViewingPatient_NotConnected_ThrowsException | Patient không trong connections | - | 🟡 P1 |
| TC-VW-007 | testSetViewingPatient_UniqueConstraint_Works | idx_unique_viewing_patient | BR-026 | 🟡 P1 |
| TC-VW-008 | testSetViewingPatient_PublishKafkaEvent | Kafka event published | - | 🟢 P2 |
| TC-VW-009 | testSetViewingPatient_AtomicTransaction | Rollback on failure | BR-026 | 🔴 P0 |

```java
@ExtendWith(MockitoExtension.class)
class ViewingPatientServiceTest {

    @Mock
    private EmergencyContactRepository emergencyContactRepository;
    
    @Mock
    private KafkaTemplate<String, Object> kafkaTemplate;
    
    @InjectMocks
    private ViewingPatientService viewingPatientService;

    // TC-VW-001: Has viewing patient
    @Test
    void testGetViewingPatient_HasSelection_Success() {
        // Given
        UUID caregiverId = UUID.randomUUID();
        UUID patientId = UUID.randomUUID();
        
        UserEmergencyContact viewingContact = UserEmergencyContact.builder()
            .contactId(UUID.randomUUID())
            .userId(caregiverId)
            .linkedUserId(patientId)
            .name("Nguyễn Thị Patient")
            .contactType(ContactType.CAREGIVER)
            .isViewing(true)
            .build();
            
        when(emergencyContactRepository.findViewingPatient(caregiverId))
            .thenReturn(Optional.of(viewingContact));
        
        // When
        ViewingPatientResponse response = viewingPatientService.getViewingPatient(caregiverId);
        
        // Then
        assertNotNull(response.getPatient());
        assertEquals(patientId, response.getPatient().getId());
        assertEquals("Nguyễn Thị Patient", response.getPatient().getName());
    }

    // TC-VW-005: Switch clears previous
    @Test
    void testSetViewingPatient_Switch_ClearsPrevious() {
        // Given
        UUID caregiverId = UUID.randomUUID();
        UUID oldPatientId = UUID.randomUUID();
        UUID newPatientId = UUID.randomUUID();
        
        UserEmergencyContact previousViewing = contactWithViewing(caregiverId, oldPatientId, true);
        UserEmergencyContact newConnection = contactWithViewing(caregiverId, newPatientId, false);
        
        when(emergencyContactRepository.findViewingPatient(caregiverId))
            .thenReturn(Optional.of(previousViewing));
        when(emergencyContactRepository.findByUserAndLinkedUser(caregiverId, newPatientId))
            .thenReturn(Optional.of(newConnection));
            
        SetViewingPatientRequest request = SetViewingPatientRequest.builder()
            .caregiverId(caregiverId)
            .patientId(newPatientId)
            .build();
        
        // When
        ViewingPatientResponse response = viewingPatientService.setViewingPatient(request);
        
        // Then
        // Verify previous was cleared
        ArgumentCaptor<UserEmergencyContact> captor = 
            ArgumentCaptor.forClass(UserEmergencyContact.class);
        verify(emergencyContactRepository, times(2)).save(captor.capture());
        
        List<UserEmergencyContact> savedContacts = captor.getAllValues();
        assertFalse(savedContacts.get(0).isViewing()); // Old cleared
        assertTrue(savedContacts.get(1).isViewing());  // New set
    }

    // TC-VW-009: Atomic transaction
    @Test
    void testSetViewingPatient_AtomicTransaction_RollbackOnFailure() {
        // Given
        UUID caregiverId = UUID.randomUUID();
        
        when(emergencyContactRepository.findByUserAndLinkedUser(any(), any()))
            .thenThrow(new DataAccessException("DB Error") {});
        
        // When/Then
        assertThrows(DataAccessException.class,
            () -> viewingPatientService.setViewingPatient(defaultRequest()));
        
        // Verify no partial updates
        verify(emergencyContactRepository, never()).save(any());
    }
}
```

---

## 1.5 PermissionService Tests

### File: `PermissionServiceTest.java`

| Test ID | Test Name | Description | BR | Priority |
|---------|-----------|-------------|:--:|:--------:|
| TC-PRM-001 | testGetPermissions_Returns6Permissions | Trả về 6 permissions | - | 🟡 P1 |
| TC-PRM-002 | testGetPermissions_ConnectionNotFound_ThrowException | Connection không tồn tại | - | 🟡 P1 |
| TC-PRM-003 | testUpdatePermission_ToggleON_Success | Bật permission | BR-016 | 🔴 P0 |
| TC-PRM-004 | testUpdatePermission_ToggleOFF_Success | Tắt permission | BR-016 | 🔴 P0 |
| TC-PRM-005 | testUpdatePermission_EmergencyOFF_MarkedWarning | Tắt emergency_alert | BR-018 | 🔴 P0 |
| TC-PRM-006 | testUpdatePermission_PublishKafkaEvent_Success | Kafka event published | BR-016 | 🟡 P1 |
| TC-PRM-007 | testUpdatePermission_NotPatient_ThrowException | Không phải Patient | - | 🟡 P1 |
| TC-PRM-008 | testUpdatePermission_InvalidType_ThrowException | Permission type không hợp lệ | - | 🟡 P1 |
| TC-PRM-009 | testCreateDefaultPermissions_AllON | 6 permissions default ALL ON | BR-009 | 🔴 P0 |
| TC-PRM-010 | testCreateDefaultPermissions_FromInviteConfig | Sử dụng config từ invite | BR-009 | 🟡 P1 |
| TC-PRM-011 | testListPermissionTypes_Returns6Types | ListPermissionTypes trả về 6 types | - | 🟡 P1 |
| TC-PRM-012 | testListPermissionTypes_IncludesDisplayInfo | Includes name_vi, icon, description | - | 🟡 P1 |
| TC-PRM-013 | testListPermissionTypes_OrderedByDisplayOrder | Sắp xếp theo display_order | - | 🟠 P2 |

```java
    // TC-PRM-005: Emergency alert warning
    @Test
    void testUpdatePermission_EmergencyOFF_MarkedWarning() {
        // Given
        UUID connectionId = UUID.randomUUID();
        UpdatePermissionRequest request = UpdatePermissionRequest.builder()
            .connectionId(connectionId)
            .permissionType("emergency_alert")
            .isEnabled(false)
            .updatedBy(patientId)
            .build();
            
        when(connectionRepository.findById(connectionId))
            .thenReturn(Optional.of(activeConnection()));
        when(permissionRepository.findByConnectionAndType(connectionId, "emergency_alert"))
            .thenReturn(Optional.of(enabledPermission("emergency_alert")));
            
        // When
        PermissionResponse response = permissionService.updatePermission(request);
        
        // Then
        assertFalse(response.getPermissions().stream()
            .filter(p -> p.getType().equals("emergency_alert"))
            .findFirst().get().isEnabled());
        
        // Verify warning flag in Kafka event
        ArgumentCaptor<PermissionChangedEvent> eventCaptor = 
            ArgumentCaptor.forClass(PermissionChangedEvent.class);
        verify(kafkaTemplate).send(eq("connection.permission.changed"), eventCaptor.capture());
        assertTrue(eventCaptor.getValue().isEmergencyPermission());
    }
```

---

## 1.6 DashboardService Tests (v2.13)

### File: `DashboardServiceTest.java`

> ⚠️ **DB-SCHEMA-001 Compliance:** All queries MUST use `user_health_profiles` (correct table name)

| Test ID | Test Name | Description | BR/SEC | Priority |
|---------|-----------|-------------|:------:|:--------:|
| TC-DSH-001 | testGetBloodPressureChart_WeekMode_Success | Chart week mode (Mon→today) | BR-DB-006 | 🔴 P0 |
| TC-DSH-002 | testGetBloodPressureChart_MonthMode_Success | Chart month mode (1st→today) | BR-DB-006 | 🔴 P0 |
| TC-DSH-003 | testGetBloodPressureChart_IncludesPatientThresholds | v2.13 patient_target_thresholds | BR-DB-001 | 🔴 P0 |
| TC-DSH-004 | testGetBloodPressureChart_ThresholdsFromUserHealthProfiles | Query user_health_profiles table | DB-SCHEMA-001 | 🔴 P0 |
| TC-DSH-005 | testGetBloodPressureChart_NoHealthProfile_ReturnsNull | No threshold record → null | - | 🟡 P1 |
| TC-DSH-006 | testGetBloodPressureChart_EmptyMeasurements_ReturnsEmptyState | Empty state handling | BR-DB-007 | 🟡 P1 |
| TC-DSH-007 | testGetBloodPressureChart_NoConnection_Returns403 | SEC-DB-001 Triple-check step 1 | SEC-DB-001 | 🔴 P0 |
| TC-DSH-008 | testGetBloodPressureChart_PermissionOff_Returns403 | SEC-DB-001 Triple-check step 3 | SEC-DB-002 | 🔴 P0 |

```java
@ExtendWith(MockitoExtension.class)
class DashboardServiceTest {

    @Mock
    private Pool pgPool;
    
    @InjectMocks
    private DashboardServiceImpl dashboardService;

    // TC-DSH-003: v2.13 patient thresholds included
    @Test
    void testGetBloodPressureChart_IncludesPatientThresholds() {
        // Given
        UUID caregiverId = UUID.randomUUID();
        UUID patientId = UUID.randomUUID();
        
        // Mock authorization check
        mockAuthorizationSuccess(patientId, caregiverId, "health_overview");
        
        // Mock measurements query
        mockMeasurementsQuery(patientId, List.of(
            measurement(130, 85, 72, OffsetDateTime.now())
        ));
        
        // Mock thresholds query - CRITICAL: Uses user_health_profiles table
        mockThresholdsQuery(patientId, 110, 140, 70, 90);
        
        // When
        BloodPressureChartData result = dashboardService
            .getBloodPressureChart(caregiverId, patientId, "week")
            .toCompletionStage().toCompletableFuture().join();
        
        // Then
        assertNotNull(result.getPatientTargetThresholds());
        assertEquals(110, result.getPatientTargetThresholds().getSystolicLower());
        assertEquals(140, result.getPatientTargetThresholds().getSystolicUpper());
        assertEquals(70, result.getPatientTargetThresholds().getDiastolicLower());
        assertEquals(90, result.getPatientTargetThresholds().getDiastolicUpper());
    }

    // TC-DSH-004: DB-SCHEMA-001 - Query must use user_health_profiles
    @Test
    void testGetBloodPressureChart_ThresholdsFromUserHealthProfiles() {
        // Given
        UUID caregiverId = UUID.randomUUID();
        UUID patientId = UUID.randomUUID();
        
        mockAuthorizationSuccess(patientId, caregiverId, "health_overview");
        mockMeasurementsQuery(patientId, Collections.emptyList());
        
        // Verify SQL query contains correct table name
        ArgumentCaptor<String> sqlCaptor = ArgumentCaptor.forClass(String.class);
        
        // When
        dashboardService.getBloodPressureChart(caregiverId, patientId, "week");
        
        // Then - Verify threshold SQL uses user_health_profiles (NOT health_profile)
        verify(pgPool, times(2)).preparedQuery(sqlCaptor.capture());
        String thresholdSql = sqlCaptor.getAllValues().get(1);
        
        assertTrue(thresholdSql.contains("user_health_profiles"),
            "DB-SCHEMA-001: Must query user_health_profiles table");
        assertFalse(thresholdSql.contains("health_profile "),
            "DB-SCHEMA-001: Must NOT use incorrect table name 'health_profile'");
    }

    // TC-DSH-005: No health profile returns null thresholds
    @Test
    void testGetBloodPressureChart_NoHealthProfile_ReturnsNullThresholds() {
        // Given
        UUID caregiverId = UUID.randomUUID();
        UUID patientId = UUID.randomUUID();
        
        mockAuthorizationSuccess(patientId, caregiverId, "health_overview");
        mockMeasurementsQuery(patientId, List.of(
            measurement(125, 80, 70, OffsetDateTime.now())
        ));
        mockThresholdsQueryEmpty(patientId);  // No health profile
        
        // When
        BloodPressureChartData result = dashboardService
            .getBloodPressureChart(caregiverId, patientId, "week")
            .toCompletionStage().toCompletableFuture().join();
        
        // Then
        assertFalse(result.isEmptyState());
        assertEquals(1, result.getMeasurements().size());
        assertNull(result.getPatientTargetThresholds(),
            "Should return null when patient has no health_profile");
    }
}
```

---

## 1.7 Repository Tests

### File: `ConnectionInviteRepositoryTest.java` (Integration)

| Test ID | Test Name | Description | BR | Priority |
|---------|-----------|-------------|:--:|:--------:|
| TC-REPO-001 | testFindPendingByPhone_ReturnsCorrect | Tìm pending invite theo phone | - | 🟡 P1 |
| TC-REPO-002 | testExistsPendingInvite_TrueWhenExists | Check trùng pending | BR-007 | 🔴 P0 |
| TC-REPO-003 | testUniquePendingIndex_BlocksDuplicate | UNIQUE index hoạt động | BR-007 | 🔴 P0 |
| TC-REPO-004 | testNoSelfInviteConstraint_ThrowsException | CHECK constraint hoạt động | BR-006 | 🔴 P0 |
| TC-REPO-005 | testStatusTransition_PendingToAccepted | Status transition hợp lệ | - | 🟡 P1 |
| TC-REPO-006 | testFindByReceiverOrderByCreatedAt_FIFO | FIFO ordering | BR-013 | 🟢 P2 |

```java
@DataJpaTest
@Testcontainers
class ConnectionInviteRepositoryTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15");
    
    @Autowired
    private ConnectionInviteRepository inviteRepository;

    // TC-REPO-003: UNIQUE index blocks duplicate
    @Test
    void testUniquePendingIndex_BlocksDuplicate() {
        // Given
        UUID senderId = UUID.randomUUID();
        String receiverPhone = "0912345678";
        
        ConnectionInvite invite1 = ConnectionInvite.builder()
            .senderId(senderId)
            .receiverPhone(receiverPhone)
            .status(InviteStatus.PENDING)
            .build();
        inviteRepository.save(invite1);
        
        // When - try to create duplicate pending
        ConnectionInvite invite2 = ConnectionInvite.builder()
            .senderId(senderId)
            .receiverPhone(receiverPhone)
            .status(InviteStatus.PENDING)
            .build();
        
        // Then - should throw constraint violation
        assertThrows(DataIntegrityViolationException.class, 
            () -> inviteRepository.saveAndFlush(invite2));
    }

    // TC-REPO-004: CHECK constraint
    @Test
    void testNoSelfInviteConstraint_ThrowsException() {
        // Given
        UUID userId = UUID.randomUUID();
        
        ConnectionInvite selfInvite = ConnectionInvite.builder()
            .senderId(userId)
            .receiverId(userId)  // Same as sender
            .receiverPhone("0912345678")
            .status(InviteStatus.PENDING)
            .build();
        
        // When/Then
        assertThrows(DataIntegrityViolationException.class,
            () -> inviteRepository.saveAndFlush(selfInvite));
    }
}
```

---

## 1.5 gRPC Handler Tests

### File: `ConnectionGrpcHandlerTest.java`

| Test ID | Test Name | Description | BR | Priority |
|---------|-----------|-------------|:--:|:--------:|
| TC-GRPC-001 | testCreateInvite_Success | gRPC CreateInvite thành công | - | 🔴 P0 |
| TC-GRPC-002 | testCreateInvite_SelfInvite_ReturnsError | SELF_INVITE error code | BR-006 | 🔴 P0 |
| TC-GRPC-003 | testAcceptInvite_Success | gRPC AcceptInvite thành công | - | 🔴 P0 |
| TC-GRPC-004 | testAcceptInvite_WithPermissions_Success | Accept với custom permissions | - | 🔴 P0 |
| TC-GRPC-005 | testListInvites_Success | gRPC ListInvites thành công | - | 🟡 P1 |
| TC-GRPC-006 | testListConnections_Success | gRPC ListConnections thành công | - | 🟡 P1 |
| TC-GRPC-007 | testDisconnect_Success | gRPC Disconnect thành công | - | 🟡 P1 |
| TC-GRPC-008 | testGetPermissions_Success | gRPC GetPermissions thành công | - | 🟡 P1 |
| TC-GRPC-009 | testUpdatePermissions_Success | gRPC UpdatePermissions thành công | - | 🟡 P1 |
| TC-GRPC-010 | testRejectInvite_Success | gRPC RejectInvite thành công | - | 🟡 P1 |
| TC-GRPC-011 | testCancelInvite_Success | gRPC CancelInvite thành công | - | 🔴 P0 |
| TC-GRPC-012 | testCancelInvite_NotSender_ReturnsError | NOT_AUTHORIZED error code | - | 🟡 P1 |
| TC-GRPC-013 | testCancelInvite_NotPending_ReturnsError | CANNOT_CANCEL error code | - | 🟡 P1 |
| TC-GRPC-014 | testListPermissionTypes_Success | gRPC ListPermissionTypes thành công | - | 🟡 P1 |
| TC-GRPC-015 | testListPermissionTypes_Returns6Types | Trả về 6 permission types | - | 🟡 P1 |
| TC-GRPC-016 | testListPermissionTypes_IncludesMetadata | Includes icon, name_vi, name_en | - | 🟠 P2 |
| TC-GRPC-017 | testGetViewingPatient_Success | gRPC GetViewingPatient thành công | BR-026 | 🔴 P0 |
| TC-GRPC-018 | testGetViewingPatient_Empty_ReturnsEmpty | Không có viewing patient | BR-026 | 🟡 P1 |
| TC-GRPC-019 | testSetViewingPatient_Success | gRPC SetViewingPatient thành công | BR-026 | 🔴 P0 |
| TC-GRPC-020 | testSetViewingPatient_Switch_Success | Đổi patient viewing | BR-026 | 🔴 P0 |
| TC-GRPC-021 | testSetViewingPatient_NotConnected_ReturnsError | PATIENT_NOT_CONNECTED error | - | 🟡 P1 |
| TC-GRPC-022 | testSetViewingPatient_NotCaregiver_ReturnsError | NOT_CAREGIVER error | - | 🟡 P1 |
| TC-GRPC-023 | testSetViewingPatient_AtomicUpdate_Success | Atomic update constraints | BR-026 | 🔴 P0 |

---

# 2. api-gateway-service Tests (Java/Vert.x)

> **Package:** `com.company.apiservice.handler.connection`  
> **Framework:** JUnit 5 + Mockito + WireMock  
> **Coverage Target:** ≥85%

---

## 2.1 InviteHandler Tests

### File: `InviteHandlerTest.java`

| Test ID | Test Name | Description | BR | Priority |
|---------|-----------|-------------|:--:|:--------:|
| TC-API-INV-001 | testCreateInvite_ValidRequest_Returns201 | POST /invites → 201 | - | 🔴 P0 |
| TC-API-INV-002 | testCreateInvite_MissingPhone_Returns400 | Missing phone → 400 | - | 🟡 P1 |
| TC-API-INV-003 | testCreateInvite_InvalidPhone_Returns400 | Invalid phone → 400 | - | 🟡 P1 |
| TC-API-INV-004 | testCreateInvite_MissingRelationship_Returns400 | Missing relationship → 400 | BR-028 | 🟡 P1 |
| TC-API-INV-005 | testCreateInvite_SelfInvite_Returns400 | SELF_INVITE → 400 | BR-006 | 🔴 P0 |
| TC-API-INV-006 | testCreateInvite_DuplicatePending_Returns400 | DUPLICATE → 400 | BR-007 | 🔴 P0 |
| TC-API-INV-007 | testListInvites_Returns200 | GET /invites → 200 | - | 🟡 P1 |
| TC-API-INV-008 | testListInvites_FilterByType_Works | ?type=sent | - | 🟢 P2 |
| TC-API-INV-009 | testListInvites_FilterByStatus_Works | ?status=pending | - | 🟢 P2 |
| TC-API-INV-010 | testAcceptInvite_Returns200 | POST /invites/{id}/accept → 200 | - | 🔴 P0 |
| TC-API-INV-011 | testAcceptInvite_WithPermissions_Returns200 | Accept with permissions | - | 🔴 P0 |
| TC-API-INV-012 | testAcceptInvite_NotFound_Returns404 | INVITE_NOT_FOUND → 404 | - | 🟡 P1 |
| TC-API-INV-013 | testRejectInvite_Returns200 | POST /invites/{id}/reject → 200 | - | 🟡 P1 |
| TC-API-INV-014 | testRejectInvite_NotFound_Returns404 | Not found → 404 | - | 🟡 P1 |

```java
@WebFluxTest(InviteHandler.class)
@ExtendWith(MockitoExtension.class)
class InviteHandlerTest {

    @Autowired
    private WebTestClient webClient;
    
    @MockBean
    private ConnectionGrpcClient grpcClient;

    // TC-API-INV-001: Create invite success
    @Test
    void testCreateInvite_ValidRequest_Returns201() {
        // Given
        CreateInviteRequestDTO request = CreateInviteRequestDTO.builder()
            .receiverPhone("0912345678")
            .receiverName("Nguyễn Văn A")
            .relationship("con_trai")
            .inviteType("patient_to_caregiver")
            .permissions(defaultPermissions())
            .build();
            
        InviteResponse grpcResponse = InviteResponse.newBuilder()
            .setInviteId(UUID.randomUUID().toString())
            .setStatus("pending")
            .build();
            
        when(grpcClient.createInvite(any())).thenReturn(grpcResponse);
        
        // When/Then
        webClient.post()
            .uri("/api/v1/invites")
            .header("Authorization", "Bearer " + validToken())
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(request)
            .exchange()
            .expectStatus().isCreated()
            .expectBody()
            .jsonPath("$.invite_id").isNotEmpty()
            .jsonPath("$.status").isEqualTo("pending");
    }

    // TC-API-INV-005: Self invite error
    @Test
    void testCreateInvite_SelfInvite_Returns400() {
        // Given
        when(grpcClient.createInvite(any()))
            .thenThrow(new GrpcException(Status.INVALID_ARGUMENT, "SELF_INVITE"));
        
        // When/Then
        webClient.post()
            .uri("/api/v1/invites")
            .header("Authorization", "Bearer " + validToken())
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(selfInviteRequest())
            .exchange()
            .expectStatus().isBadRequest()
            .expectBody()
            .jsonPath("$.error_code").isEqualTo("SELF_INVITE");
    }
}
```

---

## 2.2 ConnectionHandler Tests

### File: `ConnectionHandlerTest.java`

| Test ID | Test Name | Description | BR | Priority |
|---------|-----------|-------------|:--:|:--------:|
| TC-API-CON-001 | testListConnections_Returns200 | GET /connections → 200 | - | 🟡 P1 |
| TC-API-CON-002 | testListConnections_IncludesMonitoring | monitoring list included | - | 🟡 P1 |
| TC-API-CON-003 | testListConnections_IncludesMonitoredBy | monitored_by list included | - | 🟡 P1 |
| TC-API-CON-004 | testListConnections_RelationshipDisplay_Formatted | relationship_display format đúng | BR-029 | 🟡 P1 |
| TC-API-CON-005 | testListConnections_LastActive_Included | last_active included | BR-014 | 🟡 P1 |
| TC-API-CON-006 | testDisconnect_Returns200 | DELETE /connections/{id} → 200 | - | 🟡 P1 |
| TC-API-CON-007 | testDisconnect_NotFound_Returns404 | Not found → 404 | - | 🟡 P1 |
| TC-API-CON-008 | testDisconnect_NotAuthorized_Returns403 | Not authorized → 403 | - | 🟡 P1 |
| TC-API-CON-009 | testGetPermissions_Returns200 | GET /connections/{id}/permissions → 200 | - | 🟡 P1 |
| TC-API-CON-010 | testGetPermissions_6PermissionsReturned | 6 permissions in response | - | 🟡 P1 |
| TC-API-CON-011 | testUpdatePermissions_Returns200 | PUT /connections/{id}/permissions → 200 | - | 🟡 P1 |
| TC-API-CON-012 | testUpdatePermissions_InvalidType_Returns400 | Invalid type → 400 | - | 🟡 P1 |
| TC-API-CON-013 | testUpdatePermissions_NotPatient_Returns403 | Not patient → 403 | - | 🟡 P1 |

---

## 2.3 DTO Validation Tests

### File: `InviteRequestValidationTest.java`

| Test ID | Test Name | Description | BR | Priority |
|---------|-----------|-------------|:--:|:--------:|
| TC-VAL-001 | testPhoneValidation_Valid10Digits | 10 digits, starts with 0 | - | 🟡 P1 |
| TC-VAL-002 | testPhoneValidation_Invalid9Digits | 9 digits → invalid | - | 🟡 P1 |
| TC-VAL-003 | testPhoneValidation_InvalidNoLeadingZero | No leading 0 → invalid | - | 🟡 P1 |
| TC-VAL-004 | testNameValidation_Min2Chars | Min 2 characters | - | 🟡 P1 |
| TC-VAL-005 | testNameValidation_Max50Chars | Max 50 characters | - | 🟡 P1 |
| TC-VAL-006 | testRelationshipValidation_ValidCode | Valid relationship code | BR-028 | 🟡 P1 |
| TC-VAL-007 | testRelationshipValidation_InvalidCode | Invalid code → error | BR-028 | 🟡 P1 |
| TC-VAL-008 | testInviteTypeValidation_PatientToCaregiver | Valid type | BR-001 | 🔴 P0 |
| TC-VAL-009 | testInviteTypeValidation_CaregiverToPatient | Valid type | BR-001 | 🔴 P0 |
| TC-VAL-010 | testInviteTypeValidation_InvalidType | Invalid type → error | - | 🟡 P1 |

---

# 3. schedule-service Tests (Python/Celery)

> **Package:** `schedule_service.tasks.connection`  
> **Framework:** pytest + unittest.mock  
> **Coverage Target:** ≥85%

---

## 3.1 Notification Task Tests

### File: `test_invite_notification.py`

| Test ID | Test Name | Description | BR | Priority |
|---------|-----------|-------------|:--:|:--------:|
| TC-SCH-001 | test_send_invite_notification_existing_user_zns_push | ZNS + Push cho user có tài khoản | BR-002 | 🔴 P0 |
| TC-SCH-002 | test_send_invite_notification_new_user_zns_deeplink | ZNS + Deep Link cho user mới | BR-003 | 🔴 P0 |
| TC-SCH-003 | test_zns_fallback_to_sms_on_failure | ZNS fail → SMS fallback | BR-004 | 🔴 P0 |
| TC-SCH-004 | test_sms_retry_3_times_30s_interval | SMS retry 3x, 30s interval | BR-004 | 🔴 P0 |
| TC-SCH-005 | test_notification_status_tracking | Status tracked in invite_notifications | - | 🟡 P1 |
| TC-SCH-006 | test_deep_link_format_correct | Deep link format kolia://invite?id={} | - | 🟡 P1 |
| TC-SCH-007 | test_accept_notification_sent_to_sender | Notify sender on accept | BR-010 | 🟡 P1 |
| TC-SCH-008 | test_reject_notification_sent_to_sender | Notify sender on reject | BR-011 | 🟡 P1 |
| TC-SCH-009 | test_permission_change_notification | Notify caregiver on permission change | BR-016 | 🟡 P1 |
| TC-SCH-010 | test_disconnect_notification_patient | Notify caregiver when patient disconnects | BR-019 | 🟡 P1 |
| TC-SCH-011 | test_disconnect_notification_caregiver | Notify patient when caregiver exits | BR-020 | 🟡 P1 |

```python
# test_invite_notification.py
import pytest
from unittest.mock import Mock, patch, MagicMock
from schedule_service.tasks.connection import (
    send_invite_notification,
    send_connection_notification
)

class TestInviteNotification:

    # TC-SCH-001: ZNS + Push for existing user
    @patch('schedule_service.clients.zns_client.ZNSClient')
    @patch('schedule_service.clients.push_client.PushClient')
    def test_send_invite_notification_existing_user_zns_push(
        self, mock_push, mock_zns
    ):
        # Given
        mock_zns.return_value.send.return_value = {'success': True}
        mock_push.return_value.send.return_value = {'success': True}
        
        payload = {
            'invite_id': 'uuid-123',
            'receiver_phone': '0912345678',
            'receiver_user_id': 'uuid-456',  # Existing user
            'template': 'CONNECTION_INVITE_NEW',
            'params': {
                'sender_name': 'Nguyễn Văn A',
                'invite_type': 'patient_to_caregiver'
            }
        }
        
        # When
        result = send_invite_notification.apply(args=[payload]).get()
        
        # Then
        assert result['status'] == 'success'
        mock_zns.return_value.send.assert_called_once()
        mock_push.return_value.send.assert_called_once()

    # TC-SCH-003: ZNS fallback to SMS
    @patch('schedule_service.clients.zns_client.ZNSClient')
    @patch('schedule_service.clients.sms_client.SMSClient')
    def test_zns_fallback_to_sms_on_failure(self, mock_sms, mock_zns):
        # Given
        mock_zns.return_value.send.return_value = {
            'success': False, 
            'error': 'User has no Zalo'
        }
        mock_sms.return_value.send.return_value = {'success': True}
        
        payload = {
            'invite_id': 'uuid-123',
            'receiver_phone': '0912345678',
            'receiver_user_id': None,  # New user
            'fallback': {'channel': 'SMS', 'retry_count': 3}
        }
        
        # When
        result = send_invite_notification.apply(args=[payload]).get()
        
        # Then
        assert result['status'] == 'success'
        assert result['channel'] == 'SMS'
        mock_sms.return_value.send.assert_called_once()

    # TC-SCH-004: SMS retry 3 times
    @patch('schedule_service.clients.sms_client.SMSClient')
    @patch('time.sleep')  # Mock sleep to speed up test
    def test_sms_retry_3_times_30s_interval(self, mock_sleep, mock_sms):
        # Given
        mock_sms.return_value.send.side_effect = [
            {'success': False},  # 1st fail
            {'success': False},  # 2nd fail
            {'success': True}    # 3rd success
        ]
        
        payload = {
            'invite_id': 'uuid-123',
            'receiver_phone': '0912345678',
            'fallback': {'channel': 'SMS', 'retry_count': 3, 'retry_interval': 30}
        }
        
        # When
        result = send_invite_notification.apply(args=[payload]).get()
        
        # Then
        assert result['status'] == 'success'
        assert mock_sms.return_value.send.call_count == 3
        # Check retry interval
        mock_sleep.assert_called_with(30)
```

---

## 3.2 Kafka Consumer Tests

### File: `test_kafka_consumers.py`

| Test ID | Test Name | Description | BR | Priority |
|---------|-----------|-------------|:--:|:--------:|
| TC-KFK-001 | test_handle_invite_created_event | Consume invite.created event | - | 🟡 P1 |
| TC-KFK-002 | test_handle_invite_accepted_event | Consume invite.accepted event | BR-010 | 🟡 P1 |
| TC-KFK-003 | test_handle_invite_rejected_event | Consume invite.rejected event | BR-011 | 🟡 P1 |
| TC-KFK-004 | test_handle_permission_changed_event | Consume permission.changed event | BR-016 | 🟡 P1 |
| TC-KFK-005 | test_handle_connection_disconnected_event | Consume status.changed event | BR-019 | 🟡 P1 |
| TC-KFK-006 | test_invalid_event_format_logged | Invalid format logged, not crash | - | 🟢 P2 |
| TC-KFK-007 | test_duplicate_event_idempotent | Duplicate event không gây side effect | - | 🟢 P2 |

---

## Summary

| Service | Test Files | Test Cases | Priority Breakdown |
|---------|:----------:|:----------:|:------------------:|
| user-service | 7 | ~86 | 🔴 32, 🟡 42, 🟢 12 |
| api-gateway | 4 | ~50 | 🔴 17, 🟡 28, 🟢 5 |
| schedule-service | 2 | ~28 | 🔴 11, 🟡 14, 🟢 3 |
| **Total** | **13** | **~164** | **🔴 60, 🟡 84, 🟢 20** |

---

**Generated:** 2026-01-29T15:35:00+07:00  
**Workflow:** `/alio-testing` (v2.7)
