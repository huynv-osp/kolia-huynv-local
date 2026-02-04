# API Integration Tests: US 1.2 - Nhận Cảnh Báo

> **Version:** 1.0  
> **Date:** 2026-02-04  
> **Test Framework:** WebTestClient (Java)

---

## 1. Alert History API

### GET /api/v1/alerts

#### API-ALT-001: Get 24h alerts
```java
@Test
void getAlerts_default_returns24Hours() {
    webTestClient.get()
        .uri("/api/v1/alerts")
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
            .jsonPath("$.alerts").isArray()
            .jsonPath("$.alerts[0].alert_type_id").isNumber()
            .jsonPath("$.alerts[0].patient_name").isNotEmpty()
            .jsonPath("$.alerts[0].created_at").isNotEmpty();
}
```

#### API-ALT-002: Filter by type
```java
@Test
void getAlerts_filterByType_returnsFiltered() {
    webTestClient.get()
        .uri(uriBuilder -> uriBuilder
            .path("/api/v1/alerts")
            .queryParam("type", "SOS")
            .build())
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
            .jsonPath("$.alerts[*].alert_type_id").value(
                types -> assertThat(types).allMatch(t -> t.equals(1)));
}
```

#### API-ALT-003: Filter by patient
```java
@Test
void getAlerts_filterByPatient_returnsFiltered() {
    webTestClient.get()
        .uri(uriBuilder -> uriBuilder
            .path("/api/v1/alerts")
            .queryParam("patientId", PATIENT_UUID)
            .build())
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
            .jsonPath("$.alerts[*].patient_id").value(
                ids -> assertThat(ids).allMatch(id -> id.equals(PATIENT_UUID)));
}
```

#### API-ALT-004: Pagination
```java
@Test
void getAlerts_pagination_works() {
    webTestClient.get()
        .uri(uriBuilder -> uriBuilder
            .path("/api/v1/alerts")
            .queryParam("page", 0)
            .queryParam("size", 5)
            .build())
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
            .jsonPath("$.total").isNumber()
            .jsonPath("$.page").isEqualTo(0)
            .jsonPath("$.size").isEqualTo(5);
}
```

#### API-ALT-005: Unauthorized
```java
@Test
void getAlerts_noToken_returns401() {
    webTestClient.get()
        .uri("/api/v1/alerts")
        .exchange()
        .expectStatus().isUnauthorized();
}
```

---

## 2. Alert Detail API

### GET /api/v1/alerts/{id}

#### API-ALT-006: Get SOS detail with location
```java
@Test
void getAlertDetail_sosWithLocation_returnsLocation() {
    // Given - Create SOS alert with GPS
    String alertId = createSosAlertWithLocation(PATIENT_UUID, 10.762622, 106.660172);
    
    webTestClient.get()
        .uri("/api/v1/alerts/" + alertId)
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
            .jsonPath("$.alert_type_id").isEqualTo(1)
            .jsonPath("$.location.lat").isEqualTo(10.762622)
            .jsonPath("$.location.lng").isEqualTo(106.660172)
            .jsonPath("$.has_location").isEqualTo(true);
}
```

#### API-ALT-007: Get BP detail with values
```java
@Test
void getAlertDetail_bpAbnormal_returnsValues() {
    // Given - Create BP alert
    String alertId = createBpAlert(PATIENT_UUID, 185, 125, "HIGH");
    
    webTestClient.get()
        .uri("/api/v1/alerts/" + alertId)
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
            .jsonPath("$.alert_type_id").isEqualTo(2)
            .jsonPath("$.systolic").isEqualTo(185)
            .jsonPath("$.diastolic").isEqualTo(125)
            .jsonPath("$.direction").isEqualTo("HIGH");
}
```

#### API-ALT-008: Not found
```java
@Test
void getAlertDetail_notFound_returns404() {
    webTestClient.get()
        .uri("/api/v1/alerts/" + UUID.randomUUID())
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectStatus().isNotFound();
}
```

#### API-ALT-009: Permission denied
```java
@Test
void getAlertDetail_noPermission_returns403() {
    // Given - Caregiver without permission #2
    String alertId = createAlert(OTHER_PATIENT_UUID);
    
    webTestClient.get()
        .uri("/api/v1/alerts/" + alertId)
        .header("Authorization", "Bearer " + caregiverNoPermissionToken)
        .exchange()
        .expectStatus().isForbidden();
}
```

---

## 3. Mark Read API

### POST /api/v1/alerts/{id}/read

#### API-ALT-010: Mark as read
```java
@Test
void markAlertAsRead_success() {
    // Given
    String alertId = createAlert(PATIENT_UUID);
    
    webTestClient.post()
        .uri("/api/v1/alerts/" + alertId + "/read")
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectStatus().isOk();
    
    // Verify
    webTestClient.get()
        .uri("/api/v1/alerts/" + alertId)
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectBody()
            .jsonPath("$.is_read").isEqualTo(true);
}
```

#### API-ALT-011: Already read
```java
@Test
void markAlertAsRead_alreadyRead_stillOk() {
    // Given - Already marked
    String alertId = createAlert(PATIENT_UUID);
    markAsRead(alertId, caregiverToken);
    
    webTestClient.post()
        .uri("/api/v1/alerts/" + alertId + "/read")
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectStatus().isOk();  // Idempotent
}
```

---

## 4. Unread Count API

### GET /api/v1/alerts/unread-count

#### API-ALT-012: Get unread count
```java
@Test
void getUnreadCount_returnsCount() {
    webTestClient.get()
        .uri("/api/v1/alerts/unread-count")
        .header("Authorization", "Bearer " + caregiverToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
            .jsonPath("$.count").isNumber();
}
```

---

## 5. Test Summary

| Endpoint | Tests |
|----------|:-----:|
| GET /api/v1/alerts | 5 |
| GET /api/v1/alerts/{id} | 4 |
| POST /api/v1/alerts/{id}/read | 2 |
| GET /api/v1/alerts/unread-count | 1 |
| **Total** | **12** |
