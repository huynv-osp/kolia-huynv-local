# Implementation Plan: US 1.2 - Xem Kết Quả Tuân Thủ

> **Final Implementation Guide**  
> **Version:** 1.0  
> **Date:** 2026-02-05  
> **Effort:** 76 hours (~2 weeks)

---

## Quick Reference

| Service | Tasks | Hours | Dependency |
|---------|:-----:|:-----:|:----------:|
| **user-service** | 6 | 16h | None |
| **api-gateway** | 4 | 12h | user-service |
| **app-mobile-ai** | 8 | 48h | api-gateway |

---

## Phase 1: Backend - user-service (16h)

### Step 1.1: Proto Definitions (2h)

**File:** `proto/user_service.proto`

```protobuf
// Add to existing service definition

// ===== US 1.2 Caregiver Compliance =====
rpc GetPatientDailySummary(GetPatientDailySummaryRequest) 
    returns (GetPatientDailySummaryResponse);
rpc GetPatientBPHistory(GetPatientBPHistoryRequest) 
    returns (GetPatientBPHistoryResponse);
rpc GetPatientMedications(GetPatientMedicationsRequest) 
    returns (GetPatientMedicationsResponse);
rpc GetPatientCheckups(GetPatientCheckupsRequest) 
    returns (GetPatientCheckupsResponse);

// ===== Messages =====
message GetPatientDailySummaryRequest {
    string caregiver_id = 1;
    string patient_id = 2;
    string date = 3; // YYYY-MM-DD, optional
}

message GetPatientDailySummaryResponse {
    bool has_permission = 1;
    string permission_message = 2;
    PatientInfo patient_info = 3;
    BloodPressureSummary bp_summary = 4;
    MedicationSummary med_summary = 5;
    CheckupSummary checkup_summary = 6;
}

// ... (similar patterns for other 3 methods)
```

**Command:** 
```bash
cd user-service && mvn generate-sources
```

---

### Step 1.2: Service Interface (1h)

**File:** `service/CaregiverComplianceService.java` [NEW]

```java
package com.userservice.service;

public interface CaregiverComplianceService {
    Future<GetPatientDailySummaryResponse> getPatientDailySummary(
        String caregiverId, String patientId, String date);
    Future<GetPatientBPHistoryResponse> getPatientBPHistory(
        String caregiverId, String patientId, String date);
    Future<GetPatientMedicationsResponse> getPatientMedications(
        String caregiverId, String patientId, String date);
    Future<GetPatientCheckupsResponse> getPatientCheckups(
        String caregiverId, String patientId);
}
```

---

### Step 1.3: Service Implementation (8h) ⭐ CRITICAL

**File:** `service/impl/CaregiverComplianceServiceImpl.java` [NEW]

**Key Implementation Points:**
1. Check Permission #4 via `permissionService.hasPermission()`
2. Return `has_permission = false` if Permission OFF
3. Fetch data from existing repositories
4. Override `{userTitle}` → `{relationship}`
5. Add audit log với `caregiver_id`

**Clone Pattern từ:** `CaregiverAlertServiceImpl.java`

```java
@Override
public Future<GetPatientDailySummaryResponse> getPatientDailySummary(
        String caregiverId, String patientId, String date) {
    
    return connectionRepository.findActiveConnection(caregiverId, patientId)
        .compose(connection -> {
            if (connection == null) {
                return Future.failedFuture("Connection not found");
            }
            return permissionService.hasPermission(
                connection.getId(), 
                PermissionType.COMPLIANCE_TRACKING // Permission #4
            ).compose(hasPermission -> {
                if (!hasPermission) {
                    return Future.succeededFuture(
                        GetPatientDailySummaryResponse.newBuilder()
                            .setHasPermission(false)
                            .setPermissionMessage("Người thân chưa cho phép xem")
                            .build()
                    );
                }
                return fetchDailySummary(connection, patientId, date);
            });
        });
}
```

---

### Step 1.4: gRPC Handler (3h)

**File:** `grpc/CaregiverComplianceGrpcService.java` [NEW]

**Clone Pattern từ:** `CaregiverAlertGrpcService.java`

---

### Step 1.5: Register Service (0.5h)

**File:** `MainVerticle.java` [MODIFY]

```java
// Add to gRPC service registration
services.add(new CaregiverComplianceGrpcService(caregiverComplianceService));
```

---

### Step 1.6: Unit Tests (1.5h)

**File:** `test/service/CaregiverComplianceServiceImplTest.java` [NEW]

**Test Cases:**
- ✅ Permission ON → Return data
- ❌ Permission OFF → Return denied
- ❌ No connection → Error
- ❌ Invalid patientId → Error

---

## Phase 2: Backend - api-gateway-service (12h)

### Step 2.1: DTOs (2h)

**Files:** [NEW]
- `dto/response/PatientDailySummaryResponse.java`
- `dto/response/PatientBPHistoryResponse.java`
- `dto/response/PatientMedicationsResponse.java`
- `dto/response/PatientCheckupsResponse.java`

---

### Step 2.2: gRPC Client (3h)

**File:** `client/grpc/CaregiverComplianceClient.java` [NEW]

**Clone Pattern từ:** `CaregiverAlertClient.java`

---

### Step 2.3: Handler (5h) ⭐ CRITICAL

**File:** `handler/CaregiverComplianceHandler.java` [NEW]

```java
@Inject
public CaregiverComplianceHandler(CaregiverComplianceClient client) {
    this.client = client;
}

public void getPatientDailySummary(RoutingContext ctx) {
    String caregiverId = AuthUtil.getUserId(ctx);
    String patientId = ctx.pathParam("patientId");
    String date = ctx.queryParams().get("date"); // optional
    
    client.getPatientDailySummary(caregiverId, patientId, date)
        .onSuccess(response -> ResponseUtil.success(ctx, response))
        .onFailure(err -> ResponseUtil.error(ctx, err));
}

// Similar for other 3 methods...
```

---

### Step 2.4: Routes (2h)

**File:** `verticles/HttpServerVerticle.java` [MODIFY]

```java
// Add to setupCaregiverRoutes() or create new section
private void setupCaregiverComplianceRoutes(Router router) {
    router.get("/v1/patients/:patientId/daily-summary")
        .handler(complianceHandler::getPatientDailySummary);
    router.get("/v1/patients/:patientId/blood-pressure")
        .handler(complianceHandler::getPatientBPHistory);
    router.get("/v1/patients/:patientId/medications")
        .handler(complianceHandler::getPatientMedications);
    router.get("/v1/patients/:patientId/checkups")
        .handler(complianceHandler::getPatientCheckups);
}
```

---

## Phase 3: Mobile - app-mobile-ai (48h)

### Step 3.1: Service Layer (3h)

**File:** `shared/services/caregiverCompliance.service.ts` [NEW]

```typescript
export const caregiverComplianceService = {
  getPatientDailySummary: (patientId: string, date?: string) =>
    apiClient.get(`/patients/${patientId}/daily-summary`, { params: { date } }),
  
  getPatientBPHistory: (patientId: string, date: string) =>
    apiClient.get(`/patients/${patientId}/blood-pressure`, { params: { date } }),
  
  getPatientMedications: (patientId: string, date: string) =>
    apiClient.get(`/patients/${patientId}/medications`, { params: { date } }),
  
  getPatientCheckups: (patientId: string) =>
    apiClient.get(`/patients/${patientId}/checkups`),
};
```

---

### Step 3.2: Shared Components (5h)

**Files:** [NEW]
- `features/caregiver_compliance/components/CaregiverContextHeader.tsx`
- `features/caregiver_compliance/components/PermissionDeniedOverlay.tsx`

---

### Step 3.3: Dashboard Screen (10h) ⭐ CRITICAL

**File:** `features/caregiver_compliance/screens/CaregiverComplianceDashboardScreen.tsx` [NEW]

**Clone từ:** `features/heartbeat_bulletin/screens/HeartbeatBulletinScreen.tsx`

**Clone Strategy:**
```
❌ DELETE: SmartKolia, TourProvider, Add buttons, Bottom action row
✅ KEEP: 3 Blocks (HA, Thuốc, Tái khám), Loading states, Empty states
➕ ADD: Permission #4 check, patientId param, agents-service call
⚙️ MODIFY: {userTitle} → {relationship}
```

---

### Step 3.4-3.6: Drill-down Screens (24h)

**Files:** [NEW]
- `CaregiverBPHistoryScreen.tsx` (8h) - Clone từ BloodPressureMissionScreen
- `CaregiverMedicationScheduleScreen.tsx` (8h) - Clone từ MedicationMissionScreen
- `CaregiverCheckupListScreen.tsx` (8h) - Clone từ ReExamScheduleScreen

**Common Clone Strategy:**
```
❌ DELETE: All action handlers (add, edit, delete, feedback)
✅ KEEP: List views, Date picker, Status icons
➕ ADD: CaregiverContextHeader, patientId param
⚙️ MODIFY: Remove header action icons (BR-CG-020)
```

---

### Step 3.7: Navigation (2h)

**File:** `navigation/AppNavigator.tsx` [MODIFY]

```typescript
<Stack.Screen 
  name="CaregiverComplianceDashboard" 
  component={CaregiverComplianceDashboardScreen} 
/>
<Stack.Screen 
  name="CaregiverBPHistory" 
  component={CaregiverBPHistoryScreen} 
/>
<Stack.Screen 
  name="CaregiverMedicationSchedule" 
  component={CaregiverMedicationScheduleScreen} 
/>
<Stack.Screen 
  name="CaregiverCheckupList" 
  component={CaregiverCheckupListScreen} 
/>
```

---

### Step 3.8: Integration Testing (4h)

**Test Scenarios:**
1. Permission ON: Full flow Dashboard → Drill-down → Back
2. Permission OFF: Show PermissionDeniedOverlay
3. Empty states: No data scenarios
4. Error states: Network error handling

---

## Verification Plan

### 1. Unit Tests (Automated)

**user-service:**
```bash
cd user-service
mvn test -Dtest=CaregiverComplianceServiceImplTest
```

**Expected:** All 4 test cases pass

---

### 2. API Integration Test (Manual)

**Prerequisites:**
- Caregiver và Patient đã kết nối với Permission #4 ON

**Test Steps:**

```bash
# 1. Get JWT token for caregiver
export TOKEN="<caregiver_jwt_token>"

# 2. Test Daily Summary API
curl -X GET "http://localhost:8080/v1/patients/{patientId}/daily-summary" \
  -H "Authorization: Bearer $TOKEN"

# Expected: 200 with has_permission: true and data

# 3. Test with Permission OFF (update in DB first)
# Expected: 200 with has_permission: false
```

---

### 3. Mobile E2E Test (Manual)

**Prerequisites:**
- App running với valid caregiver account
- Patient có BP, Medication, Checkup data

**Test Flow:**
1. Login as Caregiver
2. Select Patient from Profile Selector
3. Navigate to Compliance Dashboard
4. Verify 3 blocks display correctly
5. Tap each block → Verify drill-down screen
6. Check Context Header shows correct {Mối quan hệ}
7. Verify no action buttons visible

---

## Rollback Procedure

```bash
# If rollback needed:

# 1. user-service
git checkout -- proto/user_service.proto
rm -rf service/CaregiverCompliance*
rm -rf grpc/CaregiverComplianceGrpcService.java

# 2. api-gateway-service
rm -rf handler/CaregiverComplianceHandler.java
rm -rf dto/response/Patient*Response.java
rm -rf client/grpc/CaregiverComplianceClient.java

# 3. app-mobile-ai
rm -rf features/caregiver_compliance/

# Rebuild and restart services
```

---

## Checklist Before Merge

- [ ] All unit tests pass
- [ ] All 4 APIs return correct data
- [ ] Mobile screens render correctly
- [ ] Permission #4 check works (ON/OFF)
- [ ] Context Header shows {Mối quan hệ}
- [ ] No action buttons on drill-down screens
- [ ] Swagger documentation updated
- [ ] No console errors on mobile

---

## References

| Document | Path |
|----------|------|
| SRS v2.5 | [srs-xem-ket-qua-tuan-thu.md](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/srs_input_documents/srs-xem-ket-qua-tuan-thu.md) |
| SA Analysis | [docs/nguoi_than/sa-analysis/us12-xem-ket-qua-tuan-thu/](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/us12-xem-ket-qua-tuan-thu/) |
| Implementation Tasks | [implementation-tasks.md](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/features/us12-xem-ket-qua-tuan-thu/02_planning/implementation-tasks.md) |

