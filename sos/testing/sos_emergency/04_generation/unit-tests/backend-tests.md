# 🧪 Backend Unit Tests - SOS Emergency Feature

## Document Information

| Attribute | Value |
|-----------|-------|
| **Version** | 1.0 |
| **Date** | 2026-01-26 |
| **Author** | Test Generator (Automated via /alio-testing) |
| **Services** | api-gateway-service, user-service, schedule-service |

---

## Table of Contents

1. [api-gateway-service Tests](#1-api-gateway-service-tests)
2. [user-service Tests](#2-user-service-tests)
3. [schedule-service Tests](#3-schedule-service-tests)

---

# 1. api-gateway-service Tests

## Framework: JUnit 5 + Mockito

---

## 1.1 SOSHandler Tests

### Class: `SOSHandlerTest`

```java
package com.alio.gateway.sos;

import org.junit.jupiter.api.*;
import org.mockito.*;
import static org.mockito.Mockito.*;

@DisplayName("SOSHandler Tests")
class SOSHandlerTest {
    
    @Mock private SOSService sosService;
    @Mock private CooldownService cooldownService;
    @Mock private EmergencyContactClient contactClient;
    @InjectMocks private SOSHandler sosHandler;
    
    @BeforeEach
    void setUp() {
        MockitoAnnotations.openMocks(this);
    }
```

#### TC-HANDLER-001: Activate SOS - Happy Path

```java
    @Test
    @DisplayName("TC-HANDLER-001: Kích hoạt SOS thành công")
    void activate_WithValidRequest_ReturnsEventId() {
        // Given
        String userId = "test-user-001";
        SOSActivateRequest request = SOSActivateRequest.builder()
            .latitude(10.762622)
            .longitude(106.660172)
            .batteryLevelPercent(85)
            .build();
        
        when(cooldownService.isOnCooldown(userId)).thenReturn(false);
        when(contactClient.countActiveContacts(userId)).thenReturn(3);
        when(sosService.createEvent(any())).thenReturn(mockEvent());
        
        // When
        SOSActivateResponse response = sosHandler.activate(userId, request);
        
        // Then
        assertThat(response.isSuccess()).isTrue();
        assertThat(response.getData().getEventId()).isNotNull();
        assertThat(response.getData().getCountdownSeconds()).isEqualTo(30);
        assertThat(response.getData().getStatus()).isEqualTo("PENDING");
        assertThat(response.getData().getContactsCount()).isEqualTo(3);
        
        verify(sosService).createEvent(any());
        verify(kafkaProducer).send(eq("sos.activated"), any());
    }
```

#### TC-HANDLER-002: Activate SOS - Low Battery (10s countdown)

```java
    @Test
    @DisplayName("TC-HANDLER-002: Kích hoạt SOS với pin < 10% → countdown 10 giây")
    void activate_WithLowBattery_Returns10SecondCountdown() {
        // Given - BR-SOS-018
        String userId = "test-user-001";
        SOSActivateRequest request = SOSActivateRequest.builder()
            .batteryLevelPercent(8)  // < 10%
            .build();
        
        when(cooldownService.isOnCooldown(userId)).thenReturn(false);
        when(contactClient.countActiveContacts(userId)).thenReturn(2);
        when(sosService.createEvent(any())).thenReturn(mockEventWithCountdown(10));
        
        // When
        SOSActivateResponse response = sosHandler.activate(userId, request);
        
        // Then
        assertThat(response.getData().getCountdownSeconds()).isEqualTo(10);
    }
```

#### TC-HANDLER-003: Activate SOS - Cooldown Active

```java
    @Test
    @DisplayName("TC-HANDLER-003: Kích hoạt SOS trong cooldown → 429")
    void activate_DuringCooldown_Returns429WithBypassOption() {
        // Given - BR-SOS-019
        String userId = "test-user-001";
        SOSActivateRequest request = SOSActivateRequest.builder().build();
        
        when(cooldownService.isOnCooldown(userId)).thenReturn(true);
        when(cooldownService.getRemainingSeconds(userId)).thenReturn(120L);
        
        // When & Then
        SOSCooldownException exception = assertThrows(
            SOSCooldownException.class,
            () -> sosHandler.activate(userId, request)
        );
        
        assertThat(exception.getRetryAfterSeconds()).isEqualTo(120);
        assertThat(exception.isBypassAllowed()).isTrue();
    }
```

#### TC-HANDLER-004: Activate SOS - No Emergency Contacts

```java
    @Test
    @DisplayName("TC-HANDLER-004: Kích hoạt SOS không có người thân → 400")
    void activate_WithNoContacts_Returns400() {
        // Given
        String userId = "test-user-001";
        SOSActivateRequest request = SOSActivateRequest.builder().build();
        
        when(cooldownService.isOnCooldown(userId)).thenReturn(false);
        when(contactClient.countActiveContacts(userId)).thenReturn(0);
        
        // When & Then
        SOSContactsRequiredException exception = assertThrows(
            SOSContactsRequiredException.class,
            () -> sosHandler.activate(userId, request)
        );
        
        assertThat(exception.getErrorCode()).isEqualTo("CONTACTS_REQUIRED");
    }
```

#### TC-HANDLER-005: Bypass Cooldown - True Emergency

```java
    @Test
    @DisplayName("TC-HANDLER-005: Bypass cooldown thành công")
    void activateBypass_WithTrueEmergency_IgnoresCooldown() {
        // Given - BR-SOS-019 exception
        String userId = "test-user-001";
        SOSBypassRequest request = SOSBypassRequest.builder()
            .bypassReason("TRUE_EMERGENCY")
            .build();
        
        // Không check cooldown
        when(contactClient.countActiveContacts(userId)).thenReturn(2);
        when(sosService.createEventWithBypass(any())).thenReturn(mockEventBypassed());
        
        // When
        SOSActivateResponse response = sosHandler.activateBypass(userId, request);
        
        // Then
        assertThat(response.isSuccess()).isTrue();
        verify(cooldownService, never()).isOnCooldown(anyString());
    }
```

#### TC-HANDLER-006: Cancel SOS - Happy Path

```java
    @Test
    @DisplayName("TC-HANDLER-006: Hủy SOS thành công trong countdown")
    void cancel_DuringCountdown_ReturnsCancelled() {
        // Given - BR-SOS-005
        String userId = "test-user-001";
        String eventId = "test-event-001";
        SOSCancelRequest request = SOSCancelRequest.builder()
            .eventId(eventId)
            .cancellationReason("Ấn nhầm")
            .build();
        
        SOSEvent event = mockEventPending();
        when(sosService.findEventById(eventId)).thenReturn(Optional.of(event));
        when(sosService.cancelEvent(any())).thenReturn(mockEventCancelled());
        
        // When
        SOSCancelResponse response = sosHandler.cancel(userId, request);
        
        // Then
        assertThat(response.getData().getStatus()).isEqualTo("CANCELLED");
        verify(kafkaProducer).send(eq("sos.cancelled"), any());
        verify(cooldownService, never()).setCooldown(anyString()); // BR-SOS-005: Không set cooldown
    }
```

#### TC-HANDLER-007: Cancel SOS - Already Completed

```java
    @Test
    @DisplayName("TC-HANDLER-007: Hủy SOS đã hoàn thành → 409")
    void cancel_WhenAlreadyCompleted_Returns409() {
        // Given
        String eventId = "test-event-001";
        SOSEvent event = mockEventCompleted();
        
        when(sosService.findEventById(eventId)).thenReturn(Optional.of(event));
        
        // When & Then
        SOSAlreadyCompletedException exception = assertThrows(
            SOSAlreadyCompletedException.class,
            () -> sosHandler.cancel("user", new SOSCancelRequest(eventId, null))
        );
        
        assertThat(exception.getErrorCode()).isEqualTo("EVENT_ALREADY_COMPLETED");
    }
```

#### TC-HANDLER-008: Cancel SOS - Not Found

```java
    @Test
    @DisplayName("TC-HANDLER-008: Hủy SOS không tồn tại → 404")
    void cancel_WhenEventNotFound_Returns404() {
        // Given
        String eventId = "non-existent-event";
        when(sosService.findEventById(eventId)).thenReturn(Optional.empty());
        
        // When & Then
        SOSEventNotFoundException exception = assertThrows(
            SOSEventNotFoundException.class,
            () -> sosHandler.cancel("user", new SOSCancelRequest(eventId, null))
        );
    }
```

#### TC-HANDLER-009: Get SOS Status - Pending

```java
    @Test
    @DisplayName("TC-HANDLER-009: Lấy trạng thái SOS đang countdown")
    void getStatus_WhenPending_ReturnsRemainingSeconds() {
        // Given - BR-SOS-020
        String eventId = "test-event-001";
        SOSEvent event = mockEventPending();
        event.setCountdownStartedAt(Instant.now().minusSeconds(15));
        
        when(sosService.findEventById(eventId)).thenReturn(Optional.of(event));
        
        // When
        SOSStatusResponse response = sosHandler.getStatus(eventId);
        
        // Then
        assertThat(response.getData().getStatus()).isEqualTo("PENDING");
        assertThat(response.getData().getCountdownRemainingSeconds()).isBetween(14, 16);
    }
```

---

## 1.2 CooldownService Tests

### Class: `CooldownServiceTest`

```java
@DisplayName("CooldownService Tests")
class CooldownServiceTest {
    
    @Mock private RedisTemplate<String, String> redisTemplate;
    @Mock private ValueOperations<String, String> valueOps;
    @InjectMocks private CooldownService cooldownService;
```

#### TC-COOL-001: Check Cooldown - Active

```java
    @Test
    @DisplayName("TC-COOL-001: Kiểm tra cooldown đang active")
    void isOnCooldown_WhenKeyExists_ReturnsTrue() {
        // Given
        String userId = "test-user-001";
        when(redisTemplate.hasKey("sos:cooldown:" + userId)).thenReturn(true);
        
        // When
        boolean result = cooldownService.isOnCooldown(userId);
        
        // Then
        assertThat(result).isTrue();
    }
```

#### TC-COOL-002: Check Cooldown - Not Active

```java
    @Test
    @DisplayName("TC-COOL-002: Kiểm tra cooldown không active")
    void isOnCooldown_WhenKeyNotExists_ReturnsFalse() {
        // Given
        String userId = "test-user-001";
        when(redisTemplate.hasKey("sos:cooldown:" + userId)).thenReturn(false);
        
        // When
        boolean result = cooldownService.isOnCooldown(userId);
        
        // Then
        assertThat(result).isFalse();
    }
```

#### TC-COOL-003: Set Cooldown - 5 Minutes

```java
    @Test
    @DisplayName("TC-COOL-003: Set cooldown 5 phút")
    void setCooldown_WithUserId_Sets5MinuteExpiry() {
        // Given - BR-SOS-019
        String userId = "test-user-001";
        when(redisTemplate.opsForValue()).thenReturn(valueOps);
        
        // When
        cooldownService.setCooldown(userId);
        
        // Then
        verify(valueOps).set(
            eq("sos:cooldown:" + userId),
            any(),
            eq(Duration.ofMinutes(5))
        );
    }
```

#### TC-COOL-004: Get Remaining Seconds

```java
    @Test
    @DisplayName("TC-COOL-004: Lấy số giây còn lại của cooldown")
    void getRemainingSeconds_WhenActive_ReturnsSeconds() {
        // Given
        String userId = "test-user-001";
        when(redisTemplate.getExpire("sos:cooldown:" + userId, TimeUnit.SECONDS))
            .thenReturn(120L);
        
        // When
        long remaining = cooldownService.getRemainingSeconds(userId);
        
        // Then
        assertThat(remaining).isEqualTo(120);
    }
```

---

## 1.3 EmergencyContactHandler Tests

### Class: `EmergencyContactHandlerTest`

```java
@DisplayName("EmergencyContactHandler Tests")
class EmergencyContactHandlerTest {
    
    @Mock private EmergencyContactClient contactClient;
    @InjectMocks private EmergencyContactHandler handler;
```

#### TC-CONTACT-001: List Contacts - Has Contacts

```java
    @Test
    @DisplayName("TC-CONTACT-001: Lấy danh sách người thân")
    void listContacts_WithContacts_ReturnsList() {
        // Given
        String userId = "test-user-001";
        List<EmergencyContact> contacts = List.of(
            mockContact("Người thân 1", "0912345678", 1),
            mockContact("Người thân 2", "0923456789", 2)
        );
        
        when(contactClient.listContacts(userId)).thenReturn(contacts);
        
        // When
        ContactListResponse response = handler.listContacts(userId);
        
        // Then
        assertThat(response.getData().getContacts()).hasSize(2);
        assertThat(response.getData().getCount()).isEqualTo(2);
        assertThat(response.getData().getMaxContacts()).isEqualTo(5);
    }
```

#### TC-CONTACT-002: List Contacts - Empty

```java
    @Test
    @DisplayName("TC-CONTACT-002: Lấy danh sách người thân - rỗng")
    void listContacts_WhenEmpty_ReturnsEmptyList() {
        // Given
        String userId = "test-user-001";
        when(contactClient.listContacts(userId)).thenReturn(List.of());
        
        // When
        ContactListResponse response = handler.listContacts(userId);
        
        // Then
        assertThat(response.getData().getContacts()).isEmpty();
        assertThat(response.getData().getCount()).isEqualTo(0);
    }
```

#### TC-CONTACT-003: Add Contact - Success

```java
    @Test
    @DisplayName("TC-CONTACT-003: Thêm người thân thành công")
    void addContact_WithValidPhone_CreatesContact() {
        // Given
        String userId = "test-user-001";
        AddContactRequest request = AddContactRequest.builder()
            .name("Lê Văn C")
            .phone("0923456789")
            .relationship("Cháu")
            .priority(3)
            .build();
        
        when(contactClient.countActiveContacts(userId)).thenReturn(2); // < 5
        when(contactClient.addContact(any())).thenReturn(mockContact("Lê Văn C", "0923456789", 3));
        
        // When
        AddContactResponse response = handler.addContact(userId, request);
        
        // Then
        assertThat(response.getData().getContactId()).isNotNull();
        assertThat(response.getData().getName()).isEqualTo("Lê Văn C");
    }
```

#### TC-CONTACT-004: Add Contact - Max Reached

```java
    @Test
    @DisplayName("TC-CONTACT-004: Thêm người thân khi đã đủ 5 → 400")
    void addContact_WhenMaxReached_Returns400() {
        // Given
        String userId = "test-user-001";
        when(contactClient.countActiveContacts(userId)).thenReturn(5);
        
        // When & Then
        MaxContactsReachedException exception = assertThrows(
            MaxContactsReachedException.class,
            () -> handler.addContact(userId, new AddContactRequest())
        );
        
        assertThat(exception.getErrorCode()).isEqualTo("MAX_CONTACTS_REACHED");
    }
```

#### TC-CONTACT-005: Add Contact - Invalid Phone Format

```java
    @Test
    @DisplayName("TC-CONTACT-005: Thêm người thân với số điện thoại không hợp lệ → 400")
    void addContact_WithInvalidPhone_Returns400() {
        // Given
        AddContactRequest request = AddContactRequest.builder()
            .name("Test")
            .phone("123")  // Invalid
            .build();
        
        // When & Then
        InvalidPhoneFormatException exception = assertThrows(
            InvalidPhoneFormatException.class,
            () -> handler.addContact("user", request)
        );
        
        assertThat(exception.getErrorCode()).isEqualTo("INVALID_PHONE_FORMAT");
    }
```

#### TC-CONTACT-006: Add Contact - Duplicate Phone

```java
    @Test
    @DisplayName("TC-CONTACT-006: Thêm người thân với số điện thoại đã tồn tại → 400")
    void addContact_WithDuplicatePhone_Returns400() {
        // Given
        String userId = "test-user-001";
        AddContactRequest request = AddContactRequest.builder()
            .name("Test")
            .phone("0912345678")  // Already exists
            .build();
        
        when(contactClient.countActiveContacts(userId)).thenReturn(2);
        when(contactClient.addContact(any()))
            .thenThrow(new DuplicatePhoneException("0912345678"));
        
        // When & Then
        DuplicatePhoneException exception = assertThrows(
            DuplicatePhoneException.class,
            () -> handler.addContact(userId, request)
        );
        
        assertThat(exception.getErrorCode()).isEqualTo("DUPLICATE_PHONE");
    }
```

#### TC-CONTACT-007: Update Contact - Success

```java
    @Test
    @DisplayName("TC-CONTACT-007: Cập nhật người thân thành công")
    void updateContact_WithValidData_UpdatesContact() {
        // Given
        String contactId = "contact-001";
        UpdateContactRequest request = UpdateContactRequest.builder()
            .name("Tên mới")
            .priority(2)
            .build();
        
        when(contactClient.updateContact(any())).thenReturn(mockUpdatedContact());
        
        // When
        UpdateContactResponse response = handler.updateContact("user", contactId, request);
        
        // Then
        assertThat(response.getData().getName()).isEqualTo("Tên mới");
        assertThat(response.getData().getPriority()).isEqualTo(2);
    }
```

#### TC-CONTACT-008: Delete Contact - Success

```java
    @Test
    @DisplayName("TC-CONTACT-008: Xóa người thân thành công")
    void deleteContact_WithValidId_DeletesContact() {
        // Given
        String contactId = "contact-001";
        doNothing().when(contactClient).deleteContact(contactId);
        
        // When
        DeleteContactResponse response = handler.deleteContact("user", contactId);
        
        // Then
        assertThat(response.isSuccess()).isTrue();
        verify(contactClient).deleteContact(contactId);
    }
```

---

## 1.4 PhoneValidator Tests

### Class: `PhoneValidatorTest`

```java
@DisplayName("PhoneValidator Tests - VN Phone Format")
class PhoneValidatorTest {
```

#### TC-PHONE-001 to TC-PHONE-008: Phone Validation

```java
    @ParameterizedTest
    @DisplayName("TC-PHONE: Valid VN phone numbers")
    @ValueSource(strings = {
        "0901234567",   // 10 digits - 09x
        "0812345678",   // 10 digits - 08x
        "0712345678",   // 10 digits - 07x
        "0312345678",   // 10 digits - 03x
        "0512345678",   // 10 digits - 05x
        "02812345678",  // 11 digits - landline
    })
    void isValid_WithValidVNPhone_ReturnsTrue(String phone) {
        assertThat(PhoneValidator.isValid(phone)).isTrue();
    }
    
    @ParameterizedTest
    @DisplayName("TC-PHONE: Invalid phone numbers")
    @ValueSource(strings = {
        "123",           // Too short
        "901234567",     // Missing leading 0
        "09012345678",   // Too long (11 digits for mobile)
        "abc",           // Non-numeric
        "",              // Empty
    })
    void isValid_WithInvalidPhone_ReturnsFalse(String phone) {
        assertThat(PhoneValidator.isValid(phone)).isFalse();
    }
```

---

## 1.5 FirstAidHandler Tests

### Class: `FirstAidHandlerTest`

```java
@DisplayName("FirstAidHandler Tests")
class FirstAidHandlerTest {
```

#### TC-FIRSTAID-001: Get Content - All Categories

```java
    @Test
    @DisplayName("TC-FIRSTAID-001: Lấy tất cả nội dung sơ cứu")
    void getContent_WithoutFilter_ReturnsAllCategories() {
        // Given - BR-SOS-013
        List<FirstAidContent> contents = List.of(
            mockContent("cpr", "Hồi sinh tim phổi", 1),
            mockContent("stroke", "Đột quỵ", 2),
            mockContent("low_sugar", "Hạ đường huyết", 3),
            mockContent("fall", "Té ngã", 4)
        );
        
        when(firstAidRepository.findAllActive()).thenReturn(contents);
        
        // When
        FirstAidResponse response = handler.getContent(null, null);
        
        // Then
        assertThat(response.getData().getCategories()).hasSize(4);
        assertThat(response.getData().getDisclaimer()).contains("THÔNG TIN CHỈ MANG TÍNH THAM KHẢO");
    }
```

#### TC-FIRSTAID-002: Get Content - With Disclaimer

```java
    @Test
    @DisplayName("TC-FIRSTAID-002: Nội dung sơ cứu có disclaimer bắt buộc")
    void getContent_Always_IncludesDisclaimer() {
        // Given - BR-SOS-014
        when(firstAidRepository.findAllActive()).thenReturn(List.of(mockContent("cpr", "CPR", 1)));
        
        // When
        FirstAidResponse response = handler.getContent(null, null);
        
        // Then
        assertThat(response.getData().getDisclaimer())
            .isNotEmpty()
            .contains("THÔNG TIN CHỈ MANG TÍNH THAM KHẢO")
            .contains("115");
    }
```

---

# 2. user-service Tests

## Framework: JUnit 5 + Mockito + Testcontainers

---

## 2.1 EmergencyContactRepository Tests

### Class: `EmergencyContactRepositoryTest`

```java
@Testcontainers
@DataJpaTest
@DisplayName("EmergencyContactRepository Tests")
class EmergencyContactRepositoryTest {
    
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15");
    
    @Autowired
    private EmergencyContactRepository repository;
```

#### TC-DB-001: Find By User ID

```java
    @Test
    @DisplayName("TC-DB-001: Tìm contacts theo user ID và priority")
    void findByUserId_WithContacts_ReturnsSortedByPriority() {
        // Given
        UUID userId = UUID.randomUUID();
        createContact(userId, "C1", "0912345678", 2);
        createContact(userId, "C2", "0923456789", 1);
        createContact(userId, "C3", "0934567890", 3);
        
        // When
        List<EmergencyContact> contacts = repository.findByUserIdOrderByPriority(userId);
        
        // Then
        assertThat(contacts).hasSize(3);
        assertThat(contacts.get(0).getPriority()).isEqualTo(1);
        assertThat(contacts.get(1).getPriority()).isEqualTo(2);
        assertThat(contacts.get(2).getPriority()).isEqualTo(3);
    }
```

#### TC-DB-002: Count Active Contacts

```java
    @Test
    @DisplayName("TC-DB-002: Đếm số contacts active")
    void countActiveByUserId_WithMixedStatus_ReturnsActiveCount() {
        // Given
        UUID userId = UUID.randomUUID();
        createContact(userId, "C1", "0912345678", 1, true);
        createContact(userId, "C2", "0923456789", 2, false);  // inactive
        createContact(userId, "C3", "0934567890", 3, true);
        
        // When
        int count = repository.countActiveByUserId(userId);
        
        // Then
        assertThat(count).isEqualTo(2);
    }
```

#### TC-DB-003: Unique Phone Constraint

```java
    @Test
    @DisplayName("TC-DB-003: Không cho phép duplicate phone trong cùng user")
    void save_WithDuplicatePhone_ThrowsException() {
        // Given
        UUID userId = UUID.randomUUID();
        createContact(userId, "C1", "0912345678", 1);
        
        EmergencyContact duplicate = EmergencyContact.builder()
            .userId(userId)
            .name("C2")
            .phone("0912345678")  // Duplicate
            .priority(2)
            .build();
        
        // When & Then
        assertThrows(
            DataIntegrityViolationException.class,
            () -> repository.saveAndFlush(duplicate)
        );
    }
```

#### TC-DB-004: Priority Range Constraint

```java
    @Test
    @DisplayName("TC-DB-004: Priority phải trong khoảng 1-5")
    void save_WithInvalidPriority_ThrowsException() {
        // Given
        EmergencyContact contact = EmergencyContact.builder()
            .userId(UUID.randomUUID())
            .name("Test")
            .phone("0912345678")
            .priority(6)  // Invalid > 5
            .build();
        
        // When & Then
        assertThrows(
            ConstraintViolationException.class,
            () -> repository.saveAndFlush(contact)
        );
    }
```

---

## 2.2 EmergencyContactService Tests

### Class: `EmergencyContactServiceTest`

```java
@DisplayName("EmergencyContactService Tests")
class EmergencyContactServiceTest {
    
    @Mock private EmergencyContactRepository repository;
    @InjectMocks private EmergencyContactService service;
```

#### TC-SVC-001: Create Contact With Priority Reorder

```java
    @Test
    @DisplayName("TC-SVC-001: Thêm contact và reorder priority")
    void createContact_WithExistingPriority_ReordersPriorities() {
        // Given
        UUID userId = UUID.randomUUID();
        List<EmergencyContact> existing = List.of(
            mockContact(1), mockContact(2), mockContact(3)
        );
        
        CreateContactCommand command = CreateContactCommand.builder()
            .userId(userId)
            .name("New")
            .phone("0999999999")
            .priority(2)  // Insert at position 2
            .build();
        
        when(repository.findByUserIdOrderByPriority(userId)).thenReturn(new ArrayList<>(existing));
        
        // When
        service.createContact(command);
        
        // Then
        // Verify that contacts 2, 3 are shifted to 3, 4
        verify(repository).saveAll(argThat(contacts -> {
            List<EmergencyContact> list = StreamSupport.stream(contacts.spliterator(), false)
                .collect(Collectors.toList());
            return list.stream().anyMatch(c -> c.getPriority() == 3);
        }));
    }
```

---

# 3. schedule-service Tests

## Framework: pytest + unittest.mock

---

## 3.1 SOS Alert Task Tests

### File: `test_sos_tasks.py`

```python
"""
SOS Celery Task Tests
Framework: pytest
"""

import pytest
from unittest.mock import Mock, patch, AsyncMock
from datetime import datetime, timedelta
from uuid import uuid4

from sos.tasks import send_sos_alerts, execute_escalation, retry_failed_zns
from sos.models import SOSEvent, SOSNotification, NotificationStatus


class TestSendSOSAlerts:
    """Unit tests for send_sos_alerts Celery task"""
```

#### TC-TASK-001: Send Alerts - All Contacts

```python
    @patch('sos.tasks.zns_client')
    @patch('sos.tasks.cskh_client')
    def test_send_sos_alerts_sends_to_all_contacts(
        self, mock_cskh, mock_zns
    ):
        """
        TC-TASK-001: Gửi ZNS đến TẤT CẢ người thân đồng thời
        BR-SOS-003: ZNS gửi đồng thời đến TẤT CẢ người thân
        """
        # Given
        event_id = str(uuid4())
        contacts = [
            {'name': 'Contact 1', 'phone': '0912345678'},
            {'name': 'Contact 2', 'phone': '0923456789'},
            {'name': 'Contact 3', 'phone': '0934567890'},
        ]
        
        mock_zns.send_template.return_value = {'success': True, 'message_id': 'msg-001'}
        mock_cskh.send_alert.return_value = {'success': True}
        
        # When
        result = send_sos_alerts.apply(args=[event_id, contacts])
        
        # Then
        assert result.successful()
        assert mock_zns.send_template.call_count == 3  # All contacts
        assert mock_cskh.send_alert.call_count == 1    # CSKH alert once
```

#### TC-TASK-002: Send Alerts - With CSKH Alert

```python
    @patch('sos.tasks.zns_client')
    @patch('sos.tasks.cskh_client')
    def test_send_sos_alerts_sends_cskh_alert(self, mock_cskh, mock_zns):
        """
        TC-TASK-002: Gửi alert đến CSKH qua API
        BR-SOS-004: Gửi alert đến CSKH qua API
        """
        # Given
        event_id = str(uuid4())
        user_data = {'name': 'Nguyễn Văn A', 'phone': '0901234567'}
        location = {'lat': 10.762622, 'lng': 106.660172}
        
        # When
        result = send_sos_alerts.apply(args=[event_id, [], user_data, location])
        
        # Then
        mock_cskh.send_alert.assert_called_once()
        call_args = mock_cskh.send_alert.call_args
        assert call_args.kwargs['event_id'] == event_id
        assert call_args.kwargs['user_name'] == 'Nguyễn Văn A'
```

#### TC-TASK-003: ZNS Retry - 3 Times

```python
    @patch('sos.tasks.zns_client')
    @patch('sos.tasks.db_session')
    def test_retry_failed_zns_retries_3_times(self, mock_db, mock_zns):
        """
        TC-TASK-003: ZNS fail → Retry 3 lần
        BR-SOS-021: ZNS fail: Retry 3 lần → Alert CSKH
        """
        # Given
        notification = SOSNotification(
            notification_id=uuid4(),
            status=NotificationStatus.RETRY_PENDING,
            retry_count=2,  # Already retried 2 times
        )
        mock_db.query.return_value.filter.return_value.all.return_value = [notification]
        mock_zns.send_template.side_effect = ZNSException("Rate limit")
        
        # When
        with pytest.raises(MaxRetryExceeded):
            retry_failed_zns.apply()
        
        # Then
        assert notification.retry_count == 3
        assert notification.status == NotificationStatus.FAILED
```

---

## 3.2 Escalation Task Tests

### Class: `TestExecuteEscalation`

```python
class TestExecuteEscalation:
    """Unit tests for execute_escalation Celery task"""
```

#### TC-ESC-001: Escalation - First Contact

```python
    @patch('sos.tasks.push_notification_client')
    def test_escalation_starts_with_first_contact(self, mock_push):
        """
        TC-ESC-001: Escalation bắt đầu với người thân #1
        BR-SOS-007: Escalation timeout: 20 giây per contact
        """
        # Given
        event_id = str(uuid4())
        contacts = [
            {'id': 'c1', 'phone': '0912345678', 'priority': 1},
            {'id': 'c2', 'phone': '0923456789', 'priority': 2},
        ]
        
        # When
        result = execute_escalation.apply(args=[event_id, contacts])
        
        # Then
        mock_push.send_call_notification.assert_called_once()
        call_args = mock_push.send_call_notification.call_args
        assert call_args.kwargs['contact_id'] == 'c1'
        assert call_args.kwargs['timeout_seconds'] == 20
```

#### TC-ESC-002: Escalation - All Failed → CSKH

```python
    @patch('sos.tasks.push_notification_client')
    @patch('sos.tasks.cskh_client')
    def test_escalation_all_failed_alerts_cskh(self, mock_cskh, mock_push):
        """
        TC-ESC-002: Tất cả 5 người thân không trả lời → Alert CSKH
        BR-SOS-008: Sau 5 người thân → CSKH → Prompt 115
        """
        # Given
        event_id = str(uuid4())
        contacts = [
            {'id': f'c{i}', 'phone': f'091234567{i}', 'priority': i}
            for i in range(1, 6)
        ]
        
        # All contacts fail
        mock_push.send_call_notification.return_value = {'answered': False}
        
        # When
        result = execute_escalation.apply(args=[event_id, contacts])
        
        # Then
        assert mock_push.send_call_notification.call_count == 5
        mock_cskh.send_escalation_alert.assert_called_once()
```

#### TC-ESC-003: Escalation - Connected Stops

```python
    @patch('sos.tasks.push_notification_client')
    def test_escalation_stops_when_connected(self, mock_push):
        """
        TC-ESC-003: Call Connected → Dừng escalation ngay lập tức
        BR-SOS-009: Call Connected → Dừng escalation
        """
        # Given
        event_id = str(uuid4())
        contacts = [
            {'id': 'c1', 'priority': 1},
            {'id': 'c2', 'priority': 2},
            {'id': 'c3', 'priority': 3},
        ]
        
        # Second contact answers
        mock_push.send_call_notification.side_effect = [
            {'answered': False},  # c1 doesn't answer
            {'answered': True},   # c2 answers
        ]
        
        # When
        result = execute_escalation.apply(args=[event_id, contacts])
        
        # Then
        assert mock_push.send_call_notification.call_count == 2
        # c3 should not be called
```

#### TC-ESC-004: Escalation - During 115 Call

```python
    @patch('sos.tasks.push_notification_client')
    def test_escalation_pauses_during_115_call(self, mock_push):
        """
        TC-ESC-004: Không auto-call nếu user đang gọi 115
        BR-SOS-010: Không auto-call nếu user đang gọi 115
        """
        # Given
        event_id = str(uuid4())
        is_calling_115 = True
        
        # When
        result = execute_escalation.apply(
            args=[event_id, [], is_calling_115]
        )
        
        # Then
        mock_push.send_call_notification.assert_not_called()
        # Should only send ZNS, not auto-call
```

---

## 3.3 Offline Queue Task Tests

### Class: `TestProcessOfflineQueue`

```python
class TestProcessOfflineQueue:
    """Unit tests for process_offline_queue Celery task"""
```

#### TC-OFF-001: Process Offline Queue - Retry 3 Times

```python
    @patch('sos.tasks.zns_client')
    @patch('sos.tasks.db_session')
    def test_offline_queue_retries_3_times(self, mock_db, mock_zns):
        """
        TC-OFF-001: Offline queue auto-retry khi có mạng
        BR-SOS-015: Offline: Queue + Auto-retry khi có mạng (Max 3 lần, 30s interval)
        """
        # Given
        queued_event = SOSEvent(
            event_id=uuid4(),
            is_offline_triggered=True,
            offline_queue_timestamp=datetime.utcnow() - timedelta(minutes=5),
        )
        
        mock_db.query.return_value.filter.return_value.all.return_value = [queued_event]
        mock_zns.send_template.side_effect = [
            ZNSException("Network error"),  # Retry 1
            ZNSException("Network error"),  # Retry 2
            {'success': True},               # Success on retry 3
        ]
        
        # When
        result = process_offline_queue.apply()
        
        # Then
        assert mock_zns.send_template.call_count == 3
        assert queued_event.sync_completed_at is not None
```

---

## 3.4 ZNS Client Tests

### Class: `TestZNSClient`

```python
class TestZNSClient:
    """Unit tests for ZNS API client"""
```

#### TC-ZNS-001: Send Template - Success

```python
    @responses.activate
    def test_send_template_success(self):
        """TC-ZNS-001: Gửi ZNS template thành công"""
        # Given
        responses.add(
            responses.POST,
            'https://zns.api.zalo.me/v2/send-template',
            json={'error': 0, 'message': 'Success', 'data': {'msg_id': 'zns-001'}},
            status=200
        )
        
        client = ZNSClient()
        
        # When
        result = client.send_template(
            phone='0912345678',
            template_id='TEMPLATE_1',
            template_data={'name': 'Test', 'time': '10:00'}
        )
        
        # Then
        assert result['success'] is True
        assert result['message_id'] == 'zns-001'
```

#### TC-ZNS-002: Send Template - Rate Limit Retry

```python
    @responses.activate
    def test_send_template_rate_limit_retry(self):
        """TC-ZNS-002: ZNS rate limit → retry với backoff"""
        # Given
        responses.add(
            responses.POST,
            'https://zns.api.zalo.me/v2/send-template',
            json={'error': 429, 'message': 'Rate limit exceeded'},
            status=429
        )
        responses.add(
            responses.POST,
            'https://zns.api.zalo.me/v2/send-template',
            json={'error': 0, 'message': 'Success'},
            status=200
        )
        
        client = ZNSClient(max_retries=2, retry_delay=0.1)
        
        # When
        result = client.send_template(phone='0912345678', template_id='T1')
        
        # Then
        assert len(responses.calls) == 2
        assert result['success'] is True
```

---

## Test Summary

| Service | Test Class | Test Cases | Priority |
|---------|------------|:----------:|:--------:|
| api-gateway | SOSHandlerTest | 9 | 🔴 Critical |
| api-gateway | CooldownServiceTest | 4 | 🔴 Critical |
| api-gateway | EmergencyContactHandlerTest | 8 | 🔴 Critical |
| api-gateway | PhoneValidatorTest | 8 | 🟡 High |
| api-gateway | FirstAidHandlerTest | 2 | 🟡 High |
| user-service | EmergencyContactRepositoryTest | 4 | 🔴 Critical |
| user-service | EmergencyContactServiceTest | 1 | 🔴 Critical |
| schedule-service | TestSendSOSAlerts | 3 | 🔴 Critical |
| schedule-service | TestExecuteEscalation | 4 | 🔴 Critical |
| schedule-service | TestProcessOfflineQueue | 1 | 🟡 High |
| schedule-service | TestZNSClient | 2 | 🔴 Critical |
| **TOTAL** | - | **46** | - |

---

**Report Version:** 1.0  
**Generated:** 2026-01-26T11:25:00+07:00  
**Workflow:** `/alio-testing`
