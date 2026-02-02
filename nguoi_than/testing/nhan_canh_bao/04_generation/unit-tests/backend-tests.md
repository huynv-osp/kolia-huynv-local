# 🔧 Backend Unit Tests - Nhận Cảnh Báo (US 1.2)

## Document Information

| Attribute | Value |
|-----------|-------|
| **Version** | 1.5 |
| **Date** | 2026-02-02 |
| **Services** | user-service, schedule-service |
| **Total Test Cases** | ~55 |

---

## 1. user-service Tests (Java/Vert.x)

### 1.1 AlertServiceTest

```java
@ExtendWith(MockitoExtension.class)
class AlertServiceTest {

    @Mock AlertRepository alertRepository;
    @Mock ConnectionRepository connectionRepository;
    @Mock PermissionRepository permissionRepository;
    @Mock AlertKafkaProducer kafkaProducer;
    @InjectMocks AlertServiceImpl alertService;

    // ============================================================
    // CREATE ALERT TESTS
    // ============================================================
    
    @Test @DisplayName("BR-ALT-001: Chỉ gửi khi Permission #2 ON")
    void createAlert_permissionOn_shouldSaveAndPublish() {
        // Given: Caregiver có permission emergency_alert = ON
        // When: createAlert(patientId, caregiverId, alertType)
        // Then: Alert saved + Kafka event published
    }
    
    @Test @DisplayName("BR-ALT-001: Skip khi Permission #2 OFF")
    void createAlert_permissionOff_shouldNotSave() {
        // Given: Caregiver có permission emergency_alert = OFF
        // When: createAlert(patientId, caregiverId, alertType)
        // Then: No alert saved, no Kafka event
    }
    
    @Test @DisplayName("BR-ALT-004: SOS bypass mọi permission")
    void createAlert_SOS_shouldBypassPermission() {
        // Given: Caregiver có permission = OFF
        // When: createAlert với type = SOS (priority = 0)
        // Then: Alert vẫn được save và publish
    }
    
    @Test @DisplayName("BR-ALT-005: Debounce 5 phút - duplicate blocked")
    void createAlert_withinDebounce_shouldThrowDuplicateException() {
        // Given: Alert cùng loại đã được tạo 2 phút trước
        // When: createAlert cùng parameters
        // Then: DuplicateAlertException thrown
    }
    
    @Test @DisplayName("BR-ALT-005: SOS không bị debounce")
    void createAlert_SOS_shouldNotDebounce() {
        // Given: SOS alert đã được tạo 1 phút trước
        // When: createAlert SOS mới
        // Then: Alert saved successfully
    }
    
    @Test @DisplayName("Priority sort - SOS first")
    void getAlerts_shouldSortByPriorityThenTime() {
        // Given: Mixed alerts (P0, P1, P2)
        // When: getAlerts(caregiverId)
        // Then: SOS (P0) trước, sau đó P1, P2 theo time DESC
    }

    // ============================================================
    // MARK READ TESTS
    // ============================================================
    
    @Test @DisplayName("Mark read - success")
    void markAsRead_validAlert_shouldUpdateStatus() {
        // Given: Unread alert
        // When: markAsRead(alertId, caregiverId)
        // Then: status = 1, read_at = now
    }
    
    @Test @DisplayName("Mark read - idempotent")
    void markAsRead_alreadyRead_shouldBeIdempotent() {
        // Given: Already read alert
        // When: markAsRead again
        // Then: No error, same status
    }
    
    @Test @DisplayName("Mark read - NOT_FOUND")
    void markAsRead_invalidAlert_shouldThrow404() {
        // Given: Non-existent alertId
        // When: markAsRead
        // Then: AlertNotFoundException
    }
}
```

### 1.2 BPDeltaEvaluatorTest

```java
@ExtendWith(MockitoExtension.class)
class BPDeltaEvaluatorTest {

    @Mock BloodPressureRepository bpRepository;
    @InjectMocks BPDeltaEvaluator evaluator;
    
    // ============================================================
    // BR-ALT-002 + BR-HA-017: Delta calculation
    // ============================================================
    
    @Test @DisplayName("BR-HA-017: Calculate 7-day rolling average")
    void calculate7DayAverage_withRecords_shouldReturnCorrectAvg() {
        // Given: 10 BP records in last 7 days
        // When: calculate7DayAverage(patientId)
        // Then: Correct systolic + diastolic averages
    }
    
    @Test @DisplayName("BR-ALT-002: HIGH delta detected (+15 systolic)")
    void evaluate_highDelta_shouldReturnHighAlert() {
        // Given: 7-day avg = 120/80, current = 145/95
        // When: evaluate(patientId, currentBP)
        // Then: AlertType.HA_HIGH with delta = +25/+15
    }
    
    @Test @DisplayName("BR-ALT-002: LOW delta detected (-15 systolic)")
    void evaluate_lowDelta_shouldReturnLowAlert() {
        // Given: 7-day avg = 120/80, current = 95/55
        // When: evaluate(patientId, currentBP)
        // Then: AlertType.HA_LOW with delta = -25/-25
    }
    
    @Test @DisplayName("Normal BP - no alert")
    void evaluate_normalRange_shouldReturnNull() {
        // Given: 7-day avg = 120/80, current = 125/82
        // When: evaluate (delta = +5/+2 < 10)
        // Then: null (no alert needed)
    }
    
    @Test @DisplayName("Not enough historical data")
    void evaluate_lessThan3Records_shouldReturnNull() {
        // Given: Only 2 BP records in 7 days
        // When: evaluate
        // Then: null (insufficient data)
    }
    
    @Test @DisplayName("Edge case: exactly 10mmHg delta")
    void evaluate_exactlyThreshold_shouldNotAlert() {
        // Given: avg = 120, current = 130 (delta = 10)
        // When: evaluate
        // Then: null (must be > 10, not >=)
    }
}
```

### 1.3 AlertKafkaProducerTest

```java
@ExtendWith(MockitoExtension.class)
class AlertKafkaProducerTest {

    @Mock KafkaTemplate<String, AlertEvent> kafkaTemplate;
    @InjectMocks AlertKafkaProducer producer;
    
    @Test @DisplayName("Publish BP alert event")
    void publishBPAlert_shouldSendToCorrectTopic() {
        // Given: BPAlert event
        // When: publish(event)
        // Then: Sent to "topic-alert-triggers" with correct payload
    }
    
    @Test @DisplayName("Publish SOS alert event")
    void publishSOSAlert_shouldIncludeLocationInPayload() {
        // Given: SOS event with GPS coordinates
        // When: publish(event)
        // Then: Payload contains location data
    }
    
    @Test @DisplayName("Publish medication alert event")
    void publishMedicationAlert_shouldIncludeDrugName() {
        // Given: Medication wrong dose event
        // When: publish(event)
        // Then: Payload contains medication name
    }
}
```

### 1.4 AlertRepositoryTest (Integration)

```java
@DataJpaTest
@Testcontainers
class AlertRepositoryIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15");
    
    @Autowired AlertRepository alertRepository;
    @Autowired AlertTypeRepository alertTypeRepository;
    
    @Test @DisplayName("Debounce index blocks duplicate")
    void save_duplicateWithinDebounce_shouldThrowConstraintViolation() {
        // Given: Alert A saved at 10:00
        // When: Save similar alert at 10:03 (same 5-min bucket)
        // Then: ConstraintViolationException
    }
    
    @Test @DisplayName("Debounce allows after 5-min window")
    void save_afterDebounceWindow_shouldSucceed() {
        // Given: Alert A saved at 10:00
        // When: Save similar alert at 10:06 (different bucket)
        // Then: Success
    }
    
    @Test @DisplayName("Find unread by caregiver - uses partial index")
    void findUnreadByCaregiver_shouldUseIndex() {
        // Given: Mixed read/unread alerts
        // When: findByCaregiver(id, status=0)
        // Then: Only unread returned, query plan uses idx_alerts_caregiver_unread
    }
    
    @Test @DisplayName("Find by type filter")
    void findByType_shouldFilter() {
        // Given: Alerts of different types
        // When: findByType(caregiverId, "HA")
        // Then: Only HA alerts returned
    }
}
```

---

## 2. schedule-service Tests (Python/Celery)

### 2.1 AlertConsumerTest

```python
# tests/unit/consumers/test_alert_consumer.py

import pytest
from unittest.mock import Mock, patch, AsyncMock
from app.consumers.alert_consumer import AlertConsumer
from app.models.alert_event import AlertEvent


class TestAlertConsumer:
    """Kafka consumer tests for real-time alerts."""
    
    @pytest.fixture
    def consumer(self):
        return AlertConsumer()
    
    @pytest.fixture
    def sample_bp_event(self):
        return AlertEvent(
            event_type="BP_ALERT",
            patient_id="patient-001",
            caregiver_ids=["caregiver-001", "caregiver-002"],
            alert_type_id=2,  # HA
            title="Mẹ - HA 145/95 (Cao hơn bình thường)",
            payload={"systolic": 145, "diastolic": 95, "delta": 25}
        )
    
    # ============================================================
    # CONSUME TESTS
    # ============================================================
    
    @patch('app.services.fcm_service.FCMService.send_push')
    async def test_handle_bp_event_sends_push(self, mock_fcm, consumer, sample_bp_event):
        """Should send FCM push to all caregivers."""
        mock_fcm.return_value = True
        
        await consumer.handle_event(sample_bp_event)
        
        assert mock_fcm.call_count == 2  # 2 caregivers
    
    @patch('app.services.fcm_service.FCMService.send_push')
    async def test_handle_sos_event_priority(self, mock_fcm, consumer):
        """SOS alerts should have priority = 0."""
        sos_event = AlertEvent(
            event_type="SOS_ALERT",
            patient_id="patient-001",
            caregiver_ids=["caregiver-001"],
            alert_type_id=1,  # SOS
            title="🚨 Mẹ cần hỗ trợ KHẨN CẤP!",
            payload={"location": {"lat": 10.8, "lng": 106.6}}
        )
        
        await consumer.handle_event(sos_event)
        
        call_args = mock_fcm.call_args
        assert call_args[1]['priority'] == 'high'
```

### 2.2 ComplianceEvaluatorTest

```python
# tests/unit/evaluators/test_compliance_evaluator.py

import pytest
from datetime import datetime, timedelta
from unittest.mock import Mock, patch
from app.evaluators.compliance_evaluator import ComplianceEvaluator


class TestComplianceEvaluator:
    """Batch evaluation tests for compliance alerts."""
    
    @pytest.fixture
    def evaluator(self):
        return ComplianceEvaluator()
    
    # ============================================================
    # MEDICATION MISSED TESTS
    # ============================================================
    
    @patch('app.repositories.medication_repository.get_missed_streaks')
    def test_evaluate_3_missed_doses_triggers_alert(self, mock_repo, evaluator):
        """3 consecutive missed doses should trigger alert."""
        mock_repo.return_value = [
            {"patient_id": "p1", "medication_name": "Amlodipine", "missed_count": 3}
        ]
        
        alerts = evaluator.evaluate_medication_missed()
        
        assert len(alerts) == 1
        assert alerts[0].alert_type_id == 3  # MEDICATION
    
    @patch('app.repositories.medication_repository.get_missed_streaks')
    def test_evaluate_2_missed_doses_no_alert(self, mock_repo, evaluator):
        """2 missed doses should NOT trigger alert."""
        mock_repo.return_value = [
            {"patient_id": "p1", "missed_count": 2}
        ]
        
        alerts = evaluator.evaluate_medication_missed()
        
        assert len(alerts) == 0
    
    # ============================================================
    # BP MISSED TESTS
    # ============================================================
    
    @patch('app.repositories.bp_repository.get_missed_schedules')
    def test_evaluate_3_missed_bp_triggers_alert(self, mock_repo, evaluator):
        """3 consecutive missed BP measurements should trigger alert."""
        mock_repo.return_value = [
            {"patient_id": "p1", "missed_count": 3}
        ]
        
        alerts = evaluator.evaluate_bp_missed()
        
        assert len(alerts) == 1
        assert alerts[0].alert_type_id == 4  # COMPLIANCE
    
    # ============================================================
    # LOW COMPLIANCE RATE TESTS
    # ============================================================
    
    @patch('app.repositories.compliance_repository.get_24h_rates')
    def test_evaluate_compliance_below_70_triggers_alert(self, mock_repo, evaluator):
        """Compliance rate < 70% should trigger alert."""
        mock_repo.return_value = [
            {"patient_id": "p1", "compliance_rate": 0.65}
        ]
        
        alerts = evaluator.evaluate_low_compliance()
        
        assert len(alerts) == 1
        assert "65%" in alerts[0].body
    
    @patch('app.repositories.compliance_repository.get_24h_rates')
    def test_evaluate_compliance_at_70_no_alert(self, mock_repo, evaluator):
        """Compliance rate = 70% should NOT trigger alert."""
        mock_repo.return_value = [
            {"patient_id": "p1", "compliance_rate": 0.70}
        ]
        
        alerts = evaluator.evaluate_low_compliance()
        
        assert len(alerts) == 0
```

### 2.3 FCMDispatcherTest

```python
# tests/unit/services/test_fcm_dispatcher.py

import pytest
from unittest.mock import Mock, patch
from app.services.fcm_dispatcher import FCMDispatcher


class TestFCMDispatcher:
    """FCM push notification tests."""
    
    @pytest.fixture
    def dispatcher(self):
        return FCMDispatcher()
    
    @patch('firebase_admin.messaging.send')
    def test_send_push_success(self, mock_firebase, dispatcher):
        """Should send FCM message successfully."""
        mock_firebase.return_value = "message-id-123"
        
        result = dispatcher.send(
            token="device_token_abc",
            title="Test Alert",
            body="Test body",
            data={"alert_id": "alert-001"}
        )
        
        assert result is True
    
    @patch('firebase_admin.messaging.send')
    def test_send_push_with_high_priority(self, mock_firebase, dispatcher):
        """SOS alerts should use high priority Android config."""
        dispatcher.send(
            token="token",
            title="🚨 SOS",
            body="Emergency",
            priority="high"
        )
        
        call_args = mock_firebase.call_args
        message = call_args[0][0]
        assert message.android.priority == "high"
    
    def test_format_title_hides_pii(self, dispatcher):
        """BR-ALT-013: Lock screen should not show PII."""
        formatted = dispatcher.format_for_lockscreen(
            title="Nguyễn Văn A - HA cao",
            body="Full detail here"
        )
        
        assert "Nguyễn" not in formatted["title"]
        assert "Cảnh báo sức khỏe" in formatted["title"]
```

---

## 3. Test Data Fixtures

### 3.1 Java Fixtures

```java
public class AlertTestFixtures {
    
    public static CaregiverAlert createUnreadAlert(
            UUID caregiverId, 
            UUID patientId, 
            int typeId, 
            int priority) {
        return CaregiverAlert.builder()
            .alertId(UUID.randomUUID())
            .caregiverId(caregiverId)
            .patientId(patientId)
            .alertTypeId(typeId)
            .priority(priority)
            .title("Test Alert")
            .status(0)  // unread
            .createdAt(Instant.now())
            .build();
    }
    
    public static List<CaregiverAlert> createMixedPriorityAlerts(
            UUID caregiverId, UUID patientId) {
        return List.of(
            createUnreadAlert(caregiverId, patientId, 2, 1),  // HA - P1
            createUnreadAlert(caregiverId, patientId, 1, 0),  // SOS - P0
            createUnreadAlert(caregiverId, patientId, 4, 2)   // COMPLIANCE - P2
        );
    }
}
```

### 3.2 Python Fixtures

```python
# tests/fixtures/alert_fixtures.py

import pytest
from datetime import datetime, timedelta
from uuid import uuid4

@pytest.fixture
def patient_with_bp_history():
    """Patient với 7 ngày BP records."""
    return {
        "patient_id": str(uuid4()),
        "bp_records": [
            {"systolic": 120, "diastolic": 80, "measured_at": datetime.now() - timedelta(days=i)}
            for i in range(7)
        ]
    }

@pytest.fixture  
def caregiver_with_permission_on():
    """Caregiver có Permission #2 = ON."""
    return {
        "caregiver_id": str(uuid4()),
        "fcm_token": "test_fcm_token",
        "permissions": {"emergency_alert": True}
    }
```

---

## Summary

| Service | Test Class | Test Count |
|---------|------------|:----------:|
| user-service | AlertServiceTest | 10 |
| user-service | BPDeltaEvaluatorTest | 8 |
| user-service | AlertKafkaProducerTest | 4 |
| user-service | AlertRepositoryIntegrationTest | 6 |
| schedule-service | AlertConsumerTest | 5 |
| schedule-service | ComplianceEvaluatorTest | 8 |
| schedule-service | FCMDispatcherTest | 6 |
| **Total** | | **~55** |

---

**Generated:** 2026-02-02T23:15:00+07:00  
**Workflow:** `/alio-testing`
