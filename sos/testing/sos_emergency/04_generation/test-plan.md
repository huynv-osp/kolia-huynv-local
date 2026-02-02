# 📋 Test Plan - SOS Emergency Feature

## Document Information

| Attribute | Value |
|-----------|-------|
| **Version** | 1.0 |
| **Date** | 2026-01-26 |
| **Author** | Test Generator (Automated via /alio-testing) |
| **Status** | Draft |
| **Feature** | SOS Emergency - Chức năng hỗ trợ khẩn cấp |

---

## Table of Contents

1. [Test Objectives](#1-test-objectives)
2. [Test Scope](#2-test-scope)
3. [Test Strategy](#3-test-strategy)
4. [Test Environment](#4-test-environment)
5. [Test Categories](#5-test-categories)
6. [Test Schedule](#6-test-schedule)
7. [Entry/Exit Criteria](#7-entryexit-criteria)
8. [Risk Analysis](#8-risk-analysis)

---

# 1. Test Objectives

## 1.1 Primary Objectives

1. **Validate SOS Core Flow**: Đảm bảo quy trình kích hoạt SOS → Countdown → Alert hoạt động đúng
2. **Validate Escalation Logic**: Xác minh quy trình gọi người thân tuần tự hoạt động chính xác
3. **Validate Error Handling**: Đảm bảo xử lý lỗi cho các tình huống offline, timeout, retry
4. **Validate Data Integrity**: Kiểm tra tính toàn vẹn dữ liệu trong các bảng SOS
5. **Validate Business Rules**: Đảm bảo 23 business rules được implement đúng

## 1.2 Coverage Targets

| Metric | Target | Measurement |
|--------|:------:|-------------|
| Statement Coverage | ≥85% | JaCoCo (Java), pytest-cov (Python) |
| Branch Coverage | ≥75% | JaCoCo, pytest-cov |
| API Endpoint Coverage | 100% | All 10 endpoints tested |
| Business Rule Coverage | 100% | All 23 rules validated |
| Error Code Coverage | 100% | All 10 error codes tested |

---

# 2. Test Scope

## 2.1 In Scope

### Backend Services

| Service | Components | Test Types |
|---------|------------|------------|
| **api-gateway-service** | 10 REST endpoints, Cooldown service | Unit, Integration |
| **user-service** | EmergencyContact gRPC service | Unit, Integration |
| **schedule-service** | 6 Celery tasks, ZNS client | Unit, Integration |

### Database

| Table | Focus Areas |
|-------|-------------|
| `user_emergency_contacts` | CRUD, Constraints, Priority |
| `sos_events` | Status transitions, Partitioning |
| `sos_notifications` | Retry logic, Status tracking |
| `sos_escalation_calls` | Call status, Timeout |
| `first_aid_content` | Content retrieval |

### Business Rules

- 23 Business Rules (BR-SOS-001 to BR-SOS-023)
- 17 Gherkin scenarios from SRS

## 2.2 Out of Scope

| Item | Reason |
|------|--------|
| Mobile UI Tests | Separate test plan |
| E2E Performance Tests | Separate test plan |
| External Integration (ZNS, Google Maps) | Mock-based testing only |
| Load Testing | Separate test plan |

---

# 3. Test Strategy

## 3.1 Test Pyramid

```
                    ┌─────────────────┐
                    │   E2E Tests     │  ← Manual / Later
                    │   (5%)          │
                    └────────┬────────┘
               ┌─────────────┴─────────────┐
               │  Integration Tests (25%)  │  ← API + Service
               └─────────────┬─────────────┘
          ┌──────────────────┴──────────────────┐
          │         Unit Tests (70%)            │  ← Focus
          └─────────────────────────────────────┘
```

## 3.2 Testing Approach by Service

### api-gateway-service (Java/Vert.x)

| Test Type | Framework | Focus |
|-----------|-----------|-------|
| Unit Tests | JUnit 5 + Mockito | Handlers, Services, Validators |
| Integration Tests | WebTestClient + WireMock | REST endpoints, gRPC clients |
| Mock External | WireMock | ZNS API, CSKH API |

### user-service (Java/Vert.x)

| Test Type | Framework | Focus |
|-----------|-----------|-------|
| Unit Tests | JUnit 5 + Mockito | Services, Repositories |
| Integration Tests | Testcontainers (PostgreSQL) | Repository queries |
| gRPC Tests | grpc-testing | gRPC endpoints |

### schedule-service (Python/Celery)

| Test Type | Framework | Focus |
|-----------|-----------|-------|
| Unit Tests | pytest + unittest.mock | Tasks, Handlers |
| Integration Tests | pytest + responses/aioresponses | External APIs |
| Task Tests | Celery testing utilities | Task execution |

## 3.3 Mocking Strategy

| External Dependency | Mock Approach |
|---------------------|---------------|
| **ZNS API** | WireMock stub / responses library |
| **CSKH API** | WireMock stub |
| **Google Maps API** | Mock client |
| **Database** | Testcontainers (PostgreSQL) |
| **Redis** | Embedded Redis / Testcontainers |
| **Kafka** | EmbeddedKafka / Testcontainers |

---

# 4. Test Environment

## 4.1 Environments

| Environment | Purpose | Configuration |
|-------------|---------|---------------|
| **Local** | Developer testing | Docker Compose |
| **CI/CD** | Automated testing | GitHub Actions |
| **QA** | Integration testing | Kubernetes |

## 4.2 Test Data

### Fixture Strategy

| Data Type | Approach |
|-----------|----------|
| Users | Factory pattern with Faker |
| Emergency Contacts | Pre-defined fixtures |
| SOS Events | Builder pattern |
| First Aid Content | Seed data from SQL |

### Sample Data

```yaml
# test-fixtures.yaml
users:
  - id: "test-user-001"
    name: "Nguyễn Văn Test"
    phone: "0901234567"
    
emergency_contacts:
  - user_id: "test-user-001"
    name: "Người thân 1"
    phone: "0912345678"
    priority: 1
  - user_id: "test-user-001"
    name: "Người thân 2"
    phone: "0923456789"
    priority: 2
```

---

# 5. Test Categories

## 5.1 Unit Test Categories

| Category | Focus | Example |
|----------|-------|---------|
| **Handler Tests** | REST endpoint handlers | SOSHandler.activate() |
| **Service Tests** | Business logic | CooldownService.checkCooldown() |
| **Repository Tests** | Data access | EmergencyContactRepository.findByUserId() |
| **Validator Tests** | Input validation | PhoneValidator.isValid() |
| **Mapper Tests** | Object mapping | SOSEventMapper.toProto() |
| **Task Tests** | Celery tasks | send_sos_alerts() |

## 5.2 Integration Test Categories

| Category | Focus | Example |
|----------|-------|---------|
| **API Tests** | Full endpoint flow | POST /api/sos/activate |
| **gRPC Tests** | Inter-service calls | EmergencyContactGrpcService |
| **Database Tests** | Real DB queries | Complex queries with indexes |
| **External API Tests** | Mocked external calls | ZNS API integration |

## 5.3 Test Case Prioritization

| Priority | Criteria | Count |
|:--------:|----------|:-----:|
| 🔴 P0 (Critical) | Core SOS flow, Safety-critical | 45 |
| 🟡 P1 (High) | Error handling, Data integrity | 65 |
| 🟢 P2 (Medium) | Edge cases, Performance | 35 |
| ⚪ P3 (Low) | Nice-to-have, Logging | 17 |

---

# 6. Test Schedule

## 6.1 Timeline

| Week | Phase | Activities |
|:----:|-------|------------|
| Week 1 | Setup | Test framework, Fixtures, CI/CD |
| Week 2 | Backend Unit | api-gateway, user-service unit tests |
| Week 3 | Backend Unit | schedule-service unit tests |
| Week 4 | Integration | API integration tests |
| Week 5 | Integration | Service integration, E2E prep |
| Week 6 | Finalization | Coverage review, Test report |

## 6.2 Milestones

| Milestone | Date | Criteria |
|-----------|------|----------|
| M1: Unit Test Complete | Week 3 | 80% backend unit tests done |
| M2: Integration Test Complete | Week 5 | All API tests passing |
| M3: Coverage Target Met | Week 6 | ≥85% statement coverage |

---

# 7. Entry/Exit Criteria

## 7.1 Entry Criteria

| Criteria | Status |
|----------|:------:|
| SRS approved and baselined | ✅ |
| SA Analysis complete | ✅ |
| API specification finalized | ✅ |
| Database schema finalized | ✅ |
| Test environment ready | ⏳ |
| Test data prepared | ⏳ |

## 7.2 Exit Criteria

| Criteria | Target |
|----------|:------:|
| All P0 tests passing | 100% |
| All P1 tests passing | ≥95% |
| Statement coverage | ≥85% |
| No critical defects open | 0 |
| No high defects open | ≤3 |

---

# 8. Risk Analysis

## 8.1 Test Risks

| Risk | Impact | Probability | Mitigation |
|------|:------:|:-----------:|------------|
| ZNS API không ổn định | High | Medium | Mock-based testing |
| Escalation logic phức tạp | High | Medium | Extensive unit tests |
| Database partitioning issues | Medium | Low | Testcontainers testing |
| Celery task failures | High | Medium | Task isolation, retry tests |
| CI/CD flakiness | Medium | Medium | Retry mechanism, parallel jobs |

## 8.2 Dependencies

| Dependency | Status | Risk |
|------------|:------:|:----:|
| Feature "Kết nối người thân" | 🔴 Not started | Blocker for escalation tests |
| ZNS OA Setup | 🟡 Pending | Mock-based testing initially |
| CSKH API | 🟡 Pending | Mock-based testing |

---

## Appendix A: Related Documents

| Document | Path |
|----------|------|
| SRS Document | `docs/sos/srs_input_documents/srs_sos.md` |
| SA Analysis | `docs/sos/sa-analysis/sos_emergency/` |
| API Specification | `docs/sos/features/sos_emergency/04_output/api-specification.md` |
| Database Schema | `docs/sos/features/sos_emergency/04_output/database-changes.sql` |
| Backend Tests | `docs/testing/sos_emergency/04_generation/unit-tests/backend-tests.md` |
| API Tests | `docs/testing/sos_emergency/04_generation/unit-tests/api-tests.md` |

---

**Report Version:** 1.0  
**Generated:** 2026-01-26T11:20:00+07:00  
**Workflow:** `/alio-testing`
