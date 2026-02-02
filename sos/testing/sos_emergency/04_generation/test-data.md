# 📦 Test Data & Fixtures - SOS Emergency Feature

## Document Information

| Attribute | Value |
|-----------|-------|
| **Version** | 1.0 |
| **Date** | 2026-01-26 |
| **Author** | Test Generator (Automated via /alio-testing) |

---

## Table of Contents

1. [Test Fixtures Overview](#1-test-fixtures-overview)
2. [Java Test Fixtures](#2-java-test-fixtures)
3. [Python Test Fixtures](#3-python-test-fixtures)
4. [Database Seed Data](#4-database-seed-data)
5. [Mock Server Responses](#5-mock-server-responses)

---

# 1. Test Fixtures Overview

## 1.1 Data Categories

| Category | Purpose | Format |
|----------|---------|--------|
| **Users** | Test user accounts | Factory pattern |
| **Emergency Contacts** | SOS contact list | Pre-defined fixtures |
| **SOS Events** | Event lifecycle states | Builder pattern |
| **Notifications** | ZNS/SMS notification data | Template-based |
| **First Aid** | CMS content | SQL seed |
| **API Responses** | Mock external APIs | JSON stubs |

## 1.2 Fixture Naming Convention

```
test-{entity}-{state}-{number}
```

Examples:
- `test-user-001` - Standard test user
- `test-event-pending-001` - SOS event in PENDING state
- `test-contact-active-001` - Active emergency contact

---

# 2. Java Test Fixtures

## 2.1 TestFixtures.java

```java
package com.alio.gateway.test.fixtures;

import java.time.Instant;
import java.util.UUID;

/**
 * Centralized test fixtures for SOS Emergency feature tests.
 */
public class TestFixtures {

    // =========================================================================
    // USER FIXTURES
    // =========================================================================
    
    public static final String TEST_USER_ID = "test-user-001";
    public static final String TEST_USER_NAME = "Nguyễn Văn Test";
    public static final String TEST_USER_PHONE = "0901234567";
    
    public static User mockUser() {
        return User.builder()
            .userId(UUID.fromString(TEST_USER_ID))
            .name(TEST_USER_NAME)
            .phone(TEST_USER_PHONE)
            .isActive(true)
            .createdAt(Instant.now().minusDays(30))
            .build();
    }

    // =========================================================================
    // EMERGENCY CONTACT FIXTURES
    // =========================================================================
    
    public static EmergencyContact mockContact(String name, String phone, int priority) {
        return EmergencyContact.builder()
            .contactId(UUID.randomUUID())
            .userId(UUID.fromString(TEST_USER_ID))
            .name(name)
            .phone(phone)
            .relationship("Người thân")
            .priority(priority)
            .isActive(true)
            .zaloEnabled(false)
            .createdAt(Instant.now())
            .build();
    }
    
    public static EmergencyContact mockContactWithZalo(String name, String phone, int priority) {
        return EmergencyContact.builder()
            .contactId(UUID.randomUUID())
            .userId(UUID.fromString(TEST_USER_ID))
            .name(name)
            .phone(phone)
            .relationship("Người thân")
            .priority(priority)
            .isActive(true)
            .zaloEnabled(true)
            .createdAt(Instant.now())
            .build();
    }
    
    public static List<EmergencyContact> mockContactList() {
        return List.of(
            mockContact("Nguyễn Văn A", "0912345678", 1),
            mockContact("Trần Thị B", "0923456789", 2),
            mockContact("Lê Văn C", "0934567890", 3)
        );
    }
    
    public static List<EmergencyContact> mockMaxContacts() {
        return IntStream.rangeClosed(1, 5)
            .mapToObj(i -> mockContact("Contact " + i, "091234567" + i, i))
            .collect(Collectors.toList());
    }

    // =========================================================================
    // SOS EVENT FIXTURES
    // =========================================================================
    
    public static final String TEST_EVENT_ID = "550e8400-e29b-41d4-a716-446655440000";
    
    public static SOSEvent mockSOSEvent() {
        return SOSEvent.builder()
            .eventId(UUID.fromString(TEST_EVENT_ID))
            .userId(UUID.fromString(TEST_USER_ID))
            .triggeredAt(Instant.now())
            .triggerSource("manual")
            .latitude(10.762622)
            .longitude(106.660172)
            .locationAccuracyM(15.5)
            .locationSource("gps")
            .countdownSeconds((short) 30)
            .countdownStartedAt(Instant.now())
            .status((short) 0) // PENDING
            .isOfflineTriggered(false)
            .cooldownBypassed(false)
            .batteryLevelPercent((short) 85)
            .build();
    }
    
    public static SOSEvent mockSOSEventWithCountdown(int seconds) {
        SOSEvent event = mockSOSEvent();
        event.setCountdownSeconds((short) seconds);
        return event;
    }
    
    public static SOSEvent mockSOSEventPending() {
        return mockSOSEvent(); // Status = 0 (PENDING)
    }
    
    public static SOSEvent mockSOSEventCompleted() {
        SOSEvent event = mockSOSEvent();
        event.setStatus((short) 1); // COMPLETED
        event.setCountdownCompletedAt(Instant.now());
        return event;
    }
    
    public static SOSEvent mockSOSEventCancelled() {
        SOSEvent event = mockSOSEvent();
        event.setStatus((short) 2); // CANCELLED
        event.setCancelledAt(Instant.now());
        event.setCancellationReason("Ấn nhầm");
        return event;
    }
    
    public static SOSEvent mockSOSEventFailed() {
        SOSEvent event = mockSOSEvent();
        event.setStatus((short) 3); // FAILED
        return event;
    }
    
    public static SOSEvent mockSOSEventBypassed() {
        SOSEvent event = mockSOSEvent();
        event.setCooldownBypassed(true);
        return event;
    }
    
    public static SOSEvent mockSOSEventLowBattery() {
        SOSEvent event = mockSOSEvent();
        event.setBatteryLevelPercent((short) 8);
        event.setCountdownSeconds((short) 10);
        return event;
    }
    
    public static SOSEvent mockSOSEventOffline() {
        SOSEvent event = mockSOSEvent();
        event.setIsOfflineTriggered(true);
        event.setOfflineQueueTimestamp(Instant.now().minusMinutes(5));
        return event;
    }

    // =========================================================================
    // NOTIFICATION FIXTURES
    // =========================================================================
    
    public static SOSNotification mockNotification(String contactPhone, int status) {
        return SOSNotification.builder()
            .notificationId(UUID.randomUUID())
            .eventId(UUID.fromString(TEST_EVENT_ID))
            .recipientName("Người thân")
            .recipientPhone(contactPhone)
            .recipientType("family")
            .channel("zns")
            .templateId("SOS_TEMPLATE_1")
            .status((short) status)
            .retryCount((short) 0)
            .build();
    }
    
    public static NotificationStats mockNotificationStats() {
        return new NotificationStats(5, 5, 3, 0, 2);
    }

    // =========================================================================
    // ESCALATION CALL FIXTURES
    // =========================================================================
    
    public static SOSEscalationCall mockEscalationCall(int order, int status) {
        return SOSEscalationCall.builder()
            .callId(UUID.randomUUID())
            .eventId(UUID.fromString(TEST_EVENT_ID))
            .contactName("Contact " + order)
            .contactPhone("091234567" + order)
            .escalationOrder((short) order)
            .callType("auto_call")
            .status((short) status)
            .initiatedAt(Instant.now())
            .timeoutSeconds((short) 20)
            .build();
    }

    // =========================================================================
    // FIRST AID CONTENT FIXTURES
    // =========================================================================
    
    public static FirstAidContent mockFirstAid(String category, String title, int order) {
        return FirstAidContent.builder()
            .contentId(UUID.randomUUID())
            .category(category)
            .title(title)
            .content("## " + title + "\n\nNội dung hướng dẫn...")
            .displayOrder((short) order)
            .iconName(category)
            .isActive(true)
            .version(1)
            .build();
    }
    
    public static List<FirstAidContent> mockAllFirstAidContent() {
        return List.of(
            mockFirstAid("cpr", "Hồi sinh tim phổi (CPR)", 1),
            mockFirstAid("stroke", "Đột quỵ (F.A.S.T)", 2),
            mockFirstAid("low_sugar", "Hạ đường huyết", 3),
            mockFirstAid("fall", "Té ngã", 4)
        );
    }
    
    public static final String FIRST_AID_DISCLAIMER = 
        "⚠️ THÔNG TIN CHỈ MANG TÍNH THAM KHẢO\n\n" +
        "Hướng dẫn sơ cứu này không thay thế sự chăm sóc y tế chuyên nghiệp.\n" +
        "Trong trường hợp khẩn cấp, hãy gọi 115 ngay lập tức.";

    // =========================================================================
    // REQUEST/RESPONSE FIXTURES
    // =========================================================================
    
    public static SOSActivateRequest mockActivateRequest() {
        return SOSActivateRequest.builder()
            .latitude(10.762622)
            .longitude(106.660172)
            .locationAccuracyM(15.5)
            .batteryLevelPercent(85)
            .isOfflineTriggered(false)
            .deviceInfo(Map.of(
                "platform", "ios",
                "os_version", "16.0",
                "app_version", "2.1.0"
            ))
            .build();
    }
    
    public static SOSActivateResponse mockActivateResponse() {
        return SOSActivateResponse.builder()
            .success(true)
            .data(SOSActivateResponseData.builder()
                .eventId(TEST_EVENT_ID)
                .countdownSeconds(30)
                .countdownStartedAt(Instant.now())
                .status("PENDING")
                .contactsCount(3)
                .build())
            .build();
    }
}
```

---

## 2.2 JwtTestHelper.java

```java
package com.alio.gateway.test.helpers;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;

/**
 * JWT token helper for test authentication.
 */
public class JwtTestHelper {

    private static final String TEST_SECRET = "test-secret-key-for-unit-tests-only";
    
    public static String generateToken(String userId) {
        return generateToken(userId, "PATIENT", 24);
    }
    
    public static String generateToken(String userId, String role, int hoursValid) {
        Instant now = Instant.now();
        
        return Jwts.builder()
            .setSubject(userId)
            .setIssuedAt(Date.from(now))
            .setExpiration(Date.from(now.plus(hoursValid, ChronoUnit.HOURS)))
            .setIssuer("alio-auth-service")
            .claim("roles", List.of(role))
            .signWith(SignatureAlgorithm.HS256, TEST_SECRET)
            .compact();
    }
    
    public static String generateExpiredToken(String userId) {
        Instant pastTime = Instant.now().minus(1, ChronoUnit.HOURS);
        
        return Jwts.builder()
            .setSubject(userId)
            .setIssuedAt(Date.from(pastTime.minus(2, ChronoUnit.HOURS)))
            .setExpiration(Date.from(pastTime))
            .setIssuer("alio-auth-service")
            .signWith(SignatureAlgorithm.HS256, TEST_SECRET)
            .compact();
    }
}
```

---

# 3. Python Test Fixtures

## 3.1 conftest.py

```python
"""
Pytest fixtures for SOS Emergency feature tests.
File: schedule-service/tests/sos/conftest.py
"""

import pytest
from datetime import datetime, timedelta
from uuid import uuid4
from unittest.mock import Mock, patch

from sos.models import (
    SOSEvent, SOSNotification, SOSEscalationCall,
    NotificationStatus, CallStatus, EventStatus
)


# =============================================================================
# USER FIXTURES
# =============================================================================

@pytest.fixture
def test_user_id():
    """Standard test user ID."""
    return "test-user-001"


@pytest.fixture
def test_user():
    """Standard test user data."""
    return {
        'user_id': 'test-user-001',
        'name': 'Nguyễn Văn Test',
        'phone': '0901234567',
    }


# =============================================================================
# EMERGENCY CONTACT FIXTURES
# =============================================================================

@pytest.fixture
def mock_contact():
    """Factory for creating mock contacts."""
    def _create_contact(name: str, phone: str, priority: int, zalo: bool = False):
        return {
            'contact_id': str(uuid4()),
            'name': name,
            'phone': phone,
            'relationship': 'Người thân',
            'priority': priority,
            'is_active': True,
            'zalo_enabled': zalo,
        }
    return _create_contact


@pytest.fixture
def mock_contact_list(mock_contact):
    """Standard list of 3 emergency contacts."""
    return [
        mock_contact('Nguyễn Văn A', '0912345678', 1),
        mock_contact('Trần Thị B', '0923456789', 2),
        mock_contact('Lê Văn C', '0934567890', 3),
    ]


@pytest.fixture
def mock_max_contacts(mock_contact):
    """Maximum 5 emergency contacts."""
    return [
        mock_contact(f'Contact {i}', f'091234567{i}', i)
        for i in range(1, 6)
    ]


# =============================================================================
# SOS EVENT FIXTURES
# =============================================================================

@pytest.fixture
def test_event_id():
    """Standard test event ID."""
    return "550e8400-e29b-41d4-a716-446655440000"


@pytest.fixture
def mock_sos_event(test_event_id, test_user_id):
    """Factory for creating mock SOS events."""
    def _create_event(
        status: EventStatus = EventStatus.PENDING,
        countdown_seconds: int = 30,
        battery_level: int = 85,
        is_offline: bool = False,
        cooldown_bypassed: bool = False,
    ) -> SOSEvent:
        event = SOSEvent(
            event_id=test_event_id,
            user_id=test_user_id,
            triggered_at=datetime.utcnow(),
            trigger_source='manual',
            latitude=10.762622,
            longitude=106.660172,
            location_accuracy_m=15.5,
            location_source='gps',
            countdown_seconds=countdown_seconds,
            countdown_started_at=datetime.utcnow(),
            status=status,
            is_offline_triggered=is_offline,
            cooldown_bypassed=cooldown_bypassed,
            battery_level_percent=battery_level,
        )
        return event
    return _create_event


@pytest.fixture
def mock_event_pending(mock_sos_event):
    """SOS event in PENDING state."""
    return mock_sos_event(status=EventStatus.PENDING)


@pytest.fixture
def mock_event_completed(mock_sos_event):
    """SOS event in COMPLETED state."""
    event = mock_sos_event(status=EventStatus.COMPLETED)
    event.countdown_completed_at = datetime.utcnow()
    return event


@pytest.fixture
def mock_event_cancelled(mock_sos_event):
    """SOS event in CANCELLED state."""
    event = mock_sos_event(status=EventStatus.CANCELLED)
    event.cancelled_at = datetime.utcnow()
    event.cancellation_reason = 'Ấn nhầm'
    return event


@pytest.fixture
def mock_event_low_battery(mock_sos_event):
    """SOS event with low battery (< 10%)."""
    return mock_sos_event(battery_level=8, countdown_seconds=10)


@pytest.fixture
def mock_event_offline(mock_sos_event):
    """SOS event triggered offline."""
    event = mock_sos_event(is_offline=True)
    event.offline_queue_timestamp = datetime.utcnow() - timedelta(minutes=5)
    return event


# =============================================================================
# NOTIFICATION FIXTURES
# =============================================================================

@pytest.fixture
def mock_notification(test_event_id):
    """Factory for creating mock notifications."""
    def _create_notification(
        phone: str,
        status: NotificationStatus = NotificationStatus.PENDING,
        channel: str = 'zns',
        retry_count: int = 0,
    ) -> SOSNotification:
        return SOSNotification(
            notification_id=str(uuid4()),
            event_id=test_event_id,
            recipient_name='Người thân',
            recipient_phone=phone,
            recipient_type='family',
            channel=channel,
            template_id='SOS_TEMPLATE_1',
            status=status,
            retry_count=retry_count,
        )
    return _create_notification


@pytest.fixture
def mock_notification_list(mock_notification):
    """List of notifications for all contacts."""
    return [
        mock_notification('0912345678', NotificationStatus.DELIVERED),
        mock_notification('0923456789', NotificationStatus.SENT),
        mock_notification('0934567890', NotificationStatus.PENDING),
    ]


# =============================================================================
# ESCALATION CALL FIXTURES
# =============================================================================

@pytest.fixture
def mock_escalation_call(test_event_id):
    """Factory for creating mock escalation calls."""
    def _create_call(
        order: int,
        status: CallStatus = CallStatus.PENDING,
    ) -> SOSEscalationCall:
        return SOSEscalationCall(
            call_id=str(uuid4()),
            event_id=test_event_id,
            contact_name=f'Contact {order}',
            contact_phone=f'091234567{order}',
            escalation_order=order,
            call_type='auto_call',
            status=status,
            initiated_at=datetime.utcnow(),
            timeout_seconds=20,
        )
    return _create_call


# =============================================================================
# EXTERNAL SERVICE MOCKS
# =============================================================================

@pytest.fixture
def mock_zns_client():
    """Mock ZNS client."""
    with patch('sos.clients.zns_client') as mock:
        mock.send_template.return_value = {
            'success': True,
            'message_id': 'zns-msg-001',
        }
        yield mock


@pytest.fixture
def mock_cskh_client():
    """Mock CSKH API client."""
    with patch('sos.clients.cskh_client') as mock:
        mock.send_alert.return_value = {
            'success': True,
            'ticket_id': 'ticket-001',
        }
        yield mock


@pytest.fixture
def mock_push_client():
    """Mock push notification client."""
    with patch('sos.clients.push_notification_client') as mock:
        mock.send_call_notification.return_value = {
            'answered': False,
        }
        yield mock


# =============================================================================
# DATABASE MOCKS
# =============================================================================

@pytest.fixture
def mock_db_session():
    """Mock database session."""
    with patch('sos.db.session') as mock:
        yield mock
```

---

# 4. Database Seed Data

## 4.1 test-seed-data.sql

```sql
-- ============================================================================
-- TEST SEED DATA FOR SOS EMERGENCY FEATURE
-- Use in test environment only
-- ============================================================================

-- Clean existing test data
DELETE FROM sos_escalation_calls WHERE event_id IN 
    (SELECT event_id FROM sos_events WHERE user_id = 'test-user-001'::uuid);
DELETE FROM sos_notifications WHERE event_id IN 
    (SELECT event_id FROM sos_events WHERE user_id = 'test-user-001'::uuid);
DELETE FROM sos_events WHERE user_id = 'test-user-001'::uuid;
DELETE FROM user_emergency_contacts WHERE user_id = 'test-user-001'::uuid;

-- ============================================================================
-- TEST USERS (if not exists)
-- ============================================================================

INSERT INTO users (user_id, name, phone, email, is_active, created_at)
VALUES 
    ('test-user-001'::uuid, 'Nguyễn Văn Test', '0901234567', 'test@example.com', true, NOW()),
    ('test-user-002'::uuid, 'Trần Thị Test', '0909876543', 'test2@example.com', true, NOW())
ON CONFLICT (user_id) DO NOTHING;

-- ============================================================================
-- EMERGENCY CONTACTS
-- ============================================================================

-- User 001: 3 contacts
INSERT INTO user_emergency_contacts 
    (contact_id, user_id, name, phone, relationship, priority, is_active, zalo_enabled)
VALUES
    ('contact-001'::uuid, 'test-user-001'::uuid, 'Nguyễn Văn A', '0912345678', 'Con trai', 1, true, true),
    ('contact-002'::uuid, 'test-user-001'::uuid, 'Trần Thị B', '0923456789', 'Con gái', 2, true, false),
    ('contact-003'::uuid, 'test-user-001'::uuid, 'Lê Văn C', '0934567890', 'Cháu', 3, true, true);

-- User 002: 5 contacts (max)
INSERT INTO user_emergency_contacts 
    (contact_id, user_id, name, phone, relationship, priority, is_active, zalo_enabled)
VALUES
    ('contact-011'::uuid, 'test-user-002'::uuid, 'Contact 1', '0941111111', 'Người thân', 1, true, false),
    ('contact-012'::uuid, 'test-user-002'::uuid, 'Contact 2', '0942222222', 'Người thân', 2, true, false),
    ('contact-013'::uuid, 'test-user-002'::uuid, 'Contact 3', '0943333333', 'Người thân', 3, true, false),
    ('contact-014'::uuid, 'test-user-002'::uuid, 'Contact 4', '0944444444', 'Người thân', 4, true, false),
    ('contact-015'::uuid, 'test-user-002'::uuid, 'Contact 5', '0945555555', 'Người thân', 5, true, false);

-- ============================================================================
-- SOS EVENTS (Various states)
-- ============================================================================

-- Event 001: PENDING (active countdown)
INSERT INTO sos_events
    (event_id, user_id, triggered_at, trigger_source, latitude, longitude, 
     countdown_seconds, countdown_started_at, status)
VALUES
    ('event-pending-001'::uuid, 'test-user-001'::uuid, NOW() - interval '10 seconds', 'manual',
     10.762622, 106.660172, 30, NOW() - interval '10 seconds', 0);

-- Event 002: COMPLETED
INSERT INTO sos_events
    (event_id, user_id, triggered_at, trigger_source, latitude, longitude,
     countdown_seconds, countdown_started_at, countdown_completed_at, status)
VALUES
    ('event-completed-001'::uuid, 'test-user-001'::uuid, NOW() - interval '5 minutes', 'manual',
     10.762622, 106.660172, 30, NOW() - interval '5 minutes', 
     NOW() - interval '5 minutes' + interval '30 seconds', 1);

-- Event 003: CANCELLED
INSERT INTO sos_events
    (event_id, user_id, triggered_at, trigger_source,
     countdown_seconds, countdown_started_at, status, cancelled_at, cancellation_reason)
VALUES
    ('event-cancelled-001'::uuid, 'test-user-001'::uuid, NOW() - interval '1 hour', 'manual',
     30, NOW() - interval '1 hour', 2, NOW() - interval '1 hour' + interval '15 seconds', 'Ấn nhầm');

-- Event 004: Low battery (10s countdown)
INSERT INTO sos_events
    (event_id, user_id, triggered_at, trigger_source, battery_level_percent,
     countdown_seconds, countdown_started_at, status)
VALUES
    ('event-low-battery-001'::uuid, 'test-user-002'::uuid, NOW() - interval '5 seconds', 'manual',
     8, 10, NOW() - interval '5 seconds', 0);

-- ============================================================================
-- NOTIFICATIONS
-- ============================================================================

-- Notifications for completed event
INSERT INTO sos_notifications
    (notification_id, event_id, recipient_name, recipient_phone, recipient_type,
     channel, template_id, status, sent_at, delivered_at)
VALUES
    ('notif-001'::uuid, 'event-completed-001'::uuid, 'Nguyễn Văn A', '0912345678', 'family',
     'zns', 'SOS_TEMPLATE_1', 2, NOW() - interval '5 minutes', NOW() - interval '4 minutes'),
    ('notif-002'::uuid, 'event-completed-001'::uuid, 'Trần Thị B', '0923456789', 'family',
     'zns', 'SOS_TEMPLATE_1', 2, NOW() - interval '5 minutes', NOW() - interval '4 minutes'),
    ('notif-003'::uuid, 'event-completed-001'::uuid, 'Lê Văn C', '0934567890', 'family',
     'zns', 'SOS_TEMPLATE_1', 1, NOW() - interval '5 minutes', NULL),
    ('notif-004'::uuid, 'event-completed-001'::uuid, 'CSKH', '1900xxxx', 'cskh',
     'cskh_api', NULL, 2, NOW() - interval '5 minutes', NOW() - interval '5 minutes');

-- ============================================================================
-- FIRST AID CONTENT
-- ============================================================================

-- Already seeded in database-changes.sql
-- No additional seed needed here

-- ============================================================================
-- VERIFY SEED DATA
-- ============================================================================

SELECT 'Users:' as check_type, count(*) as count FROM users WHERE user_id::text LIKE 'test-user%';
SELECT 'Contacts:' as check_type, count(*) as count FROM user_emergency_contacts WHERE user_id::text LIKE 'test-user%';
SELECT 'Events:' as check_type, count(*) as count FROM sos_events WHERE user_id::text LIKE 'test-user%';
SELECT 'Notifications:' as check_type, count(*) as count FROM sos_notifications WHERE event_id::text LIKE 'event-%';
```

---

# 5. Mock Server Responses

## 5.1 WireMock Stubs (wiremock-stubs/)

### zns-api-stubs.json

```json
{
  "mappings": [
    {
      "name": "ZNS Send Template - Success",
      "request": {
        "method": "POST",
        "urlPathPattern": "/v2/send-template",
        "headers": {
          "Authorization": {
            "matches": "Bearer .*"
          }
        }
      },
      "response": {
        "status": 200,
        "headers": {
          "Content-Type": "application/json"
        },
        "jsonBody": {
          "error": 0,
          "message": "Success",
          "data": {
            "msg_id": "{{randomValue type='UUID'}}"
          }
        }
      }
    },
    {
      "name": "ZNS Send Template - Rate Limit",
      "request": {
        "method": "POST",
        "urlPathPattern": "/v2/send-template",
        "headers": {
          "X-Test-Trigger": {
            "equalTo": "rate-limit"
          }
        }
      },
      "response": {
        "status": 429,
        "headers": {
          "Content-Type": "application/json",
          "Retry-After": "60"
        },
        "jsonBody": {
          "error": 429,
          "message": "Rate limit exceeded"
        }
      }
    },
    {
      "name": "ZNS Send Template - Server Error",
      "request": {
        "method": "POST",
        "urlPathPattern": "/v2/send-template",
        "headers": {
          "X-Test-Trigger": {
            "equalTo": "server-error"
          }
        }
      },
      "response": {
        "status": 500,
        "jsonBody": {
          "error": 500,
          "message": "Internal server error"
        }
      }
    }
  ]
}
```

### cskh-api-stubs.json

```json
{
  "mappings": [
    {
      "name": "CSKH Alert - Success",
      "request": {
        "method": "POST",
        "urlPathPattern": "/api/v1/alerts/sos"
      },
      "response": {
        "status": 200,
        "jsonBody": {
          "success": true,
          "data": {
            "ticket_id": "TICKET-{{randomValue type='UUID'}}",
            "assigned_to": "CSKH Team"
          }
        }
      }
    },
    {
      "name": "CSKH Alert - Escalation",
      "request": {
        "method": "POST",
        "urlPathPattern": "/api/v1/alerts/escalation"
      },
      "response": {
        "status": 200,
        "jsonBody": {
          "success": true,
          "data": {
            "ticket_id": "ESC-{{randomValue type='UUID'}}",
            "priority": "HIGH"
          }
        }
      }
    }
  ]
}
```

---

## Test Data Summary

| Category | Files | Records |
|----------|:-----:|:-------:|
| Java Fixtures | 2 | ~30 factory methods |
| Python Fixtures | 1 | ~20 fixtures |
| SQL Seed Data | 1 | ~25 records |
| WireMock Stubs | 2 | 5 mappings |

---

**Report Version:** 1.0  
**Generated:** 2026-01-26T11:35:00+07:00  
**Workflow:** `/alio-testing`
