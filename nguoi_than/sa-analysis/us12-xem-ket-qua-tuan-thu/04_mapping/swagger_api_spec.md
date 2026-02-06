# Caregiver Compliance API (US 1.2) - Swagger Specification

> **Version:** 1.0  
> **Base Path:** `/api/v1`  
> **Strategy:** 🛡️ CLONE (NEW endpoints, không modify existing)

---

## Architecture Overview

```
┌────────────────────────────────────────────────────────────────┐
│  Mobile: CaregiverComplianceDashboardScreen                    │
│  (Reuse pattern từ HeartbeatBulletinScreen.tsx)                │
└───────────────────┬────────────────────────────────────────────┘
                    │
      ┌─────────────┴─────────────┐
      ▼                           ▼
┌─────────────────┐       ┌─────────────────┐
│ api-gateway     │       │ agents-service  │
│ /compliance-*   │       │ /bp-summary     │
│ REST → gRPC     │       │ (AI insight)    │
└────────┬────────┘       └─────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│  user-service (gRPC)                                            │
│  - Permission #4 check                                          │
│  - Patient compliance data queries                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## OpenAPI Specification


```yaml
openapi: 3.0.3
info:
  title: ALIO Caregiver Compliance API
  description: |
    API cho tính năng **Xem Kết Quả Tuân Thủ** (US 1.2).
    Cho phép Caregiver xem kết quả tuân thủ của Patient.
    
    **⚠️ ISOLATION:** Tất cả endpoints là MỚI, không modify endpoints cũ.
    
    **Security:** Yêu cầu Permission #4 (compliance_tracking) = ON
  version: "1.0.0"
  contact:
    name: ALIO Dev Team
    
servers:
  - url: https://api.alio.vn/api/v1
    description: Production
  - url: http://localhost:8080/api/v1
    description: Local Development

tags:
  - name: Caregiver Compliance
    description: APIs cho Caregiver xem kết quả tuân thủ của Patient

paths:

  # ==========================================
  # API 1: Dashboard Summary
  # ==========================================
  /patients/{patientId}/compliance-summary:
    get:
      tags:
        - Caregiver Compliance
      operationId: getPatientComplianceSummary
      summary: Lấy tổng quan tuân thủ của Patient
      description: |
        Trả về dữ liệu cho Dashboard 3 khối VIEW:
        - Block 1: Huyết áp hôm nay (BR-010)
        - Block 2: Kết quả tuân thủ thuốc (BR-011)
        - Block 3: Lịch tái khám (BR-012)
        
        **Clone từ:** Không có (endpoint MỚI)
        
        **Permission Check:** Permission #4 @ server (SEC-CG-001)
      parameters:
        - $ref: '#/components/parameters/patientIdParam'
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ComplianceSummaryResponse'
              examples:
                hasPermission:
                  summary: Permission #4 = ON
                  value:
                    status: 200
                    message: "Success"
                    data:
                      has_compliance_permission: true
                      patient_info:
                        id: "uuid-patient"
                        name: "Trần Thị D"
                        relationship: "Mẹ"
                        avatar_url: "https://storage.alio.vn/avatar.jpg"
                      blood_pressure:
                        today_count: 2
                        status: "controlled"
                        status_label: "Kiểm soát tốt"
                        insight: "Huyết áp của Mẹ hôm nay đang ổn định..."
                      medication:
                        total_doses: 11
                        taken: 5
                        missed: 2
                        wrong_dose: 1
                        no_response: 3
                      checkup:
                        upcoming_count: 2
                        items:
                          - specialty: "Tim mạch"
                            hospital: "BV Bạch Mai"
                            date: "2026-02-15"
                            status: "upcoming"
                            status_label: "🟢 Sắp tới"
                permissionDenied:
                  summary: Permission #4 = OFF
                  value:
                    status: 200
                    message: "Success"
                    data:
                      has_compliance_permission: false
                      patient_info:
                        id: "uuid-patient"
                        name: "Trần Thị D"
                        relationship: "Mẹ"
                        avatar_url: "https://storage.alio.vn/avatar.jpg"
                      permission_denied_message: "Mẹ đã tắt quyền theo dõi tuân thủ"
                      guidance_message: "Liên hệ Mẹ để bật lại quyền này"
        '401':
          $ref: '#/components/responses/Unauthorized'
        '403':
          $ref: '#/components/responses/NoConnection'
        '404':
          $ref: '#/components/responses/PatientNotFound'
      security:
        - bearerAuth: []

  # ==========================================
  # API 2: Blood Pressure History
  # ==========================================
  /patients/{patientId}/blood-pressure:
    get:
      tags:
        - Caregiver Compliance
      operationId: getPatientBPHistory
      summary: Lấy lịch sử đo huyết áp của Patient
      description: |
        **Clone từ:** `GET /v1/blood-pressure/history`
        
        **Sửa đổi:**
        - Request: Thêm `patientId` (path param)
        - Logic: Query với `user_id = patientId` thay vì JWT user
        - Response: Giữ nguyên format
        
        **UI mapping:** SCR-CG-HA-LIST, SCR-CG-HA-DETAIL
      parameters:
        - $ref: '#/components/parameters/patientIdParam'
        - name: date
          in: query
          description: Filter by specific date (YYYY-MM-DD)
          schema:
            type: string
            format: date
            example: "2026-02-05"
        - name: from_date
          in: query
          description: Start of date range
          schema:
            type: string
            format: date
        - name: to_date
          in: query
          description: End of date range
          schema:
            type: string
            format: date
        - name: page
          in: query
          schema:
            type: integer
            default: 1
        - name: size
          in: query
          schema:
            type: integer
            default: 20
            maximum: 50
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BPHistoryResponse'
              example:
                status: 200
                message: "Success"
                data:
                  items:
                    - id: "uuid-bp-1"
                      systolic: 125
                      diastolic: 78
                      pulse: 72
                      status: "normal"
                      status_label: "Bình thường"
                      measured_at: "2026-02-05T08:30:00+07:00"
                      period: "morning"
                      period_label: "Sáng"
                      source: "manual"
                      ai_comment: "Mẹ đang kiểm soát huyết áp rất tốt!"
                    - id: "uuid-bp-2"
                      systolic: 140
                      diastolic: 90
                      pulse: 80
                      status: "high"
                      status_label: "Cao"
                      measured_at: "2026-02-04T18:00:00+07:00"
                      period: "evening"
                      period_label: "Tối"
                      source: "manual"
                      ai_comment: "Huyết áp của Mẹ đang hơi cao..."
                  pagination:
                    page: 1
                    size: 20
                    total: 15
                    total_pages: 1
        '401':
          $ref: '#/components/responses/Unauthorized'
        '403':
          $ref: '#/components/responses/PermissionDenied'
      security:
        - bearerAuth: []

  # ==========================================
  # API 3: Medication Schedule
  # ==========================================
  /patients/{patientId}/medications:
    get:
      tags:
        - Caregiver Compliance
      operationId: getPatientMedications
      summary: Lấy lịch uống thuốc của Patient
      description: |
        **Clone từ:** `GET /v1/user-medication-feedback/by-date`
        
        **Sửa đổi:**
        - Request: Thêm `patientId` (path param)
        - Logic: Query với `user_id = patientId`
        - Response: Thêm group by time_of_day (Sáng/Trưa/Tối)
        
        **UI mapping:** SCR-CG-MED-SCHEDULE
        
        **BR-CG-014:** `{Danh xưng}` → `{Mối quan hệ}` trong AI messages
      parameters:
        - $ref: '#/components/parameters/patientIdParam'
        - name: date
          in: query
          description: Filter by date (default = today)
          schema:
            type: string
            format: date
            example: "2026-02-05"
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/MedicationScheduleResponse'
              example:
                status: 200
                message: "Success"
                data:
                  date: "2026-02-05"
                  total_doses: 11
                  summary:
                    taken: 5
                    missed: 2
                    wrong_dose: 1
                    no_response: 3
                  schedule:
                    - time_of_day: "morning"
                      time_of_day_label: "Sáng"
                      time_of_day_icon: "☀️"
                      items:
                        - id: "uuid-med-1"
                          medication_name: "Arthur 200mg"
                          dosage: "1 viên"
                          scheduled_time: "08:30"
                          instruction: "Sau khi ăn"
                          status: "taken"
                          status_label: "Đã uống"
                          feedback_time: "08:45"
                        - id: "uuid-med-2"
                          medication_name: "Hydrochlorothiazide"
                          dosage: "1 viên"
                          scheduled_time: "09:00"
                          instruction: "Trước khi ăn"
                          status: "missed"
                          status_label: "Quên uống"
                          feedback_time: null
                    - time_of_day: "afternoon"
                      time_of_day_label: "Trưa"
                      time_of_day_icon: "🌤️"
                      items:
                        - id: "uuid-med-3"
                          medication_name: "Aspirin 81mg"
                          dosage: "1 viên"
                          scheduled_time: "12:00"
                          instruction: "Sau khi ăn"
                          status: "pending"
                          status_label: "Chưa đến giờ"
                          feedback_time: null
        '401':
          $ref: '#/components/responses/Unauthorized'
        '403':
          $ref: '#/components/responses/PermissionDenied'
      security:
        - bearerAuth: []

  # ==========================================
  # API 4: Checkup Schedule
  # ==========================================
  /patients/{patientId}/checkups:
    get:
      tags:
        - Caregiver Compliance
      operationId: getPatientCheckups
      summary: Lấy lịch tái khám của Patient
      description: |
        **Clone từ:** `GET /v1/re-exam/list`
        
        **Sửa đổi:**
        - Request: Thêm `patientId` (path param)
        - Logic: Query với `user_id = patientId`
        - Response: Thêm status theo BR-CG-016 (🟢/🟠/⚫)
        
        **UI mapping:** SCR-CG-CHECKUP-LIST, SCR-CG-CHECKUP-DETAIL
        
        **BR-CG-017:** Lịch "Đã qua" được giữ lại 5 ngày sau ngày hẹn
      parameters:
        - $ref: '#/components/parameters/patientIdParam'
        - name: tab
          in: query
          description: Filter by tab
          schema:
            type: string
            enum: [upcoming, past]
            default: upcoming
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CheckupListResponse'
              example:
                status: 200
                message: "Success"
                data:
                  tab: "upcoming"
                  items:
                    - id: "uuid-checkup-1"
                      specialty: "Tim mạch"
                      hospital: "BV Bạch Mai"
                      address: "78 Giải Phóng, Hà Nội"
                      scheduled_date: "2026-02-15"
                      scheduled_time: "09:00"
                      status: "upcoming"
                      status_label: "🟢 Sắp tới"
                      notes: "Mang theo kết quả xét nghiệm"
                    - id: "uuid-checkup-2"
                      specialty: "Khoa Mắt"
                      hospital: "BV Mắt TW"
                      address: "85 Bà Triệu, Hà Nội"
                      scheduled_date: "2026-02-01"
                      scheduled_time: "14:00"
                      status: "needs_update"
                      status_label: "🟠 Cần cập nhật"
                      notes: null
        '401':
          $ref: '#/components/responses/Unauthorized'
        '403':
          $ref: '#/components/responses/PermissionDenied'
      security:
        - bearerAuth: []

  # ==========================================
  # API 5: Blood Pressure Detail
  # ==========================================
  /patients/{patientId}/blood-pressure/{recordId}:
    get:
      tags:
        - Caregiver Compliance
      operationId: getPatientBPDetail
      summary: Lấy chi tiết 1 lần đo huyết áp
      description: |
        **Clone từ:** `GET /v1/blood-pressure/{id}`
        
        **UI mapping:** SCR-CG-HA-DETAIL
        
        **BR-CG-014:** AI comment sử dụng `{Mối quan hệ}` thay `{Danh xưng}`
      parameters:
        - $ref: '#/components/parameters/patientIdParam'
        - name: recordId
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BPDetailResponse'
              example:
                status: 200
                message: "Success"
                data:
                  id: "uuid-bp-1"
                  systolic: 125
                  diastolic: 78
                  pulse: 72
                  status: "normal"
                  status_label: "Kiểm soát tốt"
                  measured_at: "2026-02-05T08:30:00+07:00"
                  period: "morning"
                  period_label: "Sáng"
                  source: "manual"
                  source_label: "Nhập thủ công"
                  ai_comment: "Mẹ đang kiểm soát huyết áp rất tốt! Giá trị này nằm trong ngưỡng mục tiêu SYS 105-140 mmHg và DIA 60-90 mmHg. Hãy tiếp tục duy trì lịch đo đều đặn nhé."
                  target_range:
                    systolic_min: 105
                    systolic_max: 140
                    diastolic_min: 60
                    diastolic_max: 90
        '404':
          description: Record not found
      security:
        - bearerAuth: []

  # ==========================================
  # API 6: Checkup Detail
  # ==========================================
  /patients/{patientId}/checkups/{checkupId}:
    get:
      tags:
        - Caregiver Compliance
      operationId: getPatientCheckupDetail
      summary: Lấy chi tiết 1 lịch tái khám
      description: |
        **Clone từ:** `GET /v1/re-exam/{id}`
        
        **UI mapping:** SCR-CG-CHECKUP-DETAIL (BR-CG-019)
      parameters:
        - $ref: '#/components/parameters/patientIdParam'
        - name: checkupId
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CheckupDetailResponse'
        '404':
          description: Checkup not found
      security:
        - bearerAuth: []

# ==========================================
# Components
# ==========================================
components:

  parameters:
    patientIdParam:
      name: patientId
      in: path
      required: true
      description: Patient's user ID (UUID)
      schema:
        type: string
        format: uuid
        example: "550e8400-e29b-41d4-a716-446655440000"

  schemas:
    
    # --- Compliance Summary ---
    ComplianceSummaryResponse:
      type: object
      properties:
        status:
          type: integer
          example: 200
        message:
          type: string
          example: "Success"
        data:
          $ref: '#/components/schemas/ComplianceSummaryData'
    
    ComplianceSummaryData:
      type: object
      properties:
        has_compliance_permission:
          type: boolean
          description: Permission #4 status
        permission_denied_message:
          type: string
          description: Message khi Permission #4 = OFF
        guidance_message:
          type: string
          description: Hướng dẫn khi Permission OFF
        patient_info:
          $ref: '#/components/schemas/PatientInfo'
        blood_pressure:
          $ref: '#/components/schemas/BPSummary'
        medication:
          $ref: '#/components/schemas/MedicationSummary'
        checkup:
          $ref: '#/components/schemas/CheckupSummary'
    
    PatientInfo:
      type: object
      properties:
        id:
          type: string
          format: uuid
        name:
          type: string
          example: "Trần Thị D"
        relationship:
          type: string
          description: "{Mối quan hệ} per BR-CG-014"
          example: "Mẹ"
        avatar_url:
          type: string
          format: uri
    
    BPSummary:
      type: object
      properties:
        today_count:
          type: integer
          description: Số lần đo hôm nay
        status:
          type: string
          enum: [controlled, fluctuating, high, low]
        status_label:
          type: string
          example: "Kiểm soát tốt"
        insight:
          type: string
          description: AI insight (BR-010), đã override {Danh xưng} → {Mối quan hệ}
    
    MedicationSummary:
      type: object
      properties:
        total_doses:
          type: integer
        taken:
          type: integer
        missed:
          type: integer
        wrong_dose:
          type: integer
        no_response:
          type: integer
    
    CheckupSummary:
      type: object
      properties:
        upcoming_count:
          type: integer
        items:
          type: array
          items:
            $ref: '#/components/schemas/CheckupItem'
    
    CheckupItem:
      type: object
      properties:
        id:
          type: string
          format: uuid
        specialty:
          type: string
        hospital:
          type: string
        date:
          type: string
          format: date
        status:
          type: string
          enum: [upcoming, needs_update, completed]
        status_label:
          type: string
          example: "🟢 Sắp tới"
    
    # --- BP History ---
    BPHistoryResponse:
      type: object
      properties:
        status:
          type: integer
        message:
          type: string
        data:
          type: object
          properties:
            items:
              type: array
              items:
                $ref: '#/components/schemas/BPRecord'
            pagination:
              $ref: '#/components/schemas/Pagination'
    
    BPRecord:
      type: object
      properties:
        id:
          type: string
          format: uuid
        systolic:
          type: integer
          example: 125
        diastolic:
          type: integer
          example: 78
        pulse:
          type: integer
          example: 72
        status:
          type: string
          enum: [normal, high, low, controlled, fluctuating]
        status_label:
          type: string
        measured_at:
          type: string
          format: date-time
        period:
          type: string
          enum: [morning, afternoon, evening]
        period_label:
          type: string
        source:
          type: string
          enum: [manual, device]
        ai_comment:
          type: string
          description: Override {Danh xưng} → {Mối quan hệ}
    
    BPDetailResponse:
      type: object
      properties:
        status:
          type: integer
        message:
          type: string
        data:
          $ref: '#/components/schemas/BPRecord'
    
    # --- Medication ---
    MedicationScheduleResponse:
      type: object
      properties:
        status:
          type: integer
        message:
          type: string
        data:
          type: object
          properties:
            date:
              type: string
              format: date
            total_doses:
              type: integer
            summary:
              $ref: '#/components/schemas/MedicationSummary'
            schedule:
              type: array
              items:
                $ref: '#/components/schemas/TimeOfDayGroup'
    
    TimeOfDayGroup:
      type: object
      properties:
        time_of_day:
          type: string
          enum: [morning, afternoon, evening]
        time_of_day_label:
          type: string
          example: "Sáng"
        time_of_day_icon:
          type: string
          example: "☀️"
        items:
          type: array
          items:
            $ref: '#/components/schemas/MedicationDose'
    
    MedicationDose:
      type: object
      properties:
        id:
          type: string
          format: uuid
        medication_name:
          type: string
        dosage:
          type: string
          example: "1 viên"
        scheduled_time:
          type: string
          example: "08:30"
        instruction:
          type: string
          example: "Sau khi ăn"
        status:
          type: string
          enum: [pending, taken, missed, wrong_dose, no_response]
        status_label:
          type: string
        feedback_time:
          type: string
          format: date-time
          nullable: true
    
    # --- Checkup ---
    CheckupListResponse:
      type: object
      properties:
        status:
          type: integer
        message:
          type: string
        data:
          type: object
          properties:
            tab:
              type: string
              enum: [upcoming, past]
            items:
              type: array
              items:
                $ref: '#/components/schemas/CheckupDetail'
    
    CheckupDetail:
      type: object
      properties:
        id:
          type: string
          format: uuid
        specialty:
          type: string
        hospital:
          type: string
        address:
          type: string
        scheduled_date:
          type: string
          format: date
        scheduled_time:
          type: string
        status:
          type: string
          enum: [upcoming, needs_update, completed]
        status_label:
          type: string
        notes:
          type: string
          nullable: true
    
    CheckupDetailResponse:
      type: object
      properties:
        status:
          type: integer
        message:
          type: string
        data:
          $ref: '#/components/schemas/CheckupDetail'
    
    Pagination:
      type: object
      properties:
        page:
          type: integer
        size:
          type: integer
        total:
          type: integer
        total_pages:
          type: integer

  responses:
    Unauthorized:
      description: Invalid or missing JWT token
      content:
        application/json:
          example:
            status: 401
            message: "Unauthorized"
    
    PermissionDenied:
      description: Permission #4 is OFF
      content:
        application/json:
          example:
            status: 403
            message: "Permission denied"
            error_code: "COMPLIANCE_PERMISSION_DENIED"
    
    NoConnection:
      description: No active connection between caregiver and patient
      content:
        application/json:
          example:
            status: 403
            message: "No connection found"
            error_code: "CONNECTION_NOT_FOUND"
    
    PatientNotFound:
      description: Patient not found
      content:
        application/json:
          example:
            status: 404
            message: "Patient not found"

  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
      description: Caregiver's JWT token
```

---

## Clone Reference Table

| New Endpoint | Clone From | Modifications |
|--------------|------------|---------------|
| `GET /patients/:id/compliance-summary` | - | **NEW** (aggregate) |
| `GET /patients/:id/blood-pressure` | `GET /blood-pressure/history` | Add `patientId`, permission check |
| `GET /patients/:id/blood-pressure/:recordId` | `GET /blood-pressure/:id` | Add `patientId`, permission check |
| `GET /patients/:id/medications` | `GET /user-medication-feedback/by-date` | Add `patientId`, group by time_of_day |
| `GET /patients/:id/checkups` | `GET /re-exam/list` | Add `patientId`, status badges (BR-CG-016) |
| `GET /patients/:id/checkups/:checkupId` | `GET /re-exam/:id` | Add `patientId` |

---

## Screen → API Mapping

| Screen | API Call | Response Section |
|--------|----------|------------------|
| SCR-CG-DASH (Dashboard) | `GET /patients/:id/compliance-summary` | Full response |
| SCR-CG-HA-LIST (BP History) | `GET /patients/:id/blood-pressure` | `data.items` |
| SCR-CG-HA-DETAIL (BP Detail) | `GET /patients/:id/blood-pressure/:recordId` | `data` |
| SCR-CG-MED-SCHEDULE (Med List) | `GET /patients/:id/medications` | `data.schedule` |
| SCR-CG-CHECKUP-LIST (Checkup List) | `GET /patients/:id/checkups` | `data.items` |
| SCR-CG-CHECKUP-DETAIL (Checkup Detail) | `GET /patients/:id/checkups/:checkupId` | `data` |

---

## Business Rules Coverage

| BR | Description | API Implementation |
|----|-------------|-------------------|
| BR-CG-001 | Dashboard 3 khối VIEW | `/compliance-summary` aggregates 3 sections |
| BR-CG-003 | Permission #4 check | `has_compliance_permission` flag |
| BR-CG-014 | {Danh xưng} → {Mối quan hệ} | `relationship` field + AI text override |
| BR-CG-016 | Status badges 🟢🟠⚫ | `status_label` with emoji |
| BR-CG-017 | 5-day retention | Server-side filter on `scheduled_date` |
| BR-CG-018 | Permission Denied Overlay | `permission_denied_message` + `guidance_message` |
| BR-CG-020 | No action buttons | Response không có action fields |
