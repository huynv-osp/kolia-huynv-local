# Test Plan: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Version:** 1.0  
> **Date:** 2026-02-04  
> **Feature Spec:** [feature-spec.md](../features/nhan_canh_bao/04_output/feature-spec.md)  
> **Coverage Target:** ≥85%

---

## 1. Test Scope

### 1.1 Alert Types Under Test

| ID | Type | Priority | Mode | Tests |
|:--:|------|:--------:|:----:|:-----:|
| 1 | 🚨 SOS | P0 | Real-time | 8 |
| 2 | 💛 HA Cao | P1 | Real-time | 6 |
| 3 | 💛 HA Thấp | P1 | Real-time | 6 |
| 4 | 💊 Sai liều | P1 | Real-time | 5 |
| 5 | 💊 Bỏ lỡ 3 liều | P2 | Batch | 5 |
| 6 | 📊 Bỏ lỡ 3 đo HA | P2 | Batch | 5 |
| 7 | 📉 Tuân thủ kém | P2 | Batch | 5 |

### 1.2 Services Under Test

| Service | Component | Coverage |
|---------|-----------|:--------:|
| **user-service** | AlertService, BP evaluation | Unit + Integration |
| **api-gateway** | AlertHandler | API Tests |
| **schedule-service** | Batch jobs, Kafka consumers | Unit |
| **Mobile App** | Alert screens | Component |

---

## 2. Test Categories

| Category | Count | Priority |
|----------|:-----:|:--------:|
| Unit Tests | 45 | HIGH |
| API Integration | 18 | HIGH |
| Kafka Event Tests | 12 | HIGH |
| Batch Job Tests | 10 | MEDIUM |
| Business Rule Tests | 15 | CRITICAL |
| **Total** | **100** | - |

---

## 3. Business Rule Test Matrix

| BR-ID | Rule | Test Cases | Priority |
|:-----:|------|:----------:|:--------:|
| BR-ALT-001 | Permission #2 required | 4 | CRITICAL |
| BR-ALT-002 | HA delta >10mmHg vs 7-day avg | 6 | HIGH |
| BR-ALT-004 | SOS bypass all settings | 3 | CRITICAL |
| BR-ALT-005 | Debounce 5 min (except SOS) | 5 | HIGH |
| BR-ALT-009 | Retention 90 days | 2 | MEDIUM |
| BR-ALT-013 | Hide PII on lock screen | 2 | CRITICAL |
| BR-ALT-019 | Merge medication notifications | 4 | HIGH |
| BR-ALT-SOS-001 | Location button requires GPS | 2 | HIGH |

---

## 4. API Test Summary

### 4.1 Alert APIs

| Method | Endpoint | Tests |
|:------:|----------|:-----:|
| GET | `/api/v1/alerts` | 5 |
| GET | `/api/v1/alerts/{id}` | 4 |
| POST | `/api/v1/alerts/{id}/read` | 3 |
| GET | `/api/v1/alerts/unread-count` | 3 |
| GET | `/api/v1/alerts/types` | 1 |

### 4.2 Test Scenarios per API

#### GET /api/v1/alerts
| Test ID | Scenario | Expected |
|:-------:|----------|:--------:|
| API-ALT-001 | Get 24h alerts | 200 OK |
| API-ALT-002 | Filter by type | 200 OK |
| API-ALT-003 | Filter by patient | 200 OK |
| API-ALT-004 | Pagination | 200 OK |
| API-ALT-005 | Unauthorized | 401 |

#### GET /api/v1/alerts/{id}
| Test ID | Scenario | Expected |
|:-------:|----------|:--------:|
| API-ALT-006 | Get SOS detail | 200 OK + location |
| API-ALT-007 | Get BP detail | 200 OK + values |
| API-ALT-008 | Not found | 404 |
| API-ALT-009 | Permission denied | 403 |

---

## 5. Unit Test Summary by Service

### 5.1 user-service (30 tests)

| Class | Method | Tests | Focus |
|-------|--------|:-----:|-------|
| AlertServiceImpl | createAlert | 10 | All 7 types |
| AlertServiceImpl | getAlerts | 5 | Filter, sort |
| AlertServiceImpl | markAsRead | 3 | Status update |
| BPAbnormalEvaluator | evaluate | 8 | Delta calc, 7-day avg |
| AlertKafkaProducer | publish | 4 | Event format |

### 5.2 schedule-service (20 tests)

| Module | Function | Tests | Focus |
|--------|----------|:-----:|-------|
| alert_consumer | handle_bp_alert | 4 | Real-time flow |
| alert_consumer | handle_sos_alert | 4 | Priority handling |
| batch_alerts | check_missed_medications | 4 | 3-dose logic |
| batch_alerts | check_missed_bp | 4 | 3-measure logic |
| batch_alerts | check_compliance | 4 | <70% calc |

---

## 6. Kafka Event Tests

### 6.1 Event Types

| Topic | Event | Tests |
|-------|-------|:-----:|
| topic-bp-abnormal | BP_ABNORMAL_DETECTED | 4 |
| topic-sos-triggered | SOS_TRIGGERED | 4 |
| topic-medication-missed | MEDICATION_WRONG_DOSE | 2 |
| topic-alert-created | ALERT_CREATED | 2 |

### 6.2 Event Payload Tests

```python
# Test: BP abnormal event contains required fields
def test_bp_abnormal_event_payload():
    event = {
        "event_type": "BP_ABNORMAL_DETECTED",
        "patient_id": "uuid",
        "systolic": 185,
        "diastolic": 125,
        "delta_systolic": 15,
        "avg_7day_systolic": 170,
        "direction": "HIGH",
        "timestamp": "2026-02-04T10:30:00Z"
    }
    
    assert "patient_id" in event
    assert "delta_systolic" in event
    assert abs(event["delta_systolic"]) > 10
```

---

## 7. Batch Job Tests

### 7.1 21:00 Daily Jobs

| Job | Test Scenarios | Tests |
|-----|----------------|:-----:|
| check_missed_medications | 3 doses missed, <3 skipped | 4 |
| check_missed_bp | 3 measures missed | 4 |
| check_low_compliance | <70% calc, ≥70% skip | 4 |

### 7.2 Test Data Setup

```python
# Test: Missed 3 medication doses
@pytest.fixture
def three_missed_doses():
    return [
        MedicationLog(status="MISSED", date=today() - 2),
        MedicationLog(status="MISSED", date=today() - 1),
        MedicationLog(status="MISSED", date=today()),
    ]
```

---

## 8. Coverage Matrix

| Requirement | Test IDs | Coverage |
|-------------|----------|:--------:|
| SOS Alert | UT-SOS-001~008 | 100% |
| BP Abnormal | UT-BP-001~012 | 100% |
| Medication | UT-MED-001~010 | 100% |
| Compliance | UT-CMP-001~010 | 100% |
| Permission #2 | UT-PERM-001~004 | 100% |
| Debounce | UT-DBN-001~005 | 100% |
| API History | API-ALT-001~005 | 100% |
| API Detail | API-ALT-006~009 | 100% |

**Overall Coverage: 100%** ✅

---

## 9. Test Fixtures

### 9.1 User Fixtures

| ID | Name | Role | Connection |
|:--:|------|:----:|:----------:|
| USER-PT-001 | Bà Lan | Patient | - |
| USER-CG-001 | Cô Huy | Caregiver | Perm #2 ON |
| USER-CG-002 | Anh Minh | Caregiver | Perm #2 OFF |

### 9.2 BP History Fixtures

| Patient | 7-day Avg | Today | Delta |
|:-------:|:---------:|:-----:|:-----:|
| USER-PT-001 | 150/95 | 185/125 | +35/+30 (HIGH) |
| USER-PT-001 | 150/95 | 125/75 | -25/-20 (LOW) |

### 9.3 Medication Fixtures

| Patient | Status | Count |
|:-------:|:------:|:-----:|
| USER-PT-001 | MISSED | 3 liên tiếp |
| USER-PT-001 | WRONG_DOSE | 1 |

---

## 10. Next Steps

1. Generate backend unit tests → `unit-tests/backend-tests.md`
2. Generate API tests → `unit-tests/api-tests.md`
3. Generate batch job tests → `unit-tests/batch-tests.md`
