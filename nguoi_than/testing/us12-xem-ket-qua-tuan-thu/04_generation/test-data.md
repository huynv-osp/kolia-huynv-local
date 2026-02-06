# Test Data: US 1.2 - Xem Kết Quả Tuân Thủ

> **Date:** 2026-02-05  
> **Purpose:** Test fixtures for unit and integration tests

---

## 1. Users

### Caregivers

```json
{
  "caregivers": [
    {
      "id": "caregiver-001",
      "phone": "0901000001",
      "name": "Nguyễn Văn B",
      "role": "caregiver",
      "description": "Active connection with Permission #4 ON"
    },
    {
      "id": "caregiver-002", 
      "phone": "0901000002",
      "name": "Trần Văn C",
      "role": "caregiver",
      "description": "Active connection with Permission #4 OFF"
    },
    {
      "id": "caregiver-003",
      "phone": "0901000003",
      "name": "Lê Văn D",
      "role": "caregiver",
      "description": "No connection"
    }
  ]
}
```

### Patients

```json
{
  "patients": [
    {
      "id": "patient-001",
      "phone": "0901000010",
      "name": "Nguyễn Văn A",
      "userTitle": "Ông",
      "description": "Has BP, Med, Checkup data"
    },
    {
      "id": "patient-002",
      "phone": "0901000011",
      "name": "Trần Thị E",
      "userTitle": "Bà",
      "description": "Empty data"
    }
  ]
}
```

---

## 2. Connections

```json
{
  "connections": [
    {
      "id": "conn-001",
      "caregiver_id": "caregiver-001",
      "patient_id": "patient-001",
      "status": "active",
      "relationship": "Bố",
      "inverse_relationship": "Con"
    },
    {
      "id": "conn-002",
      "caregiver_id": "caregiver-002",
      "patient_id": "patient-001",
      "status": "active",
      "relationship": "Ông",
      "inverse_relationship": "Cháu"
    }
  ]
}
```

---

## 3. Permissions

```json
{
  "connection_permissions": [
    {
      "connection_id": "conn-001",
      "permission_type": "compliance_tracking",
      "is_enabled": true,
      "description": "Permission #4 ON"
    },
    {
      "connection_id": "conn-002",
      "permission_type": "compliance_tracking",
      "is_enabled": false,
      "description": "Permission #4 OFF"
    }
  ]
}
```

---

## 4. Blood Pressure Records

```json
{
  "blood_pressure_records": [
    {
      "id": "bp-001",
      "user_id": "patient-001",
      "systolic": 130,
      "diastolic": 85,
      "pulse": 72,
      "measurement_time": "2026-02-05T08:00:00Z",
      "bp_status": "normal"
    },
    {
      "id": "bp-002",
      "user_id": "patient-001",
      "systolic": 145,
      "diastolic": 95,
      "pulse": 78,
      "measurement_time": "2026-02-05T14:00:00Z",
      "bp_status": "high"
    },
    {
      "id": "bp-003",
      "user_id": "patient-001",
      "systolic": 128,
      "diastolic": 80,
      "pulse": 70,
      "measurement_time": "2026-02-05T20:00:00Z",
      "bp_status": "normal"
    },
    {
      "id": "bp-004",
      "user_id": "patient-001",
      "systolic": 135,
      "diastolic": 88,
      "pulse": 75,
      "measurement_time": "2026-02-04T08:00:00Z",
      "bp_status": "normal",
      "description": "Yesterday - for date filter test"
    }
  ]
}
```

---

## 5. Medication Feedback

```json
{
  "user_medication_feedback": [
    {
      "id": "med-001",
      "user_id": "patient-001",
      "medication_name": "Amlodipine 5mg",
      "time_slot": "morning",
      "scheduled_time": "07:00",
      "feedback_status": "taken",
      "feedback_date": "2026-02-05"
    },
    {
      "id": "med-002",
      "user_id": "patient-001",
      "medication_name": "Lisinopril 10mg",
      "time_slot": "morning",
      "scheduled_time": "07:00",
      "feedback_status": "taken",
      "feedback_date": "2026-02-05"
    },
    {
      "id": "med-003",
      "user_id": "patient-001",
      "medication_name": "Metformin 500mg",
      "time_slot": "afternoon",
      "scheduled_time": "12:00",
      "feedback_status": "skipped",
      "feedback_date": "2026-02-05"
    },
    {
      "id": "med-004",
      "user_id": "patient-001",
      "medication_name": "Aspirin 81mg",
      "time_slot": "evening",
      "scheduled_time": "19:00",
      "feedback_status": "pending",
      "feedback_date": "2026-02-05"
    }
  ]
}
```

---

## 6. Checkups

```json
{
  "re_examination_events": [
    {
      "id": "checkup-001",
      "user_id": "patient-001",
      "specialty": "Tim mạch",
      "doctor_name": "BS. Nguyễn Văn X",
      "hospital": "BV Bạch Mai",
      "scheduled_date": "2026-02-10T09:00:00Z",
      "status": null,
      "description": "Upcoming - 5 days later"
    },
    {
      "id": "checkup-002",
      "user_id": "patient-001",
      "specialty": "Nội tiết",
      "doctor_name": "BS. Trần Thị Y",
      "hospital": "BV 108",
      "scheduled_date": "2026-02-03T14:00:00Z",
      "status": "completed",
      "report_url": "https://...",
      "description": "Past - completed with report"
    },
    {
      "id": "checkup-003",
      "user_id": "patient-001",
      "specialty": "Thần kinh",
      "doctor_name": "BS. Lê Văn Z",
      "hospital": "BV Việt Đức",
      "scheduled_date": "2026-02-01T10:00:00Z",
      "status": null,
      "description": "Past - overdue (within 5 days)"
    },
    {
      "id": "checkup-004",
      "user_id": "patient-001",
      "specialty": "Da liễu",
      "doctor_name": "BS. Phạm Thị W",
      "hospital": "BV Da liễu TW",
      "scheduled_date": "2026-01-20T08:00:00Z",
      "status": null,
      "description": "Past - missed (> 5 days, should not show)"
    }
  ]
}
```

---

## 7. SQL Insert Scripts

### For Local Development

```sql
-- Caregivers
INSERT INTO users (id, phone, name, role) VALUES
('caregiver-001', '0901000001', 'Nguyễn Văn B', 'caregiver'),
('caregiver-002', '0901000002', 'Trần Văn C', 'caregiver'),
('caregiver-003', '0901000003', 'Lê Văn D', 'caregiver');

-- Patients
INSERT INTO users (id, phone, name, user_title, role) VALUES
('patient-001', '0901000010', 'Nguyễn Văn A', 'Ông', 'patient'),
('patient-002', '0901000011', 'Trần Thị E', 'Bà', 'patient');

-- Connections
INSERT INTO connections (id, caregiver_id, patient_id, status, relationship, inverse_relationship) VALUES
('conn-001', 'caregiver-001', 'patient-001', 'active', 'Bố', 'Con'),
('conn-002', 'caregiver-002', 'patient-001', 'active', 'Ông', 'Cháu');

-- Permissions
INSERT INTO connection_permissions (connection_id, permission_type, is_enabled) VALUES
('conn-001', 'compliance_tracking', true),
('conn-002', 'compliance_tracking', false);

-- BP Records (add as needed from JSON above)
-- Medications (add as needed from JSON above)
-- Checkups (add as needed from JSON above)
```

---

## 8. Mock Responses

### Daily Summary - Permission Granted

```json
{
  "hasPermission": true,
  "patientInfo": {
    "id": "patient-001",
    "name": "Nguyễn Văn A",
    "relationship": "Bố",
    "avatarUrl": null
  },
  "bpSummary": {
    "totalMeasurements": 3,
    "inTargetCount": 2,
    "highCount": 1,
    "lowCount": 0,
    "latestReading": "145/95"
  },
  "medSummary": {
    "totalMeds": 4,
    "takenCount": 2,
    "skippedCount": 1,
    "pendingCount": 1
  },
  "checkupSummary": {
    "upcomingCount": 1,
    "nextCheckup": {
      "specialty": "Tim mạch",
      "date": "2026-02-10T09:00:00Z"
    }
  }
}
```

### Daily Summary - Permission Denied

```json
{
  "hasPermission": false,
  "permissionMessage": "Người thân chưa cho phép xem thông tin này",
  "patientInfo": null,
  "bpSummary": null,
  "medSummary": null,
  "checkupSummary": null
}
```
