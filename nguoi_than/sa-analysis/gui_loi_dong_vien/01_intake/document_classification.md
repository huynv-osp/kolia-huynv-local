# Document Classification: US 1.3 - Gửi Lời Động Viên

> **Phase:** 1 - Document Intake & Classification  
> **Date:** 2026-02-04  
> **SA:** Workflow-SA Automated

---

## Source Information

| Attribute | Value |
|-----------|-------|
| **Document** | SRS: Gửi Lời Động Viên (Encouragement Messages) |
| **Type** | ☑️ SRS |
| **Format** | ☑️ Markdown |
| **Version** | v1.3 |
| **Date** | 2026-02-03 |
| **Author** | Mary (Analyst) |
| **Status** | Ready for Dev Review |
| **Parent SRS** | KOLIA-1517 (Kết nối Người thân) |

---

## Classification Summary

Đây là tài liệu **SRS chi tiết** cho User Story 1.3 trong epic "Kết nối Người thân". Tài liệu mô tả chức năng cho phép Caregiver gửi lời nhắn động viên đến Patient thông qua trợ lý ảo Kolia.

### Document Structure

| Section | Lines | Content |
|---------|:-----:|---------|
| 1. Giới thiệu | 1-27 | Scope, Glossary, Dependencies |
| 2. Yêu cầu chức năng (BDD) | 30-105 | 1 user story, 8 scenarios |
| 3. Business Rules | 108-116 | 5 BR rules |
| 4. Đặc tả Logic AI | 119-156 | AI suggestion mechanism |
| 5. UI Specifications | 159-175 | 1 screen, 6 components |
| 6. UX Writing | 178-186 | Error messages |
| 7. NFR | 189-195 | Performance, Security, Availability |
| Appendix | 198-214 | Revision history, Cross-feature deps |

---

## Key Sections Identified

### Functional Requirements (1 User Story)

1. **US-001: Caregiver gửi lời nhắn cho Patient** - 8 scenarios:
   - Scenario 1: Gửi lời nhắn từ gợi ý AI (Happy Path)
   - Scenario 1b: Xử lý Timeout khi AI đang gen gợi ý
   - Scenario 2: Không có quyền gửi lời nhắn (Authorization)
   - Scenario 3: Chạm mốc hạn ngạch gửi trong ngày (Limit Quota)
   - Scenario 4: Kiểm soát độ dài nội dung (Length Constraint)
   - Scenario 5: Chặn gửi nội dung trống (Input Validation)
   - Scenario 6: Mất kết nối internet (Internet Offline)
   - Scenario 7: Lỗi hệ thống từ Server (Server Error 5xx)
   - Scenario 8: Permission bị thu hồi tại thời điểm gửi (Edge Case)

### Business Rules Count

| Category | Count | Priority |
|----------|:-----:|:--------:|
| BR-001 (Limit) | 1 | High |
| BR-002 (Limit) | 1 | High |
| BR-003 (Auth) | 1 | Critical |
| BR-004 (Responsibility) | 1 | High |
| BR-005 (Intelligence) | 1 | Medium |
| **Total** | **5** | |

### UI Screens

| Screen ID | Name | Complexity |
|-----------|------|:----------:|
| **SCR-ENG-01** | Soạn lời động viên | Medium |

### UI Components

| Component ID | Name | Type |
|--------------|------|------|
| ENG-01 | Suggested Chips | Button (3 chips) |
| ENG-02 | Text Input | Textarea |
| ENG-03 | Char Counter | Text |
| ENG-04 | Gửi | Icon Button |
| ENG-05 | Refresh AI | Icon Button |
| ENG-06 | Mic Input | Icon Button |

---

## Document Quality Assessment

| Criteria | Status | Notes |
|----------|:------:|-------|
| Gherkin Scenarios | ✅ | 8 well-defined scenarios |
| Business Rules | ✅ | 5 BR rules with priority |
| Validation Rules | ✅ | Max 150 chars, empty check |
| NFR Specifications | ✅ | Performance (3s), Security (TLS 1.3), Availability (99.9%) |
| UI Specifications | ✅ | Detailed components & behaviors |
| Edge Cases | ✅ | 3 EC documented (timeout, permission revoke, network) |
| Cross-Feature Dependencies | ✅ | 4 features mapped |

### Open Questions

- ❌ Không có câu hỏi mở

---

## User Requirements (Extended)

> Theo yêu cầu từ user, cần bổ sung các API cho Patient view:

| Requirement | Description |
|-------------|-------------|
| **Get Encouragement List** | API lấy list lời động viên trong 24h, sort mới→cũ |
| **Mark As Read (Batch)** | API đánh dấu list ID đã đọc để không show modal |
| **Modal Display** | Modal hiển thị ở màn hình chính cho Patient |
| **Full Relationship Info** | Lưu đầy đủ: sender_name, relationship_display, sent_at |

---

## Next Steps

➡️ Proceed to Phase 2: ALIO Architecture Context Loading
