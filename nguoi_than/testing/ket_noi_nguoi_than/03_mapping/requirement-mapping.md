# 📊 Requirement Mapping - KOLIA-1517

> **Phase:** 3 - Requirement Mapping  
> **Date:** 2026-02-02  
> **Source:** SRS v3.0 + SA Analysis v2.15 + FA v2.15

---

## 1. SRS Scenario ↔ Test Case Mapping

### PHẦN A: Role Người bệnh (Patient)

#### A.1 Gửi lời mời kết nối

| Scenario | Description | Test ID | Service | Priority |
|----------|-------------|---------|---------|:--------:|
| A1.1 | Gửi invite cho user ĐÃ CÓ tài khoản | TC-INV-001 | user-service | 🔴 P0 |
| A1.1 | ZNS + Push notification sent | TC-NOT-001 | schedule-service | 🔴 P0 |
| A1.2 | Gửi invite cho user CHƯA CÓ tài khoản | TC-INV-002 | user-service | 🔴 P0 |
| A1.2 | ZNS with Deep Link sent | TC-NOT-002 | schedule-service | 🔴 P0 |
| A1.3 | Self-invite blocked (BR-006) | TC-INV-003 | user-service | 🔴 P0 |
| A1.4 | Already connected blocked | TC-INV-004 | user-service | 🟡 P1 |
| A1.5 | Pending invite blocked (BR-007) | TC-INV-005 | user-service | 🔴 P0 |

#### A.2 Nhận lời mời từ Caregiver

| Scenario | Description | Test ID | Service | Priority |
|----------|-------------|---------|---------|:--------:|
| A2.1 | Accept invite với permission config | TC-CON-001 | user-service | 🔴 P0 |
| A2.1 | 6 permissions saved per config | TC-PRM-001 | user-service | 🔴 P0 |
| A2.1 | Notify sender on accept (BR-010) | TC-NOT-003 | schedule-service | 🟡 P1 |
| A2.1b | Quick accept (all ON) | TC-CON-002 | user-service | 🟡 P1 |
| A2.2 | Reject invite (BR-011) | TC-INV-006 | user-service | 🟡 P1 |
| A2.2 | Allow re-invite after reject | TC-INV-007 | user-service | 🟡 P1 |

#### A.3 Quản lý danh sách "Người thân của tôi"

| Scenario | Description | Test ID | Service | Priority |
|----------|-------------|---------|---------|:--------:|
| A3.1 | List Caregivers (BR-014) | TC-INV-008 | user-service | 🟡 P1 |
| A3.2 | List pending invites (BR-023) | TC-INV-008 | user-service | 🟡 P1 |
| A3.2b | Pending sent invites (sender view) | TC-INV-020 | user-service | 🟡 P1 |
| A3.2b | Cancel pending invite | TC-INV-021 | user-service | 🔴 P0 |
| A3.3 | Empty state CTA (BR-015) | TC-API-001 | api-gateway | 🟢 P2 |

#### A.4 Quyền truy cập Caregiver

| Scenario | Description | Test ID | Service | Priority |
|----------|-------------|---------|---------|:--------:|
| A4.1 | Toggle permission ON/OFF (BR-024) | TC-PRM-002 | user-service | 🔴 P0 |
| A4.1 | Notify Caregiver on change (BR-016) | TC-NOT-004 | schedule-service | 🟡 P1 |
| A4.1 | Hide UI block on OFF (BR-017) | TC-API-002 | api-gateway | 🔴 P0 |
| A4.2 | Emergency warning (BR-018) | TC-PRM-003 | user-service | 🔴 P0 |

#### A.5 Hủy kết nối

| Scenario | Description | Test ID | Service | Priority |
|----------|-------------|---------|---------|:--------:|
| A5.1 | Patient disconnect | TC-CON-004 | user-service | 🟡 P1 |
| A5.1 | Notify Caregiver (BR-019) | TC-NOT-005 | schedule-service | 🟡 P1 |

### PHẦN B: Role Người thân (Caregiver)

#### B.1 Gửi lời mời kết nối

| Scenario | Description | Test ID | Service | Priority |
|----------|-------------|---------|---------|:--------:|
| B1.1 | Caregiver send invite (BR-001) | TC-INV-009 | user-service | 🔴 P0 |
| B1.2 | Invite to non-user (BR-003) | TC-INV-010 | user-service | 🔴 P0 |

#### B.2 Nhận và xử lý lời mời từ Patient

| Scenario | Description | Test ID | Service | Priority |
|----------|-------------|---------|---------|:--------:|
| B2.1 | Accept invite (quick, BR-009) | TC-CON-005 | user-service | 🔴 P0 |
| B2.2 | Reject invite | TC-INV-011 | user-service | 🟡 P1 |
| B2.3 | Action item in Bản tin (BR-012) | TC-INT-001 | integration | 🟢 P2 |
| B2.4 | Multiple invites FIFO (BR-013) | TC-INV-012 | user-service | 🟢 P2 |

#### B.3 Xem danh sách "Tôi đang theo dõi"

| Scenario | Description | Test ID | Service | Priority |
|----------|-------------|---------|---------|:--------:|
| B3.1 | List Patients monitoring | TC-CON-006 | user-service | 🟡 P1 |
| B3.2 | Badge pending count | TC-API-003 | api-gateway | 🟢 P2 |
| B3.2b | Pending sent requests (sender view) | TC-INV-022 | user-service | 🟡 P1 |
| B3.2b | Cancel pending request | TC-INV-023 | user-service | 🔴 P0 |
| B3.3 | Empty state CTA | TC-API-004 | api-gateway | 🟢 P2 |

#### B.4 Xem Chi tiết Patient

| Scenario | Description | Test ID | Service | Priority |
|----------|-------------|---------|---------|:--------:|
| B4.1 | View Patient detail (BR-017) | TC-CON-007 | user-service | 🟡 P1 |

#### B.4-DVS Default View State (NEW v2.15)

| Scenario | Description | Test ID | Service | Priority |
|----------|-------------|---------|---------|:--------:|
| B4-DVS.1 | First load, no localStorage → Default View Prompt | TC-DVS-001 | mobile-app | 🔴 P0 |
| B4-DVS.2 | CTA button triggers toggleBottomSheet() | TC-DVS-002 | mobile-app | 🔴 P0 |
| B4-DVS.3 | Close Bottom Sheet → updateStopFollowUI() | TC-DVS-003 | mobile-app | 🔴 P0 |
| B4-DVS.4 | "Ngừng theo dõi" link visibility condition | TC-DVS-004 | mobile-app | 🔴 P0 |
| B4-DVS.5 | Modal validation before show | TC-DVS-005 | mobile-app | 🟡 P1 |
| B4-DVS.6 | Disconnect clears localStorage + navigate | TC-DVS-006 | mobile-app | 🔴 P0 |

#### B.5 Ngừng theo dõi Patient

| Scenario | Description | Test ID | Service | Priority |
|----------|-------------|---------|---------|:--------:|
| B5.1 | Caregiver self-exit | TC-CON-008 | user-service | 🟡 P1 |
| B5.1 | Notify Patient (BR-020) | TC-NOT-006 | schedule-service | 🟡 P1 |

### PHẦN C: System Behaviors

| Scenario | Description | Test ID | Service | Priority |
|----------|-------------|---------|---------|:--------:|
| SYS.1 | ZNS → SMS fallback (BR-004) | TC-NOT-007 | schedule-service | 🔴 P0 |
| SYS.1 | 3x retry, 30s interval | TC-NOT-008 | schedule-service | 🔴 P0 |
| SYS.2 | Account deleted cascade (BR-022) | TC-DB-001 | database | 🔴 P0 |

---

## 2. API Endpoint ↔ Test Case Mapping

| Endpoint | Method | Test Cases |
|----------|:------:|------------|
| `/api/v1/connections/invite` | POST | TC-API-INV-001~010 |
| `/api/v1/connections/invite` | GET | TC-API-INV-011~015 |
| `/api/v1/connections/invites/{id}` | DELETE | TC-API-INV-036~042 |
| `/api/v1/connections/invites/{id}/accept` | POST | TC-API-INV-016~022 |
| `/api/v1/connections/invites/{id}/reject` | POST | TC-API-INV-023~028 |
| `/api/v1/connections` | GET | TC-API-CON-001~008 |
| `/api/v1/connections/{id}` | DELETE | TC-API-CON-009~014 |
| `/api/v1/connections/{id}/permissions` | GET | TC-API-PRM-001~005 |
| `/api/v1/connections/{id}/permissions` | PUT | TC-API-PRM-006~015 |
| `/api/v1/connections/viewing` | GET | TC-API-VW-001~005 |
| `/api/v1/connections/viewing` | PUT | TC-API-VW-006~012 |
| `/api/v1/patients/{id}/blood-pressure-chart` | GET | TC-API-BP-001~009 |
| `/api/v1/patients/{id}/periodic-reports` | GET | TC-API-RPT-001~008 |

---

## 3. gRPC Method ↔ Test Case Mapping

| Method | Service | Test Cases |
|--------|---------|------------|
| `CreateInvite` | user-service | TC-GRPC-001~010 |
| `GetInvite` | user-service | TC-GRPC-011~014 |
| `ListInvites` | user-service | TC-GRPC-015~020 |
| `AcceptInvite` | user-service | TC-GRPC-021~030 |
| `RejectInvite` | user-service | TC-GRPC-031~036 |
| `CancelInvite` | user-service | TC-GRPC-071~076 |
| `ListConnections` | user-service | TC-GRPC-037~044 |
| `Disconnect` | user-service | TC-GRPC-045~050 |
| `GetPermissions` | user-service | TC-GRPC-051~056 |
| `UpdatePermissions` | user-service | TC-GRPC-057~070 |
| `GetViewingPatient` | user-service | TC-GRPC-077~080 |
| `SetViewingPatient` | user-service | TC-GRPC-081~087 |
| `ListPermissionTypes` | user-service | TC-GRPC-088~092 |
| `GetBloodPressureChart` | user-service | TC-GRPC-093~100 |
| `GetPatientReports` | user-service | TC-GRPC-101~107 |

---

## 4. Database Table ↔ Test Case Mapping

| Table | Test Focus | Test Cases |
|-------|------------|------------|
| `relationships` | Seed data, Lookup | TC-DB-REL-001~005 |
| `connection_invites` | CRUD, Constraints, Status | TC-DB-INV-001~015 |
| `user_emergency_contacts` | Extension, contact_type | TC-DB-CON-001~010 |
| `connection_permissions` | 6 permissions, CRUD | TC-DB-PRM-001~012 |
| `connection_permission_types` | Permission types lookup | TC-DB-PTY-001~005 |
| `invite_notifications` | Retry, Channel tracking | TC-DB-NOT-001~008 |
| `caregiver_report_views` | **NEW v2.11** Report read tracking | TC-DB-CRV-001~007 |
| `idx_unique_viewing_patient` | Unique constraint for is_viewing | TC-DB-VW-001~003 |

---

## 5. Kafka Topic ↔ Test Case Mapping

| Topic | Publisher | Consumer | Test Cases |
|-------|-----------|----------|------------|
| `connection.invite.created` | user-service | schedule-service | TC-KFK-001~005 |
| `connection.invite.accepted` | user-service | schedule-service | TC-KFK-006~010 |
| `connection.invite.rejected` | user-service | schedule-service | TC-KFK-011~015 |
| `connection.status.changed` | user-service | schedule-service | TC-KFK-016~020 |
| `connection.permission.changed` | user-service | schedule-service | TC-KFK-021~025 |

---

## 6. Error Code ↔ Test Case Mapping

| Error Code | HTTP | Description | Test Cases |
|------------|:----:|-------------|------------|
| SELF_INVITE | 400 | Cannot invite yourself | TC-ERR-001 |
| DUPLICATE_PENDING | 400 | Already has pending invite | TC-ERR-002 |
| ALREADY_CONNECTED | 400 | Connection exists | TC-ERR-003 |
| INVITE_NOT_FOUND | 404 | Invite not found | TC-ERR-004 |
| CONNECTION_NOT_FOUND | 404 | Connection not found | TC-ERR-005 |
| NOT_AUTHORIZED | 403 | Not allowed | TC-ERR-006 |
| INVALID_PERMISSION_TYPE | 400 | Unknown permission | TC-ERR-007 |
| ZNS_SEND_FAILED | 503 | ZNS unavailable | TC-ERR-008 |
| SMS_SEND_FAILED | 503 | SMS unavailable | TC-ERR-009 |

---

## 7. Summary

| Category | Total Test Cases |
|----------|:----------------:|
| Unit Tests - user-service | 110 |
| Unit Tests - api-gateway | 65 |
| Unit Tests - schedule-service | 28 |
| Integration Tests - API | 80 |
| Integration Tests - gRPC | 55 |
| Database Tests | 62 |
| Kafka Tests | 25 |
| Error Handling Tests | 12 |
| **Grand Total** | **~437** |

> **v2.15 Changes:** +15 tests for Default View State (UX-DVS-001~005, Disconnect Side Effects), +6 for mobile tests

---

**Generated:** 2026-02-02T08:40:00+07:00  
**Workflow:** `/alio-testing`
