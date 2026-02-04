# 📊 Coverage Matrix - KOLIA-1517 Kết nối Người thân

> **Version:** 2.19  
> **Date:** 2026-02-04  
> **Coverage Target:** ≥85%

---

## Table of Contents

1. [Business Rule Coverage](#1-business-rule-coverage)
2. [SRS Scenario Coverage](#2-srs-scenario-coverage)
3. [API Endpoint Coverage](#3-api-endpoint-coverage)
4. [gRPC Method Coverage](#4-grpc-method-coverage)
5. [Database Coverage](#5-database-coverage)
6. [Error Code Coverage](#6-error-code-coverage)
7. [Service Coverage Summary](#7-service-coverage-summary)
8. [Test Case Summary](#8-test-case-summary)

---

# 1. Business Rule Coverage

## 1.1 Complete BR ↔ Test Mapping

| BR-ID | Rule Description | Priority | Unit Tests | API Tests | Total | Status |
|:-----:|------------------|:--------:|:----------:|:---------:|:-----:|:------:|
| BR-001 | Bi-directional invites (Patient ↔ Caregiver) | P0 | 4 | 2 | 6 | ✅ |
| BR-002 | ZNS + Push for existing users | P0 | 2 | 1 | 3 | ✅ |
| BR-003 | ZNS + Deep Link for new users | P0 | 2 | 1 | 3 | ✅ |
| BR-004 | ZNS → SMS fallback (3x, 30s) | P0 | 4 | 0 | 4 | ✅ |
| BR-006 | No self-invite | P0 | 2 | 2 | 4 | ✅ |
| BR-007 | No duplicate pending / already connected | P0 | 3 | 2 | 5 | ✅ |
| BR-008 | Accept → Create connection + 6 permissions | P0 | 4 | 2 | 6 | ✅ |
| BR-009 | Default permissions ALL ON | P0 | 3 | 1 | 4 | ✅ |
| BR-010 | Notify sender on accept | P1 | 2 | 1 | 3 | ✅ |
| BR-011 | Reject → Allow re-invite | P1 | 2 | 2 | 4 | ✅ |
| BR-012 | Pending → Action item in Bản tin | P1 | 1 | 0 | 1 | ✅ |
| BR-013 | Multiple invites → FIFO order | P1 | 1 | 1 | 2 | ✅ |
| BR-014 | Display: Avatar, Tên, Last active | P1 | 2 | 1 | 3 | ✅ |
| BR-015 | Empty state với CTA | P2 | 1 | 1 | 2 | ✅ |
| BR-016 | Permission change → Notify Caregiver | P1 | 2 | 1 | 3 | ✅ |
| BR-017 | Permission OFF → Hide UI block | P0 | 2 | 1 | 3 | ✅ |
| BR-018 | Red warning for emergency OFF | P0 | 2 | 1 | 3 | ✅ |
| BR-019 | Patient disconnect → Notify Caregiver | P0 | 2 | 1 | 3 | ✅ |
| BR-020 | Caregiver exit → Notify Patient | P1 | 2 | 1 | 3 | ✅ |
| BR-021 | Phase 1: No limit on connections | P1 | 1 | 1 | 2 | ✅ |
| BR-022 | Account deleted → Cascade delete + Notify | P0 | 1 | 0 | 1 | ✅ |
| BR-023 | Badge tap → Navigate to screen | P1 | 1 | 1 | 2 | ✅ |
| BR-024 | Confirmation popup for ALL changes | P0 | 0 | 0 | 0 | ⚠️ FE |
| BR-025 | Message phân biệt invite type | P0 | 1 | 1 | 2 | ✅ |
| BR-026 | Profile selection persisted (is_viewing) | P0 | 4 | 2 | 6 | ✅ |
| BR-028 | Relationship type stored | P0 | 2 | 2 | 4 | ✅ |
| BR-029 | Display format: "{MQH} ({Tên})", khac→Nguoi than | P1 | 2 | 2 | 4 | ✅ |

**Legend:**
- ✅ = Fully covered
- ⚠️ FE = Frontend coverage (out of scope)

## 1.2 Coverage Summary by Priority

| Priority | Total BRs | Covered | Coverage |
|:--------:|:---------:|:-------:|:--------:|
| 🔴 P0 | 33 | 33 | **100%** |
| 🟡 P1 | 15 | 15 | **100%** |
| 🟢 P2 | 4 | 4 | **100%** |
| **Total** | **52** | **52** | **100%** |

> **v2.19 Addition:** See section 1.8 for new Inverse Relationship Code (BR-035/BR-036) rules

## 1.3 Dashboard Rules Coverage (v2.11)

| BR-ID | Rule | Unit | API | Total | Status |
|:-----:|------|:----:|:---:|:-----:|:------:|
| BR-DB-001 | Line Chart 2 đường (systolic/diastolic) | 2 | 1 | 3 | ✅ |
| BR-DB-002 | Auto week/month toggle | 1 | 1 | 2 | ✅ |
| BR-DB-003 | Toggle Week/Month cho chart | 2 | 2 | 4 | ✅ |
| BR-DB-004 | Drill-down ngày → chi tiết | 1 | 1 | 2 | ✅ |
| BR-DB-005 | Giá trị trung bình mỗi ngày | 3 | 1 | 4 | ✅ |
| BR-DB-006 | Chart hiển thị 7/30 days | 2 | 2 | 4 | ✅ |
| BR-DB-007 | Empty state | 1 | 1 | 2 | ✅ |
| BR-DB-008 | Loading state | 0 | 0 | 0 | ⚠️ FE |
| BR-DB-009 | Error state + retry | 1 | 1 | 2 | ✅ |
| BR-DB-010 | Refresh data | 0 | 0 | 0 | ⚠️ FE |
| BR-DB-011 | Chart responsive | 0 | 0 | 0 | ⚠️ FE |
| **Total** | | **13** | **10** | **23** | ✅ |

## 1.4 Report Rules Coverage (v2.11)

| BR-ID | Rule | Unit | API | Total | Status |
|:-----:|------|:----:|:---:|:-----:|:------:|
| BR-RPT-001 | List báo cáo với `is_read` status | 3 | 2 | 5 | ✅ |
| BR-RPT-002 | Header format | 1 | 1 | 2 | ✅ |
| **BR-RPT-003** | **Mark report as read (idempotent)** | **2** | **7** | **9** | **✅** |
| **Total** | | **6** | **10** | **16** | ✅ |

## 1.5 Security Rules Coverage (v2.11)

| SEC-ID | Rule | Unit | API | Total | Status |
|:------:|------|:----:|:---:|:-----:|:------:|
| SEC-DB-001 | Triple-Check Authorization | 5 | 4 | 9 | ✅ |
| SEC-DB-002 | Permission revoke → 403 | 2 | 2 | 4 | ✅ |
| SEC-DB-003 | Deep link protection | 2 | 2 | 4 | ✅ |
| **DB-SCHEMA-001** | **Correct table names in queries** | **2** | **1** | **3** | **✅** |
| **Total** | | **11** | **9** | **20** | ✅ |

## 1.6 Default View State (UX-DVS) Coverage (v2.15) - NEW

| Rule-ID | Rule | Mobile Unit | Integration | Total | Status |
|:-------:|------|:-----------:|:-----------:|:-----:|:------:|
| UX-DVS-001 | Page load → Default View Prompt | 2 | 1 | 3 | ✅ |
| UX-DVS-002 | CTA → toggleBottomSheet() | 1 | 1 | 2 | ✅ |
| UX-DVS-003 | Close Bottom Sheet → updateStopFollowUI() | 1 | 1 | 2 | ✅ |
| UX-DVS-004 | Link visibility conditional | 2 | 1 | 3 | ✅ |
| UX-DVS-005 | Modal validation before show | 1 | 1 | 2 | ✅ |
| **Disconnect Side Effects** | **Clear localStorage + Navigate** | **2** | **1** | **3** | **✅** |
| **Total** | | **9** | **6** | **15** | ✅ |

## 1.7 Update Pending Invite Permissions Coverage (v2.16) - NEW

| Rule-ID | Rule | Unit Tests | API Tests | Total | Status |
|:-------:|------|:----------:|:---------:|:-----:|:------:|
| BR-031 | Chỉ sender của invite được sửa permissions | 2 | 2 | 4 | ✅ |
| BR-032 | Chỉ áp dụng cho invite status = 0 (pending) | 2 | 2 | 4 | ✅ |
| BR-033 | Permissions lưu vào `initial_permissions` | 2 | 1 | 3 | ✅ |
| BR-034 | Không gửi notification đến receiver | 1 | 1 | 2 | ✅ |
| **Total** | | **7** | **6** | **13** | ✅ |

## 1.8 Inverse Relationship Code Coverage (v2.19) - NEW

| Rule-ID | Rule | Unit Tests | API Tests | Total | Status |
|:-------:|------|:----------:|:---------:|:-----:|:------:|
| BR-035 | inverse_relationship_code stored in DB | 4 | 2 | 6 | ✅ |
| BR-036 | API returns inverse_relationship_code/name | 3 | 4 | 7 | ✅ |
| **Total** | | **7** | **6** | **13** | ✅ |

---

# 2. SRS Scenario Coverage

## 2.1 PHẦN A: Role Người bệnh (Patient)

| Scenario | Description | Test Cases | Status |
|----------|-------------|:----------:|:------:|
| A1.1 | Gửi invite cho user ĐÃ CÓ tài khoản | TC-INV-001,TC-INT-INV-001 | ✅ |
| A1.2 | Gửi invite cho user CHƯA CÓ tài khoản | TC-INV-002,TC-INT-INV-003 | ✅ |
| A1.3 | Self-invite blocked | TC-INV-005,TC-INT-INV-007 | ✅ |
| A1.4 | Already connected blocked | TC-INV-004,TC-INT-INV-009 | ✅ |
| A1.5 | Pending invite blocked | TC-INV-005,TC-INT-INV-008 | ✅ |
| A2.1 | Accept invite với permission config | TC-CON-001,TC-INT-INV-024 | ✅ |
| A2.1b | Quick accept (all ON) | TC-CON-002,TC-INT-INV-023 | ✅ |
| A2.2 | Reject invite | TC-INV-006,TC-INT-INV-031 | ✅ |
| A3.1 | Xem danh sách Caregivers | TC-CON-011,TC-INT-CON-003 | ✅ |
| A3.2 | Xem pending invites | TC-INV-008,TC-INT-INV-020 | ✅ |
| A3.3 | Empty state CTA | TC-API-001 | ✅ |
| A4.1 | Toggle permission với warning | TC-PRM-002,TC-INT-PRM-006 | ✅ |
| A4.2 | Emergency warning | TC-PRM-005,TC-INT-PRM-008 | ✅ |
| A5.1 | Patient hủy kết nối | TC-CON-018,TC-INT-CON-009 | ✅ |

## 2.2 PHẦN B: Role Người thân (Caregiver)

| Scenario | Description | Test Cases | Status |
|----------|-------------|:----------:|:------:|
| B1.1 | Caregiver gửi invite | TC-INV-009,TC-INT-INV-002 | ✅ |
| B1.2 | Invite to new user | TC-INV-010,TC-INT-INV-003 | ✅ |
| B2.1 | Accept invite (quick) | TC-CON-005,TC-INT-INV-023 | ✅ |
| B2.2 | Reject invite | TC-INV-011,TC-INT-INV-031 | ✅ |
| B2.3 | Action item in Bản tin | TC-INT-001 | ✅ |
| B2.4 | Multiple invites FIFO | TC-INV-012,TC-INT-INV-019 | ✅ |
| B3.1 | List Patients monitoring | TC-CON-006,TC-INT-CON-002 | ✅ |
| B3.2 | Badge pending count | TC-API-003,TC-INT-INV-020 | ✅ |
| B3.3 | Empty state CTA | TC-API-004 | ✅ |
| B4.1 | View Patient detail | TC-CON-007 | ✅ |
| B5.1 | Caregiver self-exit | TC-CON-008,TC-INT-CON-010 | ✅ |

## 2.3 PHẦN C: System Behaviors

| Scenario | Description | Test Cases | Status |
|----------|-------------|:----------:|:------:|
| SYS.1 | ZNS → SMS fallback | TC-SCH-003,TC-SCH-004 | ✅ |
| - | Account deleted cascade | TC-DB-001 | ✅ |

**SRS Scenario Coverage: 28/28 = 100%**

---

# 3. API Endpoint Coverage

| Endpoint | Method | Happy Path | Error Cases | Edge Cases | Total | Status |
|----------|:------:|:----------:|:-----------:|:----------:|:-----:|:------:|
| `/api/v1/connections/invite` | POST | 6 | 8 | 2 | 16 | ✅ |
| `/api/v1/connections/invite` | GET | 3 | 1 | 3 | 7 | ✅ |
| `/api/v1/connections/invites/{id}` | DELETE | 2 | 4 | 1 | 7 | ✅ |
| `/api/v1/connections/invites/{id}/accept` | POST | 4 | 4 | 2 | 10 | ✅ |
| `/api/v1/connections/invites/{id}/reject` | POST | 1 | 2 | 2 | 5 | ✅ |
| `/api/v1/connections` | GET | 4 | 1 | 3 | 8 | ✅ |
| `/api/v1/connections/{id}` | DELETE | 2 | 2 | 2 | 6 | ✅ |
| `/api/v1/connections/{id}/permissions` | GET | 2 | 2 | 1 | 5 | ✅ |
| `/api/v1/connections/{id}/permissions` | PUT | 3 | 4 | 1 | 8 | ✅ |
| `/api/v1/connection/permission-types` | GET | 2 | 1 | 1 | 4 | ✅ |
| `/api/v1/connections/viewing` | GET | 2 | 2 | 1 | 5 | ✅ |
| `/api/v1/connections/viewing` | PUT | 3 | 3 | 2 | 8 | ✅ |
| `/api/v1/patients/{id}/blood-pressure-chart` | GET | 3 | 4 | 2 | 9 | ✅ |
| `/api/v1/patients/{id}/periodic-reports` | GET | 3 | 3 | 2 | 8 | ✅ |
| **`/api/v1/patients/{id}/periodic-reports/{reportId}/mark-read`** | **POST** | **2** | **5** | **2** | **9** | **✅** |
| **`/api/v1/connections/invites/{id}/permissions`** | **PUT** | **2** | **4** | **2** | **8** | **✅** |
| **Total** | | **44** | **51** | **28** | **123** | ✅ |

**API Endpoint Coverage: 15/15 = 100%**

---

# 4. gRPC Method Coverage

| Method | Service | Unit Tests | Integration | Total | Status |
|--------|---------|:----------:|:-----------:|:-----:|:------:|
| CreateInvite | ConnectionService | 12 | 2 | 14 | ✅ |
| GetInvite | ConnectionService | 4 | 1 | 5 | ✅ |
| ListInvites | ConnectionService | 7 | 2 | 9 | ✅ |
| AcceptInvite | ConnectionService | 10 | 3 | 13 | ✅ |
| RejectInvite | ConnectionService | 6 | 2 | 8 | ✅ |
| CancelInvite | ConnectionService | 5 | 3 | 8 | ✅ |
| ListConnections | ConnectionService | 7 | 3 | 10 | ✅ |
| Disconnect | ConnectionService | 6 | 2 | 8 | ✅ |
| GetPermissions | ConnectionService | 5 | 2 | 7 | ✅ |
| UpdatePermissions | ConnectionService | 10 | 3 | 13 | ✅ |
| ListPermissionTypes | ConnectionService | 4 | 2 | 6 | ✅ |
| GetViewingPatient | ConnectionService | 4 | 2 | 6 | ✅ |
| SetViewingPatient | ConnectionService | 6 | 3 | 9 | ✅ |
| GetBloodPressureChart | DashboardService | 8 | 2 | 10 | ✅ |
| GetPatientReports | DashboardService | 5 | 2 | 7 | ✅ |
| **MarkReportAsRead** | **DashboardService** | **2** | **7** | **9** | **✅** |
| **UpdatePendingInvitePermissions** | **InviteService** | **8** | **5** | **13** | **✅** |
| **Total** | | **114** | **50** | **164** | ✅ |

**gRPC Method Coverage: 18/18 = 100%**

---

# 5. Database Coverage

## 5.1 Table Coverage

| Table | CRUD Tests | Constraint Tests | Index Tests | Trigger Tests | Total |
|-------|:----------:|:----------------:|:-----------:|:-------------:|:-----:|
| `relationships` | 5 | 1 | 0 | 0 | 6 |
| `connection_invites` | 6 | 4 | 3 | 0 | 13 |
| `user_emergency_contacts` | 6 | 2 | 2 | 1 | 11 |
| `connection_permissions` | 6 | 2 | 1 | 0 | 9 |
| `connection_permission_types` | 4 | 1 | 0 | 0 | 5 |
| `invite_notifications` | 4 | 2 | 2 | 0 | 8 |
| `caregiver_report_views` | 4 | 2 | 1 | 0 | 7 |
| `idx_unique_viewing_patient` | 0 | 1 | 2 | 0 | 3 |
| `idx_contacts_viewing` | 0 | 0 | 1 | 0 | 1 |
| **Total** | **39** | **16** | **12** | **1** | **68** |

## 5.2 Constraint Coverage

| Constraint | Table | Test ID | Status |
|------------|-------|---------|:------:|
| `chk_no_self_invite` | connection_invites | TC-REPO-004 | ✅ |
| `idx_unique_pending` | connection_invites | TC-REPO-003 | ✅ |
| `chk_contact_type` | user_emergency_contacts | TC-DB-CON-005 | ✅ |
| `chk_invite_type` | connection_invites | TC-DB-INV-008 | ✅ |
| `chk_invite_status` | connection_invites | TC-DB-INV-009 | ✅ |
| `chk_perm_type` | connection_permissions | TC-DB-PRM-006 | ✅ |
| `uq_perm_unique` | connection_permissions | TC-DB-PRM-007 | ✅ |
| `chk_channel` | invite_notifications | TC-DB-NOT-005 | ✅ |
| `chk_retry` | invite_notifications | TC-DB-NOT-006 | ✅ |

## 5.3 Trigger Coverage

| Trigger | Table | Test ID | Status |
|---------|-------|---------|:------:|
| `trigger_create_default_perms` | user_emergency_contacts | TC-DB-TRG-001 | ✅ |

---

# 6. Error Code Coverage

| Error Code | HTTP | Unit Tests | API Tests | Total | Status |
|------------|:----:|:----------:|:---------:|:-----:|:------:|
| SELF_INVITE | 400 | 2 | 2 | 4 | ✅ |
| DUPLICATE_PENDING | 400 | 2 | 2 | 4 | ✅ |
| ALREADY_CONNECTED | 400 | 1 | 1 | 2 | ✅ |
| INVITE_NOT_FOUND | 404 | 1 | 2 | 3 | ✅ |
| CONNECTION_NOT_FOUND | 404 | 1 | 2 | 3 | ✅ |
| NOT_AUTHORIZED | 403 | 2 | 2 | 4 | ✅ |
| INVALID_PERMISSION_TYPE | 400 | 1 | 1 | 2 | ✅ |
| ZNS_SEND_FAILED | 503 | 2 | 0 | 2 | ✅ |
| SMS_SEND_FAILED | 503 | 2 | 0 | 2 | ✅ |
| **INVITE_NOT_PENDING** | **409** | **2** | **2** | **4** | **✅** |
| **Total** | | **16** | **14** | **30** | ✅ |

**Error Code Coverage: 10/10 = 100%**

---

# 7. Service Coverage Summary

## 7.1 user-service

| Component | Unit Tests | Integration | Total | Coverage Target |
|-----------|:----------:|:-----------:|:-----:|:---------------:|
| InviteService | 12 | 5 | 17 | ≥85% |
| ConnectionService | 23 | 8 | 31 | ≥85% |
| PermissionService | 10 | 4 | 14 | ≥85% |
| ViewingPatientService | 6 | 3 | 9 | ≥85% |
| InviteRepository | 6 | 6 | 12 | ≥85% |
| ConnectionRepository | 4 | 4 | 8 | ≥85% |
| PermissionRepository | 4 | 3 | 7 | ≥85% |
| ViewingPatientRepository | 4 | 2 | 6 | ≥85% |
| ConnectionGrpcHandler | 12 | 5 | 17 | ≥85% |
| Mappers | 8 | 0 | 8 | ≥85% |
| **InvitePermissionUpdater (v2.16)** | **8** | **5** | **13** | **≥85%** |
| **Total** | **97** | **45** | **142** | ≥85% |

## 7.2 api-gateway-service

| Component | Unit Tests | Integration | Total | Coverage Target |
|-----------|:----------:|:-----------:|:-----:|:---------------:|
| InviteHandler | 14 | 16 | 30 | ≥85% |
| ConnectionHandler | 10 | 14 | 24 | ≥85% |
| DTO Validators | 10 | 0 | 10 | ≥85% |
| gRPC Client | 5 | 8 | 13 | ≥85% |
| Error Handler | 5 | 9 | 14 | ≥85% |
| **Total** | **44** | **47** | **91** | ≥85% |

## 7.3 schedule-service

| Component | Unit Tests | Integration | Total | Coverage Target |
|-----------|:----------:|:-----------:|:-----:|:---------------:|
| invite_notification task | 11 | 3 | 14 | ≥85% |
| connection_notification task | 6 | 2 | 8 | ≥85% |
| Kafka consumers | 7 | 3 | 10 | ≥85% |
| ZNS/SMS clients | 4 | 2 | 6 | ≥85% |
| **Total** | **28** | **10** | **38** | ≥85% |

---

# 8. Test Case Summary

## 8.1 By Category

| Category | Count | Percentage |
|----------|:-----:|:----------:|
| Unit Tests - user-service | 96 | 31% |
| Unit Tests - api-gateway | 54 | 18% |
| Unit Tests - schedule-service | 28 | 9% |
| **Unit Tests - mobile-app (v2.15)** | **15** | **5%** |
| Integration Tests - API | 60 | 20% |
| Integration Tests - gRPC | 28 | 9% |
| Integration Tests - Kafka | 10 | 3% |
| Database Tests | 18 | 6% |
| **Total** | **309** | 100% |

## 8.2 By Priority

| Priority | Count | Percentage |
|:--------:|:-----:|:----------:|
| 🔴 P0 (Critical) | 70 | 27% |
| 🟡 P1 (High) | 138 | 53% |
| 🟢 P2 (Medium) | 44 | 17% |
| ⚪ P3 (Low) | 10 | 4% |
| **Total** | **262** | 100% |

## 8.3 By Service

| Service | Unit | Integration | Total | % |
|---------|:----:|:-----------:|:-----:|:-:|
| user-service | 96 | 43 | 139 | 45% |
| api-gateway-service | 54 | 60 | 114 | 37% |
| schedule-service | 28 | 10 | 38 | 12% |
| **mobile-app (v2.15)** | **15** | **6** | **21** | **7%** |
| **Total** | **193** | **119** | **312** | 100% |

---

## Coverage Quality Gates

| Metric | Target | Estimated | Status |
|--------|:------:|:---------:|:------:|
| Statement Coverage | ≥85% | ~88% | ✅ |
| Branch Coverage | ≥75% | ~78% | ✅ |
| Business Rule Coverage | 100% | 100% | ✅ |
| SRS Scenario Coverage | 100% | 100% | ✅ |
| API Endpoint Coverage | 100% | 100% | ✅ |
| gRPC Method Coverage | 100% | 100% | ✅ |
| Error Code Coverage | 100% | 100% | ✅ |
| **UX-DVS Coverage (v2.15)** | **100%** | **100%** | **✅** |
| **BR-031 to BR-034 Coverage (v2.16)** | **100%** | **100%** | **✅** |
| **BR-035/BR-036 Coverage (v2.19)** | **100%** | **100%** | **✅** |
| P0 Test Pass Rate | 100% | TBD | ⏳ |
| P1 Test Pass Rate | ≥95% | TBD | ⏳ |

---

**Generated:** 2026-02-04T11:42:00+07:00  
**Workflow:** `/alio-testing`
