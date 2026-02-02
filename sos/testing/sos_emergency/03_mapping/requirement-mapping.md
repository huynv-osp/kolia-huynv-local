# 🗺️ Requirement to Test Case Mapping

## SOS Emergency Feature

---

## 1. Functional Requirements → Test Cases

### 1.1 SOS Core (FR-SOS-01 to FR-SOS-05)

| SRS Scenario | FR-ID | Business Rules | Test Cases | Priority |
|--------------|-------|----------------|------------|:--------:|
| **Kịch bản 1:** Kích hoạt SOS thành công | FR-SOS-01, FR-SOS-02 | BR-SOS-001, BR-SOS-002 | TC-CORE-001..005 | 🔴 |
| **Kịch bản 2:** Countdown hoàn thành | FR-SOS-03 | BR-SOS-003, BR-SOS-004 | TC-CORE-006..010 | 🔴 |
| **Kịch bản 3:** Hủy SOS (Ấn nhầm) | FR-SOS-04 | BR-SOS-005 | TC-CORE-011..013 | 🔴 |
| **Kịch bản 4:** Gọi 115 trong countdown | FR-SOS-05 | BR-SOS-006 | TC-CORE-014..016 | 🔴 |

### 1.2 Escalation Flow (FR-SOS-06 to FR-SOS-08)

| SRS Scenario | FR-ID | Business Rules | Test Cases | Priority |
|--------------|-------|----------------|------------|:--------:|
| **Kịch bản 5:** Escalation tự động | FR-SOS-06 | BR-SOS-007, BR-SOS-008 | TC-ESC-001..006 | 🔴 |
| **Kịch bản 6:** Escalation thành công | FR-SOS-07 | BR-SOS-009 | TC-ESC-007..009 | 🔴 |
| **Kịch bản 7:** User đang gọi 115 | FR-SOS-08 | BR-SOS-010 | TC-ESC-010..012 | 🔴 |

### 1.3 Post-SOS Support (FR-SOS-09 to FR-SOS-11)

| SRS Scenario | FR-ID | Business Rules | Test Cases | Priority |
|--------------|-------|----------------|------------|:--------:|
| **Kịch bản 8:** Gọi người thân từ Contact List | FR-SOS-09 | BR-SOS-011 | TC-SUP-001..003 | 🟡 |
| **Kịch bản 9:** Xem bệnh viện gần nhất | FR-SOS-10 | BR-SOS-012 | TC-SUP-004..006 | 🟡 |
| **Kịch bản 10:** Xem hướng dẫn sơ cứu | FR-SOS-11 | BR-SOS-013, BR-SOS-014 | TC-SUP-007..009 | 🟡 |

### 1.4 Offline & Error Handling (FR-SOS-12 to FR-SOS-18)

| SRS Scenario | FR-ID | Business Rules | Test Cases | Priority |
|--------------|-------|----------------|------------|:--------:|
| **Kịch bản 11:** SOS khi offline | FR-SOS-12 | BR-SOS-015, BR-SOS-016 | TC-OFF-001..004 | 🔴 |
| **Kịch bản 12:** Airplane mode | FR-SOS-13 | BR-SOS-017 | TC-OFF-005..007 | 🟡 |
| **Kịch bản 13:** SOS khi pin < 10% | FR-SOS-14 | BR-SOS-018 | TC-BAT-001..003 | 🟡 |
| **Kịch bản 14:** SOS trong cooldown | FR-SOS-15 | BR-SOS-019 | TC-ERR-001..004 | 🟡 |
| **Kịch bản 15:** ZNS gửi thất bại | FR-SOS-16 | BR-SOS-021 | TC-ERR-005..008 | 🔴 |
| **Kịch bản 16:** GPS timeout | FR-SOS-17 | BR-SOS-022 | TC-ERR-009..011 | 🟡 |
| **Kịch bản 17:** Server không phản hồi | FR-SOS-18 | BR-SOS-023 | TC-ERR-012..015 | 🔴 |

---

## 2. API Endpoint → Test Cases

### 2.1 SOS Core APIs

| Endpoint | Method | Test Cases | Coverage |
|----------|--------|------------|:--------:|
| `/api/sos/activate` | POST | TC-API-001..010 | Happy path, Cooldown, No contacts, Low battery |
| `/api/sos/activate/bypass` | POST | TC-API-011..015 | Bypass cooldown, Validation |
| `/api/sos/cancel` | POST | TC-API-016..022 | Cancel success, Already cancelled, Already completed |
| `/api/sos/status/{eventId}` | GET | TC-API-023..028 | Pending, Completed, Cancelled, Not found |

### 2.2 Emergency Contact APIs

| Endpoint | Method | Test Cases | Coverage |
|----------|--------|------------|:--------:|
| `/api/sos/contacts` | GET | TC-API-029..032 | List contacts, Empty list |
| `/api/sos/contacts` | POST | TC-API-033..040 | Add success, Max reached, Duplicate phone, Invalid format |
| `/api/sos/contacts/{id}` | PUT | TC-API-041..045 | Update success, Priority reorder |
| `/api/sos/contacts/{id}` | DELETE | TC-API-046..050 | Delete success, Not found |

### 2.3 Support APIs

| Endpoint | Method | Test Cases | Coverage |
|----------|--------|------------|:--------:|
| `/api/sos/first-aid` | GET | TC-API-051..054 | Get content, Version filter |
| `/api/sos/escalation/confirm` | POST | TC-API-055..058 | Confirm call answered |

---

## 3. Database → Test Cases

### 3.1 Repository Layer Tests

| Table | Repository | Test Cases | Focus |
|-------|------------|------------|-------|
| `user_emergency_contacts` | EmergencyContactRepository | TC-DB-001..010 | CRUD, Priority, Unique constraint |
| `sos_events` | SOSEventRepository | TC-DB-011..020 | Create, Status update, Cooldown query |
| `sos_notifications` | SOSNotificationRepository | TC-DB-021..030 | Create, Retry logic, Status tracking |
| `sos_escalation_calls` | EscalationCallRepository | TC-DB-031..040 | Call status tracking |
| `first_aid_content` | FirstAidRepository | TC-DB-041..045 | Content retrieval, Version |

---

## 4. Business Rules → Test Cases

| BR-ID | Description | Test Cases | Covered By |
|-------|-------------|------------|------------|
| BR-SOS-001 | Countdown bắt đầu ngay khi vào SOS Main | TC-CORE-001, TC-API-001 | api-gateway, mobile |
| BR-SOS-002 | Sound/Haptic bypass DND | TC-MOB-001 | mobile |
| BR-SOS-003 | ZNS gửi đồng thời đến TẤT CẢ người thân | TC-ZNS-001..003 | schedule-service |
| BR-SOS-004 | Gửi alert đến CSKH | TC-ZNS-004 | schedule-service |
| BR-SOS-005 | Hủy không áp dụng cooldown | TC-API-016..018 | api-gateway |
| BR-SOS-006 | Gọi 115 không dừng countdown | TC-CORE-014 | mobile |
| BR-SOS-007 | Escalation timeout 20s | TC-ESC-001..003 | schedule-service |
| BR-SOS-008 | Sau 5 người → CSKH → 115 | TC-ESC-004..006 | schedule-service |
| BR-SOS-009 | Connected → Dừng escalation | TC-ESC-007..009 | schedule-service |
| BR-SOS-010 | Đang gọi 115 → Chỉ ZNS | TC-ESC-010..012 | schedule-service |
| BR-SOS-011 | Manual call → Skip escalation | TC-SUP-001..003 | schedule-service |
| BR-SOS-012 | Hospital Map GPS fallback | TC-SUP-004..006 | mobile |
| BR-SOS-013 | First Aid từ CMS | TC-API-051..054 | api-gateway |
| BR-SOS-014 | Disclaimer bắt buộc | TC-MOB-002 | mobile |
| BR-SOS-015 | Offline queue + retry | TC-OFF-001..004 | schedule-service |
| BR-SOS-016 | Gọi điện offline OK | TC-OFF-002 | mobile |
| BR-SOS-017 | Airplane mode detect | TC-OFF-005..007 | mobile |
| BR-SOS-018 | Pin < 10% → 10s | TC-BAT-001..003, TC-API-003 | api-gateway, mobile |
| BR-SOS-019 | Cooldown 5 phút | TC-ERR-001..004, TC-API-007..010 | api-gateway |
| BR-SOS-020 | Server-client tolerance 5s | TC-CORE-002 | api-gateway, mobile |
| BR-SOS-021 | ZNS retry 3 lần | TC-ERR-005..008 | schedule-service |
| BR-SOS-022 | GPS timeout → last known | TC-ERR-009..011 | api-gateway |
| BR-SOS-023 | Server timeout → queue | TC-ERR-012..015 | mobile |

---

## 5. Test Case Summary

| Category | Count | Priority |
|----------|:-----:|:--------:|
| Core SOS Flow | 16 | 🔴 Critical |
| Escalation Flow | 12 | 🔴 Critical |
| Post-SOS Support | 9 | 🟡 High |
| Offline Handling | 7 | 🔴 Critical |
| Error Handling | 15 | 🔴/🟡 Mixed |
| API Tests | 58 | 🔴 Critical |
| Database Tests | 45 | 🔴 Critical |
| **TOTAL** | **162** | - |

---

## Next Phase

✅ **Phase 3: Requirement Mapping** - COMPLETE

➡️ **Phase 4: Test Generation**
