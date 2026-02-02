# 📊 Coverage Matrix - Nhận Cảnh Báo (US 1.2)

## Document Information

| Attribute | Value |
|-----------|-------|
| **Version** | 1.5 |
| **Date** | 2026-02-02 |
| **Target Coverage** | ≥85% |

---

## 1. Business Rule Coverage

| BR-ID | Rule | Test File | Test Method | Status |
|-------|------|-----------|-------------|:------:|
| BR-ALT-001 | Permission #2 controls delivery | backend-tests.md | `createAlert_permissionOn_shouldSaveAndPublish` | ⬜ |
| BR-ALT-001 | Permission #2 OFF skips | backend-tests.md | `createAlert_permissionOff_shouldNotSave` | ⬜ |
| BR-ALT-002 | Delta >10mmHg triggers | backend-tests.md | `evaluate_highDelta_shouldReturnHighAlert` | ⬜ |
| BR-ALT-002 | Delta <10mmHg no alert | backend-tests.md | `evaluate_normalRange_shouldReturnNull` | ⬜ |
| BR-ALT-004 | SOS bypasses all | backend-tests.md | `createAlert_SOS_shouldBypassPermission` | ⬜ |
| BR-ALT-005 | Debounce 5 min | backend-tests.md | `createAlert_withinDebounce_shouldThrowDuplicateException` | ⬜ |
| BR-ALT-005 | SOS no debounce | backend-tests.md | `createAlert_SOS_shouldNotDebounce` | ⬜ |
| BR-ALT-006 | Tuân thủ thuốc <70% | backend-tests.md | `evaluate_compliance_below_70_triggers_alert` | ⬜ |
| BR-ALT-006b | Tuân thủ đo HA <70% | backend-tests.md | `evaluate_bp_compliance_below_70` | ⬜ |
| BR-ALT-007 | 3 missed medication | backend-tests.md | `evaluate_3_missed_doses_triggers_alert` | ⬜ |
| BR-ALT-008 | Sai liều real-time | backend-tests.md | `handle_wrong_dose_event` | ⬜ |
| BR-ALT-009 | 90-day retention | backend-tests.md | Cleanup job test | ⬜ |
| BR-ALT-013 | Hide PII on lock screen | backend-tests.md | `format_title_hides_pii` | ⬜ |
| BR-ALT-015 | 3 missed BP | backend-tests.md | `evaluate_3_missed_bp_triggers_alert` | ⬜ |
| BR-ALT-019 | Consolidate medication alerts | backend-tests.md | Aggregation test | ⬜ |
| BR-HA-017 | 7-day rolling average | backend-tests.md | `calculate7DayAverage_withRecords_shouldReturnCorrectAvg` | ⬜ |

**Coverage: 0/16 (0%)** → Target: 100%

---

## 2. API Endpoint Coverage

| Endpoint | Test File | Tests | Status |
|----------|-----------|:-----:|:------:|
| GET `/api/v1/connections/alerts` | api-tests.md | 7 | ⬜ |
| GET `/api/v1/connections/alerts/{id}` | api-tests.md | 3 | ⬜ |
| POST `/api/v1/connections/alerts/mark-read` | api-tests.md | 3 | ⬜ |
| POST `/api/v1/connections/alerts/mark-all-read` | api-tests.md | 2 | ⬜ |
| GET `/api/v1/connections/alerts/unread-count` | api-tests.md | 2 | ⬜ |
| GET `/api/v1/connections/alerts/types` | api-tests.md | 2 | ⬜ |

**Coverage: 0/6 (0%)** → Target: 100%

---

## 3. gRPC Method Coverage

| Service | Method | Test File | Status |
|---------|--------|-----------|:------:|
| AlertService | CreateAlert | backend-tests.md | ⬜ |
| AlertService | GetAlertHistory | api-tests.md | ⬜ |
| AlertService | GetAlertDetail | api-tests.md | ⬜ |
| AlertService | MarkAlertAsRead | api-tests.md | ⬜ |
| AlertService | MarkAllAlertsAsRead | api-tests.md | ⬜ |
| AlertService | GetUnreadCount | api-tests.md | ⬜ |

**Coverage: 0/6 (0%)** → Target: 100%

---

## 4. Alert Type Coverage

| Type ID | Code | Trigger Test | Push Test | Status |
|:-------:|------|--------------|-----------|:------:|
| 1 | SOS | `handle_sos_event_priority` | FCMDispatcher test | ⬜ |
| 2 | HA | `evaluate_highDelta_*`, `evaluate_lowDelta_*` | FCMDispatcher test | ⬜ |
| 3 | MEDICATION | `handle_medication_*` | FCMDispatcher test | ⬜ |
| 4 | COMPLIANCE | `evaluate_compliance_*` | FCMDispatcher test | ⬜ |

**Coverage: 0/4 (0%)** → Target: 100%

---

## 5. Kafka Event Coverage

| Topic | Producer | Consumer | Test | Status |
|-------|----------|----------|------|:------:|
| topic-alert-triggers | user-service | schedule-service | `publishBPAlert_*` | ⬜ |
| topic-alert-dispatched | schedule-service | user-service | `handle_dispatched_*` | ⬜ |

**Coverage: 0/2 (0%)** → Target: 100%

---

## 6. Database Table Coverage

| Table | Create | Read | Update | Delete | Status |
|-------|:------:|:----:|:------:|:------:|:------:|
| caregiver_alert_types | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| caregiver_alerts | ⬜ | ⬜ | ⬜ | N/A | ⬜ |

---

## Summary

| Category | Covered | Total | % |
|----------|:-------:|:-----:|:-:|
| Business Rules | 0 | 16 | 0% |
| REST Endpoints | 0 | 6 | 0% |
| gRPC Methods | 0 | 6 | 0% |
| Alert Types | 0 | 4 | 0% |
| Kafka Topics | 0 | 2 | 0% |
| **Total** | **0** | **34** | **0%** |

> **Target: ≥85% coverage before implementation complete**

---

**Generated:** 2026-02-02  
**Workflow:** `/alio-testing`
