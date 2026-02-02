# Scope Summary

## Analysis Information

| Item | Value |
|------|-------|
| **Analysis Name** | `sos_emergency` |
| **Analysis Date** | 2026-01-26 |
| **Analyst** | Solution Architect (Automated) |
| **Source SRS** | `docs/srs_input_documents/srs.md` |
| **SRS Version** | 2.1 |

---

## ✅ In Scope (MVP)

| # | Chức năng | Complexity |
|---|-----------|:----------:|
| 1 | Màn hình SOS Entry (xác nhận trước khi kích hoạt) | 🟢 Low |
| 2 | Màn hình SOS Main với đồng hồ đếm ngược 30s | 🟡 Medium |
| 3 | Gọi 115 (cấp cứu) - ưu tiên cao nhất | 🟢 Low |
| 4 | Tự động gửi thông báo cầu cứu qua ZNS | 🟡 Medium |
| 5 | Gửi thông báo đến người thân và CSKH | 🟡 Medium |
| 6 | Escalation Flow tự động (20s per contact) | 🔴 High |
| 7 | Hủy SOS trong trường hợp ấn nhầm | 🟢 Low |
| 8 | Offline Queue & Retry khi mất mạng | 🟡 Medium |
| 9 | Màn hình SOS Support Dashboard | 🟡 Medium |
| 10 | Gọi điện thoại cho người thân | 🟡 Medium |
| 11 | Tìm kiếm bệnh viện gần nhất (Google Maps) | 🟡 Medium |
| 12 | Hướng dẫn sơ cứu tại chỗ (Offline-capable) | 🟡 Medium |

---

## ❌ Out of Scope

| # | Feature | Reason |
|---|---------|--------|
| 1 | Kết nối trực tiếp với hệ thống cấp cứu bên ngoài | Phức tạp, cần integration với hospital systems |
| 2 | Tích hợp với thiết bị IoT y tế | Phase 2 consideration |
| 3 | SOS History/Log | Nice-to-have, defer to later |
| 4 | Zalo Video Call | Không có public API/deep link |

---

## 📋 Assumptions

| # | Assumption | Validation Required |
|---|------------|:-------------------:|
| 1 | User đã cài đặt ít nhất 1 người thân | ✅ App validation |
| 2 | Device có khả năng gọi điện | ✅ OS capability check |

---

## 🔒 Constraints

| # | Constraint | Impact |
|---|------------|--------|
| 1 | ZNS OA chưa setup | Cannot send ZNS until approved |
| 2 | Feature "Kết nối người thân" chưa có timeline | BLOCKER for escalation flow |
| 3 | Sound/Haptic phải bypass DND | Requires special OS permissions |

---

## Initial Complexity Assessment

| Factor | Assessment | Confidence | Notes |
|--------|:----------:|:----------:|-------|
| **Services Affected** | 3-5 | 🟡 70% | user-service, api-gateway, agents-service, schedule-service |
| **Database Changes** | Minor | 🟡 70% | New SOS-related tables (events, contacts) |
| **API Changes** | Extension | 🟢 80% | New endpoints, no breaking changes expected |
| **UI Changes** | Major | 🟢 90% | 16 new screens/states in mobile app |
| **Integration Points** | 3-5 | 🟡 70% | ZNS, Google Maps, Native Phone, CSKH API |

---

## Key Technical Challenges (Preview)

| # | Challenge | Severity | Notes |
|---|-----------|:--------:|-------|
| 1 | **Server-Client Countdown Sync** | 🟡 Medium | 5s tolerance, server as source of truth |
| 2 | **Escalation Auto-Call** | 🔴 High | Complex state machine, call detection |
| 3 | **Offline Queue Management** | 🟡 Medium | Queue persistence, retry logic |
| 4 | **ZNS Integration** | 🟡 Medium | Template registration, rate limits |
| 5 | **DND Bypass for Sound/Haptic** | 🟡 Medium | OS-level permissions required |

---

## Business Rules Summary

| Priority | Count | Examples |
|----------|:-----:|----------|
| 🔴 High | 13 | Countdown, ZNS gửi đồng thời, Escalation |
| 🟡 Medium | 9 | Cooldown, GPS timeout, Pin <10% |
| 🟢 Low | 1 | First Aid content caching |

---

## Phase Gate 1 Validation

| Checkpoint | Status |
|------------|:------:|
| Document successfully loaded and parsed | ✅ |
| Document type correctly identified (SRS) | ✅ |
| Key sections extracted | ✅ |
| Scope boundaries defined | ✅ |
| Analysis directory created | ✅ |
| Intake documents generated | ✅ |

---

## Next Steps

✅ **Phase 1: Intake** - COMPLETE

➡️ **Phase 2: Context Loading** - Load ALIO Architecture + Database Schema
