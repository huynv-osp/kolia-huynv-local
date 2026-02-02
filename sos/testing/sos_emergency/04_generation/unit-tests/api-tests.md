# 🌐 API Integration Tests - SOS Emergency Feature

## Document Information

| Attribute | Value |
|-----------|-------|
| **Version** | 1.0 |
| **Date** | 2026-01-26 |
| **Author** | Test Generator (Automated via /alio-testing) |
| **Framework** | JUnit 5 + WebTestClient + WireMock |

---

## Table of Contents

1. [SOS Core API Tests](#1-sos-core-api-tests)
2. [Emergency Contact API Tests](#2-emergency-contact-api-tests)
3. [Support API Tests](#3-support-api-tests)
4. [Error Handling Tests](#4-error-handling-tests)

---

# 1. SOS Core API Tests

## 1.1 POST /api/sos/activate

### Test Class: `SOSActivateApiTest`

```java
@WebFluxTest
@Import({SecurityConfig.class, TestConfig.class})
@DisplayName("POST /api/sos/activate - API Tests")
class SOSActivateApiTest {

    @Autowired
    private WebTestClient webClient;
    
    @MockBean
    private SOSService sosService;
    
    @MockBean
    private CooldownService cooldownService;
    
    @MockBean
    private EmergencyContactClient contactClient;
    
    private String validJwtToken;
    
    @BeforeEach
    void setUp() {
        validJwtToken = JwtTestHelper.generateToken("test-user-001");
    }
```

#### TC-API-001: Activate SOS - Success 200

```java
    @Test
    @DisplayName("TC-API-001: POST /api/sos/activate - Thành công 200")
    void activate_WithValidRequest_Returns200() {
        // Given
        when(cooldownService.isOnCooldown(any())).thenReturn(false);
        when(contactClient.countActiveContacts(any())).thenReturn(3);
        when(sosService.createEvent(any())).thenReturn(TestFixtures.mockSOSEvent());
        
        String requestBody = """
            {
                "latitude": 10.762622,
                "longitude": 106.660172,
                "location_accuracy_m": 15.5,
                "battery_level_percent": 85,
                "is_offline_triggered": false,
                "device_info": {
                    "platform": "ios",
                    "os_version": "16.0",
                    "app_version": "2.1.0"
                }
            }
            """;
        
        // When & Then
        webClient.post()
            .uri("/api/sos/activate")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.success").isEqualTo(true)
            .jsonPath("$.data.event_id").isNotEmpty()
            .jsonPath("$.data.countdown_seconds").isEqualTo(30)
            .jsonPath("$.data.status").isEqualTo("PENDING")
            .jsonPath("$.data.contacts_count").isEqualTo(3);
    }
```

#### TC-API-002: Activate SOS - Low Battery Returns 10s Countdown

```java
    @Test
    @DisplayName("TC-API-002: POST /api/sos/activate - Pin < 10% → countdown 10s")
    void activate_WithLowBattery_Returns10SecondCountdown() {
        // Given - BR-SOS-018
        when(cooldownService.isOnCooldown(any())).thenReturn(false);
        when(contactClient.countActiveContacts(any())).thenReturn(2);
        when(sosService.createEvent(any())).thenReturn(
            TestFixtures.mockSOSEventWithCountdown(10)
        );
        
        String requestBody = """
            {
                "battery_level_percent": 8
            }
            """;
        
        // When & Then
        webClient.post()
            .uri("/api/sos/activate")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.data.countdown_seconds").isEqualTo(10);
    }
```

#### TC-API-003: Activate SOS - Cooldown Returns 429

```java
    @Test
    @DisplayName("TC-API-003: POST /api/sos/activate - Cooldown active → 429")
    void activate_DuringCooldown_Returns429() {
        // Given - BR-SOS-019
        when(cooldownService.isOnCooldown(any())).thenReturn(true);
        when(cooldownService.getRemainingSeconds(any())).thenReturn(120L);
        
        // When & Then
        webClient.post()
            .uri("/api/sos/activate")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue("{}")
            .exchange()
            .expectStatus().isEqualTo(429)
            .expectBody()
            .jsonPath("$.success").isEqualTo(false)
            .jsonPath("$.error.code").isEqualTo("COOLDOWN_ACTIVE")
            .jsonPath("$.error.retry_after_seconds").isEqualTo(120)
            .jsonPath("$.error.bypass_allowed").isEqualTo(true);
    }
```

#### TC-API-004: Activate SOS - No Contacts Returns 400

```java
    @Test
    @DisplayName("TC-API-004: POST /api/sos/activate - Không có người thân → 400")
    void activate_WithNoContacts_Returns400() {
        // Given
        when(cooldownService.isOnCooldown(any())).thenReturn(false);
        when(contactClient.countActiveContacts(any())).thenReturn(0);
        
        // When & Then
        webClient.post()
            .uri("/api/sos/activate")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue("{}")
            .exchange()
            .expectStatus().isBadRequest()
            .expectBody()
            .jsonPath("$.error.code").isEqualTo("CONTACTS_REQUIRED")
            .jsonPath("$.error.message").value(containsString("người thân"));
    }
```

#### TC-API-005: Activate SOS - Unauthorized Returns 401

```java
    @Test
    @DisplayName("TC-API-005: POST /api/sos/activate - Không có token → 401")
    void activate_WithoutToken_Returns401() {
        // When & Then
        webClient.post()
            .uri("/api/sos/activate")
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue("{}")
            .exchange()
            .expectStatus().isUnauthorized()
            .expectBody()
            .jsonPath("$.error.code").isEqualTo("UNAUTHORIZED");
    }
```

---

## 1.2 POST /api/sos/activate/bypass

### Test Class: `SOSBypassApiTest`

```java
@WebFluxTest
@DisplayName("POST /api/sos/activate/bypass - API Tests")
class SOSBypassApiTest {
```

#### TC-API-006: Bypass Cooldown - Success

```java
    @Test
    @DisplayName("TC-API-006: POST /api/sos/activate/bypass - Thành công")
    void bypass_WithTrueEmergency_Returns200() {
        // Given - BR-SOS-019 exception
        when(contactClient.countActiveContacts(any())).thenReturn(2);
        when(sosService.createEventWithBypass(any())).thenReturn(
            TestFixtures.mockSOSEventBypassed()
        );
        
        String requestBody = """
            {
                "latitude": 10.762622,
                "longitude": 106.660172,
                "bypass_reason": "TRUE_EMERGENCY"
            }
            """;
        
        // When & Then
        webClient.post()
            .uri("/api/sos/activate/bypass")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.success").isEqualTo(true)
            .jsonPath("$.data.event_id").isNotEmpty();
        
        // Verify cooldown was NOT checked
        verify(cooldownService, never()).isOnCooldown(any());
    }
```

#### TC-API-007: Bypass - Invalid Reason Returns 400

```java
    @Test
    @DisplayName("TC-API-007: POST /api/sos/activate/bypass - bypass_reason required")
    void bypass_WithoutReason_Returns400() {
        // Given
        String requestBody = """
            {
                "latitude": 10.762622,
                "longitude": 106.660172
            }
            """;
        
        // When & Then
        webClient.post()
            .uri("/api/sos/activate/bypass")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isBadRequest();
    }
```

---

## 1.3 POST /api/sos/cancel

### Test Class: `SOSCancelApiTest`

```java
@WebFluxTest
@DisplayName("POST /api/sos/cancel - API Tests")
class SOSCancelApiTest {
```

#### TC-API-008: Cancel SOS - Success

```java
    @Test
    @DisplayName("TC-API-008: POST /api/sos/cancel - Hủy thành công")
    void cancel_DuringCountdown_Returns200() {
        // Given - BR-SOS-005
        String eventId = "550e8400-e29b-41d4-a716-446655440000";
        when(sosService.findEventById(eventId))
            .thenReturn(Optional.of(TestFixtures.mockSOSEventPending()));
        when(sosService.cancelEvent(any()))
            .thenReturn(TestFixtures.mockSOSEventCancelled());
        
        String requestBody = """
            {
                "event_id": "%s",
                "cancellation_reason": "Ấn nhầm"
            }
            """.formatted(eventId);
        
        // When & Then
        webClient.post()
            .uri("/api/sos/cancel")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.success").isEqualTo(true)
            .jsonPath("$.data.status").isEqualTo("CANCELLED")
            .jsonPath("$.data.cancelled_at").isNotEmpty();
        
        // Verify NO cooldown set
        verify(cooldownService, never()).setCooldown(any());
    }
```

#### TC-API-009: Cancel SOS - Already Completed Returns 409

```java
    @Test
    @DisplayName("TC-API-009: POST /api/sos/cancel - Đã hoàn thành → 409")
    void cancel_WhenCompleted_Returns409() {
        // Given
        String eventId = "550e8400-e29b-41d4-a716-446655440000";
        when(sosService.findEventById(eventId))
            .thenReturn(Optional.of(TestFixtures.mockSOSEventCompleted()));
        
        String requestBody = """
            {
                "event_id": "%s"
            }
            """.formatted(eventId);
        
        // When & Then
        webClient.post()
            .uri("/api/sos/cancel")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isEqualTo(409)
            .expectBody()
            .jsonPath("$.error.code").isEqualTo("EVENT_ALREADY_COMPLETED");
    }
```

#### TC-API-010: Cancel SOS - Not Found Returns 404

```java
    @Test
    @DisplayName("TC-API-010: POST /api/sos/cancel - Không tồn tại → 404")
    void cancel_WhenNotFound_Returns404() {
        // Given
        String eventId = "non-existent-id";
        when(sosService.findEventById(eventId)).thenReturn(Optional.empty());
        
        String requestBody = """
            {
                "event_id": "%s"
            }
            """.formatted(eventId);
        
        // When & Then
        webClient.post()
            .uri("/api/sos/cancel")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isNotFound()
            .expectBody()
            .jsonPath("$.error.code").isEqualTo("EVENT_NOT_FOUND");
    }
```

---

## 1.4 GET /api/sos/status/{eventId}

### Test Class: `SOSStatusApiTest`

```java
@WebFluxTest
@DisplayName("GET /api/sos/status/{eventId} - API Tests")
class SOSStatusApiTest {
```

#### TC-API-011: Get Status - Pending

```java
    @Test
    @DisplayName("TC-API-011: GET /api/sos/status - Trạng thái PENDING")
    void getStatus_WhenPending_ReturnsRemainingSeconds() {
        // Given - BR-SOS-020
        String eventId = "550e8400-e29b-41d4-a716-446655440000";
        SOSEvent event = TestFixtures.mockSOSEventPending();
        event.setCountdownStartedAt(Instant.now().minusSeconds(15));
        
        when(sosService.findEventById(eventId)).thenReturn(Optional.of(event));
        
        // When & Then
        webClient.get()
            .uri("/api/sos/status/" + eventId)
            .header("Authorization", "Bearer " + validJwtToken)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.data.status").isEqualTo("PENDING")
            .jsonPath("$.data.countdown_remaining_seconds").value(
                val -> assertThat((Integer) val).isBetween(14, 16)
            )
            .jsonPath("$.data.server_time").isNotEmpty();
    }
```

#### TC-API-012: Get Status - Completed

```java
    @Test
    @DisplayName("TC-API-012: GET /api/sos/status - Trạng thái COMPLETED")
    void getStatus_WhenCompleted_ReturnsNotificationStats() {
        // Given
        String eventId = "550e8400-e29b-41d4-a716-446655440000";
        when(sosService.findEventById(eventId))
            .thenReturn(Optional.of(TestFixtures.mockSOSEventCompleted()));
        when(sosService.getNotificationStats(eventId))
            .thenReturn(new NotificationStats(5, 5, 3, 0, 2));
        
        // When & Then
        webClient.get()
            .uri("/api/sos/status/" + eventId)
            .header("Authorization", "Bearer " + validJwtToken)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.data.status").isEqualTo("COMPLETED")
            .jsonPath("$.data.notifications.total").isEqualTo(5)
            .jsonPath("$.data.notifications.sent").isEqualTo(5)
            .jsonPath("$.data.notifications.delivered").isEqualTo(3);
    }
```

---

# 2. Emergency Contact API Tests

## 2.1 GET /api/sos/contacts

### Test Class: `ContactListApiTest`

```java
@WebFluxTest
@DisplayName("GET /api/sos/contacts - API Tests")
class ContactListApiTest {
```

#### TC-API-013: List Contacts - Has Data

```java
    @Test
    @DisplayName("TC-API-013: GET /api/sos/contacts - Có dữ liệu")
    void listContacts_WithData_ReturnsList() {
        // Given
        List<EmergencyContact> contacts = List.of(
            TestFixtures.mockContact("Người thân 1", "0912345678", 1),
            TestFixtures.mockContact("Người thân 2", "0923456789", 2)
        );
        when(contactClient.listContacts(any())).thenReturn(contacts);
        
        // When & Then
        webClient.get()
            .uri("/api/sos/contacts")
            .header("Authorization", "Bearer " + validJwtToken)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.success").isEqualTo(true)
            .jsonPath("$.data.contacts.length()").isEqualTo(2)
            .jsonPath("$.data.contacts[0].priority").isEqualTo(1)
            .jsonPath("$.data.count").isEqualTo(2)
            .jsonPath("$.data.max_contacts").isEqualTo(5);
    }
```

#### TC-API-014: List Contacts - Empty

```java
    @Test
    @DisplayName("TC-API-014: GET /api/sos/contacts - Rỗng")
    void listContacts_WhenEmpty_ReturnsEmptyList() {
        // Given
        when(contactClient.listContacts(any())).thenReturn(List.of());
        
        // When & Then
        webClient.get()
            .uri("/api/sos/contacts")
            .header("Authorization", "Bearer " + validJwtToken)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.data.contacts").isEmpty()
            .jsonPath("$.data.count").isEqualTo(0);
    }
```

---

## 2.2 POST /api/sos/contacts

### Test Class: `AddContactApiTest`

```java
@WebFluxTest
@DisplayName("POST /api/sos/contacts - API Tests")
class AddContactApiTest {
```

#### TC-API-015: Add Contact - Success 201

```java
    @Test
    @DisplayName("TC-API-015: POST /api/sos/contacts - Thành công 201")
    void addContact_WithValidData_Returns201() {
        // Given
        when(contactClient.countActiveContacts(any())).thenReturn(2);
        when(contactClient.addContact(any()))
            .thenReturn(TestFixtures.mockContact("Lê Văn C", "0923456789", 3));
        
        String requestBody = """
            {
                "name": "Lê Văn C",
                "phone": "0923456789",
                "relationship": "Cháu",
                "priority": 3,
                "zalo_enabled": true
            }
            """;
        
        // When & Then
        webClient.post()
            .uri("/api/sos/contacts")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isCreated()
            .expectBody()
            .jsonPath("$.success").isEqualTo(true)
            .jsonPath("$.data.contact_id").isNotEmpty()
            .jsonPath("$.data.name").isEqualTo("Lê Văn C")
            .jsonPath("$.data.phone").isEqualTo("0923456789");
    }
```

#### TC-API-016: Add Contact - Max Reached Returns 400

```java
    @Test
    @DisplayName("TC-API-016: POST /api/sos/contacts - Đã đủ 5 → 400")
    void addContact_WhenMaxReached_Returns400() {
        // Given
        when(contactClient.countActiveContacts(any())).thenReturn(5);
        
        String requestBody = """
            {
                "name": "Test",
                "phone": "0999999999"
            }
            """;
        
        // When & Then
        webClient.post()
            .uri("/api/sos/contacts")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isBadRequest()
            .expectBody()
            .jsonPath("$.error.code").isEqualTo("MAX_CONTACTS_REACHED")
            .jsonPath("$.error.message").value(containsString("5 người"));
    }
```

#### TC-API-017: Add Contact - Duplicate Phone Returns 400

```java
    @Test
    @DisplayName("TC-API-017: POST /api/sos/contacts - Trùng SĐT → 400")
    void addContact_WithDuplicatePhone_Returns400() {
        // Given
        when(contactClient.countActiveContacts(any())).thenReturn(2);
        when(contactClient.addContact(any()))
            .thenThrow(new DuplicatePhoneException("0912345678"));
        
        String requestBody = """
            {
                "name": "Test",
                "phone": "0912345678"
            }
            """;
        
        // When & Then
        webClient.post()
            .uri("/api/sos/contacts")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isBadRequest()
            .expectBody()
            .jsonPath("$.error.code").isEqualTo("DUPLICATE_PHONE");
    }
```

#### TC-API-018: Add Contact - Invalid Phone Format Returns 400

```java
    @ParameterizedTest
    @DisplayName("TC-API-018: POST /api/sos/contacts - SĐT không hợp lệ → 400")
    @ValueSource(strings = {"123", "901234567", "abc", ""})
    void addContact_WithInvalidPhone_Returns400(String invalidPhone) {
        // Given
        String requestBody = """
            {
                "name": "Test",
                "phone": "%s"
            }
            """.formatted(invalidPhone);
        
        // When & Then
        webClient.post()
            .uri("/api/sos/contacts")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isBadRequest()
            .expectBody()
            .jsonPath("$.error.code").isEqualTo("INVALID_PHONE_FORMAT");
    }
```

---

## 2.3 PUT /api/sos/contacts/{contactId}

### Test Class: `UpdateContactApiTest`

```java
@WebFluxTest
@DisplayName("PUT /api/sos/contacts/{contactId} - API Tests")
class UpdateContactApiTest {
```

#### TC-API-019: Update Contact - Success

```java
    @Test
    @DisplayName("TC-API-019: PUT /api/sos/contacts/{id} - Thành công")
    void updateContact_WithValidData_Returns200() {
        // Given
        String contactId = "contact-001";
        when(contactClient.updateContact(any()))
            .thenReturn(TestFixtures.mockContact("Tên mới", "0912345678", 2));
        
        String requestBody = """
            {
                "name": "Tên mới",
                "priority": 2
            }
            """;
        
        // When & Then
        webClient.put()
            .uri("/api/sos/contacts/" + contactId)
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.data.name").isEqualTo("Tên mới")
            .jsonPath("$.data.priority").isEqualTo(2);
    }
```

#### TC-API-020: Update Contact - Not Found Returns 404

```java
    @Test
    @DisplayName("TC-API-020: PUT /api/sos/contacts/{id} - Không tồn tại → 404")
    void updateContact_WhenNotFound_Returns404() {
        // Given
        String contactId = "non-existent";
        when(contactClient.updateContact(any()))
            .thenThrow(new ContactNotFoundException(contactId));
        
        // When & Then
        webClient.put()
            .uri("/api/sos/contacts/" + contactId)
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue("{\"name\": \"Test\"}")
            .exchange()
            .expectStatus().isNotFound();
    }
```

---

## 2.4 DELETE /api/sos/contacts/{contactId}

### Test Class: `DeleteContactApiTest`

```java
@WebFluxTest
@DisplayName("DELETE /api/sos/contacts/{contactId} - API Tests")
class DeleteContactApiTest {
```

#### TC-API-021: Delete Contact - Success

```java
    @Test
    @DisplayName("TC-API-021: DELETE /api/sos/contacts/{id} - Thành công")
    void deleteContact_WithValidId_Returns200() {
        // Given
        String contactId = "contact-001";
        doNothing().when(contactClient).deleteContact(contactId);
        
        // When & Then
        webClient.delete()
            .uri("/api/sos/contacts/" + contactId)
            .header("Authorization", "Bearer " + validJwtToken)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.success").isEqualTo(true)
            .jsonPath("$.message").value(containsString("Đã xóa"));
    }
```

#### TC-API-022: Delete Contact - Not Found Returns 404

```java
    @Test
    @DisplayName("TC-API-022: DELETE /api/sos/contacts/{id} - Không tồn tại → 404")
    void deleteContact_WhenNotFound_Returns404() {
        // Given
        String contactId = "non-existent";
        doThrow(new ContactNotFoundException(contactId))
            .when(contactClient).deleteContact(contactId);
        
        // When & Then
        webClient.delete()
            .uri("/api/sos/contacts/" + contactId)
            .header("Authorization", "Bearer " + validJwtToken)
            .exchange()
            .expectStatus().isNotFound();
    }
```

---

# 3. Support API Tests

## 3.1 GET /api/sos/first-aid

### Test Class: `FirstAidApiTest`

```java
@WebFluxTest
@DisplayName("GET /api/sos/first-aid - API Tests")
class FirstAidApiTest {
```

#### TC-API-023: Get First Aid Content - All

```java
    @Test
    @DisplayName("TC-API-023: GET /api/sos/first-aid - Lấy tất cả")
    void getFirstAid_WithoutFilter_ReturnsAll() {
        // Given - BR-SOS-013, BR-SOS-014
        List<FirstAidContent> contents = List.of(
            TestFixtures.mockFirstAid("cpr", "Hồi sinh tim phổi", 1),
            TestFixtures.mockFirstAid("stroke", "Đột quỵ", 2),
            TestFixtures.mockFirstAid("low_sugar", "Hạ đường huyết", 3),
            TestFixtures.mockFirstAid("fall", "Té ngã", 4)
        );
        when(firstAidRepository.findAllActive()).thenReturn(contents);
        
        // When & Then
        webClient.get()
            .uri("/api/sos/first-aid")
            .header("Authorization", "Bearer " + validJwtToken)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.data.categories.length()").isEqualTo(4)
            .jsonPath("$.data.categories[0].category").isEqualTo("cpr")
            .jsonPath("$.data.disclaimer").value(containsString("THÔNG TIN CHỈ MANG TÍNH THAM KHẢO"))
            .jsonPath("$.data.disclaimer").value(containsString("115"));
    }
```

#### TC-API-024: Get First Aid Content - By Category

```java
    @Test
    @DisplayName("TC-API-024: GET /api/sos/first-aid?category=cpr")
    void getFirstAid_WithCategory_ReturnsFiltered() {
        // Given
        when(firstAidRepository.findByCategory("cpr"))
            .thenReturn(List.of(TestFixtures.mockFirstAid("cpr", "Hồi sinh tim phổi", 1)));
        
        // When & Then
        webClient.get()
            .uri("/api/sos/first-aid?category=cpr")
            .header("Authorization", "Bearer " + validJwtToken)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.data.categories.length()").isEqualTo(1)
            .jsonPath("$.data.categories[0].category").isEqualTo("cpr");
    }
```

---

## 3.2 POST /api/sos/escalation/confirm

### Test Class: `EscalationConfirmApiTest`

```java
@WebFluxTest
@DisplayName("POST /api/sos/escalation/confirm - API Tests")
class EscalationConfirmApiTest {
```

#### TC-API-025: Confirm Escalation - Success

```java
    @Test
    @DisplayName("TC-API-025: POST /api/sos/escalation/confirm - Thành công")
    void confirmEscalation_WithValidData_StopsEscalation() {
        // Given - BR-SOS-009
        when(escalationService.confirmAnswered(any())).thenReturn(true);
        
        String requestBody = """
            {
                "event_id": "550e8400-e29b-41d4-a716-446655440000",
                "contact_id": "123e4567-e89b-12d3-a456-426614174000",
                "confirmation_type": "ANSWERED_CALL"
            }
            """;
        
        // When & Then
        webClient.post()
            .uri("/api/sos/escalation/confirm")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.success").isEqualTo(true)
            .jsonPath("$.data.escalation_stopped").isEqualTo(true);
    }
```

---

# 4. Error Handling Tests

## 4.1 Global Error Response Format

### Test Class: `ErrorResponseFormatTest`

```java
@WebFluxTest
@DisplayName("Error Response Format Tests")
class ErrorResponseFormatTest {
```

#### TC-ERR-001: Error Response Structure

```java
    @Test
    @DisplayName("TC-ERR-001: Error response có đúng cấu trúc")
    void errorResponse_HasCorrectStructure() {
        // Given - Trigger a 400 error
        when(contactClient.countActiveContacts(any())).thenReturn(5);
        
        // When & Then
        webClient.post()
            .uri("/api/sos/contacts")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue("{\"name\": \"Test\", \"phone\": \"0912345678\"}")
            .exchange()
            .expectStatus().isBadRequest()
            .expectBody()
            .jsonPath("$.success").isEqualTo(false)
            .jsonPath("$.error").exists()
            .jsonPath("$.error.code").isNotEmpty()
            .jsonPath("$.error.message").isNotEmpty()
            .jsonPath("$.meta").exists()
            .jsonPath("$.meta.timestamp").isNotEmpty();
    }
```

#### TC-ERR-002: Vietnamese Error Messages

```java
    @Test
    @DisplayName("TC-ERR-002: Error messages bằng tiếng Việt")
    void errorMessage_IsInVietnamese() {
        // Given
        String requestBody = """
            {
                "name": "Test",
                "phone": "123"
            }
            """;
        
        // When & Then
        webClient.post()
            .uri("/api/sos/contacts")
            .header("Authorization", "Bearer " + validJwtToken)
            .header("Accept-Language", "vi-VN")
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectBody()
            .jsonPath("$.error.message").value(msg -> 
                assertThat((String) msg).containsAnyOf(
                    "không hợp lệ", "Vui lòng", "số điện thoại"
                )
            );
    }
```

---

# 5. Location & Hospital API Tests (GAP APIs)

---

## 5.1 GET /api/sos/hospitals/nearby

### Test Class: `HospitalNearbyApiTest`

```java
@WebFluxTest
@Import({SecurityConfig.class, TestConfig.class})
@DisplayName("GET /api/sos/hospitals/nearby - API Tests")
class HospitalNearbyApiTest {

    @Autowired
    private WebTestClient webClient;
    
    @MockBean
    private HospitalService hospitalService;
    
    private String validJwtToken;
    
    @BeforeEach
    void setUp() {
        validJwtToken = JwtTestHelper.generateToken("test-user-001");
    }
```

#### TC-API-026: Hospital Nearby - Success

```java
    @Test
    @DisplayName("TC-API-026: GET /api/sos/hospitals/nearby - Thành công")
    void getNearbyHospitals_WithValidLocation_ReturnsHospitals() {
        // Given - GAP-API-001, BR-SOS-012
        List<Hospital> hospitals = List.of(
            TestFixtures.mockHospital("Bệnh viện Chợ Rẫy", 10.7577, 106.6592, 2.3),
            TestFixtures.mockHospital("Bệnh viện Đại học Y Dược", 10.7560, 106.6610, 2.8)
        );
        when(hospitalService.findNearby(anyDouble(), anyDouble(), anyInt()))
            .thenReturn(hospitals);
        
        // When & Then
        webClient.get()
            .uri("/api/sos/hospitals/nearby?lat=10.762622&lng=106.660172&radius_km=10")
            .header("Authorization", "Bearer " + validJwtToken)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.success").isEqualTo(true)
            .jsonPath("$.data.hospitals.length()").isEqualTo(2)
            .jsonPath("$.data.hospitals[0].name").isEqualTo("Bệnh viện Chợ Rẫy")
            .jsonPath("$.data.hospitals[0].distance_km").isEqualTo(2.3)
            .jsonPath("$.data.count").isEqualTo(2);
    }
```

#### TC-API-027: Hospital Nearby - No Results

```java
    @Test
    @DisplayName("TC-API-027: GET /api/sos/hospitals/nearby - Không tìm thấy")
    void getNearbyHospitals_WhenNoResults_ReturnsEmptyList() {
        // Given
        when(hospitalService.findNearby(anyDouble(), anyDouble(), anyInt()))
            .thenReturn(List.of());
        
        // When & Then
        webClient.get()
            .uri("/api/sos/hospitals/nearby?lat=10.0&lng=106.0&radius_km=10")
            .header("Authorization", "Bearer " + validJwtToken)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.success").isEqualTo(true)
            .jsonPath("$.data.hospitals").isEmpty()
            .jsonPath("$.data.count").isEqualTo(0)
            .jsonPath("$.data.message").value(containsString("Không tìm thấy"));
    }
```

#### TC-API-028: Hospital Nearby - Missing Coordinates

```java
    @Test
    @DisplayName("TC-API-028: GET /api/sos/hospitals/nearby - Thiếu tọa độ → 400")
    void getNearbyHospitals_WithoutCoordinates_Returns400() {
        // When & Then
        webClient.get()
            .uri("/api/sos/hospitals/nearby")
            .header("Authorization", "Bearer " + validJwtToken)
            .exchange()
            .expectStatus().isBadRequest()
            .expectBody()
            .jsonPath("$.error.code").isEqualTo("VALIDATION_ERROR");
    }
```

---

## 5.2 POST /api/sos/events/{eventId}/location

### Test Class: `LocationUpdateApiTest`

```java
@WebFluxTest
@DisplayName("POST /api/sos/events/{eventId}/location - API Tests")
class LocationUpdateApiTest {
```

#### TC-API-029: Location Update - Success

```java
    @Test
    @DisplayName("TC-API-029: POST /api/sos/events/{id}/location - Thành công")
    void updateLocation_WithValidData_Returns200() {
        // Given - GAP-API-003, BR-SOS-015
        String eventId = "550e8400-e29b-41d4-a716-446655440000";
        when(sosService.findEventById(eventId))
            .thenReturn(Optional.of(TestFixtures.mockSOSEventPending()));
        when(sosService.updateEventLocation(any(), any()))
            .thenReturn(TestFixtures.mockLocationUpdateResult());
        
        String requestBody = """
            {
                "latitude": 10.765000,
                "longitude": 106.661000,
                "location_accuracy_m": 8.5,
                "location_source": "gps",
                "timestamp": "2026-01-26T10:05:00Z"
            }
            """;
        
        // When & Then
        webClient.post()
            .uri("/api/sos/events/" + eventId + "/location")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.success").isEqualTo(true)
            .jsonPath("$.data.location_updated").isEqualTo(true)
            .jsonPath("$.data.new_location.latitude").isEqualTo(10.765000);
    }
```

#### TC-API-030: Location Update - Event Not Found

```java
    @Test
    @DisplayName("TC-API-030: POST /api/sos/events/{id}/location - Event không tồn tại → 404")
    void updateLocation_WhenEventNotFound_Returns404() {
        // Given
        String eventId = "non-existent-event";
        when(sosService.findEventById(eventId)).thenReturn(Optional.empty());
        
        String requestBody = """
            {
                "latitude": 10.765000,
                "longitude": 106.661000
            }
            """;
        
        // When & Then
        webClient.post()
            .uri("/api/sos/events/" + eventId + "/location")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isNotFound()
            .expectBody()
            .jsonPath("$.error.code").isEqualTo("EVENT_NOT_FOUND");
    }
```

#### TC-API-031: Location Update - Event Cancelled

```java
    @Test
    @DisplayName("TC-API-031: POST /api/sos/events/{id}/location - Event đã hủy → 409")
    void updateLocation_WhenEventCancelled_Returns409() {
        // Given
        String eventId = "550e8400-e29b-41d4-a716-446655440000";
        when(sosService.findEventById(eventId))
            .thenReturn(Optional.of(TestFixtures.mockSOSEventCancelled()));
        
        String requestBody = """
            {
                "latitude": 10.765000,
                "longitude": 106.661000
            }
            """;
        
        // When & Then
        webClient.post()
            .uri("/api/sos/events/" + eventId + "/location")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isEqualTo(409)
            .expectBody()
            .jsonPath("$.error.code").isEqualTo("EVENT_ALREADY_CANCELLED");
    }
```

---

## 5.3 POST /api/sos/events/{eventId}/manual-call

### Test Class: `ManualCallApiTest`

```java
@WebFluxTest
@DisplayName("POST /api/sos/events/{eventId}/manual-call - API Tests")
class ManualCallApiTest {
```

#### TC-API-032: Manual Call - Success

```java
    @Test
    @DisplayName("TC-API-032: POST /api/sos/events/{id}/manual-call - Thành công")
    void reportManualCall_WithValidData_SkipsEscalation() {
        // Given - GAP-API-005, BR-SOS-011
        String eventId = "550e8400-e29b-41d4-a716-446655440000";
        String contactId = "123e4567-e89b-12d3-a456-426614174000";
        
        when(sosService.findEventById(eventId))
            .thenReturn(Optional.of(TestFixtures.mockSOSEventCompleted()));
        when(escalationService.skipContact(eventId, contactId))
            .thenReturn(true);
        
        String requestBody = """
            {
                "contact_id": "%s",
                "call_started_at": "2026-01-26T10:00:30Z"
            }
            """.formatted(contactId);
        
        // When & Then
        webClient.post()
            .uri("/api/sos/events/" + eventId + "/manual-call")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.success").isEqualTo(true)
            .jsonPath("$.data.escalation_updated").isEqualTo(true)
            .jsonPath("$.data.skipped_contact_id").isEqualTo(contactId);
    }
```

#### TC-API-033: Manual Call - Contact Not Found

```java
    @Test
    @DisplayName("TC-API-033: POST /api/sos/events/{id}/manual-call - Contact không tồn tại → 404")
    void reportManualCall_WhenContactNotFound_Returns404() {
        // Given
        String eventId = "550e8400-e29b-41d4-a716-446655440000";
        String contactId = "non-existent-contact";
        
        when(sosService.findEventById(eventId))
            .thenReturn(Optional.of(TestFixtures.mockSOSEventCompleted()));
        when(escalationService.skipContact(eventId, contactId))
            .thenThrow(new ContactNotFoundException(contactId));
        
        String requestBody = """
            {
                "contact_id": "%s"
            }
            """.formatted(contactId);
        
        // When & Then
        webClient.post()
            .uri("/api/sos/events/" + eventId + "/manual-call")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isNotFound()
            .expectBody()
            .jsonPath("$.error.code").isEqualTo("CONTACT_NOT_FOUND");
    }
```

#### TC-API-034: Manual Call - Missing Contact ID

```java
    @Test
    @DisplayName("TC-API-034: POST /api/sos/events/{id}/manual-call - Thiếu contact_id → 400")
    void reportManualCall_WithoutContactId_Returns400() {
        // Given
        String eventId = "550e8400-e29b-41d4-a716-446655440000";
        
        // When & Then
        webClient.post()
            .uri("/api/sos/events/" + eventId + "/manual-call")
            .header("Authorization", "Bearer " + validJwtToken)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue("{}")
            .exchange()
            .expectStatus().isBadRequest()
            .expectBody()
            .jsonPath("$.error.code").isEqualTo("VALIDATION_ERROR");
    }
```

---

# 6. Internal API Tests

---

## 6.1 POST /internal/cskh/alerts

### Test Class: `CSKHAlertApiTest`

```java
@WebFluxTest
@Import({InternalSecurityConfig.class})
@DisplayName("POST /internal/cskh/alerts - Internal API Tests")
class CSKHAlertApiTest {

    @Autowired
    private WebTestClient webClient;
    
    @MockBean
    private CSKHAlertService cskhAlertService;
    
    private static final String INTERNAL_API_KEY = "test-internal-api-key";
```

#### TC-API-035: CSKH Alert - SOS Triggered Success

```java
    @Test
    @DisplayName("TC-API-035: POST /internal/cskh/alerts - SOS_TRIGGERED thành công")
    void sendAlert_SOSTriggered_Returns200() {
        // Given - GAP-API-004, BR-SOS-004
        when(cskhAlertService.createAlert(any()))
            .thenReturn(TestFixtures.mockCSKHTicket("CSKH-2026-0001"));
        
        String requestBody = """
            {
                "alert_type": "SOS_TRIGGERED",
                "event_id": "550e8400-e29b-41d4-a716-446655440000",
                "user_id": "123e4567-e89b-12d3-a456-426614174000",
                "user_name": "Nguyễn Văn A",
                "user_phone": "0901234567",
                "location": {
                    "latitude": 10.762622,
                    "longitude": 106.660172,
                    "maps_link": "https://maps.google.com/?q=10.762622,106.660172"
                },
                "triggered_at": "2026-01-26T10:00:00Z"
            }
            """;
        
        // When & Then
        webClient.post()
            .uri("/internal/cskh/alerts")
            .header("X-Internal-API-Key", INTERNAL_API_KEY)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.success").isEqualTo(true)
            .jsonPath("$.data.ticket_id").isEqualTo("CSKH-2026-0001")
            .jsonPath("$.data.priority").isEqualTo("HIGH");
    }
```

#### TC-API-036: CSKH Alert - Escalation Failed

```java
    @Test
    @DisplayName("TC-API-036: POST /internal/cskh/alerts - ESCALATION_FAILED thành công")
    void sendAlert_EscalationFailed_Returns200() {
        // Given - BR-SOS-008
        when(cskhAlertService.createAlert(any()))
            .thenReturn(TestFixtures.mockCSKHTicket("CSKH-2026-0002"));
        
        String requestBody = """
            {
                "alert_type": "ESCALATION_FAILED",
                "event_id": "550e8400-e29b-41d4-a716-446655440000",
                "user_id": "123e4567-e89b-12d3-a456-426614174000",
                "user_name": "Nguyễn Văn A",
                "user_phone": "0901234567",
                "contacts_status": [
                    {"name": "Người thân 1", "phone": "0912345678", "status": "NO_ANSWER"},
                    {"name": "Người thân 2", "phone": "0923456789", "status": "BUSY"}
                ],
                "triggered_at": "2026-01-26T10:00:00Z"
            }
            """;
        
        // When & Then
        webClient.post()
            .uri("/internal/cskh/alerts")
            .header("X-Internal-API-Key", INTERNAL_API_KEY)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.success").isEqualTo(true)
            .jsonPath("$.data.ticket_id").isNotEmpty();
    }
```

#### TC-API-037: CSKH Alert - Invalid API Key

```java
    @Test
    @DisplayName("TC-API-037: POST /internal/cskh/alerts - API Key không hợp lệ → 401")
    void sendAlert_WithInvalidApiKey_Returns401() {
        // When & Then
        webClient.post()
            .uri("/internal/cskh/alerts")
            .header("X-Internal-API-Key", "invalid-key")
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue("{\"alert_type\": \"SOS_TRIGGERED\"}")
            .exchange()
            .expectStatus().isUnauthorized()
            .expectBody()
            .jsonPath("$.error.code").isEqualTo("INVALID_API_KEY");
    }
```

#### TC-API-038: CSKH Alert - Missing API Key

```java
    @Test
    @DisplayName("TC-API-038: POST /internal/cskh/alerts - Thiếu API Key → 401")
    void sendAlert_WithoutApiKey_Returns401() {
        // When & Then
        webClient.post()
            .uri("/internal/cskh/alerts")
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue("{\"alert_type\": \"SOS_TRIGGERED\"}")
            .exchange()
            .expectStatus().isUnauthorized();
    }
```

#### TC-API-039: CSKH Alert - Invalid Alert Type

```java
    @Test
    @DisplayName("TC-API-039: POST /internal/cskh/alerts - alert_type không hợp lệ → 400")
    void sendAlert_WithInvalidAlertType_Returns400() {
        // Given
        String requestBody = """
            {
                "alert_type": "INVALID_TYPE",
                "event_id": "550e8400-e29b-41d4-a716-446655440000"
            }
            """;
        
        // When & Then
        webClient.post()
            .uri("/internal/cskh/alerts")
            .header("X-Internal-API-Key", INTERNAL_API_KEY)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(requestBody)
            .exchange()
            .expectStatus().isBadRequest()
            .expectBody()
            .jsonPath("$.error.code").isEqualTo("INVALID_ALERT_TYPE");
    }
```

---

## Test Summary

| Category | Endpoint | Test Cases | Priority |
|----------|----------|:----------:|:--------:|
| SOS Core | POST /api/sos/activate | 5 | 🔴 Critical |
| SOS Core | POST /api/sos/activate/bypass | 2 | 🔴 Critical |
| SOS Core | POST /api/sos/cancel | 3 | 🔴 Critical |
| SOS Core | GET /api/sos/status/{id} | 2 | 🔴 Critical |
| Contact | GET /api/sos/contacts | 2 | 🔴 Critical |
| Contact | POST /api/sos/contacts | 4 | 🔴 Critical |
| Contact | PUT /api/sos/contacts/{id} | 2 | 🟡 High |
| Contact | DELETE /api/sos/contacts/{id} | 2 | 🟡 High |
| Support | GET /api/sos/first-aid | 2 | 🟡 High |
| Support | POST /api/sos/escalation/confirm | 1 | 🔴 Critical |
| Error | Global error format | 2 | 🔴 Critical |
| **Location & Hospital** | GET /api/sos/hospitals/nearby | 3 | 🟡 High |
| **Location & Hospital** | POST /api/sos/events/{id}/location | 3 | 🟡 High |
| **Location & Hospital** | POST /api/sos/events/{id}/manual-call | 3 | 🔴 Critical |
| **Internal** | POST /internal/cskh/alerts | 5 | 🔴 Critical |
| **TOTAL** | - | **41** | - |

---

**Report Version:** 1.1  
**Generated:** 2026-01-26T12:05:00+07:00  
**Workflow:** `/alio-testing`  
**Change:** Added 14 test cases for GAP APIs (GAP-API-001, 003, 004, 005)

