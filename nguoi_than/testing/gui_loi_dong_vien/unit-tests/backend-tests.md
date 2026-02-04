# Backend Unit Tests: US 1.3 - Gửi Lời Động Viên

> **Version:** 1.2 (Added Avatar Enrichment Tests)  
> **Date:** 2026-02-05  
> **Test Framework:** JUnit 5 + Mockito  
> **Coverage Target:** ≥85%  
> **Revision:** Added EncouragementServiceGrpcImplTest with StorageServiceClient avatar enrichment tests (UT-ENC-GRPC-001 to 004)

---

## ⚠️ DB-SCHEMA-001 Compliance Warning

> **CRITICAL**: Repository tests MUST use correct table/column names:
> - Table: `connection_permission_types` (NOT `permission_types`)
> - Column: `permission_code` VARCHAR (NOT `permission_type_id` INT)
>
> Tests should verify these patterns to prevent production errors.

---

## 1. Test Class Structure

```
user-service/src/test/java/
├── com.alio.user.service/
│   └── impl/
│       └── EncouragementServiceImplTest.java         ← 20 tests
├── com.alio.user.handler/
│   └── EncouragementServiceGrpcImplTest.java         ← 8 tests
├── com.alio.user.repository/
│   ├── EncouragementRepositoryTest.java              ← 6 tests
│   └── impl/
│       └── ConnectionPermissionRepositoryImplTest.java ← 6 tests ⭐ NEW
└── com.alio.user.kafka/
    └── EncouragementKafkaProducerTest.java           ← 4 tests
```

---

## 2. EncouragementServiceImplTest (20 tests)

### 2.1 createEncouragement() - 10 tests

#### UT-ENC-SVC-001: Create with valid data
```java
@Test
@DisplayName("Should create encouragement message successfully")
void createEncouragement_validData_success() {
    // Given
    CreateEncouragementRequest request = CreateEncouragementRequest.builder()
        .patientId(PATIENT_UUID)
        .content("Mẹ ơi, nhớ uống thuốc đúng giờ nhé! 💊")
        .build();
    
    when(connectionPermissionRepository.hasPermission(
        CAREGIVER_UUID, PATIENT_UUID, PERMISSION_ENCOURAGEMENT))
        .thenReturn(true);
    when(encouragementRepository.countTodayByPatient(CAREGIVER_UUID, PATIENT_UUID, today()))
        .thenReturn(5);
    when(userEmergencyContactRepository.findByLinkedUserAndPatient(CAREGIVER_UUID, PATIENT_UUID))
        .thenReturn(Optional.of(mockContact));
    
    // When
    EncouragementMessage result = service.createEncouragement(CAREGIVER_UUID, request);
    
    // Then
    assertThat(result).isNotNull();
    assertThat(result.getContent()).isEqualTo(request.getContent());
    assertThat(result.getSenderId()).isEqualTo(CAREGIVER_UUID);
    assertThat(result.getPatientId()).isEqualTo(PATIENT_UUID);
    verify(encouragementRepository).save(any(EncouragementMessage.class));
    verify(kafkaProducer).publishEncouragementCreated(any());
}
```

#### UT-ENC-SVC-002: Permission #6 = OFF → 403
```java
@Test
@DisplayName("Should throw FORBIDDEN when permission #6 is OFF")
void createEncouragement_noPermission_forbidden() {
    // Given
    when(connectionPermissionRepository.hasPermission(
        CAREGIVER_UUID, PATIENT_UUID, PERMISSION_ENCOURAGEMENT))
        .thenReturn(false);
    
    // When/Then
    assertThatThrownBy(() -> service.createEncouragement(CAREGIVER_UUID, request))
        .isInstanceOf(ForbiddenException.class)
        .hasMessage(ErrorCodes.ENCOURAGEMENT_PERMISSION_DENIED);
    
    verify(encouragementRepository, never()).save(any());
}
```

#### UT-ENC-SVC-003: Quota exceeded (10/day) → 429
```java
@Test
@DisplayName("Should throw TOO_MANY_REQUESTS when daily quota exceeded")
void createEncouragement_quotaExceeded_tooMany() {
    // Given
    when(connectionPermissionRepository.hasPermission(any(), any(), any())).thenReturn(true);
    when(encouragementRepository.countTodayByPatient(CAREGIVER_UUID, PATIENT_UUID, today()))
        .thenReturn(10);  // Reached limit
    
    // When/Then
    assertThatThrownBy(() -> service.createEncouragement(CAREGIVER_UUID, request))
        .isInstanceOf(TooManyRequestsException.class)
        .hasMessage(ErrorCodes.ENCOURAGEMENT_QUOTA_EXCEEDED);
}
```

#### UT-ENC-SVC-004: Content > 150 chars → 400
```java
@Test
@DisplayName("Should throw BAD_REQUEST when content exceeds 150 characters")
void createEncouragement_contentTooLong_badRequest() {
    // Given
    String longContent = "A".repeat(151);  // 151 chars
    CreateEncouragementRequest request = CreateEncouragementRequest.builder()
        .patientId(PATIENT_UUID)
        .content(longContent)
        .build();
    
    // When/Then
    assertThatThrownBy(() -> service.createEncouragement(CAREGIVER_UUID, request))
        .isInstanceOf(BadRequestException.class)
        .hasMessage(ErrorCodes.ENCOURAGEMENT_CONTENT_TOO_LONG);
}
```

#### UT-ENC-SVC-005: Empty content → 400
```java
@Test
@DisplayName("Should throw BAD_REQUEST when content is empty")
void createEncouragement_emptyContent_badRequest() {
    // Given
    request.setContent("");
    
    // When/Then
    assertThatThrownBy(() -> service.createEncouragement(CAREGIVER_UUID, request))
        .isInstanceOf(BadRequestException.class)
        .hasMessage(ErrorCodes.ENCOURAGEMENT_CONTENT_REQUIRED);
}
```

#### UT-ENC-SVC-006: Unicode emoji counted correctly
```java
@Test
@DisplayName("Should count emoji as 1 character (Unicode aware)")
void createEncouragement_emojiContent_countedCorrectly() {
    // Given - 149 chars + 1 emoji = 150 total
    String emojiContent = "A".repeat(149) + "💊";
    request.setContent(emojiContent);
    
    when(connectionPermissionRepository.hasPermission(any(), any(), any())).thenReturn(true);
    when(encouragementRepository.countTodayByPatient(any(), any(), any())).thenReturn(0);
    when(userEmergencyContactRepository.findByLinkedUserAndPatient(any(), any()))
        .thenReturn(Optional.of(mockContact));
    
    // When
    EncouragementMessage result = service.createEncouragement(CAREGIVER_UUID, request);
    
    // Then
    assertThat(result).isNotNull();
}
```

#### UT-ENC-SVC-007: relationship_display from Patient's perspective
```java
@Test
@DisplayName("Should set relationship_display as Patient's perspective")
void createEncouragement_relationshipDisplay_patientPerspective() {
    // Given
    // Patient = Bà Lan (Mẹ)
    // Caregiver = Cô Huy (Con gái)
    // relationship_code = "daughter" 
    // relationship_display = "Con gái" (Patient calls Caregiver)
    when(mockContact.getRelationshipCode()).thenReturn("daughter");
    when(mockContact.getRelationshipDisplay()).thenReturn("Con gái");
    when(mockContact.getName()).thenReturn("Huy");
    
    when(connectionPermissionRepository.hasPermission(any(), any(), any())).thenReturn(true);
    when(encouragementRepository.countTodayByPatient(any(), any(), any())).thenReturn(0);
    when(userEmergencyContactRepository.findByLinkedUserAndPatient(any(), any()))
        .thenReturn(Optional.of(mockContact));
    
    // When
    EncouragementMessage result = service.createEncouragement(CAREGIVER_UUID, request);
    
    // Then
    assertThat(result.getSenderName()).isEqualTo("Huy");
    assertThat(result.getRelationshipCode()).isEqualTo("daughter");
    assertThat(result.getRelationshipDisplay()).isEqualTo("Con gái");
}
```

#### UT-ENC-SVC-008: No connection exists → 404
```java
@Test
@DisplayName("Should throw NOT_FOUND when no connection exists")
void createEncouragement_noConnection_notFound() {
    // Given
    when(connectionPermissionRepository.hasPermission(any(), any(), any())).thenReturn(true);
    when(encouragementRepository.countTodayByPatient(any(), any(), any())).thenReturn(0);
    when(userEmergencyContactRepository.findByLinkedUserAndPatient(any(), any()))
        .thenReturn(Optional.empty());
    
    // When/Then
    assertThatThrownBy(() -> service.createEncouragement(CAREGIVER_UUID, request))
        .isInstanceOf(NotFoundException.class)
        .hasMessage(ErrorCodes.CONNECTION_NOT_FOUND);
}
```

#### UT-ENC-SVC-009: Kafka event published on success
```java
@Test
@DisplayName("Should publish Kafka event after successful creation")
void createEncouragement_success_kafkaEventPublished() {
    // Given
    setupValidCreateMocks();
    
    // When
    service.createEncouragement(CAREGIVER_UUID, request);
    
    // Then
    ArgumentCaptor<EncouragementCreatedEvent> captor = 
        ArgumentCaptor.forClass(EncouragementCreatedEvent.class);
    verify(kafkaProducer).publishEncouragementCreated(captor.capture());
    
    EncouragementCreatedEvent event = captor.getValue();
    assertThat(event.getEventType()).isEqualTo("ENCOURAGEMENT_CREATED");
    assertThat(event.getSenderName()).isEqualTo("Huy");
    assertThat(event.getRelationshipDisplay()).isEqualTo("Con gái");
}
```

#### UT-ENC-SVC-010: Quota at 9 → allow one more
```java
@Test
@DisplayName("Should allow message when quota is 9/10")
void createEncouragement_quotaAt9_allowed() {
    // Given
    when(encouragementRepository.countTodayByPatient(any(), any(), any())).thenReturn(9);
    setupValidCreateMocks();
    
    // When
    EncouragementMessage result = service.createEncouragement(CAREGIVER_UUID, request);
    
    // Then
    assertThat(result).isNotNull();
}
```

---

### 2.2 getEncouragementList() - 5 tests

#### UT-ENC-SVC-011: List 24h messages sorted by sent_at DESC
```java
@Test
@DisplayName("Should return messages from last 24h sorted by sent_at DESC")
void getEncouragementList_24hWindow_sortedDesc() {
    // Given
    LocalDateTime from = LocalDateTime.now().minusHours(24);
    List<EncouragementMessage> messages = List.of(
        createMessage(LocalDateTime.now().minusHours(1)),
        createMessage(LocalDateTime.now().minusHours(2)),
        createMessage(LocalDateTime.now().minusHours(12))
    );
    
    when(encouragementRepository.findByPatientAndSentAfter(PATIENT_UUID, from))
        .thenReturn(messages);
    
    // When
    List<EncouragementMessage> result = service.getEncouragementList(PATIENT_UUID);
    
    // Then
    assertThat(result).hasSize(3);
    assertThat(result).isSortedAccordingTo(
        Comparator.comparing(EncouragementMessage::getSentAt).reversed());
}
```

#### UT-ENC-SVC-012: Empty list when no messages
```java
@Test
@DisplayName("Should return empty list when no messages in 24h")
void getEncouragementList_noMessages_emptyList() {
    // Given
    when(encouragementRepository.findByPatientAndSentAfter(any(), any()))
        .thenReturn(Collections.emptyList());
    
    // When
    List<EncouragementMessage> result = service.getEncouragementList(PATIENT_UUID);
    
    // Then
    assertThat(result).isEmpty();
}
```

#### UT-ENC-SVC-013: Messages older than 24h excluded
```java
@Test
@DisplayName("Should exclude messages older than 24h")
void getEncouragementList_oldMessages_excluded() {
    // Given - repository returns only messages within 24h
    when(encouragementRepository.findByPatientAndSentAfter(eq(PATIENT_UUID), any()))
        .thenReturn(List.of(recentMessage));
    
    // When
    List<EncouragementMessage> result = service.getEncouragementList(PATIENT_UUID);
    
    // Then
    assertThat(result).hasSize(1);
    assertThat(result.get(0).getSentAt()).isAfter(LocalDateTime.now().minusHours(24));
}
```

#### UT-ENC-SVC-014: Include unread status
```java
@Test
@DisplayName("Should include is_read status for each message")
void getEncouragementList_includesReadStatus() {
    // Given
    EncouragementMessage unread = createMessage(LocalDateTime.now());
    unread.setRead(false);
    
    when(encouragementRepository.findByPatientAndSentAfter(any(), any()))
        .thenReturn(List.of(unread));
    
    // When
    List<EncouragementMessage> result = service.getEncouragementList(PATIENT_UUID);
    
    // Then
    assertThat(result.get(0).isRead()).isFalse();
}
```

#### UT-ENC-SVC-015: Include relationship display
```java
@Test
@DisplayName("Should include relationship_display in response")
void getEncouragementList_includesRelationshipDisplay() {
    // Given
    EncouragementMessage msg = createMessage(LocalDateTime.now());
    msg.setRelationshipDisplay("Con gái");
    msg.setSenderName("Huy");
    
    when(encouragementRepository.findByPatientAndSentAfter(any(), any()))
        .thenReturn(List.of(msg));
    
    // When
    List<EncouragementMessage> result = service.getEncouragementList(PATIENT_UUID);
    
    // Then
    assertThat(result.get(0).getRelationshipDisplay()).isEqualTo("Con gái");
    assertThat(result.get(0).getSenderName()).isEqualTo("Huy");
}
```

---

### 2.3 markAsRead() - 3 tests

#### UT-ENC-SVC-016: Batch mark read success
```java
@Test
@DisplayName("Should mark multiple messages as read")
void markAsRead_batchUpdate_success() {
    // Given
    List<UUID> ids = List.of(UUID.randomUUID(), UUID.randomUUID());
    
    // When
    service.markAsRead(PATIENT_UUID, ids);
    
    // Then
    verify(encouragementRepository).markAsReadBatch(eq(ids), eq(PATIENT_UUID), any());
}
```

#### UT-ENC-SVC-017: Only mark own messages
```java
@Test
@DisplayName("Should only mark messages owned by patient")
void markAsRead_ownershipCheck_onlyOwned() {
    // Given
    List<UUID> ids = List.of(UUID.randomUUID());
    
    // When
    service.markAsRead(PATIENT_UUID, ids);
    
    // Then
    verify(encouragementRepository).markAsReadBatch(anyList(), eq(PATIENT_UUID), any());
}
```

#### UT-ENC-SVC-018: Empty list → no-op
```java
@Test
@DisplayName("Should handle empty list gracefully")
void markAsRead_emptyList_noOp() {
    // Given
    List<UUID> ids = Collections.emptyList();
    
    // When
    service.markAsRead(PATIENT_UUID, ids);
    
    // Then
    verify(encouragementRepository, never()).markAsReadBatch(any(), any(), any());
}
```

---

### 2.4 getQuota() - 2 tests

#### UT-ENC-SVC-019: Return remaining quota
```java
@Test
@DisplayName("Should return remaining quota for today")
void getQuota_returnRemaining() {
    // Given
    when(encouragementRepository.countTodayByPatient(CAREGIVER_UUID, PATIENT_UUID, today()))
        .thenReturn(3);
    
    // When
    QuotaResponse result = service.getQuota(CAREGIVER_UUID, PATIENT_UUID);
    
    // Then
    assertThat(result.getUsed()).isEqualTo(3);
    assertThat(result.getRemaining()).isEqualTo(7);
    assertThat(result.getLimit()).isEqualTo(10);
}
```

#### UT-ENC-SVC-020: Quota resets at midnight
```java
@Test
@DisplayName("Should reset quota at midnight")
void getQuota_midnightReset() {
    // Given - yesterday had 10 messages, today has 0
    when(encouragementRepository.countTodayByPatient(CAREGIVER_UUID, PATIENT_UUID, today()))
        .thenReturn(0);
    
    // When
    QuotaResponse result = service.getQuota(CAREGIVER_UUID, PATIENT_UUID);
    
    // Then
    assertThat(result.getUsed()).isEqualTo(0);
    assertThat(result.getRemaining()).isEqualTo(10);
}
```

---

## 3. EncouragementKafkaProducerTest (4 tests)

#### UT-ENC-KFK-001: Publish event with correct topic
```java
@Test
@DisplayName("Should publish to topic-encouragement-created")
void publishEncouragementCreated_correctTopic() {
    // Given
    EncouragementCreatedEvent event = createEvent();
    
    // When
    producer.publishEncouragementCreated(event);
    
    // Then
    verify(kafkaTemplate).send(eq("topic-encouragement-created"), any());
}
```

#### UT-ENC-KFK-002: Event contains required fields
```java
@Test
@DisplayName("Should include all required fields in event")
void publishEncouragementCreated_requiredFields() {
    // Given
    EncouragementCreatedEvent event = createEvent();
    
    // When
    producer.publishEncouragementCreated(event);
    
    // Then
    ArgumentCaptor<EncouragementCreatedEvent> captor = 
        ArgumentCaptor.forClass(EncouragementCreatedEvent.class);
    verify(kafkaTemplate).send(anyString(), captor.capture());
    
    EncouragementCreatedEvent sent = captor.getValue();
    assertThat(sent.getEncouragementId()).isNotNull();
    assertThat(sent.getPatientId()).isNotNull();
    assertThat(sent.getSenderName()).isNotNull();
    assertThat(sent.getRelationshipDisplay()).isNotNull();
    assertThat(sent.getContent()).isNotNull();
}
```

#### UT-ENC-KFK-003: Retry on failure
```java
@Test
@DisplayName("Should retry 3 times on Kafka failure")
void publishEncouragementCreated_retry() {
    // Given
    when(kafkaTemplate.send(anyString(), any()))
        .thenThrow(new KafkaException("Connection failed"));
    
    // When/Then
    assertThatThrownBy(() -> producer.publishEncouragementCreated(createEvent()))
        .isInstanceOf(KafkaException.class);
    
    verify(kafkaTemplate, times(3)).send(anyString(), any());
}
```

#### UT-ENC-KFK-004: Log on success
```java
@Test
@DisplayName("Should log on successful publish")
void publishEncouragementCreated_logSuccess() {
    // Given
    EncouragementCreatedEvent event = createEvent();
    when(kafkaTemplate.send(anyString(), any()))
        .thenReturn(CompletableFuture.completedFuture(null));
    
    // When
    producer.publishEncouragementCreated(event);
    
    // Then
    // Verify log contains encouragement_id
}
```

---

## 4. Test Summary

| Test Class | Tests | Status |
|------------|:-----:|:------:|
| EncouragementServiceImplTest | 20 | ✅ Specified |
| EncouragementServiceGrpcImplTest | 12 | ✅ Specified ⭐ |
| EncouragementRepositoryTest | 6 | 📋 Pending |
| ConnectionPermissionRepositoryImplTest | 6 | ✅ Specified ⭐ |
| EncouragementKafkaProducerTest | 4 | ✅ Specified |
| **Total** | **48** | - |

---

## 5. EncouragementServiceGrpcImplTest (12 tests) ⭐ UPDATED

### 5.1 buildEncouragementInfo() - 4 tests

#### UT-ENC-GRPC-001: Avatar enrichment success
```java
@Test
@DisplayName("Should enrich avatar_id to presigned URL")
void buildEncouragementInfo_withAvatarId_enrichesToUrl() {
    // Given
    EncouragementMessage msg = createMessage();
    msg.setSenderAvatarUrl("avatar-id-123");  // This is avatar_id from DB
    
    when(storageServiceClient.getDownloadUrl("avatar-id-123", SENDER_UUID.toString()))
        .thenReturn("https://storage.kolia.vn/presigned/avatar-id-123");
    
    // When
    EncouragementInfo result = grpcImpl.buildEncouragementInfo(msg);
    
    // Then
    assertThat(result.getSenderAvatarUrl())
        .isEqualTo("https://storage.kolia.vn/presigned/avatar-id-123");
    verify(storageServiceClient).getDownloadUrl(eq("avatar-id-123"), anyString());
}
```

#### UT-ENC-GRPC-002: Avatar null returns empty string
```java
@Test
@DisplayName("Should return empty string when avatar_id is null")
void buildEncouragementInfo_nullAvatar_returnsEmpty() {
    // Given
    EncouragementMessage msg = createMessage();
    msg.setSenderAvatarUrl(null);
    
    // When
    EncouragementInfo result = grpcImpl.buildEncouragementInfo(msg);
    
    // Then
    assertThat(result.getSenderAvatarUrl()).isEmpty();
    verifyNoInteractions(storageServiceClient);
}
```

#### UT-ENC-GRPC-003: StorageService error returns empty (fail-safe)
```java
@Test
@DisplayName("Should return empty string on StorageService error (fail-safe)")
void buildEncouragementInfo_storageError_returnsEmpty() {
    // Given
    EncouragementMessage msg = createMessage();
    msg.setSenderAvatarUrl("avatar-id-123");
    
    when(storageServiceClient.getDownloadUrl(anyString(), anyString()))
        .thenThrow(new RuntimeException("Storage service unavailable"));
    
    // When
    EncouragementInfo result = grpcImpl.buildEncouragementInfo(msg);
    
    // Then
    assertThat(result.getSenderAvatarUrl()).isEmpty();
    // Should not propagate exception - fail-safe design
}
```

#### UT-ENC-GRPC-004: StorageService returns null
```java
@Test
@DisplayName("Should handle null URL from StorageService")
void buildEncouragementInfo_storageReturnsNull_returnsEmpty() {
    // Given
    EncouragementMessage msg = createMessage();
    msg.setSenderAvatarUrl("avatar-id-123");
    
    when(storageServiceClient.getDownloadUrl(anyString(), anyString()))
        .thenReturn(null);
    
    // When
    EncouragementInfo result = grpcImpl.buildEncouragementInfo(msg);
    
    // Then
    assertThat(result.getSenderAvatarUrl()).isEmpty();
}
```

### 5.2 RPC Methods - 8 tests

#### UT-ENC-GRPC-005: CreateEncouragement returns EncouragementInfo
```java
@Test
@DisplayName("Should return EncouragementInfo on successful create")
void createEncouragement_success_returnsInfo() {
    // Given
    CreateEncouragementRequest request = createValidRequest();
    when(encouragementService.createEncouragement(any(), any(), any(), any()))
        .thenReturn(Future.succeededFuture(mockMessage));
    
    // When
    grpcImpl.createEncouragement(request, responseObserver);
    
    // Then
    verify(responseObserver).onNext(any(EncouragementResponse.class));
    verify(responseObserver).onCompleted();
}
```

#### UT-ENC-GRPC-006: GetEncouragementList returns list with enriched avatars
```java
@Test
@DisplayName("Should enrich all avatar URLs in list response")
void getEncouragementList_enrichesAllAvatars() {
    // Given
    List<EncouragementMessage> messages = List.of(
        createMessage("avatar-1"),
        createMessage("avatar-2"),
        createMessage(null)  // No avatar
    );
    when(encouragementService.getEncouragementList(any(), anyBoolean()))
        .thenReturn(Future.succeededFuture(new EncouragementListResult(messages, 3, 2)));
    when(storageServiceClient.getDownloadUrl(eq("avatar-1"), any()))
        .thenReturn("https://url1");
    when(storageServiceClient.getDownloadUrl(eq("avatar-2"), any()))
        .thenReturn("https://url2");
    
    // When
    grpcImpl.getEncouragementList(request, responseObserver);
    
    // Then
    ArgumentCaptor<EncouragementListResponse> captor = 
        ArgumentCaptor.forClass(EncouragementListResponse.class);
    verify(responseObserver).onNext(captor.capture());
    
    List<EncouragementInfo> infos = captor.getValue().getData().getMessagesList();
    assertThat(infos.get(0).getSenderAvatarUrl()).isEqualTo("https://url1");
    assertThat(infos.get(1).getSenderAvatarUrl()).isEqualTo("https://url2");
    assertThat(infos.get(2).getSenderAvatarUrl()).isEmpty();
}
```

#### UT-ENC-GRPC-007 to UT-ENC-GRPC-012: Standard gRPC methods
*(MarkAsRead, GetQuota, error handling, etc.)*

---

## 5. ConnectionPermissionRepositoryImplTest (6 tests) ⭐ NEW

> ⚠️ **DB-SCHEMA-001 CRITICAL**: Tests MUST verify correct table/column names

### 5.1 Permission Check Tests

#### UT-PERM-REPO-001: isPermissionEnabled with correct schema
```java
@Test
@DisplayName("Should query connection_permission_types (NOT permission_types)")
void isPermissionEnabled_correcTable() {
    // Given
    UUID contactId = UUID.randomUUID();
    String permissionCode = "encouragement";
    
    // When
    repository.isPermissionEnabled(contactId, permissionCode);
    
    // Then - Verify SQL uses correct table
    ArgumentCaptor<String> sqlCaptor = ArgumentCaptor.forClass(String.class);
    verify(pgPool).preparedQuery(sqlCaptor.capture());
    
    String sql = sqlCaptor.getValue();
    assertThat(sql).contains("connection_permissions");
    assertThat(sql).contains("permission_code");
    assertThat(sql).doesNotContain("permission_types");  // ⚠️ DB-SCHEMA-001
    assertThat(sql).doesNotContain("permission_type_id"); // ⚠️ DB-SCHEMA-001
}
```

#### UT-PERM-REPO-002: Permission enabled returns true
```java
@Test
@DisplayName("Should return true when permission is enabled")
void isPermissionEnabled_enabled_true() {
    // Given
    mockQueryResult(true);
    
    // When
    Future<Boolean> result = repository.isPermissionEnabled(contactId, "encouragement");
    
    // Then
    assertThat(result.result()).isTrue();
}
```

#### UT-PERM-REPO-003: Permission disabled returns false
```java
@Test
@DisplayName("Should return false when permission is disabled")
void isPermissionEnabled_disabled_false() {
    // Given
    mockQueryResult(false);
    
    // When
    Future<Boolean> result = repository.isPermissionEnabled(contactId, "encouragement");
    
    // Then
    assertThat(result.result()).isFalse();
}
```

#### UT-PERM-REPO-004: No permission record returns false
```java
@Test
@DisplayName("Should return false when no permission record exists")
void isPermissionEnabled_noRecord_false() {
    // Given
    mockQueryResultEmpty();
    
    // When
    Future<Boolean> result = repository.isPermissionEnabled(contactId, "encouragement");
    
    // Then
    assertThat(result.result()).isFalse();
}
```

### 5.2 CRUD Tests

#### UT-PERM-REPO-005: Save permission with VARCHAR permission_code
```java
@Test
@DisplayName("Should save permission with VARCHAR permission_code FK")
void save_varcharPermissionCode() {
    // Given
    ConnectionPermission permission = ConnectionPermission.builder()
        .contactId(contactId)
        .permissionCode("encouragement")  // VARCHAR, not INT
        .isEnabled(true)
        .build();
    
    // When
    repository.save(permission);
    
    // Then
    ArgumentCaptor<Tuple> tupleCaptor = ArgumentCaptor.forClass(Tuple.class);
    verify(pgPool).preparedQuery(contains("permission_code"));
    
    // Verify permission_code is passed as String, not Integer
    assertThat(tupleCaptor.getValue().getString(2)).isEqualTo("encouragement");
}
```

#### UT-PERM-REPO-006: Find by contact returns all permissions
```java
@Test
@DisplayName("Should return all permissions for contact")
void findByContactId_returnsList() {
    // Given
    List<Row> mockRows = List.of(
        createMockRow("encouragement", true),
        createMockRow("health_overview", false)
    );
    mockQueryResults(mockRows);
    
    // When
    Future<List<ConnectionPermission>> result = repository.findByContactId(contactId);
    
    // Then
    assertThat(result.result()).hasSize(2);
}
```

---

## 6. Mock Setup Helper

```java
private void setupValidCreateMocks() {
    when(connectionPermissionRepository.hasPermission(any(), any(), any())).thenReturn(true);
    when(encouragementRepository.countTodayByPatient(any(), any(), any())).thenReturn(0);
    when(userEmergencyContactRepository.findByLinkedUserAndPatient(any(), any()))
        .thenReturn(Optional.of(mockContact));
    when(mockContact.getContactId()).thenReturn(CONTACT_UUID);
    when(mockContact.getName()).thenReturn("Huy");
    when(mockContact.getRelationshipCode()).thenReturn("daughter");
    when(mockContact.getRelationshipDisplay()).thenReturn("Con gái");
}
```

