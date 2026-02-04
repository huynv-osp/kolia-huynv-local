# API Integration Tests: US 1.3 - Gửi Lời Động Viên

> **Version:** 1.0  
> **Date:** 2026-02-04  
> **Test Framework:** WebTestClient (Java) / pytest (Python)

---

## 1. Test Environment Setup

```java
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
@AutoConfigureWebTestClient
class EncouragementApiTest {
    
    @Autowired
    private WebTestClient webTestClient;
    
    private String caregiverToken;
    private String patientToken;
    
    @BeforeEach
    void setup() {
        caregiverToken = getTestToken(CAREGIVER_USER);
        patientToken = getTestToken(PATIENT_USER);
    }
}
```

---

## 2. POST /api/v1/encouragements (6 tests)

### API-ENC-001: Create message successfully
```java
@Test
void createEncouragement_validRequest_returns201() {
    // Given
    CreateEncouragementRequest request = new CreateEncouragementRequest();
    request.setPatientId(PATIENT_UUID);
    request.setContent("Mẹ ơi, nhớ uống thuốc nhé! 💊");
    
    // When/Then
    webTestClient.post()
        .uri("/api/v1/encouragements")
        .header("Authorization", "Bearer " + caregiverToken)
        .contentType(MediaType.APPLICATION_JSON)
        .bodyValue(request)
        .exchange()
        .expectStatus().isCreated()
        .expectBody()
            .jsonPath("$.encouragement_id").isNotEmpty()
            .jsonPath("$.content").isEqualTo(request.getContent())
            .jsonPath("$.sender_name").isNotEmpty()
            .jsonPath("$.relationship_display").isNotEmpty()
            .jsonPath("$.sent_at").isNotEmpty();
}
```

### API-ENC-002: Permission #6 OFF → 403
```java
@Test
void createEncouragement_noPermission_returns403() {
    // Given - Caregiver has permission #6 = OFF
    CreateEncouragementRequest request = new CreateEncouragementRequest();
    request.setPatientId(NO_PERMISSION_PATIENT_UUID);
    request.setContent("Test message");
    
    // When/Then
    webTestClient.post()
        .uri("/api/v1/encouragements")
        .header("Authorization", "Bearer " + caregiverNoPermissionToken)
        .contentType(MediaType.APPLICATION_JSON)
        .bodyValue(request)
        .exchange()
        .expectStatus().isForbidden()
        .expectBody()
            .jsonPath("$.error").isEqualTo("ENCOURAGEMENT_PERMISSION_DENIED");
}
```

### API-ENC-003: Quota exceeded → 429
```java
@Test
void createEncouragement_quotaExceeded_returns429() {
    // Given - Send 10 messages first, then try 11th
    for (int i = 0; i < 10; i++) {
        sendTestMessage(PATIENT_UUID);
    }
    
    CreateEncouragementRequest request = new CreateEncouragementRequest();
    request.setPatientId(PATIENT_UUID);
    request.setContent("11th message");
    
    // When/Then
    webTestClient.post()
        .uri("/api/v1/encouragements")
        .header("Authorization", "Bearer " + caregiverToken)
        .contentType(MediaType.APPLICATION_JSON)
        .bodyValue(request)
        .exchange()
        .expectStatus().isEqualTo(429)
        .expectBody()
            .jsonPath("$.error").isEqualTo("ENCOURAGEMENT_QUOTA_EXCEEDED");
}
```

### API-ENC-004: Content > 150 chars → 400
```java
@Test
void createEncouragement_contentTooLong_returns400() {
    // Given
    CreateEncouragementRequest request = new CreateEncouragementRequest();
    request.setPatientId(PATIENT_UUID);
    request.setContent("A".repeat(151));
    
    // When/Then
    webTestClient.post()
        .uri("/api/v1/encouragements")
        .header("Authorization", "Bearer " + caregiverToken)
        .contentType(MediaType.APPLICATION_JSON)
        .bodyValue(request)
        .exchange()
        .expectStatus().isBadRequest()
        .expectBody()
            .jsonPath("$.error").isEqualTo("ENCOURAGEMENT_CONTENT_TOO_LONG");
}
```

### API-ENC-005: Empty content → 400
```java
@Test
void createEncouragement_emptyContent_returns400() {
    // Given
    CreateEncouragementRequest request = new CreateEncouragementRequest();
    request.setPatientId(PATIENT_UUID);
    request.setContent("");
    
    // When/Then
    webTestClient.post()
        .uri("/api/v1/encouragements")
        .header("Authorization", "Bearer " + caregiverToken)
        .contentType(MediaType.APPLICATION_JSON)
        .bodyValue(request)
        .exchange()
        .expectStatus().isBadRequest();
}
```

### API-ENC-006: Unauthorized → 401
```java
@Test
void createEncouragement_noToken_returns401() {
    // Given
    CreateEncouragementRequest request = new CreateEncouragementRequest();
    request.setPatientId(PATIENT_UUID);
    request.setContent("Test");
    
    // When/Then
    webTestClient.post()
        .uri("/api/v1/encouragements")
        .contentType(MediaType.APPLICATION_JSON)
        .bodyValue(request)
        .exchange()
        .expectStatus().isUnauthorized();
}
```

---

## 3. GET /api/v1/encouragements (4 tests)

### API-ENC-007: Get 24h messages
```java
@Test
void getEncouragementList_asPatient_returns200() {
    // Given - Create some test messages
    sendTestMessage(PATIENT_UUID);
    
    // When/Then
    webTestClient.get()
        .uri("/api/v1/encouragements")
        .header("Authorization", "Bearer " + patientToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
            .jsonPath("$.messages").isArray()
            .jsonPath("$.messages[0].sender_name").isNotEmpty()
            .jsonPath("$.messages[0].relationship_display").isNotEmpty()
            .jsonPath("$.messages[0].content").isNotEmpty()
            .jsonPath("$.messages[0].is_read").isBoolean();
}
```

### API-ENC-008: Empty list
```java
@Test
void getEncouragementList_noMessages_returnsEmptyArray() {
    // Given - No messages for this patient
    
    // When/Then
    webTestClient.get()
        .uri("/api/v1/encouragements")
        .header("Authorization", "Bearer " + newPatientToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
            .jsonPath("$.messages").isArray()
            .jsonPath("$.messages").isEmpty();
}
```

### API-ENC-009: Sorted by sent_at DESC
```java
@Test
void getEncouragementList_sortedBySentAtDesc() {
    // Given
    sendTestMessage(PATIENT_UUID);  // older
    Thread.sleep(100);
    sendTestMessage(PATIENT_UUID);  // newer
    
    // When/Then
    webTestClient.get()
        .uri("/api/v1/encouragements")
        .header("Authorization", "Bearer " + patientToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
            .jsonPath("$.messages[0].sent_at").value(sentAt0 -> 
                assertThat(sentAt0).isAfter(sentAt1));
}
```

### API-ENC-010: Unauthorized → 401
```java
@Test
void getEncouragementList_noToken_returns401() {
    webTestClient.get()
        .uri("/api/v1/encouragements")
        .exchange()
        .expectStatus().isUnauthorized();
}
```

---

## 4. POST /api/v1/encouragements/mark-read (3 tests)

### API-ENC-011: Batch mark read
```java
@Test
void markAsRead_validIds_returns200() {
    // Given
    String msgId = createTestMessage(PATIENT_UUID);
    MarkAsReadRequest request = new MarkAsReadRequest();
    request.setIds(List.of(msgId));
    
    // When/Then
    webTestClient.post()
        .uri("/api/v1/encouragements/mark-read")
        .header("Authorization", "Bearer " + patientToken)
        .contentType(MediaType.APPLICATION_JSON)
        .bodyValue(request)
        .exchange()
        .expectStatus().isOk();
    
    // Verify
    webTestClient.get()
        .uri("/api/v1/encouragements")
        .header("Authorization", "Bearer " + patientToken)
        .exchange()
        .expectBody()
            .jsonPath("$.messages[?(@.encouragement_id=='" + msgId + "')].is_read")
            .isEqualTo(true);
}
```

### API-ENC-012: Empty array → 400
```java
@Test
void markAsRead_emptyArray_returns400() {
    // Given
    MarkAsReadRequest request = new MarkAsReadRequest();
    request.setIds(List.of());
    
    // When/Then
    webTestClient.post()
        .uri("/api/v1/encouragements/mark-read")
        .header("Authorization", "Bearer " + patientToken)
        .contentType(MediaType.APPLICATION_JSON)
        .bodyValue(request)
        .exchange()
        .expectStatus().isBadRequest();
}
```

### API-ENC-013: Invalid IDs ignored
```java
@Test
void markAsRead_invalidIds_partialSuccess() {
    // Given
    String validId = createTestMessage(PATIENT_UUID);
    String invalidId = UUID.randomUUID().toString();
    
    MarkAsReadRequest request = new MarkAsReadRequest();
    request.setIds(List.of(validId, invalidId));
    
    // When/Then
    webTestClient.post()
        .uri("/api/v1/encouragements/mark-read")
        .header("Authorization", "Bearer " + patientToken)
        .contentType(MediaType.APPLICATION_JSON)
        .bodyValue(request)
        .exchange()
        .expectStatus().isOk();  // Partial success
}
```

---

## 5. GET /api/v1/encouragements/quota (3 tests)

### API-ENC-014: Get quota
```java
@Test
void getQuota_validPatientId_returns200() {
    // Given - Send 3 messages
    for (int i = 0; i < 3; i++) {
        sendTestMessage(PATIENT_UUID);
    }
    
    // When/Then
    webTestClient.get()
        .uri(uriBuilder -> uriBuilder
            .path("/api/v1/encouragements/quota")
            .queryParam("patientId", PATIENT_UUID)
            .build())
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
            .jsonPath("$.used").isEqualTo(3)
            .jsonPath("$.remaining").isEqualTo(7)
            .jsonPath("$.limit").isEqualTo(10);
}
```

### API-ENC-015: Missing patientId → 400
```java
@Test
void getQuota_missingPatientId_returns400() {
    webTestClient.get()
        .uri("/api/v1/encouragements/quota")
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectStatus().isBadRequest();
}
```

### API-ENC-016: No connection → 404
```java
@Test
void getQuota_noConnection_returns404() {
    webTestClient.get()
        .uri(uriBuilder -> uriBuilder
            .path("/api/v1/encouragements/quota")
            .queryParam("patientId", UNCONNECTED_PATIENT_UUID)
            .build())
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectStatus().isNotFound();
}
```

---

## 6. Test Summary

| Endpoint | Tests | Priority |
|----------|:-----:|:--------:|
| POST /encouragements | 6 | HIGH |
| GET /encouragements | 4 | HIGH |
| POST /encouragements/mark-read | 3 | MEDIUM |
| GET /encouragements/quota | 3 | MEDIUM |
| **Total** | **16** | - |
