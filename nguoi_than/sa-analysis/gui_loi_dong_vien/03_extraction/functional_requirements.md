# Functional Requirements: US 1.3 - Gửi Lời Động Viên

> **Phase:** 3 - Functional Requirements Extraction  
> **Date:** 2026-02-04  
> **Source:** SRS v1.3

---

## User Stories Summary

| Story ID | Title | Actors | Priority |
|----------|-------|--------|:--------:|
| US-ENG-001 | Caregiver gửi lời nhắn cho Patient | Caregiver, Patient, System | P0 |
| US-ENG-002 | Patient nhận lời động viên | Patient, System | P0 |

---

## US-ENG-001: Caregiver Gửi Lời Động Viên

### Scenario 1: Gửi lời nhắn từ nhập thủ công (Happy Path)

```gherkin
Feature: Send Encouragement Message

  Scenario: Successfully send message from manual input
    Given Caregiver đang ở màn hình Dashboard của Bệnh nhân X
    And Permission #6 (encouragement) = ON
    And Số tin nhắn đã gửi hôm nay < 10

    When Caregiver nhập lời động viên vào ô text input
    And Nhấn nút "Gửi"

    Then System validation:
      - Permission #6 = ON ✓
      - Quota remaining > 0 ✓
      - Content length ≤ 150 ✓
    And System saves message to encouragement_messages
    And System sends Kafka event for push notification
    And UI shows success toast "Đã gửi lời động viên cho [Mẹ]"
    And Quota counter decrements by 1
```

### ~~Scenario 1b: AI Timeout with Fallback~~ [⏸️ DEFERRED]

> **Note:** AI Suggestions deferred to future release

### Scenario 2: Permission Denied

```gherkin
  Scenario: Permission #6 is OFF
    Given Permission #6 (encouragement) = OFF
    
    When Caregiver taps Send button
    
    Then System returns error 403
    And UI shows error: "Bạn chưa được cấp quyền gửi lời động viên"
    And Message is NOT saved
```

### Scenario 3: Daily Quota Exceeded

```gherkin
  Scenario: 10 messages already sent today
    Given 10 tin nhắn đã được gửi hôm nay cho Patient X
    
    When Caregiver taps Send button
    
    Then System returns error 429
    And UI shows error: "Bạn đã gửi đủ 10 tin nhắn hôm nay"
    And Quota display shows "0/10"
```

### Scenario 4: Content Too Long

```gherkin
  Scenario: Content exceeds 150 characters
    Given Caregiver enters text with 151+ characters
    
    When Character count > 150
    
    Then UI shows char counter in red: "151/150"
    And Send button becomes disabled
    And UI hints: "Rút ngắn nội dung còn 150 ký tự"
```

### Scenario 5: Empty Content

```gherkin
  Scenario: Empty message blocked
    Given Input field is empty or whitespace only
    
    When Caregiver taps Send
    
    Then System returns error 400
    And UI prevents submission
```

### Scenario 6: Network Offline

```gherkin
  Scenario: Internet connectivity lost
    Given Device has no internet connection
    
    When Caregiver taps Send
    
    Then UI shows error: "Không có kết nối mạng"
    And Retry option available
```

### Scenario 7: Server Error 5xx

```gherkin
  Scenario: Backend returns 500+ error
    Given Server encounters internal error
    
    When Caregiver taps Send
    
    Then UI shows error: "Có lỗi xảy ra. Vui lòng thử lại."
    And Error logged for debugging
```

### Scenario 8: Permission Revoked During Session

```gherkin
  Scenario: Permission revoked between load and send
    Given Permission #6 was ON at dashboard load
    And Patient revokes permission #6
    
    When Caregiver taps Send
    
    Then System performs real-time permission check
    And Returns error 403
    And UI shows: "Quyền gửi lời động viên đã bị thu hồi"
    And Widget is disabled until refresh
```

---

## US-ENG-002: Patient Nhận Lời Động Viên

### Scenario 1: View Unread Messages in Modal

```gherkin
Feature: Patient receives encouragement

  Scenario: Modal displays unread messages
    Given Patient có lời động viên chưa đọc trong 24h
    
    When Patient mở màn hình chính
    
    Then System queries encouragement_messages:
      - patient_id = current_user
      - is_read = FALSE
      - sent_at >= NOW() - 24h
      - ORDER BY sent_at DESC
    And Modal displays with message list
    And Each message shows:
      - Sender name (e.g., "HuyA")
      - Relationship (e.g., "Con gái")
      - Content
      - Sent time
```

### Scenario 2: Mark Messages as Read (Batch)

```gherkin
  Scenario: Patient dismisses modal
    Given Modal is displayed with N unread messages
    
    When Patient taps "Đã đọc" or closes modal
    
    Then System calls batch mark-read API
    And All displayed message IDs are marked is_read = TRUE
    And Modal closes
    And Next app open will not show these messages
```

### Scenario 3: Push Notification Received

```gherkin
  Scenario: Push notification delivered
    Given Caregiver sent encouragement message
    
    When schedule-service processes Kafka event
    
    Then Patient receives push notification:
      - Title: "💬 Lời động viên từ [Mẹ]"
      - Body: "[Content preview...]"
    And Tapping notification opens Dashboard
```

---

## Business Rules Mapping

| BR ID | Rule | Validation Point | Implementation |
|-------|------|------------------|----------------|
| BR-001 | Max 10 messages/day/Patient | Send API | Redis counter + DB check |
| BR-002 | Max 150 Unicode chars | Send API | `char_length(content) <= 150` |
| BR-003 | Permission #6 required | Send API | Permission check before save |
| BR-004 | No AI moderation | N/A | Caregiver responsibility |
| BR-005 | AI suggests 3 messages | ~~Suggestions API~~ | ⏸️ DEFERRED |

---

## API Requirements Summary

| API | Method | Path | Actor | Purpose |
|-----|:------:|------|-------|---------|
| Create | POST | `/api/v1/encouragements` | Caregiver | Send message |
| Get Quota | GET | `/api/v1/encouragements/quota` | Caregiver | Check remaining quota |
| List | GET | `/api/v1/encouragements` | Patient | Get unread in 24h |
| Mark Read | POST | `/api/v1/encouragements/mark-read` | Patient | Batch mark as read |

---

## Next Steps

➡️ Proceed to Phase 4: Architecture Mapping & Analysis
