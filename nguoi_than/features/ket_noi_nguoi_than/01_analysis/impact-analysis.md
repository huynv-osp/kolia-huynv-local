# Impact Analysis: KOLIA-1517 - Kết nối Người thân

> **Phase:** 1 - Requirement Intake & Classification  
> **Date:** 2026-02-13  
> **SRS Version:** v4.0  
> **Revision:** v4.0 - Impact MEDIUM, 5 services, ~80h, feasibility 82/100

---

## 1. Impact Summary

| Metric | v2.23 | v4.0 | Δ |
|--------|:-----:|:----:|:-:|
| **Impact Level** | 🟢 LOW | **🟡 MEDIUM** | ⬆️ |
| **Feasibility Score** | 88/100 | **82/100** | ⬇️ |
| **Services Affected** | 3 | **5** | +2 |
| **New Tables** | 5 | 5 + **2 NEW** | +2 |
| **Altered Tables** | 1 | 1 + **1 ALTER** | +1 |
| **New REST Endpoints** | 8 | 8 + **6 NEW** | +6 |
| **Deprecated Endpoints** | 0 | **1** (DELETE) | +1 |
| **Effort Estimate** | ~56h | **~80h** | +24h |
| **Business Rules** | ~41 | **60+** | +19 |

---

## 2. Service Impact Detail

### 2.1 user-service — 🔴 HIGH

| Area | Impact | Details |
|------|:------:|---------|
| Entities | HIGH | 2 NEW (FamilyGroup, FamilyGroupMember), 2 MODIFY (UEC, ConnectionInvite) |
| Service Layer | HIGH | FamilyGroupService (NEW), ConnectionService (major changes) |
| gRPC | HIGH | New RPCs for group CRUD, revoke/restore, member management |
| Client | MEDIUM | PaymentServiceClient (NEW) for slot check |
| **Effort** | | **~30h** |

### 2.2 api-gateway-service — 🔴 HIGH

| Area | Impact | Details |
|------|:------:|---------|
| Handlers | HIGH | FamilyGroupHandler (NEW), ConnectionHandler (MODIFY) |
| DTOs | HIGH | 4 NEW request/response DTOs, 1 MODIFY (CreateInviteRequest simplified) |
| Endpoints | HIGH | 6 NEW, 1 DEPRECATED |
| **Effort** | | **~20h** |

### 2.3 payment-service — 🟡 MEDIUM (NEW v4.0)

| Area | Impact | Details |
|------|:------:|---------|
| gRPC | LOW | Ensure GetSubscription returns slot info |
| Service | LOW | Verify slot count/availability queries |
| **Effort** | | **~10h** |

### 2.4 schedule-service — 🟡 MEDIUM

| Area | Impact | Details |
|------|:------:|---------|
| Kafka Consumers | MEDIUM | 3 new event types (member accepted/removed, invite created) |
| Notifications | MEDIUM | Member broadcast, ZNS templates for 2 invite types |
| **Effort** | | **~10h** |

### 2.5 auth-service — 🟢 LOW (NEW v4.0)

| Area | Impact | Details |
|------|:------:|---------|
| Verification | LOW | Verify backfillPendingInviteReceiverIds handles new invite_type values |
| **Effort** | | **~5h** |

---

## 3. Database Impact

### 3.1 New Tables

| Table | Columns | Purpose |
|-------|:-------:|---------|
| `family_groups` | 6 | Admin, subscription_id, name, status, timestamps |
| `family_group_members` | 7 | user_id (UNIQUE), role (patient/caregiver), family_group_id FK |

### 3.2 Modified Tables

| Table | Column | Change |
|-------|--------|--------|
| `user_emergency_contacts` | `permission_revoked` | ADD BOOLEAN DEFAULT false |
| `user_emergency_contacts` | `family_group_id` | ADD UUID FK → family_groups |
| `connection_invites` | `invite_type` CHECK | UPDATE → `add_patient`, `add_caregiver` |

### 3.3 Indexes

| Index | Table | Columns |
|-------|-------|---------|
| `idx_fgm_user_id` | family_group_members | user_id (UNIQUE) |
| `idx_fgm_family_group_id` | family_group_members | family_group_id |
| `idx_fg_admin_id` | family_groups | admin_user_id |
| `idx_uec_family_group_id` | user_emergency_contacts | family_group_id |

---

## 4. API Impact

### 4.1 New Endpoints (6)

| Method | Path | Auth | Purpose |
|:------:|------|:----:|---------|
| GET | `/api/v1/family-groups` | User | Get user's family group info + package details |
| DELETE | `/api/v1/family-groups/members/:memberId` | Admin | Remove member from group |
| PUT | `/api/v1/connections/:contactId/revoke` | Patient | Tắt quyền theo dõi (soft disconnect) |
| PUT | `/api/v1/connections/:contactId/restore` | Patient | Mở lại quyền theo dõi |
| PUT | `/api/v1/connections/:contactId/relationship` | CG | Update MQH at SCR-06 |
| POST | `/api/v1/family-groups/leave` | Non-Admin | Self-leave group |

### 4.2 Modified Endpoints

| Endpoint | Change |
|----------|--------|
| `POST /connections/invite` | Simplified: phone only, Admin-only auth check |
| `POST /connections/invites/:id/accept` | Auto-connect CG → ALL patients |

### 4.3 Deprecated Endpoints

| Endpoint | Replacement |
|----------|-------------|
| ~~`DELETE /api/v1/connections/:id`~~ | Use `/revoke` (Patient) or `/family-groups/members/:id` (Admin) |

---

## 5. Breaking Changes

| # | Change | Impact | Migration |
|:-:|--------|--------|-----------|
| 1 | `invite_type` enum values | Data migration needed | SQL ALTER CHECK + UPDATE existing records |
| 2 | `DELETE /connections` deprecated | Mobile app must stop using | Feature flag + gradual removal |
| 3 | Admin-only invite | UI flow restructured | Mobile app update required |
| 4 | `permission_revoked` column | New column with DEFAULT false | Non-breaking ALTER ADD |

---

## 6. Cross-Feature Impact

### 6.1 Payment SRS Integration (🔴 HIGH)

| Integration | Direction | Details |
|-------------|:---------:|---------|
| Slot check | KCNT → Payment | Before send invite, call GetSubscription |
| Slot consume | KCNT → Payment | On accept, slot status changes |
| Expiry block | Payment → KCNT | Expired package → block new invites (BR-037) |
| Paywall | KCNT → Payment | Slot full → redirect to upgrade (BR-047) |

### 6.2 Bản tin Hành động (🟡 MEDIUM)

| Change | Detail |
|--------|--------|
| CR_001 | Add `INVITE_CONNECTION` action type |
| Display | Pending invite → action item in Bản tin |
| Navigation | Tap → SCR-01 |

### 6.3 Notification System (🟡 MEDIUM)

| Change | Detail |
|--------|--------|
| CR_002 | 5 notification scenarios for KCNT |
| CR_003 | Health report notification for Caregiver |
| New (v4.0) | Member broadcast on join/leave (BR-052) |

---

## 7. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|:-----------:|:------:|------------|
| Slot race condition | Medium | High | Double-check at accept time (AD-04) |
| Payment service unavailable | Low | Medium | Circuit breaker, graceful fallback |
| Auto-connect cascade failure | Medium | Medium | Transaction-based, rollback on failure |
| Data migration for invite_type | Low | Medium | Backward compatible migration script |
| Silent revoke UX confusion | Low | Low | Clear badge "🚫" in UI |
| SOS contact regression | Low | Critical | contact_type='emergency' unchanged |

---

## 8. Feasibility Score Breakdown

| Criteria | Weight | Score | v2.23 | Notes |
|----------|:------:|:-----:|:-----:|-------|
| Architecture Fit | 25% | 4 | 5 | New Family Group concept, cross-service payment |
| Database Compatibility | 20% | 5 | 5 | 2 NEW tables, backward compatible |
| API/gRPC Compatibility | 15% | 4 | 4 | +6 new endpoints, strong pattern reuse |
| Service Boundary Clarity | 15% | 3 | 4 | user→payment gRPC dependency added |
| Technology Stack Match | 10% | 5 | 5 | All existing tech |
| Team Expertise | 10% | 4 | 4 | Similar to existing KCNT |
| Time/Resource | 5% | 3 | 4 | ~80h (up from ~56h) |
| **Total** | | **82/100** | **88/100** | |

---

## References

- [SA Impact Analysis v4.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/ket_noi_nguoi_than/06_impact/impact_analysis.md)
- [SA Feasibility Report v4.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/ket_noi_nguoi_than/05_feasibility/feasibility_report.md)
- [SA Service Mapping v4.0](file:///Users/nguyenvanhuy/Desktop/OSP/Kolia/dev/kolia/docs/nguoi_than/sa-analysis/ket_noi_nguoi_than/04_mapping/service_mapping.md)
