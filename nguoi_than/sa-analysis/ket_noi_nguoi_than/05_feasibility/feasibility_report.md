# Feasibility Report: KOLIA-1517 (REVISED v4.0)

> **Phase:** 5 - Feasibility Assessment  
> **Date:** 2026-02-13  
> **Score:** 82/100 ✅ FEASIBLE

---

## Assessment Matrix

| Criteria | Weight | Score | Notes |
|----------|:------:|:-----:|-------|
| Architecture Fit | 25% | 4 | New Family Group concept, but fits existing patterns |
| Database Compatibility | 20% | 5 | 2 NEW tables + 1 ALTER, backward compatible |
| API/gRPC Compatibility | 15% | 4 | +6 new endpoints, 4 updated, strong pattern reuse |
| Service Boundary Clarity | 15% | 3 | Cross-service call user→payment required |
| Technology Stack Match | 10% | 5 | Vert.x/Java/Spring Boot/Postgres all existing |
| Team Expertise | 10% | 4 | Similar to existing KCNT implementation |
| Time/Resource | 5% | 3 | Larger scope: ~80h estimated (vs 56h v2.0) |

**Total: 82/100 → ✅ FEASIBLE**

---

## Key Decisions (v4.0)

| Decision | Rationale |
|----------|-----------| 
| **Admin-only invites** | From payment SRS §2.8, simplifies invite flow |
| **6 permissions (giữ nguyên)** | Tránh cập nhật nhiều, SRS v5 gộp nhưng code giữ 6 |
| **Soft disconnect** (permission_revoked) | Giữ connection, tắt quyền → dễ "mở lại" |
| **family_groups + family_group_members** | Explicit group model linked to subscription |
| **Auto-connect CG → ALL patients** | Khi CG accept → tự động follow tất cả Patient |
| **Exclusive Group** (1 user = 1 group) | DB UNIQUE index, validate at invite time |
| **user→payment gRPC** | user-service gọi payment-service cho GetSubscription/SyncMembers |

---

## Risks Addressed

| Risk | Mitigation |
|------|------------|
| SOS regression | contact_type='emergency' unchanged |
| Auto-connect complexity | Transaction-based, rollback on failure |
| Slot race condition | Double-check at accept time (AD-04) |
| Payment service dependency | Graceful fallback if payment unavailable |
| Silent revoke confusion | UI badge "🚫" for CG, admin notification |

---

## v2.0 → v4.0 Comparison

| Metric | v2.0 | v4.0 |
|--------|:----:|:----:|
| Feasibility Score | 88/100 | **82/100** |
| Impact Level | 🟢 LOW | **🟡 MEDIUM** |
| New Tables | 5 | 5 + **2 NEW** |
| Altered Tables | 1 | 1 + **1 ALTER** |
| New APIs | 8 | 8 + **6 NEW** |
| Effort Estimate | 56h | **~80h** |
| Services Affected | 3 | **5** |

---

## Conclusion

**✅ APPROVED for implementation** — Score 82/100 with medium complexity increase. Core architecture reuses existing patterns (gRPC, Kafka, entities). Main new complexity is cross-service payment integration and auto-connect logic.
