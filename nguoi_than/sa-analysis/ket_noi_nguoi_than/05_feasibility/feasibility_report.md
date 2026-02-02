# Feasibility Report: KOLIA-1517 (REVISED v2.6)

> **Phase:** 5 - Feasibility Assessment  
> **Date:** 2026-01-29  
> **Score:** 88/100 ✅ FEASIBLE

---

## Assessment Matrix

| Criteria | Weight | Score | Notes |
|----------|:------:|:-----:|-------|
| Architecture Fit | 25% | 5 | Reuses existing tables |
| Database Compatibility | 20% | 5 | EXTEND user_emergency_contacts |
| API/gRPC Compatibility | 15% | 4 | Standard patterns + Lookup API |
| Service Boundary Clarity | 15% | 4 | Clear ownership |
| Technology Stack Match | 10% | 5 | Vert.x/Java/Postgres |
| Team Expertise | 10% | 4 | Similar to SOS |
| Time/Resource | 5% | 4 | 56h estimated |

**Total: 88/100 → ✅ FEASIBLE**

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Extend `user_emergency_contacts` | Avoid data duplication |
| Keep `connection_invites` separate | Invite lifecycle tracking |
| Add `relationships` lookup | Shared by SOS + Caregiver |
| Add `connection_permission_types` lookup | Normalized from CHECK constraint, maintainable |
| Add `ListPermissionTypes` API | Dynamic permission loading for UI |
| Keep `invite_notifications` | Separate from sos_notifications |

---

## Risks Addressed

| Risk | Mitigation |
|------|------------|
| SOS regression | contact_type='emergency' unchanged |
| Schema complexity | Reuse reduces complexity |
| Data inconsistency | Single source of truth |
| Hardcoded permissions | Lookup table + API |

---

## Conclusion

**✅ APPROVED** - Schema v2.6 with normalized permission_types and ListPermissionTypes API is simpler and more maintainable while covering all SRS requirements.

