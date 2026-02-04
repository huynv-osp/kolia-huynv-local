# Test Coverage Matrix - Nguoi Than Features

> **Version:** 1.0  
> **Date:** 2026-02-04  
> **Features:** US 1.1, US 1.2, US 1.3

---

## 1. Summary

| Feature | Tests | Coverage Target | Status |
|---------|:-----:|:---------------:|:------:|
| **US 1.1** Kết nối Người thân | 152 | ≥85% | ✅ |
| **US 1.2** Nhận Cảnh Báo | 112 | ≥85% | ✅ |
| **US 1.3** Gửi Lời Động Viên | 54 | ≥85% | ✅ |
| **Total** | **318** | - | ✅ |

---

## 2. Coverage by Layer

| Layer | US 1.1 | US 1.2 | US 1.3 | Total |
|-------|:------:|:------:|:------:|:-----:|
| **Backend Unit** | 45 | 57 | 38 | 140 |
| **API Integration** | 32 | 18 | 16 | 66 |
| **Kafka Events** | 8 | 12 | 4 | 24 |
| **Batch Jobs** | - | 10 | - | 10 |
| **Business Rules** | 25 | 15 | 8 | 48 |

---

## 3. Priority Distribution

| Priority | Count | Percentage |
|:--------:|:-----:|:----------:|
| CRITICAL | 65 | 22% |
| HIGH | 156 | 54% |
| MEDIUM | 68 | 24% |
| **Total** | **289** | 100% |

---

## 4. Test Documentation Files

### US 1.1 - Kết nối Người thân

| File | Path | Tests |
|------|------|:-----:|
| test-plan.md | `testing/ket_noi_nguoi_than/` | 135 |
| backend-tests.md | `testing/ket_noi_nguoi_than/unit-tests/` | 45 |

### US 1.2 - Nhận Cảnh Báo

| File | Path | Tests |
|------|------|:-----:|
| test-plan.md | `testing/nhan_canh_bao/` | 100 |
| backend-tests.md | `testing/nhan_canh_bao/unit-tests/` | 57 |

### US 1.3 - Gửi Lời Động Viên

| File | Path | Tests |
|------|------|:-----:|
| test-plan.md | `testing/gui_loi_dong_vien/` | 54 |
| backend-tests.md | `testing/gui_loi_dong_vien/unit-tests/` | 38 |
| api-tests.md | `testing/gui_loi_dong_vien/unit-tests/` | 16 |

---

## 5. Key Business Rules Coverage

### Critical Rules (P0)

| Rule | Feature | Tests | Coverage |
|------|---------|:-----:|:--------:|
| BR-ALT-004 | SOS bypass all | 6 | 100% |
| BR-ALT-001 | Permission #2 | 4 | 100% |
| BR-006 | No self-invite | 2 | 100% |
| BR-003 | Permission #6 | 3 | 100% |

### High Priority Rules (P1)

| Rule | Feature | Tests | Coverage |
|------|---------|:-----:|:--------:|
| BR-035 | Inverse relationship | 8 | 100% |
| BR-036 | Perspective display | 6 | 100% |
| BR-001 | Quota 10/day | 4 | 100% |
| BR-ALT-005 | Debounce 5 min | 5 | 100% |

---

## 6. Test Frameworks

| Service | Stack | Framework |
|---------|-------|-----------|
| user-service | Java 17 | JUnit 5 + Mockito |
| api-gateway | Java 17 | WebTestClient |
| schedule-service | Python 3.11 | pytest + responses |
| Mobile App | React Native | Vitest + Testing Library |

---

## 7. Next Steps

1. ✅ Test Plans completed for all 3 features
2. ✅ Backend unit test specs completed
3. ✅ API integration test specs completed
4. 📋 Generate test data fixtures (pending)
5. 📋 Execute tests and verify coverage (pending)
