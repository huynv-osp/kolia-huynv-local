# 📋 Test Plan - Kết nối Người thân (KOLIA-1517)

## Document Information

| Attribute | Value |
|-----------|-------|
| **Version** | 2.19 |
| **Date** | 2026-02-04 |
| **Author** | Test Generator (Automated via /alio-testing) |
| **Status** | Draft |
| **Feature** | KOLIA-1517 - Kết nối Người thân (Connection Flow) |
| **SRS Version** | v3.0 |
| **FA Version** | v2.19 |
| **Changes** | Added inverse_relationship_code (BR-035/BR-036) + API response fields (v2.19) |

---

## Table of Contents

1. [Test Objectives](#1-test-objectives)
2. [Test Scope](#2-test-scope)
3. [Test Strategy](#3-test-strategy)
4. [Test Environment](#4-test-environment)
5. [Test Categories](#5-test-categories)
6. [Business Rules Coverage](#6-business-rules-coverage)
7. [Test Schedule](#7-test-schedule)
8. [Entry/Exit Criteria](#8-entryexit-criteria)
9. [Risk Analysis](#9-risk-analysis)

---

# 1. Test Objectives

## 1.1 Primary Objectives

1. **Validate Bi-directional Invite Flow**: Đảm bảo cả Patient và Caregiver có thể gửi invite (BR-001)
2. **Validate Permission System**: 6 RBAC permissions hoạt động đúng (BR-009, BR-016, BR-017)
3. **Validate Notification Cascades**: ZNS → SMS fallback, Push notifications (BR-002, BR-003, BR-004)
4. **Validate State Transitions**: Invite lifecycle (pending/accepted/rejected), Connection lifecycle
5. **Validate Business Rules**: Đảm bảo **46 business rules** được implement đúng (incl. BR-DB-*, BR-RPT-*, SEC-DB-*, UX-DVS-*)
6. **Validate API Contracts**: **18 REST endpoints**, **17 gRPC methods**
7. **Validate Error Handling**: All 10 error codes handled correctly
8. **Validate Dashboard APIs (v2.11)**: Blood Pressure Chart, Periodic Reports với Authorization Flow
9. **Validate Mark Report Read API (v2.14)**: Đánh dấu báo cáo đã đọc với SEC-DB-001 check
10. **Validate Default View State (v2.15)**: Đảm bảo UX-DVS-001 → UX-DVS-005 hoạt động đúng
11. **Validate Update Pending Invite Permissions (v2.16)**: Đảm bảo BR-031 → BR-034 hoạt động đúng
12. **Validate Inverse Relationship Code (v2.18/v2.19)**: Đảm bảo BR-035/BR-036 cho bidirectional relationship display hoạt động đúng (NEW)

## 1.2 Coverage Targets

| Metric | Target | Measurement |
|--------|:------:|-------------|
| Statement Coverage | ≥85% | JaCoCo (Java), pytest-cov (Python) |
| Branch Coverage | ≥75% | JaCoCo, pytest-cov |
| API Endpoint Coverage | 100% | All **18** REST endpoints tested |
| gRPC Method Coverage | 100% | All **17** gRPC methods tested |
| Business Rule Coverage | 100% | All **52** rules validated (v2.19: +BR-035/BR-036) |
| Error Code Coverage | 100% | All 10 error codes tested |
| Gherkin Scenario Coverage | 100% | All SRS scenarios covered |
| Dashboard API Coverage | 100% | BP Chart + Reports tested |
| Default View State Coverage | 100% | All 5 UX-DVS rules tested |
| Update Pending Invite Permissions Coverage | 100% | All 4 BR-031 to BR-034 rules tested |
| **Inverse Relationship Coverage** | **100%** | **BR-035/BR-036 bidirectional display tested (NEW v2.19)** |

---

# 2. Test Scope

## 2.1 In Scope

### Backend Services

| Service | Components | Test Types |
|---------|------------|------------|
| **api-gateway-service** | **14** REST endpoints, DTOs, gRPC client | Unit, Integration |
| **user-service** | ConnectionService gRPC (**15** methods), **5** Repos, **5** Services | Unit, Integration |
| **schedule-service** | 3 Celery tasks, ZNS/SMS integration | Unit, Integration |

### API Endpoints

| Method | Path | Test Focus |
|:------:|------|------------|
| POST | `/api/v1/connections/invite` | Create invite (both types), Validation |
| GET | `/api/v1/connections/invites` | List sent/received, Filtering |
| DELETE | `/api/v1/connections/invites/{id}` | Cancel pending invite |
| POST | `/api/v1/connections/invites/{id}/accept` | Accept with/without permissions |
| POST | `/api/v1/connections/invites/{id}/reject` | Reject, Re-invite allowed |
| GET | `/api/v1/connections` | List monitoring/monitored_by |
| DELETE | `/api/v1/connections/{id}` | Disconnect, Notifications |
| GET | `/api/v1/connections/{id}/permissions` | Get 6 permissions |
| PUT | `/api/v1/connections/{id}/permissions` | Toggle permissions |
| GET | `/api/v1/connection/permission-types` | List all permission types (v2.6) |
| GET | `/api/v1/connection/relationship-types` | List all relationship types (v2.8) |
| GET | `/api/v1/connections/viewing` | Get currently viewing patient (v2.7) |
| PUT | `/api/v1/connections/viewing` | Set viewing patient (v2.7) |
| GET | `/api/v1/patients/{id}/blood-pressure-chart` | **Dashboard API (v2.11)** - BP Chart data |
| GET | `/api/v1/patients/{id}/periodic-reports` | **Dashboard API (v2.11)** - Report list + is_read |
| **POST** | **`/api/v1/patients/{id}/periodic-reports/{reportId}/mark-read`** | **Mark Report Read (v2.14)** |
| **PUT** | **`/api/v1/connections/invites/{id}/permissions`** | **Update Pending Invite Permissions (v2.16)** |

### Database Tables

| Table | Focus Areas |
|-------|-------------|
| `relationships` | Seed data (17 types), Lookup |
| `connection_invites` | CRUD, Status transitions, Unique constraints |
| `user_emergency_contacts` | Extended columns, contact_type, is_viewing |
| `connection_permissions` | 6 types, Enable/Disable |
| `connection_permission_types` | Permission lookup table (v2.6) |
| `invite_notifications` | Retry logic, Channel tracking |
| `caregiver_report_views` | **NEW v2.11** - Report read tracking per caregiver |

> **v2.7 Addition:** `is_viewing` column with unique constraint for profile selection  
> **v2.11 Addition:** `caregiver_report_views` table for Dashboard report read status

### Business Rules

- **52 Business Rules** total:
  - Connection Rules: BR-001 → BR-029 (25 rules)
  - Update Pending Invite Permissions: BR-031 → BR-034 (4 rules)
  - **Inverse Relationship: BR-035 → BR-036 (2 rules) - NEW v2.19**
  - Dashboard Rules: BR-DB-001 → BR-DB-011 (11 rules)
  - Report Rules: BR-RPT-001 → BR-RPT-003 (3 rules)
  - Security Rules: SEC-DB-001 → SEC-DB-003 (3 rules)
  - Default View State: UX-DVS-001 → UX-DVS-005 (5 rules)
- 20+ Gherkin scenarios from SRS v3.0

## 2.2 Out of Scope

| Item | Reason |
|------|--------|
| Mobile UI Tests | Separate test plan |
| E2E Performance Tests | Separate test plan |
| External Integration (ZNS, SMS) | Mock-based testing only |
| Load Testing | Separate test plan |
| Profile Selector UI Logic | Frontend testing |

---

# 3. Test Strategy

## 3.1 Test Pyramid

```
                    ┌─────────────────┐
                    │   E2E Tests     │  ← Manual / Later
                    │   (5%)          │
                    └────────┬────────┘
               ┌─────────────┴─────────────┐
               │  Integration Tests (25%)  │  ← API + gRPC
               └─────────────┬─────────────┘
          ┌──────────────────┴──────────────────┐
          │         Unit Tests (70%)            │  ← Focus
          └─────────────────────────────────────┘
```

## 3.2 Testing Approach by Service

### api-gateway-service (Java/Vert.x)

| Test Type | Framework | Focus |
|-----------|-----------|-------|
| Unit Tests | JUnit 5 + Mockito | InviteHandler, ConnectionHandler, Validators |
| Integration Tests | WebTestClient + WireMock | REST endpoints flow |
| Mock External | WireMock | user-service gRPC |

### user-service (Java/Vert.x)

| Test Type | Framework | Focus |
|-----------|-----------|-------|
| Unit Tests | JUnit 5 + Mockito | InviteService, ConnectionService, PermissionService |
| Integration Tests | Testcontainers (PostgreSQL) | Repository queries |
| gRPC Tests | grpc-testing | ConnectionService gRPC |

### schedule-service (Python/Celery)

| Test Type | Framework | Focus |
|-----------|-----------|-------|
| Unit Tests | pytest + unittest.mock | invite_notification, connection_notification tasks |
| Integration Tests | pytest + responses/aioresponses | ZNS/SMS client |
| Task Tests | Celery testing utilities | Task execution, retry |

## 3.3 Mocking Strategy

| External Dependency | Mock Approach |
|---------------------|---------------|
| **ZNS API** | WireMock stub / responses library |
| **SMS Gateway** | WireMock stub |
| **Push Service** | Mock client |
| **Database** | Testcontainers (PostgreSQL) |
| **Redis** | Testcontainers |
| **Kafka** | EmbeddedKafka / Testcontainers |
| **gRPC Services** | InProcessServer / Mock stubs |

---

# 4. Test Environment

## 4.1 Environments

| Environment | Purpose | Configuration |
|-------------|---------|---------------|
| **Local** | Developer testing | Docker Compose |
| **CI/CD** | Automated testing | GitHub Actions |
| **QA** | Integration testing | Kubernetes |

## 4.2 Test Data

### Fixture Strategy

| Data Type | Approach |
|-----------|----------|
| Users | Factory pattern with Faker |
| Relationships | Seed data from SQL (17 types) |
| Invites | Builder pattern |
| Connections | Factory + Builder |
| Permissions | Pre-defined 6 defaults |

### Sample Data

```yaml
# test-fixtures.yaml
users:
  patient:
    id: "patient-001"
    name: "Nguyễn Văn Patient"
    phone: "0901234567"
    
  caregiver:
    id: "caregiver-001"
    name: "Nguyễn Văn Caregiver"
    phone: "0912345678"
    
  caregiver_no_account:
    phone: "0987654321"
    exists: false

relationships:
  - code: "con_trai"
    name_vi: "Con trai"
  - code: "me"
    name_vi: "Mẹ"
  - code: "khac"
    name_vi: "Khác"

invites:
  pending:
    id: "invite-001"
    sender_id: "patient-001"
    receiver_phone: "0912345678"
    invite_type: "patient_to_caregiver"
    status: 0  # pending
    
permissions:
  default_all_on:
    health_overview: true
    emergency_alert: true
    task_config: true
    compliance_tracking: true
    proxy_execution: true
    encouragement: true
```

---

# 5. Test Categories

## 5.1 Unit Test Categories

| Category | Focus | Example |
|----------|-------|---------|
| **Handler Tests** | REST endpoint handlers | InviteHandler.create(), ConnectionHandler.list() |
| **Service Tests** | Business logic | InviteService.createInvite(), ConnectionService.acceptInvite() |
| **Repository Tests** | Data access | ConnectionInviteRepository.findPendingByPhone() |
| **Validator Tests** | Input validation | PhoneValidator.isValid(), RelationshipValidator |
| **Mapper Tests** | Object mapping | InviteMapper.toProto(), ConnectionMapper.toResponse() |
| **Task Tests** | Celery tasks | send_invite_notification(), notify_connection_change() |

## 5.2 Integration Test Categories

| Category | Focus | Example |
|----------|-------|---------|
| **API Tests** | Full endpoint flow | POST /api/v1/connections/invite → 201 Created |
| **gRPC Tests** | Inter-service calls | ConnectionService.AcceptInvite() |
| **Database Tests** | Real DB queries | Partial indexes, Constraints |
| **Kafka Tests** | Event publishing | connection.invite.created topic |
| **External API Tests** | Mocked external calls | ZNS/SMS integration |

## 5.3 Test Case Prioritization

| Priority | Criteria | Count |
|:--------:|----------|:-----:|
| 🔴 P0 (Critical) | Core invite/connection flow, Safety-critical (BR-018) | ~55 |
| 🟡 P1 (High) | Error handling, Notification, State transitions | ~70 |
| 🟢 P2 (Medium) | Edge cases, Performance, Display logic | ~40 |
| ⚪ P3 (Low) | Nice-to-have, Logging, Analytics | ~15 |

**Total Estimated Test Cases: ~200**

---

# 6. Business Rules Coverage

## 6.1 Critical Business Rules (P0)

| BR-ID | Rule | Test Category |
|-------|------|---------------|
| BR-001 | Bi-directional invites | InviteService |
| BR-006 | No self-invite | InviteService, API |
| BR-007 | No duplicate pending | InviteService, Repository |
| BR-008 | Accept → Create connection + 6 perms | ConnectionService |
| BR-009 | Default permissions ALL ON | PermissionService, Trigger |
| BR-017 | Permission OFF → Hide UI | API Response |
| BR-018 | Red warning for emergency OFF | Frontend (skip) |
| BR-022 | Account deleted → Cascade | Database Trigger |
| BR-024 | Confirmation for ALL changes | Frontend (skip) |

## 6.2 High Priority Rules (P1)

| BR-ID | Rule | Test Category |
|-------|------|---------------|
| BR-002 | ZNS + Push for existing users | schedule-service |
| BR-003 | ZNS + Deep Link for new users | schedule-service |
| BR-004 | ZNS → SMS fallback (3x, 30s) | schedule-service |
| BR-010 | Notify sender on accept | Kafka event |
| BR-011 | Reject → Allow re-invite | State machine |
| BR-016 | Permission change → Notify | Kafka event |
| BR-019 | Patient disconnect → Notify Caregiver | Kafka event |
| BR-020 | Caregiver exit → Notify Patient | Kafka event |
| BR-028 | Relationship stored | Database, Entity |
| **BR-035** | **Inverse relationship stored (v2.18)** | **Database, Entity** |
| **BR-036** | **API returns inverse_relationship_code/name (v2.19)** | **API Response** |

## 6.3 Medium Priority Rules (P2)

| BR-ID | Rule | Test Category |
|-------|------|---------------|
| BR-012 | Pending → Action item in Bản tin | Integration |
| BR-013 | Multiple invites → FIFO | Repository sort |
| BR-014 | Display: Avatar, Tên, Last active | API Response |
| BR-015 | Empty state với CTA | Frontend (skip) |
| BR-021 | No limit on connections | Repository |
| BR-023 | Badge tap → Navigate | Frontend (skip) |
| BR-025 | Message phân biệt invite type | API Response |
| BR-026 | Profile selection persisted (is_viewing) | ViewingPatientService, Repository |
| BR-029 | Display format: "{Mối QH} ({Tên})" | API Mapper |

## 6.4 Dashboard Rules (v2.11 - P0/P1)

| BR-ID | Rule | Test Category | Priority |
|-------|------|---------------|:--------:|
| BR-DB-001 | Line Chart 2 đường (Tâm thu xanh lá, Tâm trương xanh dương) | API Response, Mapper | 🔴 P0 |
| BR-DB-002 | Auto week/month toggle based on data availability | Service Logic | 🟡 P1 |
| BR-DB-003 | Toggle Week/Month cho chart | API Query Params | 🔴 P0 |
| BR-DB-004 | Drill-down ngày → danh sách chi tiết | API Response | 🟡 P1 |
| BR-DB-005 | Giá trị trung bình mỗi ngày tính từ measurements | Service Calculation | 🔴 P0 |
| BR-DB-006 | Chart hiển thị 7 days (week) hoặc ~30 days (month) | Service Logic | 🔴 P0 |
| BR-DB-007 | Empty state khi không có data trong khoảng thời gian | API Response | 🟡 P1 |
| BR-DB-008 | Loading state khi fetch data | Frontend (skip) | 🟡 P1 |
| BR-DB-009 | Error state với retry button | API Error Response | 🟡 P1 |
| BR-DB-010 | Refresh để load lại data | Frontend (skip) | 🟢 P2 |
| BR-DB-011 | Chart responsive theo screen size | Frontend (skip) | 🟢 P2 |

## 6.5 Report Rules (v2.11 - P0/P1)

| BR-ID | Rule | Test Category | Priority |
|-------|------|---------------|:--------:|
| BR-RPT-001 | Hiển thị danh sách báo cáo với `is_read` status | API Response, Repository | 🔴 P0 |
| BR-RPT-002 | Header format: "Báo cáo {type} - {period}" | API Mapper | 🟡 P1 |
| **BR-RPT-003** | **Mark report as read (idempotent)** | **API POST, Service** | **🔴 P0** |

## 6.6 Security Rules (v2.11 - P0)

| SEC-ID | Rule | Test Category | Priority |
|--------|------|---------------|:--------:|
| SEC-DB-001 | API `/patients/{id}/...` PHẢI check connection + permission | **Auth Guard Tests** | 🔴 P0 |
| SEC-DB-002 | Permission revoke → Real-time 403 response | Service Logic, API | 🔴 P0 |
| SEC-DB-003 | Deep link protection với connection validation | API Validation | 🔴 P0 |

> **Authorization Flow Test (SEC-DB-001):**
> 1. Check Connection exists? → ❌ 404
> 2. Check Connection active? → ❌ 403
> 3. Check Permission enabled? → ❌ 403
> 4. ✅ Return data scoped to patient

## 6.7 Default View State Rules (v2.15 - P0) - NEW

| Rule-ID | Rule | Test Category | Priority |
|---------|------|---------------|:--------:|
| UX-DVS-001 | Page load (no localStorage) → Default View Prompt | Mobile Unit Test | 🔴 P0 |
| UX-DVS-002 | CTA "Xem danh sách" → toggleBottomSheet() | Mobile Unit Test | 🔴 P0 |
| UX-DVS-003 | Close Bottom Sheet → updateStopFollowUI() | Mobile Unit Test | 🔴 P0 |
| UX-DVS-004 | "Ngừng theo dõi" link visible only when selectedPatient != null | Mobile Unit Test | 🔴 P0 |
| UX-DVS-005 | Modal validation before show | Mobile Unit Test | 🟡 P1 |

> **Default View State Test Scenarios:**
> 1. First visit (no localStorage) → Show Default View Prompt
> 2. Select Patient → Dashboard loads, localStorage saved
> 3. Stop following → Return to Default View Prompt
> 4. Close Bottom Sheet without selecting → Remain on Default View
> 5. Disconnect via API → Clear state + Navigate to Default View

## 6.8 Update Pending Invite Permissions Rules (v2.16 - P0) - NEW

| Rule-ID | Rule | Test Category | Priority |
|---------|------|---------------|:--------:|
| BR-031 | Chỉ sender của invite mới được sửa permissions | InviteService Unit Test | 🔴 P0 |
| BR-032 | Chỉ áp dụng cho invite status = 0 (pending) | InviteService Unit Test | 🔴 P0 |
| BR-033 | Permissions được lưu vào `initial_permissions` | Repository Integration Test | 🔴 P0 |
| BR-034 | Không gửi notification đến receiver | Kafka Verify Test | 🟡 P1 |

> **Update Pending Invite Permissions Test Scenarios:**
> 1. Sender updates permissions successfully → 200 + updated permissions
> 2. Non-sender attempts update → 403 NOT_AUTHORIZED
> 3. Update non-pending invite → 409 INVITE_NOT_PENDING

## 6.9 Inverse Relationship Rules (v2.18/v2.19) - NEW

| Rule-ID | Rule | Test Category | Priority |
|---------|------|---------------|:--------:|
| BR-035 | inverse_relationship_code stored in DB | ConnectionService Unit Test, Repository | 🔴 P0 |
| BR-036 | API responses include inverse_relationship_code/name | API Response Test | 🔴 P0 |

> **Inverse Relationship Test Scenarios:**
> 1. Patient→Caregiver invite: relationship_code = Patient mô tả Caregiver, inverse = Caregiver mô tả Patient
> 2. Caregiver→Patient invite: SWAP mapping khi accept → UEC perspective đúng
> 3. ListInvites API returns inverse_relationship_code/name
> 4. ListConnections API returns inverse_relationship_code/name
> 5. GetViewingPatient API returns relationship from correct perspective
> 4. Update non-existent invite → 404 INVITE_NOT_FOUND
> 5. Invalid permission code → 400 INVALID_PERMISSION_TYPE
> 6. Verify no notification sent to receiver

---

# 7. Test Schedule

## 7.1 Timeline

| Week | Phase | Activities |
|:----:|-------|------------|
| Week 1 | Setup | Test framework, Fixtures, CI/CD |
| Week 2 | user-service Unit | InviteService, ConnectionService, PermissionService |
| Week 3 | api-gateway Unit | Handlers, DTOs, Validators |
| Week 4 | schedule-service Unit | Celery tasks, Notification |
| Week 5 | Integration | API integration, gRPC, Kafka |
| Week 6 | Finalization | Coverage review, Test report |

## 7.2 Milestones

| Milestone | Date | Criteria |
|-----------|------|----------|
| M1: Unit Test Complete | Week 4 | 80% unit tests done |
| M2: Integration Test Complete | Week 5 | All API tests passing |
| M3: Coverage Target Met | Week 6 | ≥85% statement coverage |

---

# 8. Entry/Exit Criteria

## 8.1 Entry Criteria

| Criteria | Status |
|----------|:------:|
| SRS v3.0 approved and baselined | ✅ |
| SA Analysis v2.15 complete | ✅ |
| Feature Analysis v2.15 complete | ✅ |
| API specification finalized | ✅ |
| Database schema finalized | ✅ |
| Test environment ready | ⏳ |
| Test data prepared | ⏳ |

## 8.2 Exit Criteria

| Criteria | Target |
|----------|:------:|
| All P0 tests passing | 100% |
| All P1 tests passing | ≥95% |
| Statement coverage | ≥85% |
| No critical defects open | 0 |
| No high defects open | ≤3 |

---

# 9. Risk Analysis

## 9.1 Test Risks

| Risk | Impact | Probability | Mitigation |
|------|:------:|:-----------:|------------|
| ZNS API không ổn định | High | Medium | Mock-based testing |
| Permission logic phức tạp | High | Medium | Extensive unit tests |
| Database trigger issues | Medium | Low | Testcontainers testing |
| Celery task failures | High | Medium | Task isolation, retry tests |
| State machine edge cases | High | Medium | Comprehensive state tests |
| Re-invite flow complexity | Medium | Medium | State diagram testing |

## 9.2 Dependencies

| Dependency | Status | Risk |
|------------|:------:|:----:|
| SOS Emergency Feature | ✅ Complete | Low |
| ZNS OA Setup | 🟡 Pending | Mock initially |
| Deep Link Infrastructure | 🟡 Pending | Mock initially |
| user_emergency_contacts extension | ⏳ Migration ready | Low |

---

## Appendix A: Related Documents

| Document | Path |
|----------|------|
| SRS Document | `docs/nguoi_than/srs_input_documents/srs_nguoi_than.md` |
| SA Analysis | `docs/nguoi_than/sa-analysis/ket_noi_nguoi_than/` |
| Feature Analysis | `docs/nguoi_than/features/ket_noi_nguoi_than/` |
| API Specification | `docs/nguoi_than/sa-analysis/ket_noi_nguoi_than/04_mapping/api_mapping.md` |
| Database Schema | `docs/nguoi_than/features/ket_noi_nguoi_than/04_output/database-changes.sql` |
| Backend Tests | `docs/testing/ket_noi_nguoi_than/04_generation/unit-tests/backend-tests.md` |
| API Tests | `docs/testing/ket_noi_nguoi_than/04_generation/unit-tests/api-tests.md` |

---

**Report Version:** 1.0  
**Generated:** 2026-01-28T17:40:00+07:00  
**Workflow:** `/alio-testing`
