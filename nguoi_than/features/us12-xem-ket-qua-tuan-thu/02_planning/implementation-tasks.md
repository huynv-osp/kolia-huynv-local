# Implementation Tasks: US 1.2 - Xem Kết Quả Tuân Thủ

> **Feature Analysis Phase 5: Task Generation (FA-002, FA-003)**  
> **Date:** 2026-02-05  
> **Total Effort:** 76 hours

---

## Task Summary

| Service | Tasks | Hours | Priority |
|---------|:-----:|:-----:|:--------:|
| user-service | 6 | 16h | P0 |
| api-gateway-service | 4 | 12h | P0 |
| app-mobile-ai | 8 | 48h | P0 |
| **TOTAL** | **18** | **76h** | |

---

## user-service Tasks (16h)

### TASK-US-001: Proto Definitions ⭐

| Attribute | Value |
|-----------|-------|
| **Priority** | P0 |
| **Effort** | 2h |
| **Dependencies** | None |

**Description:** Add 4 RPC methods và message definitions cho Caregiver Compliance

**Technical Scope:**
- [ ] `proto/user_service.proto`: Add 4 RPC methods
  - `GetPatientDailySummary`
  - `GetPatientBPHistory`
  - `GetPatientMedications`
  - `GetPatientCheckups`
- [ ] Add 8 message types (Request/Response)
- [ ] Generate Java stubs: `mvn generate-sources`

**Acceptance Criteria:**
- [ ] Proto compiles without errors
- [ ] All 8 message types generated
- [ ] IDE recognizes generated classes

---

### TASK-US-002: Service Interface

| Attribute | Value |
|-----------|-------|
| **Priority** | P0 |
| **Effort** | 1h |
| **Dependencies** | TASK-US-001 |

**Description:** Create CaregiverComplianceService interface

**Technical Scope:**
- [ ] `service/CaregiverComplianceService.java` [NEW]
  - `getPatientDailySummary()`
  - `getPatientBPHistory()`
  - `getPatientMedications()`
  - `getPatientCheckups()`

**Acceptance Criteria:**
- [ ] Interface với 4 methods defined
- [ ] Javadoc cho mỗi method

---

### TASK-US-003: Service Implementation ⭐

| Attribute | Value |
|-----------|-------|
| **Priority** | P0 |
| **Effort** | 8h |
| **Dependencies** | TASK-US-002 |

**Description:** Implement business logic với Permission #4 check

**Technical Scope:**
- [ ] `service/impl/CaregiverComplianceServiceImpl.java` [NEW]
  - Permission #4 check via PermissionService
  - Reuse existing repositories (BloodPressureRepository, etc.)
  - {Danh xưng} → {Mối quan hệ} logic
  - Audit log với caregiver_id

**Code Pattern:**
```java
@Override
public Future<GetPatientDailySummaryResponse> getPatientDailySummary(
        String caregiverId, String patientId, String date) {
    return permissionService.hasPermission(
            caregiverId, patientId, PermissionType.COMPLIANCE_TRACKING)
        .compose(hasPermission -> {
            if (!hasPermission) {
                return buildPermissionDeniedResponse();
            }
            return fetchDailySummary(patientId, date);
        });
}
```

**Acceptance Criteria:**
- [ ] Permission #4 check works correctly
- [ ] PermissionDenied response khi OFF
- [ ] Data fetched correctly khi ON
- [ ] Unit tests pass

---

### TASK-US-004: gRPC Handler

| Attribute | Value |
|-----------|-------|
| **Priority** | P0 |
| **Effort** | 3h |
| **Dependencies** | TASK-US-003 |

**Description:** Create gRPC handler để expose service

**Technical Scope:**
- [ ] `grpc/CaregiverComplianceGrpcService.java` [NEW]
  - Map proto requests → service calls
  - Error handling với proper gRPC codes

**Acceptance Criteria:**
- [ ] 4 RPC methods exposed
- [ ] Error codes handled correctly

---

### TASK-US-005: Register gRPC Service

| Attribute | Value |
|-----------|-------|
| **Priority** | P0 |
| **Effort** | 0.5h |
| **Dependencies** | TASK-US-004 |

**Description:** Register service trong MainVerticle

**Technical Scope:**
- [ ] `MainVerticle.java` [MODIFY]: Add service binding

**Acceptance Criteria:**
- [ ] Service registered at startup
- [ ] gRPC calls routed correctly

---

### TASK-US-006: Unit Tests

| Attribute | Value |
|-----------|-------|
| **Priority** | P1 |
| **Effort** | 1.5h |
| **Dependencies** | TASK-US-003, TASK-US-004 |

**Description:** Unit tests cho service và gRPC handler

**Technical Scope:**
- [ ] `test/service/CaregiverComplianceServiceTest.java` [NEW]
- [ ] `test/grpc/CaregiverComplianceGrpcServiceTest.java` [NEW]

**Test Cases:**
- [ ] Permission ON → Return data
- [ ] Permission OFF → Return denied
- [ ] Invalid patientId → Error
- [ ] No connection → Error

---

## api-gateway-service Tasks (12h)

### TASK-GW-001: DTOs

| Attribute | Value |
|-----------|-------|
| **Priority** | P0 |
| **Effort** | 2h |
| **Dependencies** | TASK-US-001 |

**Description:** Create Request/Response DTOs

**Technical Scope:**
- [ ] `dto/request/PatientComplianceRequest.java` [NEW]
- [ ] `dto/response/PatientDailySummaryResponse.java` [NEW]
- [ ] `dto/response/PatientBPHistoryResponse.java` [NEW]
- [ ] `dto/response/PatientMedicationsResponse.java` [NEW]
- [ ] `dto/response/PatientCheckupsResponse.java` [NEW]

**Acceptance Criteria:**
- [ ] All DTOs with Jackson annotations
- [ ] Nested DTOs for complex structures

---

### TASK-GW-002: gRPC Client

| Attribute | Value |
|-----------|-------|
| **Priority** | P0 |
| **Effort** | 3h |
| **Dependencies** | TASK-US-001, TASK-GW-001 |

**Description:** Create gRPC client cho user-service

**Technical Scope:**
- [ ] `client/grpc/CaregiverComplianceClient.java` [NEW]
  - 4 async methods
  - Error handling với Future

**Acceptance Criteria:**
- [ ] All 4 methods implemented
- [ ] Proto-to-DTO mapping works

---

### TASK-GW-003: Handler ⭐

| Attribute | Value |
|-----------|-------|
| **Priority** | P0 |
| **Effort** | 5h |
| **Dependencies** | TASK-GW-002 |

**Description:** REST handler với 4 endpoints

**Technical Scope:**
- [ ] `handler/CaregiverComplianceHandler.java` [NEW]
  - `getPatientDailySummary()`
  - `getPatientBPHistory()`
  - `getPatientMedications()`
  - `getPatientCheckups()`
- [ ] Extract caregiverId from JWT
- [ ] Validate patientId param

**Code Pattern:**
```java
public void getPatientDailySummary(RoutingContext ctx) {
    String caregiverId = AuthUtil.getUserId(ctx);
    String patientId = ctx.pathParam("patientId");
    String date = ctx.queryParams().get("date");
    
    caregiverComplianceClient.getPatientDailySummary(caregiverId, patientId, date)
        .onSuccess(res -> ResponseUtil.success(ctx, res))
        .onFailure(err -> ResponseUtil.error(ctx, err));
}
```

**Acceptance Criteria:**
- [ ] All 4 endpoints work
- [ ] JWT auth required
- [ ] Proper error responses

---

### TASK-GW-004: Routes

| Attribute | Value |
|-----------|-------|
| **Priority** | P0 |
| **Effort** | 2h |
| **Dependencies** | TASK-GW-003 |

**Description:** Register routes trong HttpServerVerticle

**Technical Scope:**
- [ ] `verticles/HttpServerVerticle.java` [MODIFY]
  - Add 4 GET routes với JWT auth
  
**Routes:**
```java
router.get("/v1/patients/:patientId/daily-summary").handler(complianceHandler::getPatientDailySummary);
router.get("/v1/patients/:patientId/blood-pressure").handler(complianceHandler::getPatientBPHistory);
router.get("/v1/patients/:patientId/medications").handler(complianceHandler::getPatientMedications);
router.get("/v1/patients/:patientId/checkups").handler(complianceHandler::getPatientCheckups);
```

**Acceptance Criteria:**
- [ ] Routes registered
- [ ] API docs updated (Swagger)

---

## app-mobile-ai Tasks (48h)

### TASK-FE-001: Service Layer

| Attribute | Value |
|-----------|-------|
| **Priority** | P0 |
| **Effort** | 3h |
| **Dependencies** | TASK-GW-004 |

**Description:** Create caregiverCompliance.service.ts

**Technical Scope:**
- [ ] `shared/services/caregiverCompliance.service.ts` [NEW]
  - `getPatientDailySummary(patientId)`
  - `getPatientBPHistory(patientId, date)`
  - `getPatientMedications(patientId, date)`
  - `getPatientCheckups(patientId)`

**Acceptance Criteria:**
- [ ] All 4 API calls implemented
- [ ] TypeScript types defined
- [ ] Error handling

---

### TASK-FE-002: Shared Components

| Attribute | Value |
|-----------|-------|
| **Priority** | P0 |
| **Effort** | 5h |
| **Dependencies** | None |

**Description:** Create shared components cho Caregiver screens

**Technical Scope:**
- [ ] `features/caregiver_compliance/components/CaregiverContextHeader.tsx` [NEW]
  - Avatar + Name + Relationship
  - Clone từ ConnectionCard style
- [ ] `features/caregiver_compliance/components/PermissionDeniedOverlay.tsx` [NEW]
  - Lock icon + Message + Settings button

**Acceptance Criteria:**
- [ ] Components render correctly
- [ ] Follows design system
- [ ] {Mối quan hệ} displayed correctly

---

### TASK-FE-003: Dashboard Screen ⭐

| Attribute | Value |
|-----------|-------|
| **Priority** | P0 |
| **Effort** | 10h |
| **Dependencies** | TASK-FE-001, TASK-FE-002 |

**Description:** Clone HeartbeatBulletinScreen cho Caregiver

**Technical Scope:**
- [ ] `features/caregiver_compliance/screens/CaregiverComplianceDashboardScreen.tsx` [NEW]
- Clone từ: `features/heartbeat_bulletin/screens/HeartbeatBulletinScreen.tsx`

**Clone Strategy:**
```
❌ DELETE:
- SmartKolia component
- TourProvider wrapper
- Add buttons (all onPress handlers)
- Bottom action row

✅ KEEP:
- 3 Blocks (HA, Thuốc, Tái khám)
- Loading/Error states
- Empty states

➕ ADD:
- Permission #4 check
- patientId parameter từ navigation
- CaregiverContextHeader (ở drill-down)

⚙️ MODIFY:
- {userTitle} → {relationship}
- Block titles unchanged (Vietnamese)
```

**Acceptance Criteria:**
- [ ] Permission OFF → PermissionDeniedOverlay
- [ ] Permission ON → 3 blocks hiển thị
- [ ] Tap block → Navigate đúng screen
- [ ] agents-service call works (AI insight)

---

### TASK-FE-004: BP History Screen

| Attribute | Value |
|-----------|-------|
| **Priority** | P0 |
| **Effort** | 8h |
| **Dependencies** | TASK-FE-001, TASK-FE-002 |

**Description:** Clone BloodPressureMissionScreen

**Technical Scope:**
- [ ] `features/caregiver_compliance/screens/CaregiverBPHistoryScreen.tsx` [NEW]
- Clone từ: `features/missions_check_in/blood_pressure/`

**Clone Strategy:**
```
❌ DELETE:
- handleAddBloodPressure()
- handleSetSchedule()
- Guide modal
- Action icons in header (BR-CG-020)

✅ KEEP:
- HorizontalDatePicker
- FlatList với BP records
- BloodPressureInputCard (view mode only)

➕ ADD:
- CaregiverContextHeader với patient info
```

**Acceptance Criteria:**
- [ ] List BP records for selected date
- [ ] Context Header shows patient info
- [ ] View-only (no edit buttons)
- [ ] Date picker navigation works

---

### TASK-FE-005: Medication Schedule Screen

| Attribute | Value |
|-----------|-------|
| **Priority** | P0 |
| **Effort** | 8h |
| **Dependencies** | TASK-FE-001, TASK-FE-002 |

**Description:** Clone MedicationMissionScreen

**Technical Scope:**
- [ ] `features/caregiver_compliance/screens/CaregiverMedicationScheduleScreen.tsx` [NEW]
- Clone từ: `features/missions_check_in/medication/`

**Clone Strategy:**
```
❌ DELETE:
- handleMedicationFeedback()
- Coin modal
- Action buttons

✅ KEEP:
- Time grouping (Sáng, Trưa, Chiều, Tối)
- Status icons (✅, ➖, ❌)
- Date picker

➕ ADD:
- CaregiverContextHeader
```

**Acceptance Criteria:**
- [ ] Show medication schedule by time group
- [ ] View-only mode
- [ ] Status icons correct

---

### TASK-FE-006: Checkup List Screen

| Attribute | Value |
|-----------|-------|
| **Priority** | P0 |
| **Effort** | 8h |
| **Dependencies** | TASK-FE-001, TASK-FE-002 |

**Description:** Clone ReExamScheduleScreen

**Technical Scope:**
- [ ] `features/caregiver_compliance/screens/CaregiverCheckupListScreen.tsx` [NEW]
- Clone từ: `features/checkup_management/screens/`

**Clone Strategy:**
```
❌ DELETE:
- handleAddCheckup()
- Edit button
- Delete actions

✅ KEEP:
- Tab switcher (Sắp tới, Đã qua)
- Checkup cards
- Status tags (BR-CG-016)

➕ ADD:
- CaregiverContextHeader
- 5-day retention logic (BR-CG-017)
```

**Acceptance Criteria:**
- [ ] Tab navigation works
- [ ] Status tags correct
- [ ] Overdue items shown (5 days)

---

### TASK-FE-007: Navigation Routes

| Attribute | Value |
|-----------|-------|
| **Priority** | P0 |
| **Effort** | 2h |
| **Dependencies** | TASK-FE-003 → TASK-FE-006 |

**Description:** Add navigation routes

**Technical Scope:**
- [ ] `navigation/AppNavigator.tsx` [MODIFY]
  - Add 4 Stack.Screen entries
  - Define route params

**Acceptance Criteria:**
- [ ] All 4 routes work
- [ ] Deep linking configured
- [ ] Back navigation correct

---

### TASK-FE-008: Integration & Testing

| Attribute | Value |
|-----------|-------|
| **Priority** | P1 |
| **Effort** | 4h |
| **Dependencies** | All TASK-FE-* |

**Description:** E2E testing và integration verification

**Technical Scope:**
- [ ] Test full flow: Dashboard → Drill-down → Back
- [ ] Test Permission ON/OFF scenarios
- [ ] Test empty states
- [ ] Test error states

**Acceptance Criteria:**
- [ ] Full flow works on iOS/Android
- [ ] No console errors
- [ ] Performance acceptable (< 2s load)

---

## Phase 5 Checkpoint

✅ **PHASE 5 COMPLETE** → Proceed to Phase 6 (Dependency Planning)
