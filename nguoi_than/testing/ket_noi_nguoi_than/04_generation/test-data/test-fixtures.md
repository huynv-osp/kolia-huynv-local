# 📦 Test Data - KOLIA-1517 Kết nối Người thân

> **Version:** 1.1  
> **Date:** 2026-01-29  
> **Purpose:** Fixtures, factories, and sample data for testing  
> **Changes:** Added is_viewing fixtures for Profile Selection (v2.7)

---

## Table of Contents

1. [User Fixtures](#1-user-fixtures)
2. [Relationship Seed Data](#2-relationship-seed-data)
3. [Invite Fixtures](#3-invite-fixtures)
4. [Connection Fixtures](#4-connection-fixtures)
5. [Permission Fixtures](#5-permission-fixtures)
6. [Notification Fixtures](#6-notification-fixtures)
7. [API Request/Response Samples](#7-api-requestresponse-samples)
8. [Edge Case Data](#8-edge-case-data)

---

# 1. User Fixtures

## 1.1 Test Users (YAML)

```yaml
# test-data/users.yaml

users:
  # Patient user (người bệnh)
  patient_main:
    user_id: "11111111-1111-1111-1111-111111111111"
    name: "Nguyễn Thị Patient"
    phone: "0901234567"
    email: "patient@test.kolia.vn"
    avatar: "https://storage.kolia.vn/avatars/patient.jpg"
    last_active_at: "2026-01-28T09:00:00Z"
    roles: ["PATIENT"]
    
  # Caregiver users (người thân)
  caregiver_son:
    user_id: "22222222-2222-2222-2222-222222222222"
    name: "Nguyễn Văn ConTrai"
    phone: "0912345678"
    email: "contrai@test.kolia.vn"
    avatar: "https://storage.kolia.vn/avatars/contrai.jpg"
    last_active_at: "2026-01-28T08:30:00Z"
    roles: ["CAREGIVER"]
    
  caregiver_daughter:
    user_id: "33333333-3333-3333-3333-333333333333"
    name: "Nguyễn Thị ConGai"
    phone: "0923456789"
    email: "congai@test.kolia.vn"
    avatar: null
    last_active_at: "2026-01-27T10:00:00Z"
    roles: ["CAREGIVER"]
    
  # Dual-role user (both Patient and Caregiver)
  dual_role_user:
    user_id: "44444444-4444-4444-4444-444444444444"
    name: "Trần Văn DualRole"
    phone: "0934567890"
    email: "dual@test.kolia.vn"
    roles: ["PATIENT", "CAREGIVER"]
    
  # Non-existent user (for new user tests)
  non_existent:
    phone: "0987654321"
    name: null  # Will be provided in invite
    exists: false
```

## 1.2 User Factory (Java)

```java
// user-service/src/test/java/factory/UserFactory.java
public class UserFactory {
    
    private static final Faker faker = new Faker(new Locale("vi"));
    
    public static User patient() {
        return User.builder()
            .userId(UUID.fromString("11111111-1111-1111-1111-111111111111"))
            .name("Nguyễn Thị Patient")
            .phone("0901234567")
            .email("patient@test.kolia.vn")
            .lastActiveAt(Instant.now())
            .build();
    }
    
    public static User caregiver() {
        return User.builder()
            .userId(UUID.fromString("22222222-2222-2222-2222-222222222222"))
            .name("Nguyễn Văn ConTrai")
            .phone("0912345678")
            .email("contrai@test.kolia.vn")
            .lastActiveAt(Instant.now().minus(30, ChronoUnit.MINUTES))
            .build();
    }
    
    public static User randomUser() {
        return User.builder()
            .userId(UUID.randomUUID())
            .name(faker.name().fullName())
            .phone("09" + faker.number().digits(8))
            .email(faker.internet().emailAddress())
            .lastActiveAt(Instant.now())
            .build();
    }
    
    public static User withPhone(String phone) {
        return User.builder()
            .userId(UUID.randomUUID())
            .name(faker.name().fullName())
            .phone(phone)
            .build();
    }
}
```

## 1.3 User Factory (Python)

```python
# schedule-service/tests/factories/user_factory.py
from faker import Faker
from dataclasses import dataclass
from uuid import UUID, uuid4
from datetime import datetime

faker = Faker('vi_VN')

@dataclass
class User:
    user_id: UUID
    name: str
    phone: str
    email: str = None
    last_active_at: datetime = None

class UserFactory:
    
    @staticmethod
    def patient() -> User:
        return User(
            user_id=UUID("11111111-1111-1111-1111-111111111111"),
            name="Nguyễn Thị Patient",
            phone="0901234567",
            email="patient@test.kolia.vn",
            last_active_at=datetime.now()
        )
    
    @staticmethod
    def caregiver() -> User:
        return User(
            user_id=UUID("22222222-2222-2222-2222-222222222222"),
            name="Nguyễn Văn ConTrai",
            phone="0912345678",
            email="contrai@test.kolia.vn"
        )
    
    @staticmethod
    def random() -> User:
        return User(
            user_id=uuid4(),
            name=faker.name(),
            phone="09" + faker.random_number(digits=8, fix_len=True).__str__(),
            email=faker.email()
        )
```

---

# 2. Relationship Seed Data

## 2.1 Full Relationship List (17 types)

```yaml
# test-data/relationships.yaml

relationships:
  family:
    - code: "con_trai"
      name_vi: "Con trai"
      name_en: "Son"
      display_order: 1
    - code: "con_gai"
      name_vi: "Con gái"
      name_en: "Daughter"
      display_order: 2
    - code: "anh_trai"
      name_vi: "Anh trai"
      name_en: "Older brother"
      display_order: 3
    - code: "chi_gai"
      name_vi: "Chị gái"
      name_en: "Older sister"
      display_order: 4
    - code: "em_trai"
      name_vi: "Em trai"
      name_en: "Younger brother"
      display_order: 5
    - code: "em_gai"
      name_vi: "Em gái"
      name_en: "Younger sister"
      display_order: 6
    - code: "chau_trai"
      name_vi: "Cháu trai"
      name_en: "Grandson"
      display_order: 7
    - code: "chau_gai"
      name_vi: "Cháu gái"
      name_en: "Granddaughter"
      display_order: 8
    - code: "bo"
      name_vi: "Bố"
      name_en: "Father"
      display_order: 9
    - code: "me"
      name_vi: "Mẹ"
      name_en: "Mother"
      display_order: 10
    - code: "ong_noi"
      name_vi: "Ông nội"
      name_en: "Paternal grandfather"
      display_order: 11
    - code: "ba_noi"
      name_vi: "Bà nội"
      name_en: "Paternal grandmother"
      display_order: 12
    - code: "ong_ngoai"
      name_vi: "Ông ngoại"
      name_en: "Maternal grandfather"
      display_order: 13
    - code: "ba_ngoai"
      name_vi: "Bà ngoại"
      name_en: "Maternal grandmother"
      display_order: 14
      
  spouse:
    - code: "vo"
      name_vi: "Vợ"
      name_en: "Wife"
      display_order: 15
    - code: "chong"
      name_vi: "Chồng"
      name_en: "Husband"
      display_order: 16
      
  other:
    - code: "khac"
      name_vi: "Khác"
      name_en: "Other"
      display_order: 99
```

## 2.2 SQL Seed Data

```sql
-- test-data/seed_relationships.sql

INSERT INTO relationships (relationship_code, name_vi, name_en, category, display_order, is_active)
VALUES
('con_trai', 'Con trai', 'Son', 'family', 1, true),
('con_gai', 'Con gái', 'Daughter', 'family', 2, true),
('anh_trai', 'Anh trai', 'Older brother', 'family', 3, true),
('chi_gai', 'Chị gái', 'Older sister', 'family', 4, true),
('em_trai', 'Em trai', 'Younger brother', 'family', 5, true),
('em_gai', 'Em gái', 'Younger sister', 'family', 6, true),
('chau_trai', 'Cháu trai', 'Grandson', 'family', 7, true),
('chau_gai', 'Cháu gái', 'Granddaughter', 'family', 8, true),
('bo', 'Bố', 'Father', 'family', 9, true),
('me', 'Mẹ', 'Mother', 'family', 10, true),
('ong_noi', 'Ông nội', 'Paternal grandfather', 'family', 11, true),
('ba_noi', 'Bà nội', 'Paternal grandmother', 'family', 12, true),
('ong_ngoai', 'Ông ngoại', 'Maternal grandfather', 'family', 13, true),
('ba_ngoai', 'Bà ngoại', 'Maternal grandmother', 'family', 14, true),
('vo', 'Vợ', 'Wife', 'spouse', 15, true),
('chong', 'Chồng', 'Husband', 'spouse', 16, true),
('khac', 'Khác', 'Other', 'other', 99, true)
ON CONFLICT (relationship_code) DO NOTHING;
```

---

# 3. Invite Fixtures

## 3.1 Invite Test Data

```yaml
# test-data/invites.yaml

invites:
  # Pending invite from Patient to Caregiver
  pending_patient_to_caregiver:
    invite_id: "aaaa1111-1111-1111-1111-111111111111"
    sender_id: "11111111-1111-1111-1111-111111111111"  # patient_main
    receiver_phone: "0912345678"
    receiver_id: "22222222-2222-2222-2222-222222222222"  # caregiver_son
    receiver_name: "Nguyễn Văn ConTrai"
    invite_type: "patient_to_caregiver"
    relationship_code: "con_trai"
    initial_permissions:
      health_overview: true
      emergency_alert: true
      task_config: true
      compliance_tracking: true
      proxy_execution: true
      encouragement: true
    status: 0  # PENDING
    created_at: "2026-01-28T09:00:00Z"
    
  # Pending invite from Caregiver to Patient
  pending_caregiver_to_patient:
    invite_id: "aaaa2222-2222-2222-2222-222222222222"
    sender_id: "33333333-3333-3333-3333-333333333333"  # caregiver_daughter
    receiver_phone: "0901234567"
    receiver_id: "11111111-1111-1111-1111-111111111111"  # patient_main
    receiver_name: "Nguyễn Thị Patient"
    invite_type: "caregiver_to_patient"
    relationship_code: "me"
    initial_permissions: null  # No preset - Patient will configure
    status: 0  # PENDING
    created_at: "2026-01-28T08:00:00Z"
    
  # Pending invite to new user (no account)
  pending_to_new_user:
    invite_id: "aaaa3333-3333-3333-3333-333333333333"
    sender_id: "11111111-1111-1111-1111-111111111111"
    receiver_phone: "0987654321"
    receiver_id: null  # User doesn't exist yet
    receiver_name: "Người Mới"
    invite_type: "patient_to_caregiver"
    relationship_code: "em_trai"
    status: 0
    
  # Accepted invite
  accepted:
    invite_id: "aaaa4444-4444-4444-4444-444444444444"
    sender_id: "11111111-1111-1111-1111-111111111111"
    receiver_id: "22222222-2222-2222-2222-222222222222"
    invite_type: "patient_to_caregiver"
    status: 1  # ACCEPTED
    accepted_at: "2026-01-27T10:00:00Z"
    
  # Rejected invite
  rejected:
    invite_id: "aaaa5555-5555-5555-5555-555555555555"
    sender_id: "11111111-1111-1111-1111-111111111111"
    receiver_id: "33333333-3333-3333-3333-333333333333"
    invite_type: "patient_to_caregiver"
    status: 2  # REJECTED
    rejected_at: "2026-01-26T15:00:00Z"
```

## 3.2 Invite Factory (Java)

```java
public class InviteFactory {
    
    public static ConnectionInvite pendingPatientToCaregiver() {
        return ConnectionInvite.builder()
            .inviteId(UUID.fromString("aaaa1111-1111-1111-1111-111111111111"))
            .senderId(UUID.fromString("11111111-1111-1111-1111-111111111111"))
            .receiverPhone("0912345678")
            .receiverId(UUID.fromString("22222222-2222-2222-2222-222222222222"))
            .receiverName("Nguyễn Văn ConTrai")
            .inviteType(InviteType.PATIENT_TO_CAREGIVER)
            .relationshipCode("con_trai")
            .initialPermissions(defaultPermissionsJson())
            .status(InviteStatus.PENDING)
            .createdAt(Instant.parse("2026-01-28T09:00:00Z"))
            .build();
    }
    
    public static ConnectionInvite pendingCaregiverToPatient() {
        return ConnectionInvite.builder()
            .inviteId(UUID.fromString("aaaa2222-2222-2222-2222-222222222222"))
            .senderId(UUID.fromString("33333333-3333-3333-3333-333333333333"))
            .receiverPhone("0901234567")
            .receiverId(UUID.fromString("11111111-1111-1111-1111-111111111111"))
            .inviteType(InviteType.CAREGIVER_TO_PATIENT)
            .relationshipCode("me")
            .status(InviteStatus.PENDING)
            .build();
    }
    
    public static ConnectionInvite pendingToNewUser() {
        return ConnectionInvite.builder()
            .inviteId(UUID.randomUUID())
            .senderId(UUID.fromString("11111111-1111-1111-1111-111111111111"))
            .receiverPhone("0987654321")
            .receiverId(null)  // No user yet
            .receiverName("Người Mới")
            .inviteType(InviteType.PATIENT_TO_CAREGIVER)
            .status(InviteStatus.PENDING)
            .build();
    }
    
    public static ConnectionInvite rejectedInvite() {
        return ConnectionInvite.builder()
            .inviteId(UUID.randomUUID())
            .senderId(UUID.fromString("11111111-1111-1111-1111-111111111111"))
            .receiverId(UUID.fromString("33333333-3333-3333-3333-333333333333"))
            .status(InviteStatus.REJECTED)
            .build();
    }
    
    private static String defaultPermissionsJson() {
        return """
            {"health_overview":true,"emergency_alert":true,"task_config":true,
             "compliance_tracking":true,"proxy_execution":true,"encouragement":true}
            """;
    }
}
```

---

# 4. Connection Fixtures

## 4.1 Connection Test Data

```yaml
# test-data/connections.yaml

connections:
  # Active connection (Patient → Caregiver)
  active_main:
    connection_id: "bbbb1111-1111-1111-1111-111111111111"
    contact_id: "cccc1111-1111-1111-1111-111111111111"
    patient_id: "11111111-1111-1111-1111-111111111111"
    caregiver_id: "22222222-2222-2222-2222-222222222222"
    relationship_code: "con_trai"
    contact_type: "caregiver"
    status: "active"
    created_at: "2026-01-27T10:00:00Z"
    
  # Connection with partial permissions
  active_partial_perms:
    connection_id: "bbbb2222-2222-2222-2222-222222222222"
    contact_id: "cccc2222-2222-2222-2222-222222222222"
    patient_id: "11111111-1111-1111-1111-111111111111"
    caregiver_id: "33333333-3333-3333-3333-333333333333"
    relationship_code: "khac"
    permissions:
      health_overview: true
      emergency_alert: false  # OFF
      task_config: false      # OFF
      compliance_tracking: true
      proxy_execution: false  # OFF
      encouragement: true
```

## 4.2 User Emergency Contact Extension

```yaml
# test-data/user_emergency_contacts.yaml

contacts:
  # Extended contact (Caregiver type) - Currently viewing patient
  caregiver_contact_viewing:
    contact_id: "cccc1111-1111-1111-1111-111111111111"
    user_id: "22222222-2222-2222-2222-222222222222"  # Caregiver views patient
    linked_user_id: "11111111-1111-1111-1111-111111111111"  # Patient
    name: "Nguyễn Thị Patient"
    phone: "0901234567"
    relationship_code: "me"
    contact_type: "caregiver"
    is_viewing: true  # v2.7: Currently viewing this patient
    invite_id: "aaaa4444-4444-4444-4444-444444444444"
    priority: 1
    
  # Caregiver contact NOT viewing
  caregiver_contact_not_viewing:
    contact_id: "cccc2222-2222-2222-2222-222222222222"
    user_id: "22222222-2222-2222-2222-222222222222"  # Same caregiver
    linked_user_id: "33333333-3333-3333-3333-333333333333"  # Different patient
    name: "Trần Văn Patient2"
    phone: "0902345678"
    relationship_code: "bo"
    contact_type: "caregiver"
    is_viewing: false  # v2.7: Not currently viewing
    priority: 2

  # Patient view of caregiver
  patient_monitored_by:
    contact_id: "cccc3333-3333-3333-3333-333333333333"
    user_id: "11111111-1111-1111-1111-111111111111"  # Patient
    linked_user_id: "22222222-2222-2222-2222-222222222222"  # Caregiver
    name: "Nguyễn Văn ConTrai"
    phone: "0912345678"
    relationship_code: "con_trai"
    contact_type: "caregiver"
    is_viewing: false  # Patient doesn't need viewing marker
    priority: 1
    
  # Legacy SOS contact (emergency type)
  sos_contact:
    contact_id: "cccc9999-9999-9999-9999-999999999999"
    user_id: "11111111-1111-1111-1111-111111111111"
    linked_user_id: null  # Regular SOS contact
    name: "Bác sĩ Nguyễn"
    phone: "0999999999"
    relationship_code: "khac"
    contact_type: "emergency"
    is_viewing: false  # Emergency contacts don't use viewing
    priority: 2
```

## 4.3 ViewingPatient Factory (Java) - v2.7

```java
// user-service/src/test/java/factory/ViewingPatientFactory.java
public class ViewingPatientFactory {

    public static SetViewingPatientRequest setViewingRequest(UUID caregiverId, UUID patientId) {
        return SetViewingPatientRequest.builder()
            .caregiverId(caregiverId)
            .patientId(patientId)
            .build();
    }
    
    public static UserEmergencyContact contactWithViewing(UUID caregiverId, UUID patientId, boolean isViewing) {
        return UserEmergencyContact.builder()
            .contactId(UUID.randomUUID())
            .userId(caregiverId)
            .linkedUserId(patientId)
            .name("Patient " + patientId.toString().substring(0, 8))
            .phone("09" + patientId.toString().substring(0, 8).replaceAll("-", ""))
            .contactType(ContactType.CAREGIVER)
            .relationshipCode("me")
            .isViewing(isViewing)
            .build();
    }
    
    public static UserEmergencyContact viewingPatient() {
        return contactWithViewing(
            UUID.fromString("22222222-2222-2222-2222-222222222222"),
            UUID.fromString("11111111-1111-1111-1111-111111111111"),
            true
        );
    }
    
    public static UserEmergencyContact notViewingPatient() {
        return contactWithViewing(
            UUID.fromString("22222222-2222-2222-2222-222222222222"),
            UUID.fromString("33333333-3333-3333-3333-333333333333"),
            false
        );
    }
    
    public static ViewingPatientResponse viewingPatientResponse(UUID patientId, String patientName) {
        return ViewingPatientResponse.builder()
            .patient(PatientInfo.builder()
                .id(patientId)
                .name(patientName)
                .phone("0901***567")
                .build())
            .connectionId(UUID.randomUUID())
            .build();
    }
}
```

---

# 5. Permission Fixtures

## 5.1 Permission Types

```yaml
# test-data/permissions.yaml

permission_types:
  - type: "health_overview"
    name_vi: "Xem tổng quan sức khỏe"
    name_en: "View health overview"
    description: "Chỉ số HA, báo cáo"
    
  - type: "emergency_alert"
    name_vi: "Nhận cảnh báo khẩn cấp"
    name_en: "Receive emergency alerts"
    description: "Alert khi HA bất thường, SOS"
    is_safety_critical: true
    
  - type: "task_config"
    name_vi: "Thiết lập nhiệm vụ tuân thủ"
    name_en: "Configure compliance tasks"
    description: "Tạo/sửa nhiệm vụ"
    
  - type: "compliance_tracking"
    name_vi: "Theo dõi kết quả tuân thủ"
    name_en: "Track compliance results"
    description: "Xem lịch sử"
    
  - type: "proxy_execution"
    name_vi: "Thực hiện nhiệm vụ thay"
    name_en: "Execute tasks on behalf"
    description: "Đánh dấu hoàn thành"
    
  - type: "encouragement"
    name_vi: "Gửi lời động viên"
    name_en: "Send encouragement"
    description: "Gửi tin nhắn"

# Permission configurations
permission_configs:
  all_on:
    health_overview: true
    emergency_alert: true
    task_config: true
    compliance_tracking: true
    proxy_execution: true
    encouragement: true
    
  minimal:
    health_overview: true
    emergency_alert: true
    task_config: false
    compliance_tracking: false
    proxy_execution: false
    encouragement: false
    
  no_emergency:
    health_overview: true
    emergency_alert: false  # WARNING!
    task_config: true
    compliance_tracking: true
    proxy_execution: true
    encouragement: true
```

---

# 6. Notification Fixtures

## 6.1 Notification Templates

```yaml
# test-data/notifications.yaml

templates:
  # Invite notifications
  invite_existing_user:
    template_id: "CONNECTION_INVITE_EXISTING"
    channels: ["ZNS", "PUSH"]
    params:
      - sender_name
      - invite_type
    zns_template: |
      🔔 Kolia - Lời mời kết nối
      
      {sender_name} mời bạn {invite_type_message}.
      
      👉 Mở app để xem chi tiết

  invite_new_user:
    template_id: "CONNECTION_INVITE_NEW"
    channels: ["ZNS", "SMS"]
    params:
      - sender_name
      - deep_link
    zns_template: |
      🔔 Kolia - Lời mời kết nối
      
      {sender_name} mời bạn tham gia Kolia.
      
      👉 Tải app: {deep_link}

  # Connection notifications
  invite_accepted:
    template_id: "CONNECTION_ACCEPTED"
    channels: ["PUSH"]
    push_title: "Lời mời được chấp nhận"
    push_body: "{acceptor_name} đã chấp nhận lời mời của bạn"

  invite_rejected:
    template_id: "CONNECTION_REJECTED"
    channels: ["PUSH"]
    push_title: "Lời mời bị từ chối"
    push_body: "{rejector_name} đã từ chối lời mời của bạn"

  permission_changed:
    template_id: "PERMISSION_CHANGED"
    channels: ["PUSH"]
    push_title: "Quyền của bạn đã thay đổi"
    push_body: "{patient_name} đã {action} quyền '{permission_name}'"

  connection_disconnected:
    template_id: "CONNECTION_DISCONNECTED"
    channels: ["PUSH"]
    push_title: "Kết nối đã bị hủy"
    push_body: "{disconnector_name} đã hủy kết nối với bạn"
```

## 6.2 Invite Notification Records

```yaml
# test-data/invite_notifications.yaml

notifications:
  zns_success:
    notification_id: "dddd1111-1111-1111-1111-111111111111"
    invite_id: "aaaa1111-1111-1111-1111-111111111111"
    channel: "ZNS"
    status: 1  # SENT
    retry_count: 0
    deep_link_sent: true
    sent_at: "2026-01-28T09:00:05Z"
    external_message_id: "zns_msg_12345"
    
  zns_failed_sms_success:
    notification_id: "dddd2222-2222-2222-2222-222222222222"
    invite_id: "aaaa3333-3333-3333-3333-333333333333"
    channel: "ZNS"
    status: 2  # FAILED
    retry_count: 1
    error_message: "User has no Zalo account"
    fallback:
      channel: "SMS"
      status: 1  # SENT
      sent_at: "2026-01-28T09:00:35Z"
      
  sms_retry_exhausted:
    notification_id: "dddd3333-3333-3333-3333-333333333333"
    invite_id: "aaaa4444-4444-4444-4444-444444444444"
    channel: "SMS"
    status: 2  # FAILED
    retry_count: 3
    error_message: "Max retries exceeded"
```

---

# 7. API Request/Response Samples

## 7.1 Create Invite

```json
// Request: POST /api/v1/connections/invite
{
  "receiver_phone": "0912345678",
  "receiver_name": "Nguyễn Văn ConTrai",
  "relationship": "con_trai",
  "invite_type": "patient_to_caregiver",
  "permissions": {
    "health_overview": true,
    "emergency_alert": true,
    "task_config": true,
    "compliance_tracking": true,
    "proxy_execution": true,
    "encouragement": true
  }
}

// Response: 201 Created
{
  "invite_id": "aaaa1111-1111-1111-1111-111111111111",
  "status": "pending",
  "created_at": "2026-01-28T09:00:00Z"
}
```

## 7.2 List Connections

```json
// Response: GET /api/v1/connections
{
  "monitoring": [
    {
      "connection_id": "bbbb1111-1111-1111-1111-111111111111",
      "patient": {
        "id": "11111111-1111-1111-1111-111111111111",
        "name": "Nguyễn Thị Patient",
        "avatar": "https://storage.kolia.vn/avatars/patient.jpg"
      },
      "relationship": "me",
      "relationship_display": "Mẹ (Nguyễn Thị Patient)",
      "last_active": "2026-01-28T09:00:00Z"
    }
  ],
  "monitored_by": [
    {
      "connection_id": "bbbb2222-2222-2222-2222-222222222222",
      "caregiver": {
        "id": "22222222-2222-2222-2222-222222222222",
        "name": "Nguyễn Văn ConTrai"
      },
      "relationship": "con_trai",
      "relationship_display": "Con trai (Nguyễn Văn ConTrai)",
      "last_active": "2026-01-28T08:30:00Z"
    }
  ]
}
```

## 7.3 Get Permissions

```json
// Response: GET /api/v1/connections/{id}/permissions
{
  "connection_id": "bbbb1111-1111-1111-1111-111111111111",
  "caregiver": {
    "id": "22222222-2222-2222-2222-222222222222",
    "name": "Nguyễn Văn ConTrai"
  },
  "permissions": [
    {"type": "health_overview", "name": "Xem tổng quan sức khỏe", "enabled": true},
    {"type": "emergency_alert", "name": "Nhận cảnh báo khẩn cấp", "enabled": true},
    {"type": "task_config", "name": "Thiết lập nhiệm vụ tuân thủ", "enabled": false},
    {"type": "compliance_tracking", "name": "Theo dõi kết quả tuân thủ", "enabled": true},
    {"type": "proxy_execution", "name": "Thực hiện nhiệm vụ thay", "enabled": false},
    {"type": "encouragement", "name": "Gửi lời động viên", "enabled": true}
  ]
}
```

---

# 8. Edge Case Data

## 8.1 Validation Edge Cases

```yaml
# test-data/edge_cases.yaml

phone_validation:
  valid:
    - "0901234567"
    - "0912345678"
    - "0899999999"
  invalid:
    - "901234567"     # No leading 0
    - "09012345678"   # 11 digits
    - "091234567"     # 9 digits
    - "1234567890"    # No leading 0
    - "abcdefghij"    # Non-numeric
    - ""              # Empty
    - null            # Null

name_validation:
  valid:
    - "Nguyễn Văn A"
    - "AB"                      # Min 2 chars
    - "Tên Rất Dài Năm Mươi Ký Tự Đây Là Nhiều Lắm Rồi NH" # 50 chars
  invalid:
    - "A"                       # 1 char
    - ""                        # Empty
    - "Tên Quá Dài Hơn Năm Mươi Ký Tự Là Không Được Chấp Nhận NN" # 51 chars

relationship_validation:
  valid:
    - "con_trai"
    - "me"
    - "khac"
  invalid:
    - "father"    # Invalid code
    - ""          # Empty
    - null        # Missing
```

## 8.2 State Transition Edge Cases

```yaml
state_transitions:
  invite_states:
    valid:
      - from: "pending"
        to: "accepted"
        action: "accept"
      - from: "pending"
        to: "rejected"
        action: "reject"
    invalid:
      - from: "accepted"
        to: "pending"
        error: "Cannot revert to pending"
      - from: "rejected"
        to: "accepted"
        error: "Cannot accept rejected invite"

  connection_states:
    valid:
      - from: "active"
        to: "disconnected"
        action: "disconnect"
    invalid:
      - from: "disconnected"
        to: "active"
        error: "Cannot reactivate - must create new invite"
```

---

**Generated:** 2026-01-29T15:36:00+07:00  
**Workflow:** `/alio-testing` (v2.7)
