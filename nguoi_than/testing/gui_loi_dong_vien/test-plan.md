# Test Plan: US 1.3 - Gửi Lời Động Viên

> **Version:** 1.1 (Updated with DB-SCHEMA-001 compliance)  
> **Date:** 2026-02-04  
> **Feature Spec:** [feature-spec.md](../features/gui_loi_dong_vien/04_output/feature-spec.md)  
> **Coverage Target:** ≥85%  
> **Revision:** Added ConnectionPermissionRepositoryTest, DB-SCHEMA-001 warnings

---

## 1. Test Scope

### 1.1 In Scope
| Layer | Component | Coverage |
|-------|-----------|:--------:|
| **user-service** | EncouragementService | Unit + Integration |
| **user-service** | ConnectionPermissionRepositoryImpl | Unit ⭐ NEW |
| **api-gateway** | EncouragementHandler | API Tests |
| **schedule-service** | encouragement_consumer | Unit |
| **Mobile App** | EncouragementWidget, EncouragementModal | Component |

### 1.2 Out of Scope
- AI Suggestions (⏸️ DEFERRED)
- End-to-end performance testing

---

## 2. Test Categories

| Category | Count | Priority |
|----------|:-----:|:--------:|
| Unit Tests | 34 | HIGH |
| API Integration | 12 | HIGH |
| Business Rule Tests | 8 | CRITICAL |
| Error Handling | 6 | MEDIUM |
| **DB Schema Compliance** | **4** | **CRITICAL** ⭐ |
| **Total** | **64** | - |

---

## 3. Test Environment

| Service | Stack | Test Framework |
|---------|-------|----------------|
| user-service | Java 17, Vert.x | JUnit 5 + Mockito |
| api-gateway | Java 17, Vert.x | WebTestClient |
| schedule-service | Python 3.11, Celery | pytest + responses |
| Mobile App | React Native, TypeScript | Vitest + Testing Library |

---

## 4. Test Data Requirements

### 4.1 User Fixtures
| ID | Name | Role | Notes |
|:--:|------|:----:|-------|
| USER-PT-001 | Bà Lan | Patient | Target receiver |
| USER-CG-001 | Cô Huy | Caregiver | Has permission #6 ON |
| USER-CG-002 | Anh Minh | Caregiver | Permission #6 OFF |
| USER-CG-003 | Em Na | Caregiver | Quota exhausted (10/10) |

### 4.2 Connection Fixtures
| ID | Patient | Caregiver | Relationship | Permission #6 |
|:--:|:-------:|:---------:|:------------:|:-------------:|
| CONN-001 | USER-PT-001 | USER-CG-001 | daughter | ✅ ON |
| CONN-002 | USER-PT-001 | USER-CG-002 | son | ❌ OFF |
| CONN-003 | USER-PT-001 | USER-CG-003 | grandson | ✅ ON |

---

## 5. Business Rule Test Matrix

| BR-ID | Rule | Test Cases | Priority |
|:-----:|------|:----------:|:--------:|
| BR-001 | Max 10 tin/ngày/Patient | 4 | CRITICAL |
| BR-002 | Max 150 Unicode chars | 3 | HIGH |
| BR-003 | Permission #6 required | 3 | CRITICAL |
| BR-004 | No content moderation | 2 | MEDIUM |

---

## 6. API Test Summary

### 6.1 POST /api/v1/encouragements
| Test ID | Scenario | Expected | Priority |
|:-------:|----------|:--------:|:--------:|
| API-ENC-001 | Valid message | 201 Created | HIGH |
| API-ENC-002 | Missing permission #6 | 403 Forbidden | CRITICAL |
| API-ENC-003 | Quota exceeded (10/day) | 429 Too Many | CRITICAL |
| API-ENC-004 | Content > 150 chars | 400 Bad Request | HIGH |
| API-ENC-005 | Empty content | 400 Bad Request | HIGH |
| API-ENC-006 | Invalid patient_id | 404 Not Found | MEDIUM |

### 6.2 GET /api/v1/encouragements
| Test ID | Scenario | Expected | Priority |
|:-------:|----------|:--------:|:--------:|
| API-ENC-007 | List 24h messages | 200 OK | HIGH |
| API-ENC-008 | Empty list | 200 OK (empty) | MEDIUM |
| API-ENC-009 | Unauthorized | 401 Unauthorized | HIGH |

### 6.3 POST /api/v1/encouragements/mark-read
| Test ID | Scenario | Expected | Priority |
|:-------:|----------|:--------:|:--------:|
| API-ENC-010 | Mark batch read | 200 OK | HIGH |
| API-ENC-011 | Empty array | 400 Bad Request | MEDIUM |
| API-ENC-012 | Invalid IDs | 404/partial | MEDIUM |

### 6.4 GET /api/v1/encouragements/quota
| Test ID | Scenario | Expected | Priority |
|:-------:|----------|:--------:|:--------:|
| API-ENC-013 | Check quota | 200 OK | HIGH |
| API-ENC-014 | Missing patientId | 400 Bad Request | MEDIUM |

---

## 7. Unit Test Summary by Service

### 7.1 user-service (24 tests)

| Class | Method | Tests | Focus |
|-------|--------|:-----:|-------|
| EncouragementServiceImpl | createEncouragement | 8 | Quota, permission, validation |
| EncouragementServiceImpl | getEncouragementList | 4 | 24h filter, sort DESC |
| EncouragementServiceImpl | markAsRead | 4 | Batch update, ownership |
| EncouragementServiceImpl | getQuota | 4 | Daily count, reset |
| EncouragementKafkaProducer | publish | 4 | Event format, retry |

### 7.2 api-gateway (8 tests)

| Class | Method | Tests | Focus |
|-------|--------|:-----:|-------|
| EncouragementHandler | createEncouragement | 3 | DTO validation, gRPC call |
| EncouragementHandler | getEncouragementList | 2 | Query params, pagination |
| EncouragementHandler | markAsRead | 2 | Batch body parsing |
| EncouragementHandler | getQuota | 1 | Query param patientId |

### 7.3 schedule-service (6 tests)

| Module | Function | Tests | Focus |
|--------|----------|:-----:|-------|
| encouragement_consumer | handle_event | 3 | Event parsing, FCM call |
| send_notification | send_encouragement_push | 3 | Template, deeplink |

---

## 8. Coverage Matrix

| Requirement | Test IDs | Coverage |
|-------------|----------|:--------:|
| BR-001 (Quota) | API-ENC-003, UT-SVC-001~004 | 100% |
| BR-002 (150 chars) | API-ENC-004~005, UT-SVC-005~007 | 100% |
| BR-003 (Permission) | API-ENC-002, UT-SVC-008~010 | 100% |
| BR-004 (No moderation) | UT-SVC-011~012 | 100% |
| API Create | API-ENC-001~006 | 100% |
| API List | API-ENC-007~009 | 100% |
| API Mark Read | API-ENC-010~012 | 100% |
| API Quota | API-ENC-013~014 | 100% |
| Push Notification | UT-SCH-001~006 | 100% |

**Overall Coverage: 100%** ✅

---

## 9. Next Steps

1. Generate detailed unit test specs → `unit-tests/backend-tests.md`
2. Generate API test specs → `unit-tests/api-tests.md`
3. Create test data fixtures → `test-data.md`
