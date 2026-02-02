# 🧪 Test Data Fixtures - Nhận Cảnh Báo (US 1.2)

## Document Information

| Attribute | Value |
|-----------|-------|
| **Version** | 1.5 |
| **Date** | 2026-02-02 |

---

## 1. User Fixtures

### 1.1 Patients

```yaml
patients:
  patient_001:
    user_id: "550e8400-e29b-41d4-a716-446655440001"
    full_name: "Nguyễn Văn A"
    phone: "0901234567"
    # 7-day BP history for delta calculation
    bp_history:
      avg_systolic: 125
      avg_diastolic: 82
      
  patient_002:
    user_id: "550e8400-e29b-41d4-a716-446655440002"
    full_name: "Trần Thị B"
    phone: "0912345678"
    bp_history:
      avg_systolic: 110
      avg_diastolic: 70
```

### 1.2 Caregivers

```yaml
caregivers:
  caregiver_001:
    user_id: "550e8400-e29b-41d4-a716-446655440101"
    full_name: "Nguyễn Văn Con"
    phone: "0987654321"
    fcm_token: "test_fcm_token_001"
    # Connected to patient_001 with permission #2 ON
    connections:
      - patient_id: "patient_001"
        permission_emergency_alert: true
        relationship: "con_trai"
        
  caregiver_002:
    user_id: "550e8400-e29b-41d4-a716-446655440102"
    full_name: "Trần Văn Anh"
    # Connected to patient_001 with permission #2 OFF
    connections:
      - patient_id: "patient_001"
        permission_emergency_alert: false
        relationship: "ban_be"
```

---

## 2. Alert Type Fixtures

```yaml
alert_types:
  - type_id: 1
    type_code: "SOS"
    name_vi: "Khẩn cấp"
    name_en: "Emergency"
    icon: "🚨"
    display_order: 1
    
  - type_id: 2
    type_code: "HA"
    name_vi: "Huyết áp"
    name_en: "Blood Pressure"
    icon: "❤️"
    display_order: 2
    
  - type_id: 3
    type_code: "MEDICATION"
    name_vi: "Thuốc"
    name_en: "Medication"
    icon: "💊"
    display_order: 3
    
  - type_id: 4
    type_code: "COMPLIANCE"
    name_vi: "Tuân thủ"
    name_en: "Compliance"
    icon: "📊"
    display_order: 4
```

---

## 3. Blood Pressure Fixtures

### 3.1 Normal BP (No Alert)

```yaml
bp_normal:
  patient_id: "patient_001"
  systolic: 128
  diastolic: 84
  heart_rate: 72
  measurement_time: "2026-02-02T10:00:00+07:00"
  # Delta: +3/+2 (< 10, no alert)
```

### 3.2 High Delta BP (Triggers Alert)

```yaml
bp_high_delta:
  patient_id: "patient_001"
  systolic: 145
  diastolic: 95
  heart_rate: 88
  measurement_time: "2026-02-02T16:45:00+07:00"
  # Delta: +20/+13 (> 10, triggers HA_HIGH)
  expected_alert:
    type: "HA"
    title: "Nguyễn Văn A - HA 145/95 (Cao hơn bình thường)"
    priority: 1
```

### 3.3 Low Delta BP (Triggers Alert)

```yaml
bp_low_delta:
  patient_id: "patient_001"
  systolic: 95
  diastolic: 55
  heart_rate: 65
  measurement_time: "2026-02-02T08:30:00+07:00"
  # Delta: -30/-27 (> 10, triggers HA_LOW)
  expected_alert:
    type: "HA"
    title: "Nguyễn Văn A - HA 95/55 (Thấp hơn bình thường)"
    priority: 1
```

---

## 4. Alert Fixtures

### 4.1 Unread Alerts

```yaml
alert_unread_sos:
  alert_id: "alert-001"
  caregiver_id: "caregiver_001"
  patient_id: "patient_001"
  alert_type_id: 1  # SOS
  priority: 0  # Critical
  title: "🚨 Mẹ cần hỗ trợ KHẨN CẤP!"
  status: 0  # unread
  created_at: "2026-02-02T16:45:00+07:00"
  payload:
    location:
      lat: 10.8231
      lng: 106.6297
    patient_phone: "0901234567"

alert_unread_ha:
  alert_id: "alert-002"
  caregiver_id: "caregiver_001"
  patient_id: "patient_001"
  alert_type_id: 2  # HA
  priority: 1  # High
  title: "Mẹ - HA 145/95 (Cao hơn bình thường)"
  icon: "💛"
  color: "yellow"
  status: 0  # unread
  created_at: "2026-02-02T15:30:00+07:00"
  payload:
    systolic: 145
    diastolic: 95
    delta_systolic: 20
    delta_diastolic: 13
```

### 4.2 Read Alerts

```yaml
alert_read:
  alert_id: "alert-003"
  caregiver_id: "caregiver_001"
  patient_id: "patient_001"
  alert_type_id: 3  # MEDICATION
  priority: 1
  title: "Mẹ - Amlodipine uống sai liều"
  status: 1  # read
  read_at: "2026-02-02T14:00:00+07:00"
  created_at: "2026-02-02T12:00:00+07:00"
```

---

## 5. Medication Fixtures

### 5.1 Missed Medication (3 consecutive)

```yaml
medication_missed_3:
  patient_id: "patient_001"
  prescription_item_id: 101
  medication_name: "Amlodipine 5mg"
  missed_count: 3
  # Expected: Triggers MEDICATION alert in batch
  expected_alert:
    type: "MEDICATION"
    title: "Mẹ - Bỏ lỡ 3 lần uống thuốc Amlodipine 5mg"
```

### 5.2 Wrong Dose

```yaml
medication_wrong_dose:
  patient_id: "patient_001"
  prescription_item_id: 102
  medication_name: "Lisinopril 10mg"
  feedback: "sai_lieu"
  # Expected: Triggers MEDICATION alert immediately
  expected_alert:
    type: "MEDICATION"
    title: "Mẹ - Lisinopril 10mg uống sai liều"
    priority: 1
```

---

## 6. Compliance Fixtures

### 6.1 Low Compliance Rate

```yaml
compliance_low:
  patient_id: "patient_001"
  evaluation_window: "24h"
  total_scheduled: 10
  completed: 6
  compliance_rate: 0.60  # 60% < 70%
  # Expected: Triggers COMPLIANCE alert in batch
  expected_alert:
    type: "COMPLIANCE"
    title: "Mẹ - Tuân thủ thuốc/đo HA chỉ đạt 60%"
```

---

## 7. Kafka Event Fixtures

### 7.1 BP Alert Event

```json
{
  "event_type": "BP_ABNORMAL",
  "patient_id": "550e8400-e29b-41d4-a716-446655440001",
  "source_type": "blood_pressure",
  "source_id": 12345,
  "timestamp": "2026-02-02T16:45:00+07:00",
  "data": {
    "systolic": 145,
    "diastolic": 95,
    "avg_7d_systolic": 125,
    "avg_7d_diastolic": 82,
    "delta_systolic": 20,
    "delta_diastolic": 13
  }
}
```

### 7.2 SOS Alert Event

```json
{
  "event_type": "SOS",
  "patient_id": "550e8400-e29b-41d4-a716-446655440001",
  "source_type": "sos",
  "timestamp": "2026-02-02T16:45:00+07:00",
  "data": {
    "location": {
      "lat": 10.8231,
      "lng": 106.6297,
      "accuracy": 10.5
    },
    "patient_phone": "0901234567"
  }
}
```

---

## 8. Java Fixture Builders

```java
public class AlertTestFixtures {
    
    public static final UUID PATIENT_001 = UUID.fromString("550e8400-e29b-41d4-a716-446655440001");
    public static final UUID CAREGIVER_001 = UUID.fromString("550e8400-e29b-41d4-a716-446655440101");
    
    public static CaregiverAlert.Builder alertBuilder() {
        return CaregiverAlert.builder()
            .alertId(UUID.randomUUID())
            .caregiverId(CAREGIVER_001)
            .patientId(PATIENT_001)
            .status(0)
            .pushStatus(0)
            .createdAt(Instant.now());
    }
    
    public static CaregiverAlert sosAlert() {
        return alertBuilder()
            .alertTypeId(1)
            .priority(0)
            .title("🚨 Mẹ cần hỗ trợ KHẨN CẤP!")
            .icon("🚨")
            .color("red")
            .build();
    }
    
    public static CaregiverAlert haHighAlert() {
        return alertBuilder()
            .alertTypeId(2)
            .priority(1)
            .title("Mẹ - HA 145/95 (Cao hơn bình thường)")
            .icon("💛")
            .color("yellow")
            .payload("{\"systolic\":145,\"diastolic\":95}")
            .build();
    }
}
```

---

**Generated:** 2026-02-02  
**Workflow:** `/alio-testing`
