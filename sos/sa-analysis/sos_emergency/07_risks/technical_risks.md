# Technical Risks Analysis

## Analysis Context
| Item | Value |
|------|-------|
| **Analysis Name** | `sos_emergency` |
| **Assessment Date** | 2026-01-26 |

---

## 1. Risk Register

### 1.1 High Severity Risks 🔴

---

#### RISK-001: Auto-Escalation Call Technical Complexity

| Attribute | Value |
|-----------|-------|
| **Category** | Technical |
| **Severity** | 🔴 High |
| **Probability** | 🟡 Medium (40%) |
| **Impact** | High - Core feature may not work |

**Description:**
Auto-escalation requires detecting call status (answered, busy, no answer) from native phone. This is technically challenging on both iOS and Android:
- iOS: CallKit has limitations for background apps
- Android: Telephony permissions increasingly restricted

**Mitigation:**
1. **Primary:** Implement as push notification + manual call (contact taps to call)
2. **Secondary:** Use Twilio/Vonage for programmatic calling
3. **Fallback:** ZNS/SMS only escalation, no auto-call

**Residual Risk:** 🟢 Low (with fallback approach)

---

#### RISK-002: Server-Client Countdown Synchronization

| Attribute | Value |
|-----------|-------|
| **Category** | Technical |
| **Severity** | 🔴 High |
| **Probability** | 🟡 Medium (35%) |
| **Impact** | High - User confusion, potential missed alerts |

**Description:**
SRS specifies max 5-second tolerance between client and server countdown. Network latency, app backgrounding, and clock drift can cause sync issues.

**Mitigation:**
1. **Server as source of truth:** All timing decisions made server-side
2. **Periodic sync:** Client polls `/api/sos/status` every 5 seconds
3. **Optimistic UI:** Client shows countdown but server decides completion
4. **Graceful handling:** If client countdown finishes first, show "Đang gửi..."

**Residual Risk:** 🟢 Low

---

#### RISK-003: ZNS Rate Limits and Quota

| Attribute | Value |
|-----------|-------|
| **Category** | Integration |
| **Severity** | 🔴 High |
| **Probability** | 🟢 Low (20%) |
| **Impact** | High - Messages may not be delivered |

**Description:**
ZNS has rate limits (~500 messages/hour for business accounts). During high-usage periods or abuse scenarios, quota may be exhausted.

**Mitigation:**
1. **Rate limiting:** Implement per-user cooldown (already in SRS)
2. **Quota monitoring:** Alert when approaching 80% quota
3. **SMS fallback:** Switch to SMS provider when ZNS quota low
4. **Abuse prevention:** Flag accounts with >5 SOS/day

**Residual Risk:** 🟢 Low

---

### 1.2 Medium Severity Risks 🟡

---

#### RISK-004: DND (Do Not Disturb) Bypass

| Attribute | Value |
|-----------|-------|
| **Category** | Technical |
| **Severity** | 🟡 Medium |
| **Probability** | 🟡 Medium (50%) |
| **Impact** | Medium - SOS sounds may not play |

**Description:**
SRS requires bypassing DND for SOS sounds/haptics. This requires special permissions and OS-specific implementation.

**Mitigation:**
1. **iOS:** Use Critical Alerts entitlement (requires Apple approval)
2. **Android:** Use Full-screen intent with alarm channel
3. **Fallback:** Strong visual indicators if sound fails
4. **User education:** Recommend allowing notifications

**Residual Risk:** 🟡 Medium (depends on Apple approval)

---

#### RISK-005: Offline Queue Sync Timing

| Attribute | Value |
|-----------|-------|
| **Category** | Technical |
| **Severity** | 🟡 Medium |
| **Probability** | 🟡 Medium (30%) |
| **Impact** | Medium - Delayed alert delivery |

**Description:**
When SOS triggered offline, alert may be delayed significantly until network returns. Location data may be stale.

**Mitigation:**
1. **Immediate 115 call:** Native phone works offline (not airplane mode)
2. **Queue timestamp:** Include original trigger time in alert
3. **Location warning:** Mark location as "có thể không chính xác"
4. **Auto-retry:** Aggressive retry when network returns

**Residual Risk:** 🟢 Low

---

#### RISK-006: ZNS OA Approval Delay

| Attribute | Value |
|-----------|-------|
| **Category** | Business/Process |
| **Severity** | 🟡 Medium |
| **Probability** | 🟡 Medium (40%) |
| **Impact** | Medium - Feature launch delay |

**Description:**
ZNS Official Account approval can take 2-4 weeks. SOS feature cannot go live without approved OA.

**Mitigation:**
1. **Start early:** Initiate OA process immediately
2. **SMS fallback:** Develop with SMS during approval period
3. **Staging with test OA:** Use sandbox for testing
4. **Feature flag:** Launch other features first

**Residual Risk:** 🟡 Medium (timeline dependency)

---

#### RISK-007: "Kết nối người thân" Dependency

| Attribute | Value |
|-----------|-------|
| **Category** | Dependency |
| **Severity** | 🟡 Medium |
| **Probability** | 🟡 Medium (50%) |
| **Impact** | High - Cannot test full escalation |

**Description:**
SOS escalation depends on "Kết nối người thân" feature which has no confirmed timeline.

**Mitigation:**
1. **Parallel development:** Build with mock contacts
2. **Contract-first:** Define contact interface now
3. **Phased launch:** Launch SOS without escalation first
4. **Scope reduction:** Use existing emergency contact from health profile

**Residual Risk:** 🟡 Medium

---

### 1.3 Low Severity Risks 🟢

---

#### RISK-008: GPS Timeout in Urban Areas

| Attribute | Value |
|-----------|-------|
| **Category** | Technical |
| **Severity** | 🟢 Low |
| **Probability** | 🟢 Low (15%) |
| **Impact** | Low - Degraded location accuracy |

**Description:**
GPS may timeout in dense urban areas or indoors.

**Mitigation:**
1. **Fallback chain:** Last known location → Cell tower → IP location
2. **Warning in message:** "Vị trí có thể không chính xác"
3. **Continue without location:** Still send SOS

**Residual Risk:** 🟢 Low

---

#### RISK-009: First Aid Content Sync Failure

| Attribute | Value |
|-----------|-------|
| **Category** | Technical |
| **Severity** | 🟢 Low |
| **Probability** | 🟢 Low (10%) |
| **Impact** | Low - Empty state shown |

**Description:**
First aid content may not sync properly on first use.

**Mitigation:**
1. **Bundle default content:** Ship basic content with app
2. **Background sync:** Sync on app install
3. **Empty state:** Clear message with 115 prompt
4. **Version check:** Only update when version changes

**Residual Risk:** 🟢 Low

---

#### RISK-010: Zalo Video Not Installed

| Attribute | Value |
|-----------|-------|
| **Category** | Technical |
| **Severity** | 🟢 Low |
| **Probability** | 🟡 Medium (30%) |
| **Impact** | Low - Feature not available |

**Description:**
Zalo video call button may not work if Zalo not installed.

**Mitigation:**
1. **Detect installation:** Check canOpenURL for Zalo
2. **Disable button:** Show tooltip "Zalo chưa được cài đặt"
3. **Regular call fallback:** Offer phone call instead

**Residual Risk:** 🟢 Low

---

## 2. Risk Summary Matrix

| Risk ID | Risk | Severity | Probability | Score | Mitigation Status |
|---------|------|:--------:|:-----------:|:-----:|:-----------------:|
| RISK-001 | Auto-escalation calls | 🔴 | 🟡 | 8 | ⚠️ Needs design decision |
| RISK-002 | Countdown sync | 🔴 | 🟡 | 7 | ✅ Mitigation defined |
| RISK-003 | ZNS rate limits | 🔴 | 🟢 | 6 | ✅ Mitigation defined |
| RISK-004 | DND bypass | 🟡 | 🟡 | 5 | ⚠️ Needs Apple approval |
| RISK-005 | Offline queue | 🟡 | 🟡 | 4 | ✅ Mitigation defined |
| RISK-006 | ZNS OA approval | 🟡 | 🟡 | 4 | ⏳ Process dependency |
| RISK-007 | Contact feature dep | 🟡 | 🟡 | 5 | ⚠️ Needs timeline |
| RISK-008 | GPS timeout | 🟢 | 🟢 | 2 | ✅ Mitigation defined |
| RISK-009 | First aid sync | 🟢 | 🟢 | 1 | ✅ Mitigation defined |
| RISK-010 | Zalo not installed | 🟢 | 🟡 | 2 | ✅ Mitigation defined |

---

## 3. Risk Response Actions

### 3.1 Immediate Actions (Before Development)

| # | Action | Owner | Due |
|---|--------|-------|-----|
| 1 | Decide on auto-escalation approach | PM + Tech Lead | Week 1 |
| 2 | Initiate ZNS OA approval | Ops Team | Immediate |
| 3 | Confirm "Kết nối người thân" timeline | PM | Week 1 |
| 4 | Apply for iOS Critical Alerts entitlement | iOS Lead | Immediate |

### 3.2 During Development

| # | Action | Owner | Due |
|---|--------|-------|-----|
| 5 | Implement SMS fallback early | Backend Dev | Week 2 |
| 6 | Build mock contact system | Backend Dev | Week 1 |
| 7 | Prototype countdown sync | Mobile Dev | Week 1 |
| 8 | Set up ZNS sandbox | Ops Team | Week 2 |

### 3.3 Pre-Launch

| # | Action | Owner | Due |
|---|--------|-------|-----|
| 9 | Load test ZNS integration | QA | Week 4 |
| 10 | Test DND bypass on real devices | QA | Week 4 |
| 11 | Verify offline scenarios | QA | Week 4 |
| 12 | Validate feature flags | DevOps | Week 5 |

---

## 4. Overall Risk Assessment

| Metric | Value |
|--------|-------|
| **Total Risks** | 10 |
| **High Severity** | 3 |
| **Medium Severity** | 4 |
| **Low Severity** | 3 |
| **Mitigated** | 7 |
| **Needs Attention** | 3 |
| **Residual Risk Level** | 🟡 Medium-Low |

---

## Next Phase

✅ **Phase 7: Technical Risks** - COMPLETE

➡️ **See also: Implementation Recommendations**
