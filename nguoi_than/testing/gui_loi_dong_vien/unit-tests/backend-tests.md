# Backend Unit Tests: US 1.3 - Gửi Lời Động Viên

> **Version:** 1.0  
> **Date:** 2026-02-04  
> **Test Framework:** JUnit 5 + Mockito  
> **Coverage Target:** ≥85%

---

## 1. Test Class Structure

```
user-service/src/test/java/
├── com.alio.user.service/
│   └── impl/
│       └── EncouragementServiceImplTest.java     ← 20 tests
├── com.alio.user.handler/
│   └── EncouragementServiceGrpcImplTest.java     ← 8 tests
├── com.alio.user.repository/
│   └── EncouragementRepositoryTest.java          ← 6 tests
└── com.alio.user.kafka/
    └── EncouragementKafkaProducerTest.java       ← 4 tests
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
| EncouragementServiceGrpcImplTest | 8 | 📋 Pending |
| EncouragementRepositoryTest | 6 | 📋 Pending |
| EncouragementKafkaProducerTest | 4 | ✅ Specified |
| **Total** | **38** | - |

---

## 5. Mock Setup Helper

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
