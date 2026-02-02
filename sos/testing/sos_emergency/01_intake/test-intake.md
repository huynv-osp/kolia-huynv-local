# 📥 Test Intake - SOS Emergency Feature

## Document Information

| Attribute | Value |
|-----------|-------|
| **Feature** | SOS Emergency - Chức năng hỗ trợ khẩn cấp |
| **SRS Version** | 1.4 (Approved, Final + Prototype Synced) |
| **Analysis Date** | 2026-01-26 |
| **Analyst** | Test Generator (Automated via /alio-testing) |

---

## 1. Input Documents

### 1.1 SRS Document

| Attribute | Value |
|-----------|-------|
| **Path** | `docs/sos/srs_input_documents/srs_sos.md` |
| **Total Scenarios** | 17 Gherkin scenarios |
| **Business Rules** | 23 rules (BR-SOS-001..023) |
| **Features** | 6 feature groups |

### 1.2 SA Analysis

| Attribute | Value |
|-----------|-------|
| **Path** | `docs/sos/sa-analysis/sos_emergency/` |
| **Report** | `08_report/complete_analysis.md` |
| **Feasibility Score** | 86/100 ✅ |

### 1.3 Feature Output

| Attribute | Value |
|-----------|-------|
| **Path** | `docs/sos/features/sos_emergency/04_output/` |
| **API Spec** | `api-specification.md` (10 endpoints) |
| **Database** | `database-changes.sql` (5 tables) |
| **Tasks** | `task-breakdown.md` (32 tasks) |

---

## 2. Feature Summary

### 2.1 In Scope (MVP)

| # | Feature | Test Category |
|---|---------|---------------|
| 1 | Màn hình SOS Entry | UI/Integration |
| 2 | Màn hình SOS Main với đồng hồ đếm ngược 30s | Unit/Integration |
| 3 | Gọi 115 (cấp cứu) | Integration |
| 4 | Tự động gửi thông báo cầu cứu qua ZNS | Unit/Integration |
| 5 | Gửi thông báo đến người thân và CSKH | Unit/Integration |
| 6 | Escalation Flow tự động (20s per contact) | Unit |
| 7 | Hủy SOS trong trường hợp ấn nhầm | Unit/Integration |
| 8 | Offline Queue & Retry khi mất mạng | Unit |
| 9 | Màn hình SOS Support Dashboard | UI |
| 10 | Gọi điện thoại/Zalo Video cho người thân | Integration |
| 11 | Tìm kiếm bệnh viện gần nhất (Google Maps) | Integration |
| 12 | Hướng dẫn sơ cứu tại chỗ (Offline-capable) | Unit |

### 2.2 Out of Scope

- ❌ Kết nối trực tiếp với hệ thống cấp cứu bên ngoài
- ❌ Tích hợp với thiết bị IoT y tế
- ❌ SOS History/Log

---

## 3. Testing Mode Selection

### Selected Modes

| Mode | Status | Rationale |
|------|:------:|-----------|
| **Unit Test** | ✅ REQUIRED | Tạo test specs đầy đủ cho tất cả services |
| **TDD** | ❌ Optional | Không yêu cầu trong lần này |
| **BDD** | ❌ Optional | Gherkin scenarios sẵn có trong SRS |

---

## 4. Services to Test

| Service | Stack | New Components | Test Priority |
|---------|-------|----------------|:-------------:|
| **api-gateway-service** | Java 17, Vert.x | 10 endpoints | 🔴 Critical |
| **user-service** | Java 17, Vert.x | 4 gRPC methods | 🔴 Critical |
| **schedule-service** | Python, Celery | 6 Celery tasks, ZNS client | 🔴 Critical |
| **Mobile App** | React Native | 16 screens | 🟡 High |

---

## 5. Test Coverage Targets

| Category | Target | Metric |
|----------|:------:|--------|
| Backend Unit Tests | ≥85% | Statement coverage |
| API Integration Tests | 100% | Endpoint coverage |
| Business Rules | 100% | Rule coverage |
| Error Scenarios | 100% | Error code coverage |

---

## Next Phase

✅ **Phase 1: Test Intake** - COMPLETE

➡️ **Phase 2: Context Loading**
