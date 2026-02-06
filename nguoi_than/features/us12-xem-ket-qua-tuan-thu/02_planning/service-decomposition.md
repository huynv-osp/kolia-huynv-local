# Service Decomposition: US 1.2 - Xem Kết Quả Tuân Thủ

> **Feature Analysis Phase 4: Service-Level Detailing (FA-002)**  
> **Date:** 2026-02-05  
> **Strategy:** 🛡️ Clone-Based Isolation

---

## Service: api-gateway-service

### Impact Level: 🟢 LOW

### Detailed Changes

| Layer | File Path | Type | Description |
|-------|-----------|:----:|-------------|
| Handler | `handler/CaregiverComplianceHandler.java` | **NEW** | 4 REST endpoints với Permission #4 check |
| DTO | `dto/request/PatientComplianceRequest.java` | **NEW** | Common request params |
| DTO | `dto/response/PatientDailySummaryResponse.java` | **NEW** | Dashboard 3 blocks data |
| DTO | `dto/response/PatientBPHistoryResponse.java` | **NEW** | BP records list |
| DTO | `dto/response/PatientMedicationsResponse.java` | **NEW** | Medication schedule |
| DTO | `dto/response/PatientCheckupsResponse.java` | **NEW** | Checkup list |
| Client | `client/grpc/CaregiverComplianceClient.java` | **NEW** | gRPC client for 4 methods |
| Route | `verticles/HttpServerVerticle.java` | **MODIFY** | Add 4 routes to caregiver section |

### API Endpoints

| Method | Path | gRPC Call | Auth |
|--------|------|-----------|------|
| GET | `/v1/patients/:patientId/daily-summary` | GetPatientDailySummary | Bearer + Permission #4 |
| GET | `/v1/patients/:patientId/blood-pressure` | GetPatientBPHistory | Bearer + Permission #4 |
| GET | `/v1/patients/:patientId/medications` | GetPatientMedications | Bearer + Permission #4 |
| GET | `/v1/patients/:patientId/checkups` | GetPatientCheckups | Bearer + Permission #4 |

### Code Pattern (Clone from CaregiverAlertHandler)

```java
// CaregiverComplianceHandler.java
public void getPatientDailySummary(RoutingContext ctx) {
    String caregiverId = ctx.user().principal().getString("userId");
    String patientId = ctx.pathParam("patientId");
    
    caregiverComplianceClient.getPatientDailySummary(caregiverId, patientId)
        .onSuccess(response -> ctx.json(response))
        .onFailure(err -> handleError(ctx, err));
}
```

### Estimated Effort: 12 hours

---

## Service: user-service

### Impact Level: 🟢 LOW

### Detailed Changes

| Layer | File Path | Type | Description |
|-------|-----------|:----:|-------------|
| Proto | `proto/user_service.proto` | **MODIFY** | Add 4 RPC methods + messages |
| Service | `service/CaregiverComplianceService.java` | **NEW** | Interface |
| Service | `service/impl/CaregiverComplianceServiceImpl.java` | **NEW** | Implementation với Permission check |
| gRPC | `grpc/CaregiverComplianceGrpcService.java` | **NEW** | gRPC handler |
| Verticle | `MainVerticle.java` | **MODIFY** | Register new gRPC service |

### Proto Changes

```protobuf
// user_service.proto additions

// ===== RPC Methods =====
service UserService {
    // Existing methods...
    
    // US 1.2 Caregiver Compliance
    rpc GetPatientDailySummary(GetPatientDailySummaryRequest) 
        returns (GetPatientDailySummaryResponse);
    rpc GetPatientBPHistory(GetPatientBPHistoryRequest) 
        returns (GetPatientBPHistoryResponse);
    rpc GetPatientMedications(GetPatientMedicationsRequest) 
        returns (GetPatientMedicationsResponse);
    rpc GetPatientCheckups(GetPatientCheckupsRequest) 
        returns (GetPatientCheckupsResponse);
}

// ===== Messages =====
message GetPatientDailySummaryRequest {
    string caregiver_id = 1;
    string patient_id = 2;
    string date = 3; // Optional: YYYY-MM-DD, default today
}

message GetPatientDailySummaryResponse {
    bool has_permission = 1;
    PatientInfo patient_info = 2;      // {name, relationship, avatar}
    BloodPressureSummary bp_summary = 3;
    MedicationSummary med_summary = 4;
    CheckupSummary checkup_summary = 5;
}
```

### Service Pattern (Clone from CaregiverAlertServiceImpl)

```java
// CaregiverComplianceServiceImpl.java
@Override
public Future<GetPatientDailySummaryResponse> getPatientDailySummary(
        String caregiverId, String patientId, String date) {
    
    // Step 1: Validate active connection
    return connectionRepository.findActiveConnection(caregiverId, patientId)
        // Step 2: Check Permission #4 (compliance_tracking)
        .compose(conn -> permissionService.hasPermission(
            conn.getId(), PermissionType.COMPLIANCE_TRACKING))
        // Step 3: Fetch data or return permission_denied
        .compose(hasPermission -> {
            if (!hasPermission) {
                return Future.succeededFuture(buildPermissionDeniedResponse());
            }
            return fetchDailySummary(patientId, date);
        });
}
```

### Estimated Effort: 16 hours

---

## Service: app-mobile-ai

### Impact Level: 🟡 MEDIUM

### Detailed Changes

| Layer | File Path | Type | Description |
|-------|-----------|:----:|-------------|
| Screen | `features/caregiver_compliance/screens/CaregiverComplianceDashboardScreen.tsx` | **NEW** | Clone từ HeartbeatBulletinScreen |
| Screen | `features/caregiver_compliance/screens/CaregiverBPHistoryScreen.tsx` | **NEW** | Clone từ BloodPressureMissionScreen |
| Screen | `features/caregiver_compliance/screens/CaregiverMedicationScheduleScreen.tsx` | **NEW** | Clone từ MedicationMissionScreen |
| Screen | `features/caregiver_compliance/screens/CaregiverCheckupListScreen.tsx` | **NEW** | Clone từ ReExamScheduleScreen |
| Component | `features/caregiver_compliance/components/CaregiverContextHeader.tsx` | **NEW** | Patient context header |
| Component | `features/caregiver_compliance/components/PermissionDeniedOverlay.tsx` | **NEW** | Permission #4 OFF overlay |
| Service | `shared/services/caregiverCompliance.service.ts` | **NEW** | 4 API calls |
| Navigation | `navigation/AppNavigator.tsx` | **MODIFY** | Add 4 routes |

### Clone Strategy

```typescript
// Dashboard: Clone từ HeartbeatBulletinScreen
// ❌ DELETE: SmartKolia, TourProvider, Add buttons, Bottom action row
// ✅ KEEP: 3 Blocks (HA, Thuốc, Tái khám), Loading states, Empty states
// ➕ ADD: Permission #4 check, patientId parameter
// ⚙️ MODIFY: {userTitle} → {relationship}

// BP List: Clone từ BloodPressureMissionScreen  
// ❌ DELETE: handleAddBloodPressure(), handleSetSchedule(), Guide modal
// ✅ KEEP: HorizontalDatePicker, FlatList, BloodPressureInputCard (view mode)
// ➕ ADD: CaregiverContextHeader
// ⚙️ MODIFY: BỎ action icons trong header (BR-CG-020)
```

### Navigation Routes

```typescript
// navigation/AppNavigator.tsx
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

### Estimated Effort: 48 hours

---

## Service: agents-service

### Impact Level: 🟢 NONE

**NO CHANGES NEEDED**

Mobile gọi trực tiếp `POST /bp-summary` (reuse từ HeartbeatBulletinScreen).
FE tính toán `bp_in_target = bp_total - bp_high - bp_low` và gửi params.

---

## Database Changes

### Impact Level: 🟢 NONE

**NO SCHEMA CHANGES**

Reuse existing tables với thêm `patientId` filter:

```sql
-- Example: Get BP history for caregiver
SELECT bpr.* FROM blood_pressure_records bpr
WHERE bpr.user_id = :patientId
ORDER BY bpr.measurement_time DESC;
```

---

## Integration Points

| From | To | Protocol | Method | Purpose |
|------|-----|:--------:|--------|---------|
| Mobile | api-gateway | REST | 4 GET endpoints | Compliance data |
| Mobile | agents-service | REST | POST /bp-summary | AI BP insight |
| api-gateway | user-service | gRPC | 4 RPC methods | Data + Permission |
| user-service | PostgreSQL | SQL | Queries | Data access |

---

## Summary

| Service | Impact | New Files | Modified | Effort |
|---------|:------:|:---------:|:--------:|:------:|
| api-gateway-service | 🟢 | 7 | 1 | 12h |
| user-service | 🟢 | 4 | 2 | 16h |
| app-mobile-ai | 🟡 | 7 | 1 | 48h |
| agents-service | 🟢 | 0 | 0 | 0h |
| **TOTAL** | | **18** | **4** | **76h** |

---

## Phase 4 Checkpoint

✅ **PHASE 4 COMPLETE** → Proceed to Phase 5 (Task Generation)
