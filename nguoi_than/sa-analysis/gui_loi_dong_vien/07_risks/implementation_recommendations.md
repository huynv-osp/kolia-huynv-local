# Implementation Recommendations: US 1.3 - Gửi Lời Động Viên

> **Phase:** 7 - Technical Risks & Recommendations  
> **Date:** 2026-02-04

---

## Implementation Order

### Recommended Sequence

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  Phase 1: Database (2h)                                                      │
│  └── Create encouragement_messages table and indexes                         │
├──────────────────────────────────────────────────────────────────────────────┤
│  Phase 2: user-service Proto (4h)                                            │
│  └── Define encouragement_service.proto, generate stubs                      │
├──────────────────────────────────────────────────────────────────────────────┤
│  Phase 3: user-service Implementation (20h)                                  │
│  ├── Entity, Repository, Service                                             │
│  ├── gRPC Handler implementation                                             │
│  ├── Kafka producer for push events                                          │
│  └── Unit tests                                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│  Phase 4: api-gateway-service (10h)                       [PARALLEL]         │
│  ├── gRPC client                                                             │
│  ├── REST handlers                                                           │
│  └── Route configuration                                                     │
├──────────────────────────────────────────────────────────────────────────────┤
│  Phase 5: schedule-service (4h)                                              │
│  ├── Kafka consumer                                                          │
│  ├── Push notification task                                                  │
│  └── Unit tests                                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│  Phase 6: Mobile App (16h)                                                   │
│  ├── EncouragementWidget component                                           │
│  ├── EncouragementModal component                                            │
│  ├── API service integration                                                 │
│  └── State management                                                        │
├──────────────────────────────────────────────────────────────────────────────┤
│  Phase 7: Integration Testing (8h)                                           │
│  ├── E2E flow tests                                                          │
│  ├── Permission scenarios                                                    │
│  └── Edge case validation                                                    │
└──────────────────────────────────────────────────────────────────────────────┘

Total: 64 hours (including testing buffer)
```

---

## Code Recommendations

### 1. Permission Check Pattern

```java
// EncouragementServiceImpl.java
@Override
public EncouragementResponse createEncouragement(CreateEncouragementRequest request) {
    // 1. Permission check FIRST
    boolean hasPermission = permissionRepository
        .checkPermission(request.getContactId(), PermissionType.ENCOURAGEMENT.getCode());
    if (!hasPermission) {
        throw new ForbiddenException("PERMISSION_DENIED", 
            "Bạn chưa được cấp quyền gửi lời động viên");
    }
    
    // 2. Quota check
    int todayCount = repo.countByPatientAndDate(request.getPatientId(), LocalDate.now());
    if (todayCount >= MAX_DAILY_QUOTA) {
        throw new LimitExceededException("QUOTA_EXCEEDED",
            "Bạn đã gửi đủ 10 tin nhắn hôm nay");
    }
    
    // 3. Content validation
    String content = sanitize(request.getContent());
    if (content.isEmpty()) {
        throw new BadRequestException("EMPTY_CONTENT");
    }
    if (content.length() > MAX_CONTENT_LENGTH) {
        throw new BadRequestException("CONTENT_TOO_LONG");
    }
    
    // 4. Save message
    // ...
}
```

### 2. Denormalization Pattern

```java
// EncouragementServiceImpl.java - Get relationship info for denormalization
private EncouragementMessage buildMessage(CreateEncouragementRequest request) {
    // Fetch connection info once and denormalize
    ConnectionInfo info = connectionRepository.findById(request.getContactId())
        .orElseThrow(() -> new NotFoundException("CONNECTION_NOT_FOUND"));
    
    return EncouragementMessage.builder()
        .senderId(request.getSenderId())
        .patientId(request.getPatientId())
        .contactId(request.getContactId())
        .content(sanitize(request.getContent()))
        // Denormalized fields for display efficiency
        .senderName(info.getCaregiverDisplayName())
        .relationshipCode(info.getInverseRelationshipCode())
        .relationshipDisplay(info.getInverseRelationshipDisplay())  // Patient's perspective
        .build();
}
```

### 3. Batch Mark Read Pattern

```java
// EncouragementServiceImpl.java - Get relationship info for denormalization
private EncouragementMessage buildMessage(CreateEncouragementRequest request) {
    // Fetch connection info once and denormalize
    ConnectionInfo info = connectionRepository.findById(request.getContactId())
        .orElseThrow(() -> new NotFoundException("CONNECTION_NOT_FOUND"));
    
    return EncouragementMessage.builder()
        .senderId(request.getSenderId())
        .patientId(request.getPatientId())
        .contactId(request.getContactId())
        .content(sanitize(request.getContent()))
        // Denormalized fields for display efficiency
        .senderName(info.getCaregiverDisplayName())
        .relationshipCode(info.getInverseRelationshipCode())
        .relationshipDisplay(info.getInverseRelationshipDisplay())  // Patient's perspective
        .build();
}
```

### 4. Batch Mark Read Pattern

```java
// EncouragementServiceImpl.java
@Override
@Transactional
public void markAsRead(MarkAsReadRequest request) {
    // Validate all IDs belong to this patient
    List<UUID> ids = request.getEncouragementIdsList().stream()
        .map(UUID::fromString)
        .toList();
    
    int updated = repo.batchMarkAsRead(ids, request.getPatientId(), Instant.now());
    
    if (updated != ids.size()) {
        logger.warn("Partial update: {} of {} marked", updated, ids.size());
    }
}
```

---

## Testing Recommendations

### Unit Test Coverage

| Component | Coverage Target | Key Scenarios |
|-----------|:---------------:|---------------|
| EncouragementServiceImpl | 90% | Permission, quota, validation |
| EncouragementRepository | 85% | Quota count, batch update |
| EncouragementHandler | 80% | REST mapping, errors |

### Integration Test Scenarios

```gherkin
Feature: Encouragement Integration Tests

  Scenario: Full send flow - Happy path
    Given Caregiver has permission #6
    And Quota is not exceeded
    When Caregiver sends encouragement
    Then Message is saved in database
    And Kafka event is published
    And Patient receives push notification

  Scenario: Permission denied flow
    Given Caregiver does NOT have permission #6
    When Caregiver attempts to send
    Then 403 Forbidden is returned
    And No message is saved

  Scenario: Quota exceeded flow
    Given Caregiver has sent 10 messages today
    When Caregiver attempts to send
    Then 429 Too Many Requests is returned
    And Error message indicates quota exceeded
```

---

## Monitoring Recommendations

### Dashboard Metrics

```yaml
encouragement_dashboard:
  panels:
    - title: "Messages Sent"
      query: sum(encouragement_created_total)
      type: counter
      
    - title: "Permission Denial Rate"
      query: rate(encouragement_permission_denied_total)
      type: counter
      alert: "spike > 100/5min"
      
    - title: "Create Latency P95"
      query: histogram_quantile(0.95, encouragement_create_duration_seconds)
      type: histogram
      alert: "> 1s"
```

---

## Documentation Requirements

| Document | Location | Owner |
|----------|----------|-------|
| API Reference | Swagger/OpenAPI | api-gateway |
| Proto Documentation | Proto comments | user-service |
| Database Schema | Migration comments | SA |
| Runbook | /docs/runbooks/ | DevOps |

---

## Definition of Done

- [ ] All unit tests passing (>85% coverage)
- [ ] Integration tests passing
- [ ] Code review approved
- [ ] API documentation complete
- [ ] Monitoring dashboards configured
- [ ] Feature flag enabled in staging
- [ ] Performance test passed (<500ms p95)
- [ ] Security review completed
