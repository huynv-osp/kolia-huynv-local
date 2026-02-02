# 📋 Test Plan - Nhận Cảnh Báo Bất Thường (US 1.2)

## Document Information

| Attribute | Value |
|-----------|-------|
| **Version** | 1.5 |
| **Date** | 2026-02-02 |
| **Author** | Test Generator (Automated via /alio-testing) |
| **Status** | Draft |
| **Feature** | US 1.2 - Nhận Cảnh Báo Bất Thường |
| **SRS Version** | v1.5 |
| **SA Version** | v1.5 |
| **Effort** | 132 hours / 4 services |

---

## 1. Test Objectives

### 1.1 Primary Objectives

1. **Validate Alert Types**: 7 loại cảnh báo (SOS, HA, Medication, Compliance) hoạt động đúng
2. **Validate Real-time Triggers**: SOS, HA delta, Wrong dose alerts ≤5s latency
3. **Validate Batch Processing**: 21:00 daily batch cho compliance alerts
4. **Validate Permission System**: Permission #2 (emergency_alert) controls alert delivery
5. **Validate Push Notifications**: FCM push với content formatting đúng
6. **Validate Business Rules**: 8 BR-ALT-* rules + BR-HA-017
7. **Validate Debounce Logic**: 5-minute window (excl. SOS)
8. **Validate Retention**: 90-day auto-cleanup (BR-ALT-009)

### 1.2 Coverage Targets

| Metric | Target | Measurement |
|--------|:------:|-------------|
| Statement Coverage | ≥85% | JaCoCo (Java), pytest-cov (Python) |
| Branch Coverage | ≥75% | JaCoCo, pytest-cov |
| Alert Type Coverage | 100% | All 7 alert types tested |
| Business Rule Coverage | 100% | All 14 BR-ALT rules validated |
| API Endpoint Coverage | 100% | All 6 endpoints tested |

---

## 2. Test Scope

### 2.1 In Scope

#### Backend Services

| Service | Components | Test Types |
|---------|------------|------------|
| **user-service** | AlertEntity, AlertGrpcService, BPDeltaEvaluator, AlertKafkaProducer | Unit, Integration |
| **api-gateway-service** | AlertHandler, AlertHistoryHandler, Validators | Unit, Integration |
| **schedule-service** | AlertConsumer, AlertEvaluators, FCM Dispatcher, Celery Beat Tasks | Unit, Integration |
| **Mobile App** | Alert UI, Push Handling, Modal | E2E (separate) |

#### API Endpoints

| Method | Path | Test Focus |
|:------:|------|------------|
| GET | `/api/v1/connections/alerts` | List alerts with filters (type, patient, time, status) |
| GET | `/api/v1/connections/alerts/{alertId}` | Alert detail with payload |
| POST | `/api/v1/connections/alerts/mark-read` | Mark selected as read |
| POST | `/api/v1/connections/alerts/mark-all-read` | Mark all as read (EC-18) |
| GET | `/api/v1/connections/alerts/unread-count` | Badge count per caregiver |
| GET | `/api/v1/connections/alerts/types` | List 4 alert type categories |

#### Database Tables

| Table | Focus Areas |
|-------|-------------|
| `caregiver_alert_types` | 4 category lookup (SOS, HA, MEDICATION, COMPLIANCE) |
| `caregiver_alerts` | CRUD, Priority sort, Status transitions, Debounce index |

### 2.2 Out of Scope

| Item | Reason |
|------|--------|
| Mobile UI Tests | Separate test plan |
| E2E Performance Tests | Separate test plan |
| External FCM Integration | Mock-based testing only |
| Custom threshold settings | Future feature |

---

## 3. Test Strategy

### 3.1 Test Pyramid

```
                    ┌─────────────────┐
                    │   E2E Tests     │  ← Manual / Later
                    │   (5%)          │
                    └────────┬────────┘
               ┌─────────────┴─────────────┐
               │  Integration Tests (25%)  │  ← API + gRPC + Kafka
               └─────────────┬─────────────┘
          ┌──────────────────┴──────────────────┐
          │         Unit Tests (70%)            │  ← Focus
          └─────────────────────────────────────┘
```

### 3.2 Testing Approach by Service

#### user-service (Java/Vert.x)

| Test Type | Framework | Focus |
|-----------|-----------|-------|
| Unit Tests | JUnit 5 + Mockito | AlertService, BPDeltaEvaluator, AlertKafkaProducer |
| Integration Tests | Testcontainers | Repository queries, Kafka producer |
| gRPC Tests | grpc-testing | AlertGrpcService methods |

#### api-gateway-service (Java/Vert.x)

| Test Type | Framework | Focus |
|-----------|-----------|-------|
| Unit Tests | JUnit 5 + Mockito | AlertHandler, AlertHistoryHandler, Validators |
| Integration Tests | WebTestClient + WireMock | REST endpoints flow |

#### schedule-service (Python/Celery)

| Test Type | Framework | Focus |
|-----------|-----------|-------|
| Unit Tests | pytest + unittest.mock | AlertConsumer, Evaluators, FCM client |
| Integration Tests | pytest + EmbeddedKafka | Kafka consumer flow |
| Task Tests | Celery testing | Batch job execution |

### 3.3 Mocking Strategy

| External Dependency | Mock Approach |
|---------------------|---------------|
| **FCM Push** | Mock client |
| **Database** | Testcontainers (PostgreSQL) |
| **Kafka** | EmbeddedKafka / Testcontainers |
| **gRPC Services** | InProcessServer / Mock stubs |
| **User BP History** | Factory fixtures |

---

## 4. Business Rules Coverage

### 4.1 Critical Rules (P0)

| BR-ID | Rule | Test Category |
|-------|------|---------------|
| BR-ALT-001 | Chỉ gửi khi Permission #2 = ON | PermissionCheck Unit Test |
| BR-ALT-004 | SOS bypass mọi settings | SOS Handler Test |
| BR-ALT-013 | Ẩn PII trên lock screen | Push Content Test |

### 4.2 High Priority Rules (P1)

| BR-ID | Rule | Test Category |
|-------|------|---------------|
| BR-ALT-002 | HA: Chênh lệch >10mmHg so với TB 7 ngày | BPDeltaEvaluator Unit Test |
| BR-ALT-005 | Debounce 5 phút (trừ SOS) | Debounce Index Test |
| BR-ALT-019 | GỘP medication notification | Aggregation Service Test |
| BR-ALT-SOS-001 | Button "Xem vị trí" chỉ khi GPS hợp lệ | SOS Modal Test |
| BR-HA-017 | 7-day rolling average calculation | BPDeltaEvaluator Unit Test |

### 4.3 Medium Priority Rules (P2)

| BR-ID | Rule | Test Category |
|-------|------|---------------|
| BR-ALT-006 | Tuân thủ thuốc <70% triggers alert | Batch Evaluator Test |
| BR-ALT-006b | Tuân thủ đo HA <70% triggers alert | Batch Evaluator Test |
| BR-ALT-007 | 3 consecutive missed medication | Streak Evaluator Test |
| BR-ALT-008 | Sai liều triggers real-time alert | Drug Report Handler Test |
| BR-ALT-009 | Retention 90 ngày | Cleanup Job Test |
| BR-ALT-015 | 3 consecutive missed BP | Streak Evaluator Test |

---

## 5. Test Categories

### 5.1 Unit Test Categories

| Category | Focus | Example |
|----------|-------|---------|
| **Handler Tests** | REST endpoint handlers | AlertHandler.getAlerts(), AlertHandler.markRead() |
| **Service Tests** | Business logic | AlertService.createAlert(), BPDeltaEvaluator.evaluate() |
| **Repository Tests** | Data access | AlertRepository.findUnreadByCaregiver() |
| **Kafka Tests** | Event handling | AlertConsumer.handleBPEvent() |
| **Evaluator Tests** | Batch logic | ComplianceEvaluator.evaluate24h() |

### 5.2 Integration Test Categories

| Category | Focus | Example |
|----------|-------|---------|
| **API Tests** | Full endpoint flow | GET /api/v1/alerts → 200 with pagination |
| **gRPC Tests** | Inter-service calls | AlertGrpcService.CreateAlert() |
| **Database Tests** | Real DB queries | Debounce index uniqueness |
| **Kafka Tests** | Event flow | BP save → Kafka → Consumer → Push |

### 5.3 Test Case Prioritization

| Priority | Criteria | Estimated Count |
|:--------:|----------|:---------------:|
| 🔴 P0 (Critical) | SOS flow, Permission check, Push delivery | ~25 |
| 🟡 P1 (High) | HA delta, Medication alerts, Batch processing | ~35 |
| 🟢 P2 (Medium) | Debounce, Retention, Pagination, Filters | ~20 |
| ⚪ P3 (Low) | Analytics, Logging | ~10 |

**Total Estimated Test Cases: ~90**

---

## 6. Alert Type Test Scenarios

### 6.1 Real-time Alerts

| Alert Type | Trigger | Expected Behavior |
|------------|---------|-------------------|
| 🚨 SOS | Patient taps SOS button | Immediate push to ALL caregivers (bypass permission) |
| 💛 HA Cao | BP systolic/diastolic > avg+10 | Push to caregivers with Permission #2 ON |
| 💛 HA Thấp | BP < avg-10 | Push to caregivers with Permission #2 ON |
| 💊 Sai liều | Patient confirms wrong dose | Push with medication name |

### 6.2 Batch Alerts (21:00)

| Alert Type | Evaluation Query | Expected Behavior |
|------------|------------------|-------------------|
| 💊 Bỏ lỡ 3 liều | 3 consecutive missed_count | AGGREGATED notification per patient |
| 📊 Bỏ lỡ 3 đo HA | No BP records for 3 scheduled times | Push to caregivers |
| 📉 Tuân thủ kém | compliance_rate < 70% in 24h | Push with rate % |

---

## 7. Test Data Strategy

### 7.1 Fixture Strategy

| Data Type | Approach |
|-----------|----------|
| Users | Factory pattern (Patient + multiple Caregivers) |
| Alert Types | Seed data (4 categories) |
| BP Records | Builder pattern with controllable values |
| Connections | Pre-configured with Permission #2 ON/OFF |

### 7.2 Sample Fixtures

```yaml
# test-fixtures.yaml
users:
  patient:
    id: "patient-001"
    name: "Nguyễn Văn A"
    
  caregiver_1:
    id: "caregiver-001"
    name: "Nguyễn Thị B"
    permission_2: true  # emergency_alert ON
    
  caregiver_2:
    id: "caregiver-002"
    name: "Trần Văn C"
    permission_2: false  # emergency_alert OFF

bp_records:
  normal:
    systolic: 120
    diastolic: 80
    
  high_delta:
    systolic: 145  # +25 from avg
    diastolic: 95
    
  low_delta:
    systolic: 95   # -25 from avg
    diastolic: 55

medication:
  schedule_1:
    name: "Amlodipine"
    missed_count: 3  # trigger batch alert
```

---

## 8. Entry/Exit Criteria

### 8.1 Entry Criteria

| Criteria | Status |
|----------|:------:|
| SRS v1.5 approved | ✅ |
| SA Analysis v1.5 complete | ✅ |
| Feature Analysis complete | ✅ |
| Database schema finalized | ✅ |
| Test environment ready | ⏳ |

### 8.2 Exit Criteria

| Criteria | Target |
|----------|:------:|
| All P0 tests passing | 100% |
| All P1 tests passing | ≥95% |
| Statement coverage | ≥85% |
| No critical defects open | 0 |
| No high defects open | ≤3 |

---

## 9. Risk Analysis

### 9.1 Test Risks

| Risk | Impact | Probability | Mitigation |
|------|:------:|:-----------:|------------|
| FCM push delays | High | Medium | Mock + latency tolerance |
| Batch job timing | Medium | Low | Celery testing utilities |
| Kafka consumer lag | High | Medium | EmbeddedKafka with waits |
| BP delta edge cases | High | Medium | Extensive unit tests |
| Debounce race conditions | Medium | Medium | Database constraint tests |

### 9.2 Dependencies

| Dependency | Status | Risk |
|------------|:------:|:----:|
| Kết nối Người thân (Permission #2) | ✅ Complete | Low |
| Đo Huyết áp (BP records) | ✅ Complete | Low |
| Uống thuốc MVP0.3 | ✅ Complete | Low |
| SOS Feature | ⏳ In Progress | Medium |

---

## Appendix: Related Documents

| Document | Path |
|----------|------|
| SRS Document | `docs/nguoi_than/srs_input_documents/srs-nhan-canh-bao_v1.5.md` |
| SA Analysis | `docs/nguoi_than/sa-analysis/nhan_canh_bao/` |
| Feature Analysis | `docs/nguoi_than/features/nhan_canh_bao/` |
| Feature Spec | `docs/nguoi_than/features/nhan_canh_bao/04_output/feature-spec.md` |
| Database Schema | `docs/nguoi_than/features/nhan_canh_bao/04_output/database-changes.sql` |

---

**Generated:** 2026-02-02T23:10:00+07:00  
**Workflow:** `/alio-testing`
