# Backend Unit Tests: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Version:** 1.0  
> **Date:** 2026-02-04  
> **Test Framework:** JUnit 5 + Mockito (Java), pytest (Python)

---

## 1. Java Tests (user-service)

### 1.1 AlertServiceImplTest (25 tests)

#### UT-ALT-SVC-001: Create SOS alert bypasses permission check
```java
@Test
@DisplayName("SOS alert should bypass permission #2 check (BR-ALT-004)")
void createAlert_sosType_bypassesPermission() {
    // Given
    CreateAlertDto dto = CreateAlertDto.builder()
        .patientId(PATIENT_UUID)
        .alertTypeId(ALERT_TYPE_SOS)
        .priority(0)
        .build();
    
    // Permission #2 is OFF, but SOS should still work
    when(connectionPermissionRepository.hasPermission(any(), any(), eq(PERMISSION_EMERGENCY)))
        .thenReturn(false);
    
    // When
    CaregiverAlert result = alertService.createAlert(CAREGIVER_UUID, dto);
    
    // Then
    assertThat(result).isNotNull();
    assertThat(result.getPriority()).isEqualTo(0);
    verify(kafkaProducer).publishAlertCreated(any());
}
```

#### UT-ALT-SVC-002: Non-SOS alert requires permission #2
```java
@Test
@DisplayName("Non-SOS alert should require permission #2 (BR-ALT-001)")
void createAlert_bpType_requiresPermission() {
    // Given
    CreateAlertDto dto = CreateAlertDto.builder()
        .patientId(PATIENT_UUID)
        .alertTypeId(ALERT_TYPE_BP_HIGH)
        .priority(1)
        .build();
    
    when(connectionPermissionRepository.hasPermission(CAREGIVER_UUID, PATIENT_UUID, 
        PERMISSION_EMERGENCY)).thenReturn(false);
    
    // When/Then
    assertThatThrownBy(() -> alertService.createAlert(CAREGIVER_UUID, dto))
        .isInstanceOf(ForbiddenException.class)
        .hasMessage(ErrorCodes.ALERT_PERMISSION_DENIED);
}
```

#### UT-ALT-SVC-003: BP abnormal HIGH detection
```java
@Test
@DisplayName("Should detect BP abnormal HIGH when delta > 10mmHg above 7-day avg")
void evaluateBP_deltaAbove10_detectsHigh() {
    // Given
    // 7-day average: 150/95
    // Today: 185/125 (delta = +35/+30)
    BPReading reading = new BPReading(185, 125);
    when(bpRepository.get7DayAverage(PATIENT_UUID)).thenReturn(new BPAverage(150, 95));
    
    // When
    BPEvaluationResult result = bpEvaluator.evaluate(PATIENT_UUID, reading);
    
    // Then
    assertThat(result.isAbnormal()).isTrue();
    assertThat(result.getDirection()).isEqualTo("HIGH");
    assertThat(result.getDeltaSystolic()).isEqualTo(35);
}
```

#### UT-ALT-SVC-004: BP abnormal LOW detection
```java
@Test
@DisplayName("Should detect BP abnormal LOW when delta > 10mmHg below 7-day avg")
void evaluateBP_deltaBelow10_detectsLow() {
    // Given
    // 7-day average: 150/95
    // Today: 125/75 (delta = -25/-20)
    BPReading reading = new BPReading(125, 75);
    when(bpRepository.get7DayAverage(PATIENT_UUID)).thenReturn(new BPAverage(150, 95));
    
    // When
    BPEvaluationResult result = bpEvaluator.evaluate(PATIENT_UUID, reading);
    
    // Then
    assertThat(result.isAbnormal()).isTrue();
    assertThat(result.getDirection()).isEqualTo("LOW");
}
```

#### UT-ALT-SVC-005: BP normal (delta ≤ 10mmHg)
```java
@Test
@DisplayName("Should NOT trigger alert when BP delta <= 10mmHg")
void evaluateBP_deltaWithin10_noAlert() {
    // Given
    // 7-day average: 150/95
    // Today: 155/98 (delta = +5/+3)
    BPReading reading = new BPReading(155, 98);
    when(bpRepository.get7DayAverage(PATIENT_UUID)).thenReturn(new BPAverage(150, 95));
    
    // When
    BPEvaluationResult result = bpEvaluator.evaluate(PATIENT_UUID, reading);
    
    // Then
    assertThat(result.isAbnormal()).isFalse();
}
```

#### UT-ALT-SVC-006: Debounce 5 min for non-SOS (BR-ALT-005)
```java
@Test
@DisplayName("Should skip alert if same type within 5 minutes (debounce)")
void createAlert_within5Minutes_debounced() {
    // Given - Alert created 3 minutes ago
    when(alertRepository.findRecentByPatientAndType(PATIENT_UUID, ALERT_TYPE_BP_HIGH, 
        Duration.ofMinutes(5))).thenReturn(Optional.of(recentAlert));
    
    CreateAlertDto dto = CreateAlertDto.builder()
        .patientId(PATIENT_UUID)
        .alertTypeId(ALERT_TYPE_BP_HIGH)
        .build();
    
    // When
    alertService.createAlert(CAREGIVER_UUID, dto);
    
    // Then - No new alert created (debounced)
    verify(alertRepository, never()).save(any());
}
```

#### UT-ALT-SVC-007: SOS bypasses debounce
```java
@Test
@DisplayName("SOS should NOT be debounced (BR-ALT-004)")
void createAlert_sosWithin5Minutes_notDebounced() {
    // Given - SOS alert created 1 minute ago
    when(alertRepository.findRecentByPatientAndType(PATIENT_UUID, ALERT_TYPE_SOS, 
        any())).thenReturn(Optional.of(recentSosAlert));
    
    CreateAlertDto dto = CreateAlertDto.builder()
        .patientId(PATIENT_UUID)
        .alertTypeId(ALERT_TYPE_SOS)
        .priority(0)
        .build();
    
    // When
    CaregiverAlert result = alertService.createAlert(CAREGIVER_UUID, dto);
    
    // Then - New SOS alert still created
    assertThat(result).isNotNull();
    verify(alertRepository).save(any());
}
```

#### UT-ALT-SVC-008: Merge medication notifications (BR-ALT-019)
```java
@Test
@DisplayName("Should merge multiple medication alerts into one notification")
void createAlert_multipleMedications_merged() {
    // Given - 3 missed medications at same time
    List<MissedMedication> missed = List.of(
        new MissedMedication("Amlodipine"),
        new MissedMedication("Metformin"),
        new MissedMedication("Lisinopril")
    );
    
    // When
    CaregiverAlert result = alertService.createMedicationAlert(CAREGIVER_UUID, 
        PATIENT_UUID, missed);
    
    // Then
    assertThat(result.getBody()).contains("3 thuốc");
    // Only 1 notification sent, not 3
    verify(pushService, times(1)).sendPush(any());
}
```

#### UT-ALT-SVC-009: Get alerts with pagination
```java
@Test
@DisplayName("Should return paginated alerts sorted by created_at DESC")
void getAlerts_paginated_sortedDesc() {
    // Given
    PageRequest pageRequest = PageRequest.of(0, 10, Sort.by(DESC, "createdAt"));
    when(alertRepository.findByCaregiverId(CAREGIVER_UUID, pageRequest))
        .thenReturn(new PageImpl<>(alerts));
    
    // When
    Page<CaregiverAlert> result = alertService.getAlerts(CAREGIVER_UUID, pageRequest);
    
    // Then
    assertThat(result.getContent()).hasSize(10);
}
```

#### UT-ALT-SVC-010: Filter alerts by type
```java
@Test
@DisplayName("Should filter alerts by alert_type_id")
void getAlerts_filteredByType_returnFiltered() {
    // Given
    AlertFilter filter = AlertFilter.builder()
        .alertTypeId(ALERT_TYPE_SOS)
        .build();
    
    when(alertRepository.findByFilter(CAREGIVER_UUID, filter))
        .thenReturn(List.of(sosAlert));
    
    // When
    List<CaregiverAlert> result = alertService.getAlerts(CAREGIVER_UUID, filter);
    
    // Then
    assertThat(result).allMatch(a -> a.getAlertTypeId().equals(ALERT_TYPE_SOS));
}
```

---

## 2. Python Tests (schedule-service)

### 2.1 Real-time Alert Consumer (12 tests)

#### UT-SCH-ALT-001: Handle SOS event → immediate push
```python
@pytest.mark.asyncio
async def test_handle_sos_event_sends_push_immediately():
    # Given
    event = {
        "event_type": "SOS_TRIGGERED",
        "patient_id": "uuid-123",
        "patient_name": "Bà Lan",
        "location": {"lat": 10.762622, "lng": 106.660172},
        "timestamp": "2026-02-04T10:30:00Z"
    }
    
    mock_fcm = AsyncMock()
    
    # When
    await handle_sos_alert(event, fcm_service=mock_fcm)
    
    # Then
    mock_fcm.send_priority_notification.assert_called_once()
    call_args = mock_fcm.send_priority_notification.call_args
    assert call_args.kwargs["priority"] == "high"
    assert "🚨" in call_args.kwargs["title"]
```

#### UT-SCH-ALT-002: Handle BP abnormal event
```python
@pytest.mark.asyncio
async def test_handle_bp_abnormal_sends_push():
    # Given
    event = {
        "event_type": "BP_ABNORMAL_DETECTED",
        "patient_id": "uuid-123",
        "patient_name": "Mẹ",
        "systolic": 185,
        "diastolic": 125,
        "direction": "HIGH",
        "delta_systolic": 35
    }
    
    mock_fcm = AsyncMock()
    
    # When
    await handle_bp_alert(event, fcm_service=mock_fcm)
    
    # Then
    mock_fcm.send_notification.assert_called_once()
    assert "💛" in mock_fcm.send_notification.call_args.kwargs["title"]
```

#### UT-SCH-ALT-003: SOS includes location in payload
```python
@pytest.mark.asyncio
async def test_sos_push_includes_location_if_available():
    # Given (BR-ALT-SOS-001)
    event = {
        "event_type": "SOS_TRIGGERED",
        "patient_id": "uuid-123",
        "location": {"lat": 10.762622, "lng": 106.660172}
    }
    
    # When
    push_payload = build_sos_push_payload(event)
    
    # Then
    assert push_payload["data"]["has_location"] == True
    assert push_payload["data"]["lat"] == 10.762622
```

#### UT-SCH-ALT-004: SOS without location hides button
```python
def test_sos_push_without_location_hides_button():
    # Given (BR-ALT-SOS-001)
    event = {
        "event_type": "SOS_TRIGGERED",
        "patient_id": "uuid-123",
        "location": None
    }
    
    # When
    push_payload = build_sos_push_payload(event)
    
    # Then
    assert push_payload["data"]["has_location"] == False
```

---

### 2.2 Batch Job Tests (12 tests)

#### UT-SCH-BATCH-001: Detect 3 missed medication doses
```python
def test_check_missed_medications_detects_3_consecutive():
    # Given
    medication_logs = [
        {"status": "MISSED", "date": today() - timedelta(days=2)},
        {"status": "MISSED", "date": today() - timedelta(days=1)},
        {"status": "MISSED", "date": today()},
    ]
    
    mock_repo = Mock()
    mock_repo.get_recent_logs.return_value = medication_logs
    
    # When
    result = check_missed_medications(PATIENT_UUID, repo=mock_repo)
    
    # Then
    assert result.should_alert == True
    assert result.missed_count == 3
```

#### UT-SCH-BATCH-002: Skip alert if < 3 missed
```python
def test_check_missed_medications_skips_if_less_than_3():
    # Given
    medication_logs = [
        {"status": "MISSED", "date": today() - timedelta(days=1)},
        {"status": "MISSED", "date": today()},
    ]
    
    mock_repo = Mock()
    mock_repo.get_recent_logs.return_value = medication_logs
    
    # When
    result = check_missed_medications(PATIENT_UUID, repo=mock_repo)
    
    # Then
    assert result.should_alert == False
```

#### UT-SCH-BATCH-003: Check compliance < 70%
```python
def test_check_low_compliance_alerts_below_70():
    # Given
    compliance_rate = 0.65  # 65%
    
    mock_repo = Mock()
    mock_repo.get_24h_compliance.return_value = compliance_rate
    
    # When
    result = check_low_compliance(PATIENT_UUID, repo=mock_repo)
    
    # Then
    assert result.should_alert == True
    assert result.compliance_rate == 0.65
```

#### UT-SCH-BATCH-004: Skip alert if compliance ≥ 70%
```python
def test_check_low_compliance_skips_above_70():
    # Given
    compliance_rate = 0.75  # 75%
    
    mock_repo = Mock()
    mock_repo.get_24h_compliance.return_value = compliance_rate
    
    # When
    result = check_low_compliance(PATIENT_UUID, repo=mock_repo)
    
    # Then
    assert result.should_alert == False
```

#### UT-SCH-BATCH-005: Batch job runs at 21:00
```python
def test_batch_job_scheduled_at_21():
    # Given
    from schedule_service.jobs import caregiver_alerts_batch_21h
    
    # When
    schedule = get_job_schedule("caregiver_alerts_batch_21h")
    
    # Then
    assert schedule.hour == 21
    assert schedule.minute == 0
```

---

## 3. Integration Test Fixtures

### 3.1 Alert Type Fixtures
```java
@TestComponent
public class AlertTestFixtures {
    
    public static final int ALERT_TYPE_SOS = 1;
    public static final int ALERT_TYPE_BP_HIGH = 2;
    public static final int ALERT_TYPE_BP_LOW = 3;
    public static final int ALERT_TYPE_WRONG_DOSE = 4;
    public static final int ALERT_TYPE_MISSED_MED = 5;
    public static final int ALERT_TYPE_MISSED_BP = 6;
    public static final int ALERT_TYPE_LOW_COMPLIANCE = 7;
}
```

### 3.2 BP History Fixtures
```java
public static List<BloodPressure> create7DayHistory() {
    return List.of(
        bp(today().minusDays(6), 145, 92),
        bp(today().minusDays(5), 150, 95),
        bp(today().minusDays(4), 155, 98),
        bp(today().minusDays(3), 148, 93),
        bp(today().minusDays(2), 152, 96),
        bp(today().minusDays(1), 149, 94),
        bp(today(), 151, 95)
    );
    // Average: ~150/95
}
```

---

## 4. Test Summary

| Service | Test Class | Tests |
|---------|------------|:-----:|
| user-service | AlertServiceImplTest | 25 |
| user-service | BPAbnormalEvaluatorTest | 8 |
| schedule-service | test_alert_consumer | 12 |
| schedule-service | test_batch_alerts | 12 |
| **Total** | - | **57** |
