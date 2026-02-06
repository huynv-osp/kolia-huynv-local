# API Mapping: US 1.2

> **Format:** SA-002 (API Specification)  
> **SRS:** v2.5 | **APIs:** 4 REST + 1 agents-service (reuse)

---

## Overview

| # | API | Screen | Clone From |
|:-:|-----|--------|------------|
| 1 | `/patients/:id/daily-summary` | Dashboard (3 khối) | daily-summary |
| 2 | `/patients/:id/blood-pressure` | SCR-CG-HA-LIST | blood-pressure |
| 3 | `/patients/:id/medications` | SCR-CG-MED-SCHEDULE | medications |
| 4 | `/patients/:id/checkups` | SCR-CG-CHECKUP-LIST | re-examination |

> ⚠️ **All APIs require Permission #4 check server-side** (SEC-CG-001)

---

## Swagger Documentation

| API Group | Swagger File | Status |
|-----------|--------------|:------:|
| **Connection Management** | `api-gateway-service/src/main/resources/swagger/user-api/connection-management.yaml` | ✅ Consolidated |
| **Dashboard APIs** | Same file (Tag: Dashboard) | ✅ Included |
| **Alert Management** | Same file (Tag: Alert Management) | ✅ Merged |
| **Encouragement** | Same file (Tag: Encouragement) | ✅ Merged |

> **Note:** All patient/caregiver APIs are now consolidated into `connection-management.yaml` for maintainability.

---

## API 1: Get Patient Daily Summary (Dashboard)

### REST Endpoint

```
GET /v1/patients/:patientId/daily-summary
Authorization: Bearer {token}
```

### gRPC Method

```protobuf
rpc GetPatientDailySummary(GetPatientDailySummaryRequest) 
    returns (GetPatientDailySummaryResponse);

message GetPatientDailySummaryRequest {
    string caregiver_id = 1;
    string patient_id = 2;
}

message GetPatientDailySummaryResponse {
    bool has_permission = 1;
    PatientInfo patient_info = 2;
    BPSummary bp_summary = 3;
    MedicationSummary medication_summary = 4;
    repeated ReExamResult re_examination_results = 5;
}
```

### Response Example

```json
{
    "has_permission": true,
    "patient_info": {
        "name": "Trần Thị D",
        "relationship": "Mẹ"
    },
    "bp_summary": {
        "bp_total_measurements": 4,
        "bp_high_count": 1,
        "bp_low_count": 0,
        "bp_in_target_count": 3
    },
    "medication_summary": {
        "total_doses": 11,
        "taken": 2,
        "missed": 3,
        "wrong_dose": 2,
        "pending": 4
    },
    "re_examination_results": [
        {
            "id": "uuid",
            "department": "Khoa tim mạch",
            "hospital": "BV Bạch Mai",
            "appointment_date": "2026-02-01",
            "status": "NEEDS_UPDATE"
        }
    ]
}
```

### FE Flow (agents-service integration)

```typescript
// 1. Call API Gateway
const summary = await getPatientDailySummary(patientId);

// 2. FE tính params cho BP insight
const bpParams = {
    completion_percentage: calculatePercentage(summary.bp_summary),
    bp_total_measurements: summary.bp_summary.bp_total_measurements,
    bp_in_target_count: summary.bp_summary.bp_in_target_count,
    bp_high_count: summary.bp_summary.bp_high_count,
    bp_low_count: summary.bp_summary.bp_low_count
};

// 3. FE gọi agents-service trực tiếp
const bpInsight = await getBPSummary(bpParams);

// 4. Override {userTitle} → {Mối quan hệ}
const displayComment = bpInsight.bp_comment
    .replace(/{userTitle}/g, summary.patient_info.relationship);
```

---

## API 2: Get Patient Blood Pressure History

### REST Endpoint

```
GET /v1/patients/:patientId/blood-pressure?date=2026-02-05
Authorization: Bearer {token}
```

### gRPC Method

```protobuf
rpc GetPatientBPHistory(GetPatientBPHistoryRequest) 
    returns (GetPatientBPHistoryResponse);

message GetPatientBPHistoryRequest {
    string caregiver_id = 1;
    string patient_id = 2;
    optional string date = 3;  // YYYY-MM-DD
}

message GetPatientBPHistoryResponse {
    bool has_permission = 1;
    PatientInfo patient_info = 2;
    repeated BPRecord records = 3;
}

message BPRecord {
    string id = 1;
    int32 systolic = 2;
    int32 diastolic = 3;
    int32 pulse = 4;
    string status = 5;  // HIGH, LOW, NORMAL
    string recorded_at = 6;
}
```

### Response Example

```json
{
    "has_permission": true,
    "patient_info": {
        "name": "Trần Thị D",
        "relationship": "Mẹ"
    },
    "records": [
        {
            "id": "uuid-1",
            "systolic": 135,
            "diastolic": 85,
            "pulse": 72,
            "status": "HIGH",
            "recorded_at": "2026-02-05T08:30:00Z"
        }
    ]
}
```

---

## API 3: Get Patient Medications

### REST Endpoint

```
GET /v1/patients/:patientId/medications?date=2026-02-05
Authorization: Bearer {token}
```

### gRPC Method

```protobuf
rpc GetPatientMedications(GetPatientMedicationsRequest) 
    returns (GetPatientMedicationsResponse);

message GetPatientMedicationsRequest {
    string caregiver_id = 1;
    string patient_id = 2;
    optional string date = 3;
}

message GetPatientMedicationsResponse {
    bool has_permission = 1;
    PatientInfo patient_info = 2;
    repeated MedicationTimeSlot time_slots = 3;
}

message MedicationTimeSlot {
    string slot = 1;  // MORNING, NOON, EVENING
    repeated MedicationDose doses = 2;
}

message MedicationDose {
    string id = 1;
    string medication_name = 2;
    string dosage = 3;
    string status = 4;  // TAKEN, MISSED, WRONG_DOSE, PENDING
    string feedback_time = 5;
}
```

---

## API 4: Get Patient Checkups

### REST Endpoint

```
GET /v1/patients/:patientId/checkups
Authorization: Bearer {token}
```

### gRPC Method

```protobuf
rpc GetPatientCheckups(GetPatientCheckupsRequest) 
    returns (GetPatientCheckupsResponse);

message GetPatientCheckupsRequest {
    string caregiver_id = 1;
    string patient_id = 2;
}

message GetPatientCheckupsResponse {
    bool has_permission = 1;
    PatientInfo patient_info = 2;
    repeated CheckupRecord upcoming = 3;   // Tab "Sắp tới"
    repeated CheckupRecord completed = 4;  // Tab "Đã qua"
}

message CheckupRecord {
    string id = 1;
    string department = 2;
    string hospital = 3;
    string appointment_date = 4;
    string actual_date = 5;     // Ngày khám thực tế (nếu đã khám)
    string status = 6;          // UPCOMING, NEEDS_UPDATE, COMPLETED
    bool has_report = 7;
}
```

### Status Logic (BR-CG-016, BR-CG-017)

| Status | Điều kiện | Hiển thị | Action |
|--------|-----------|:--------:|--------|
| 🟢 UPCOMING | Ngày hẹn > Hôm nay | ✅ | Xem chi tiết |
| 🟠 NEEDS_UPDATE | Ngày hẹn ≤ Hôm nay ≤ Ngày hẹn+5 | ✅ | Báo cáo |
| ⚫ COMPLETED | Đã báo cáo, Hôm nay ≤ Ngày khám+5 | ✅ | Xem kết quả |
| 🔴 MISSED | Hôm nay > Ngày hẹn+5, Chưa báo cáo | ❌ ẨN | - |
| ⏹️ EXPIRED | Hôm nay > Ngày khám+5 | ❌ ẨN | - |

---

## Security Implementation

### All 4 APIs apply this pattern:

```java
// In CaregiverComplianceServiceImpl
public Future<Response> getPatient{Feature}(String caregiverId, String patientId) {
    // Step 1: Validate active connection
    return connectionRepository.findActiveConnection(caregiverId, patientId)
        .compose(conn -> {
            if (conn == null) {
                return Future.failedFuture(new UnauthorizedException("No active connection"));
            }
            // Step 2: Check Permission #4
            return permissionService.hasPermission(conn.getId(), "compliance_tracking")
                .compose(hasPermission -> {
                    if (!hasPermission) {
                        // Return response with has_permission = false
                        return Future.succeededFuture(buildPermissionDeniedResponse());
                    }
                    // Step 3: Fetch data
                    return {repository}.get{Feature}(patientId);
                });
        });
}
```

---

## Error Responses

| Code | Meaning | When |
|:----:|---------|------|
| 200 | Success | has_permission = true |
| 200 | Permission Denied | has_permission = false (for UI overlay) |
| 401 | Unauthorized | Invalid/expired token |
| 403 | Forbidden | No active connection |
| 404 | Not Found | Patient not found |
| 500 | Server Error | Internal error |

---

## Summary

| API | Clone From | Permission | Screen |
|-----|------------|:----------:|--------|
| `/patients/:id/daily-summary` | DailySummary | #4 | Dashboard |
| `/patients/:id/blood-pressure` | BloodPressure | #4 | HA List |
| `/patients/:id/medications` | Medication | #4 | Med Schedule |
| `/patients/:id/checkups` | ReExamination | #4 | Checkup List |

> ⭐ **agents-service:** FE calls `POST /bp-summary` directly (existing, no changes)
