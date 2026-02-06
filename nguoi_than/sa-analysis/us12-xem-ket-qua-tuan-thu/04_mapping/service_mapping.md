# Service Mapping: US 1.2

> **Format:** SA-002 (Service-Level Impact Detailing)  
> **Strategy:** 🛡️ CLONE-BASED ISOLATION (100% new code, 0% modify existing)  
> **SRS:** v2.5 | **Screens:** 6 | **BRs:** 20 | **Security:** 3

---

## Screen-to-API Mapping

| # | Screen | Clone From | API Endpoint | agents-service |
|:-:|--------|------------|--------------|:--------------:|
| 1 | SCR-CG-DASH (Dashboard) | HeartbeatBulletinScreen | `/patients/:id/daily-summary` | `POST /bp-summary` |
| 2 | SCR-CG-HA-LIST | BloodPressureMissionScreen | `/patients/:id/blood-pressure` | - |
| 3 | SCR-CG-HA-DETAIL | (Reuse existing detail) | (Same as list) | - |
| 4 | SCR-CG-MED-SCHEDULE | MedicationMissionScreen | `/patients/:id/medications` | - |
| 5 | SCR-CG-CHECKUP-LIST | ReExamScheduleScreen | `/patients/:id/checkups` | - |
| 6 | SCR-CG-CHECKUP-DETAIL | (Reuse existing detail) | (Same as list) | - |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│  Mobile: Feature caregiver_compliance/                              │
├─────────────────────────────────────────────────────────────────────┤
│  SCR-CG-DASH ──────────────────────┬──────────────────────────────┐ │
│  (Dashboard - 3 khối VIEW)         │                              │ │
│      │                             │                              │ │
│      ├── Block HA ─────────────────┼─────► agents-service         │ │
│      │   └── getBPSummary()        │       POST /bp-summary       │ │
│      ├── Block Thuốc               │       (AI insight)           │ │
│      └── Block Tái khám            │                              │ │
│                                    │                              │ │
│      └── All Blocks ───────────────┴─────► api-gateway            │ │
│          getDailyPatientSummary()         └── user-service        │ │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│  SCR-CG-HA-LIST ──────────────────────► /patients/:id/blood-pressure│
│  SCR-CG-MED-SCHEDULE ─────────────────► /patients/:id/medications  │
│  SCR-CG-CHECKUP-LIST ─────────────────► /patients/:id/checkups     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Service: api-gateway-service

### Impact Level: 🟢 LOW

### Code Changes Required

| Layer | File | Type | Description |
|-------|------|:----:|-------------|
| Handler | `handler/CaregiverComplianceHandler.java` | **NEW** | 4 REST endpoints |
| DTO | `dto/response/Patient*.java` | **NEW** | 4 Response DTOs |
| Client | `client/CaregiverComplianceClient.java` | **NEW** | gRPC client |
| Route | `verticles/HttpServerVerticle.java` | **MODIFY** | Add 4 routes |

### New REST Endpoints (4 APIs)

| Method | Endpoint | gRPC Call | Clone From |
|--------|----------|-----------|------------|
| GET | `/v1/patients/:patientId/daily-summary` | `GetPatientDailySummary` | DailySummaryHandler |
| GET | `/v1/patients/:patientId/blood-pressure` | `GetPatientBPHistory` | BloodPressureHandler |
| GET | `/v1/patients/:patientId/medications` | `GetPatientMedications` | MedicationHandler |
| GET | `/v1/patients/:patientId/checkups` | `GetPatientCheckups` | ReExaminationHandler |

> ⚠️ **All endpoints require Permission #4 check** (SEC-CG-001)

### ⚠️ ISOLATION NOTE
```
❌ KHÔNG modify DailySummaryHandler, BloodPressureHandler, etc.
✅ TẠO MỚI CaregiverComplianceHandler.java (isolated)
```

### Estimated Effort: 12 hours

---

## Service: user-service

### Impact Level: 🟢 LOW

### Code Changes Required

| Layer | File | Type | Description |
|-------|------|:----:|-------------|
| Proto | `proto/user_service.proto` | **MODIFY** | Add 4 RPC methods |
| Service | `service/CaregiverComplianceService.java` | **NEW** | Interface |
| Service | `service/impl/CaregiverComplianceServiceImpl.java` | **NEW** | Implementation |
| gRPC | `grpc/CaregiverComplianceGrpcService.java` | **NEW** | Handler |

### New gRPC Methods (4 Methods)

```protobuf
// user_service.proto additions  
rpc GetPatientDailySummary(GetPatientDailySummaryRequest) 
    returns (GetPatientDailySummaryResponse);  // Dashboard

rpc GetPatientBPHistory(GetPatientBPHistoryRequest) 
    returns (GetPatientBPHistoryResponse);     // SCR-CG-HA-LIST

rpc GetPatientMedications(GetPatientMedicationsRequest) 
    returns (GetPatientMedicationsResponse);   // SCR-CG-MED-SCHEDULE

rpc GetPatientCheckups(GetPatientCheckupsRequest) 
    returns (GetPatientCheckupsResponse);      // SCR-CG-CHECKUP-LIST
```

### Request/Response Messages

```protobuf
// Common request pattern for all 4 methods
message GetPatient{Feature}Request {
    string caregiver_id = 1;
    string patient_id = 2;
    optional string date = 3;  // For filtering
}

// Response includes permission status
message GetPatient{Feature}Response {
    bool has_permission = 1;           // Permission #4 status
    PatientInfo patient_info = 2;      // {Mối quan hệ} for BR-CG-014
    // ... feature-specific data (reuse existing message types)
}
```

### Security Pattern (Apply to ALL 4 methods)

```java
// Clone pattern từ CaregiverAlertServiceImpl
public Future<Response> getPatient{Feature}(String caregiverId, String patientId) {
    // Step 1: Validate active connection
    return connectionRepository.findActiveConnection(caregiverId, patientId)
        // Step 2: Check Permission #4 (compliance_tracking)
        .compose(conn -> permissionService.hasPermission(conn.getId(), "compliance_tracking"))
        // Step 3: Fetch data or return permission_denied
        .compose(hasPermission -> {
            if (!hasPermission) {
                return Future.succeededFuture(buildPermissionDeniedResponse());
            }
            // Reuse existing repository method với patientId filter
            return {existingRepository}.get{Feature}(patientId);
        });
}
```

### ⚠️ ISOLATION NOTE
```
❌ KHÔNG modify DailySummaryServiceImpl (user endpoint)
❌ KHÔNG modify BloodPressureServiceImpl (user endpoint)
❌ KHÔNG modify MedicationServiceImpl (user endpoint)
❌ KHÔNG modify ReExaminationServiceImpl (user endpoint)
✅ TẠO MỚI CaregiverComplianceServiceImpl (isolated)
✅ REUSE existing repository methods với patientId filter
```

### Estimated Effort: 16 hours

---

## Service: agents-service (FastAPI Python)

> ⭐ **Reuse Pattern từ HeartbeatBulletinScreen.tsx** (Bản tin 24H)

### Impact Level: 🟢 LOW (NO changes needed)

### Flow (Dashboard Block HA - Hình 1)

```
┌────────────────────────────────────────────────────────────────┐
│  Mobile (FE)                                                   │
├────────────────────────────────────────────────────────────────┤
│  1. Call API Gateway: /patients/:id/daily-summary              │
│     → Returns: bp_summary { bp_total, bp_high, bp_low, ... }   │
│                                                                 │
│  2. FE tính toán params:                                        │
│     bp_in_target = bp_total - bp_high - bp_low                 │
│                                                                 │
│  3. FE gọi TRỰC TIẾP agents-service: POST /bp-summary          │
│     → Input: { completion_percentage, bp_counts... }           │
│     → Output: { bp_status_label, bp_comment, ... }             │
│                                                                 │
│  4. FE hiển thị với {Mối quan hệ} override (BR-CG-014)         │
│     Replace: {userTitle} → {Mối quan hệ}                       │
└────────────────────────────────────────────────────────────────┘
```

### API Endpoint (Đã có sẵn - NO changes)

```
POST /bp-summary  ← Existing, reuse as-is

# Request (FE tính và gửi):
{
    "completion_percentage": 75,
    "bp_total_measurements": 4,
    "bp_in_target_count": 3,    ← FE tính: total - high - low
    "bp_high_count": 1,
    "bp_low_count": 0
}

# Response:
{
    "summary_title": "Thật tự hào...",
    "bp_status_label": "Kiểm soát tốt",
    "bp_comment": "Huyết áp đang ổn định..."
}
```

### ⚠️ NO BACKEND CHANGES NEEDED

agents-service endpoint `/bp-summary` **đã có sẵn** và hoạt động.
Mobile chỉ cần reuse `getBPSummary()` từ `shared/services/agents/agent.service.ts`.

### Estimated Effort: 0 hours (không có changes)

---

## Service: app-mobile-ai (React Native)

### Impact Level: 🟡 MEDIUM

### Code Changes Required

| Layer | File | Type | Description |
|-------|------|:----:|-------------|
| Screen | `caregiver_compliance/CaregiverComplianceDashboardScreen.tsx` | **CLONE** | Clone từ HeartbeatBulletinScreen |
| Screen | `caregiver_compliance/CaregiverBPHistoryScreen.tsx` | **CLONE** | Clone từ BloodPressureMissionScreen |
| Screen | `caregiver_compliance/CaregiverMedicationScheduleScreen.tsx` | **CLONE** | Clone từ MedicationMissionScreen |
| Screen | `caregiver_compliance/CaregiverCheckupListScreen.tsx` | **CLONE** | Clone từ ReExamScheduleScreen |
| Component | `components/CaregiverContextHeader.tsx` | **NEW** | Context header (BR-CG-002) |
| Component | `components/PermissionDeniedOverlay.tsx` | **NEW** | Permission overlay (BR-CG-018) |
| Service | `services/caregiverCompliance.service.ts` | **NEW** | 4 API calls |
| Navigation | `navigation/AppNavigator.tsx` | **MODIFY** | Add 4 routes |

### Clone Strategy by Screen

#### 1. Dashboard (SCR-CG-DASH) - Clone từ HeartbeatBulletinScreen

| Action | Items |
|:------:|-------|
| ❌ DELETE | SmartKolia, TourProvider, Add buttons, Bottom action row |
| ✅ KEEP | 3 Blocks (HA, Thuốc, Tái khám), Loading states, Empty states |
| ➕ ADD | Permission #4 check, API gọi `/patients/:id/daily-summary` |
| ⚙️ MODIFY | `{userTitle}` → `{Mối quan hệ}` (BR-CG-014) |

#### 2. HA History (SCR-CG-HA-LIST) - Clone từ BloodPressureMissionScreen

| Action | Items |
|:------:|-------|
| ❌ DELETE | `handleAddBloodPressure()`, `handleSetSchedule()`, SmartKolia, TourProvider, BloodPressureGuideModal, Bottom action buttons |
| ✅ KEEP | HorizontalDatePicker, FlatList, Date filtering, BloodPressureInputCard (view mode), Empty state |
| ➕ ADD | CaregiverContextHeader, patientId param, New API service |
| ⚙️ MODIFY | Header: BỎ icons (📅, 📊, +) theo BR-CG-020 |

#### 3. Medication Schedule (SCR-CG-MED-SCHEDULE) - Clone từ MedicationMissionScreen

| Action | Items |
|:------:|-------|
| ❌ DELETE | `handleMedicationFeedback()`, `handleAddMedication()`, BatchUpdateState, CoinRewardModal, FloatingKoalaConsultButton, Action buttons per item |
| ✅ KEEP | HorizontalDatePicker, Time-based grouping (Sáng/Trưa/Tối), Status icons (read-only), Empty state |
| ➕ ADD | CaregiverContextHeader, View-only note |
| ⚙️ MODIFY | Header: BỎ icons, `{Danh xưng}` → `{Mối quan hệ}` |

#### 4. Checkup List (SCR-CG-CHECKUP-LIST) - Clone từ ReExamScheduleScreen

| Action | Items |
|:------:|-------|
| ❌ DELETE | Add button, Edit/Delete handlers, Notification permission, "Báo cáo kết quả" button |
| ✅ KEEP | Tab switcher (Sắp tới/Đã qua), ReExamScheduleCard (view mode), Empty state |
| ➕ ADD | CaregiverContextHeader, Status tags (🟢🟠⚫) theo BR-CG-016, Retention logic (5 days) |
| ⚙️ MODIFY | Header: BỎ icons theo BR-CG-020 |

### ⚠️ ISOLATION NOTE
```
❌ KHÔNG modify features/blood_pressure/* (user screens)
❌ KHÔNG modify features/medication_mission/* (user screens)
❌ KHÔNG modify features/re_exam_schedule/* (user screens)
❌ KHÔNG modify features/main/screens/HeartbeatBulletinScreen.tsx
✅ TẠO MỚI features/caregiver_compliance/* (isolated folder)
```

### Estimated Effort: 48 hours

---

## Database Changes

### Impact Level: 🟢 LOW (No changes required)

| Table | Change | Details |
|-------|:------:|---------|
| `connections` | NONE | Reuse existing |
| `connection_permissions` | NONE | Reuse existing (permission_type = 'compliance_tracking') |
| `blood_pressure_records` | NONE | Query với user_id = patientId |
| `user_medication_feedback` | NONE | Query với user_id = patientId |
| `re_examination_event` | NONE | Query với user_id = patientId |

### Query Pattern

```sql
-- Example: Get BP history for caregiver (Permission #4 check)
SELECT bpr.* FROM blood_pressure_records bpr
WHERE bpr.user_id = :patientId  -- Patient's data
  AND EXISTS (
    SELECT 1 FROM connections c
    JOIN connection_permissions cp ON c.id = cp.connection_id
    WHERE c.caregiver_id = :caregiverId
      AND c.patient_id = :patientId
      AND c.status = 'active'
      AND cp.permission_type = 'compliance_tracking'
      AND cp.is_enabled = true
  );
```

---

## Integration Points

| From | To | Protocol | Purpose |
|------|-----|:--------:|---------|
| Mobile | api-gateway | REST | 4 Caregiver compliance APIs |
| Mobile | agents-service | REST | AI BP insight (getBPSummary) - Dashboard only |
| api-gateway | user-service | gRPC | Data + Permission #4 check |
| user-service | PostgreSQL | SQL | Data queries with patientId filter |

---

## Summary

| Service | Impact | New Files | Modified Files | Effort |
|---------|:------:|:---------:|:--------------:|:------:|
| api-gateway-service | 🟢 | 4 | 1 | 12h |
| user-service | 🟢 | 4 | 1 | 16h |
| agents-service | 🟢 | 0 | 0 | 0h |
| app-mobile-ai | 🟡 | 8 | 1 | 48h |
| **TOTAL** | | **16** | **3** | **76h** |

---

## Key Design Decisions

1. **Clone-Based Isolation:** 100% new code, 0% modify existing user features
2. **API Pattern:** Clone API handlers with `patientId` param + Permission #4 server-side check
3. **agents-service:** FE calls directly (same as HeartbeatBulletinScreen), no backend changes
4. **UI Override:** `{Danh xưng}` / `{userTitle}` → `{Mối quan hệ}` (BR-CG-014)
5. **Header Icons:** Remove action icons (📅, 📊, +) in drill-down screens (BR-CG-020)

> ⭐ **Pattern Summary:** Dashboard giống 24H + List/Detail clone từ user screens với isolation
