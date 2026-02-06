# Test Plan: US 1.2 - Xem Kết Quả Tuân Thủ

> **Version:** 1.0  
> **Date:** 2026-02-05  
> **Author:** Test Engineer Agent  
> **Coverage Target:** ≥85%

---

## Executive Summary

| Metric | Value |
|--------|:-----:|
| Total Test Cases | 42 |
| Unit Tests | 28 |
| Integration Tests | 10 |
| E2E Tests | 4 |
| Estimated Effort | 12h |

---

## 1. Test Strategy

### 1.1 Approach

```
┌──────────────────────────────────────────────────────────────────┐
│                      TEST PYRAMID                                 │
├──────────────────────────────────────────────────────────────────┤
│                         ╱╲                                        │
│                        ╱  ╲   E2E (4) - Manual/Browser tests     │
│                       ╱────╲                                      │
│                      ╱      ╲  Integration (10) - API tests       │
│                     ╱────────╲                                    │
│                    ╱          ╲ Unit (28) - Service/Handler       │
│                   ╱────────────╲                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 1.2 Test Frameworks

| Service | Unit Test | Integration | Mock |
|---------|-----------|-------------|------|
| user-service | JUnit 5 + Mockito | Vert.x WebClient | WireMock |
| api-gateway | JUnit 5 + Mockito | Vert.x WebClient | WireMock |
| app-mobile-ai | Jest + Testing Library | Detox (optional) | MSW |

---

## 2. Unit Test Plan

### 2.1 user-service (12 test cases)

#### CaregiverComplianceServiceImplTest

| # | Test Case | Category | Priority |
|:-:|-----------|----------|:--------:|
| 1 | `shouldReturnDailySummary_WhenPermissionGranted` | Happy Path | P0 |
| 2 | `shouldReturnPermissionDenied_WhenPermissionOff` | Security | P0 |
| 3 | `shouldThrowError_WhenNoActiveConnection` | Edge Case | P0 |
| 4 | `shouldReturnEmptyBP_WhenNoRecordsToday` | Empty State | P1 |
| 5 | `shouldReturnBPHistory_WhenPermissionGranted` | Happy Path | P0 |
| 6 | `shouldReturnMedications_WhenPermissionGranted` | Happy Path | P0 |
| 7 | `shouldReturnCheckups_WhenPermissionGranted` | Happy Path | P0 |
| 8 | `shouldFilterByDate_WhenDateProvided` | Filter | P1 |
| 9 | `shouldUseToday_WhenNoDateProvided` | Default | P1 |
| 10 | `shouldReturnRelationship_InPatientInfo` | BR-CG-014 | P0 |
| 11 | `shouldAuditLog_OnDataAccess` | BR-CG-013 | P1 |
| 12 | `shouldReturnCheckupStatus_PerBR-CG-016` | Business Rule | P0 |

#### CaregiverComplianceGrpcServiceTest

| # | Test Case | Category | Priority |
|:-:|-----------|----------|:--------:|
| 13 | `shouldMapProtoRequest_ToServiceCall` | Mapping | P1 |
| 14 | `shouldReturnGrpcCode_OnServiceError` | Error | P1 |

---

### 2.2 api-gateway-service (8 test cases)

#### CaregiverComplianceHandlerTest

| # | Test Case | Category | Priority |
|:-:|-----------|----------|:--------:|
| 15 | `shouldCallUserService_WithCorrectParams` | Integration | P0 |
| 16 | `shouldExtractCaregiverId_FromJWT` | Auth | P0 |
| 17 | `shouldValidatePatientId_PathParam` | Validation | P1 |
| 18 | `shouldReturn401_WhenNoToken` | Security | P0 |
| 19 | `shouldReturn404_WhenPatientNotFound` | Error | P1 |
| 20 | `shouldReturn200_WithDailySummary` | Happy Path | P0 |
| 21 | `shouldReturn200_WithPermissionDenied` | Permission | P0 |
| 22 | `shouldPassDateParam_WhenProvided` | Query Param | P1 |

---

### 2.3 app-mobile-ai (8 test cases)

#### CaregiverComplianceDashboardScreen.test.tsx

| # | Test Case | Category | Priority |
|:-:|-----------|----------|:--------:|
| 23 | `renders3Blocks_WhenPermissionGranted` | Render | P0 |
| 24 | `showsPermissionOverlay_WhenPermissionDenied` | Permission | P0 |
| 25 | `navigatesToBPHistory_WhenBlockTapped` | Navigation | P0 |
| 26 | `displaysLoading_WhileFetching` | UX | P1 |
| 27 | `displaysEmptyState_WhenNoData` | Empty | P1 |

#### CaregiverContextHeader.test.tsx

| # | Test Case | Category | Priority |
|:-:|-----------|----------|:--------:|
| 28 | `displaysRelationship_NotTitle` | BR-CG-014 | P0 |
| 29 | `displaysPatientAvatar_AndName` | Render | P1 |
| 30 | `acceptsPatientInfo_AsProps` | Props | P1 |

---

## 3. Integration Test Plan

### 3.1 API Integration Tests (10 test cases)

| # | Test Case | Endpoint | Priority |
|:-:|-----------|----------|:--------:|
| 31 | `GET_DailySummary_Returns200_ValidData` | daily-summary | P0 |
| 32 | `GET_DailySummary_Returns200_PermissionDenied` | daily-summary | P0 |
| 33 | `GET_DailySummary_Returns401_NoToken` | daily-summary | P0 |
| 34 | `GET_BPHistory_Returns200_ValidData` | blood-pressure | P0 |
| 35 | `GET_BPHistory_WithDate_FiltersCorrectly` | blood-pressure | P1 |
| 36 | `GET_Medications_Returns200_ValidData` | medications | P0 |
| 37 | `GET_Medications_GroupsByTime` | medications | P1 |
| 38 | `GET_Checkups_Returns200_ValidData` | checkups | P0 |
| 39 | `GET_Checkups_FiltersPast5Days` | checkups | P1 |
| 40 | `GET_Checkups_ReturnsStatusTags` | checkups | P1 |

---

## 4. E2E Test Plan

### 4.1 Manual E2E Tests (4 test cases)

| # | Test Case | Flow | Priority |
|:-:|-----------|------|:--------:|
| 41 | E2E-001: Full Dashboard Flow | Login → Dashboard → All 3 blocks → Drill-down → Back | P0 |
| 42 | E2E-002: Permission Denied Flow | Toggle Permission OFF → Dashboard → Verify Overlay | P0 |
| 43 | E2E-003: Empty State Flow | New Patient → Dashboard → Verify Empty Messages | P1 |
| 44 | E2E-004: Date Navigation Flow | BP History → Change Date → Verify Data Update | P1 |

---

## 5. Test Data Requirements

### 5.1 Users

| ID | Role | Purpose |
|----|------|---------|
| caregiver-001 | Caregiver | Active connection with permission |
| caregiver-002 | Caregiver | Active connection without permission |
| caregiver-003 | Caregiver | No connection |
| patient-001 | Patient | Has BP, Med, Checkup data |
| patient-002 | Patient | Empty data |

### 5.2 Data Records

| Table | Records Needed |
|-------|----------------|
| connections | 2 (active, inactive) |
| connection_permissions | 2 (ON, OFF) |
| blood_pressure_records | 5 (mixed dates) |
| user_medication_feedback | 6 (Sáng, Trưa, Tối) |
| re_examination_event | 4 (upcoming, past) |

---

## 6. Coverage Matrix Reference

See: `05_coverage/coverage-matrix.md`

---

## 7. Test Execution Schedule

| Phase | Tests | Effort | When |
|:-----:|-------|:------:|------|
| 1 | Unit Tests (28) | 6h | Sprint Week 1 |
| 2 | Integration Tests (10) | 4h | Sprint Week 1 |
| 3 | E2E Tests (4) | 2h | Sprint Week 2 |

---

## 8. Test Commands

### user-service
```bash
cd user-service
mvn test -Dtest="*CaregiverCompliance*"
```

### api-gateway-service
```bash
cd api-gateway-service
mvn test -Dtest="*CaregiverCompliance*"
```

### app-mobile-ai
```bash
cd app-mobile-ai
npm run test -- --testPathPattern="caregiver_compliance"
```

---

## 9. Exit Criteria

| Criteria | Target | Actual |
|----------|:------:|:------:|
| Unit Test Coverage | ≥85% | TBD |
| Integration Tests Pass | 100% | TBD |
| P0 Tests Pass | 100% | TBD |
| No Critical Bugs | 0 | TBD |
