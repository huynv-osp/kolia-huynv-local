# Document Classification: US 1.2 - Nhận Cảnh Báo Bất Thường

> **Phase:** 1 - Document Intake & Classification  
> **Date:** 2026-02-02  
> **SA:** Workflow-SA Automated

---

## Source Information

| Attribute | Value |
|-----------|-------|
| **Document** | SRS: US 1.2 - Nhận Cảnh Báo Bất Thường (Caregiver Alerts) |
| **Type** | ☑️ SRS |
| **Format** | ☑️ Markdown |
| **Version** | v1.0 |
| **Date** | 2026-02-02 |
| **Author** | BA Team |
| **Status** | Ready for Dev Review |
| **Parent SRS** | KOLIA-1517 (Kết nối Người thân) |

---

## Classification Summary

Đây là tài liệu **SRS chi tiết** cho User Story 1.2 trong epic "Kết nối Người thân". Tài liệu mô tả chức năng cho phép Caregiver nhận thông báo kịp thời khi Patient gặp các tình huống sức khỏe bất thường.

### Document Structure

| Section | Lines | Content |
|---------|:-----:|---------|
| 1. Giới thiệu | 1-59 | Scope, Glossary, Dependencies |
| 2. Yêu cầu chức năng (BDD) | 60-338 | 6 user stories, 17 scenarios |
| 3. Business Rules | 339-365 | 18 BR-ALT rules |
| 4. Validation Rules | 366-376 | Field validations |
| 5. NFR | 377-403 | Performance, Security, Availability |
| 6. UI Specifications | 404-618 | 4 screens, navigation flows |
| 7. Flow Diagrams | 619-664 | Sequence & State diagrams |
| 8. UX Writing | 665-711 | Templates, Error messages |
| Appendix | 712-754 | Edge cases, Cross-feature deps |

---

## Key Sections Identified

### Functional Requirements (6 Categories)

1. **Nhận cảnh báo HA Khẩn cấp** (2.1) - 3 scenarios
2. **Nhận cảnh báo HA Thay đổi đột ngột** (2.2) - 2 scenarios
3. **Nhận cảnh báo SOS** (2.3) - 3 scenarios
4. **Nhận cảnh báo Thuốc** (2.4) - 2 scenarios
5. **Nhận cảnh báo Tuân thủ kém** (2.5) - 2 scenarios
6. **Lịch sử Cảnh báo** (2.6) - 6 scenarios

### Business Rules Count

| Category | Count | Priority |
|----------|:-----:|:--------:|
| P0 - Critical | 5 | Must have |
| P1 - High | 10 | Should have |
| P2 - Lower | 3 | Nice to have |
| **Total** | **18** | |

### UI Screens

| Screen ID | Name | Complexity |
|-----------|------|:----------:|
| SCR-ALT-01 | Alert Block (Dashboard) | Medium |
| SCR-ALT-02 | Lịch sử Cảnh báo | Medium |
| SCR-ALT-03 | Modal Popup (In-App) | Low |
| SCR-ALT-04 | SOS Modal | Medium |

---

## Document Quality Assessment

| Criteria | Status | Notes |
|----------|:------:|-------|
| Gherkin Scenarios | ✅ | 17 well-defined scenarios |
| Business Rules | ✅ | 18 BR-ALT rules with priority |
| Validation Rules | ✅ | Field ranges defined |
| NFR Specifications | ✅ | Performance, Security targets |
| UI Specifications | ✅ | Detailed layouts & behaviors |
| Edge Cases | ✅ | 12 EC documented |
| Cross-Feature Dependencies | ✅ | 4 features mapped |

### Open Questions

- ❌ Không có câu hỏi mở

---

## Next Steps

➡️ Proceed to Phase 2: ALIO Architecture Context Loading
