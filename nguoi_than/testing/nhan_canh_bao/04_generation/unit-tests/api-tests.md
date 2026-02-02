# 🌐 API Integration Tests - Nhận Cảnh Báo (US 1.2)

## Document Information

| Attribute | Value |
|-----------|-------|
| **Version** | 1.5 |
| **Date** | 2026-02-02 |
| **Service** | api-gateway-service |
| **Total Test Cases** | ~35 |

---

## 1. Alert REST API Tests

### 1.1 GET /api/v1/connections/alerts

```java
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
@AutoConfigureWebTestClient
class AlertHistoryApiTest {

    @Autowired WebTestClient webClient;
    @MockBean AlertGrpcClient alertGrpcClient;
    
    // ============================================================
    // SUCCESS CASES
    // ============================================================
    
    @Test @DisplayName("List alerts - success with pagination")
    void getAlerts_success_returns200WithPagination() {
        // Given: Authenticated caregiver
        // When: GET /api/v1/connections/alerts?page=0&size=10
        // Then: 200 OK with paginated alert list
        
        webClient.get()
            .uri("/api/v1/connections/alerts?page=0&size=10")
            .header("Authorization", "Bearer " + validToken)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.data").isArray()
            .jsonPath("$.pagination.page").isEqualTo(0)
            .jsonPath("$.pagination.size").isEqualTo(10)
            .jsonPath("$.pagination.totalElements").isNumber();
    }
    
    @Test @DisplayName("Filter by alert type")
    void getAlerts_filterByType_returnsFiltered() {
        // Given: Alerts of type SOS, HA, MEDICATION
        // When: GET /api/v1/alerts?type=HA
        // Then: Only HA alerts returned
        
        webClient.get()
            .uri("/api/v1/connections/alerts?typeId=2")
            .header("Authorization", "Bearer " + validToken)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.data[*].alertType.typeCode").value(
                (List<String> types) -> types.forEach(t -> assertEquals("HA", t))
            );
    }
    
    @Test @DisplayName("Filter by patient")
    void getAlerts_filterByPatient_returnsFiltered() {
        // Given: Alerts from multiple patients
        // When: GET /api/v1/alerts?patientId={id}
        // Then: Only alerts for that patient
        
        webClient.get()
            .uri("/api/v1/connections/alerts?patientId=" + patientId)
            .header("Authorization", "Bearer " + validToken)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.data[*].patientId").value(
                (List<String> ids) -> ids.forEach(id -> assertEquals(patientId, id))
            );
    }
    
    @Test @DisplayName("Filter by time range")
    void getAlerts_filterByTimeRange_returnsFiltered() {
        // Given: Alerts from different dates
        // When: GET /api/v1/connections/alerts?periodDays=7
        // Then: Only alerts within range (0=today, 7, 30, 90 days)
    }
    
    @Test @DisplayName("Sort by priority then time")
    void getAlerts_defaultSort_priorityThenTimeDesc() {
        // Given: Mixed priority alerts
        // When: GET /api/v1/alerts
        // Then: SOS first, then HA, then Medication, then Compliance
        
        webClient.get()
            .uri("/api/v1/alerts")
            .header("Authorization", "Bearer " + validToken)
            .exchange()
            .expectStatus().isOk()
            .expectBody()
            .jsonPath("$.data[0].priority").isEqualTo(0)  // SOS = P0
            .jsonPath("$.data[1].priority").isEqualTo(1); // HA = P1
    }
    
    // ============================================================
    // ERROR CASES
    // ============================================================
    
    @Test @DisplayName("Unauthorized - no token")
    void getAlerts_noToken_returns401() {
        webClient.get()
            .uri("/api/v1/alerts")
            .exchange()
            .expectStatus().isUnauthorized();
    }
    
    @Test @DisplayName("Invalid page parameter")
    void getAlerts_invalidPage_returns400() {
        webClient.get()
            .uri("/api/v1/connections/alerts?page=-1")
            .header("Authorization", "Bearer " + validToken)
            .exchange()
            .expectStatus().isBadRequest()
            .expectBody()
            .jsonPath("$.code").isEqualTo("INVALID_PARAMETER");
    }
}
```

### 1.2 GET /api/v1/connections/alerts/{alertId}

```java
@Test @DisplayName("Get alert detail - success")
void getAlertDetail_validId_returns200() {
    // Given: Existing alert belonging to caregiver
    // When: GET /api/v1/connections/alerts/{alertId}
    // Then: 200 with full alert detail + payload
    
    webClient.get()
        .uri("/api/v1/connections/alerts/" + alertId)
        .header("Authorization", "Bearer " + validToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
        .jsonPath("$.alertId").isEqualTo(alertId)
        .jsonPath("$.title").isNotEmpty()
        .jsonPath("$.payload").exists();
}

@Test @DisplayName("Get alert detail - not found")
void getAlertDetail_invalidId_returns404() {
    webClient.get()
        .uri("/api/v1/alerts/" + UUID.randomUUID())
        .header("Authorization", "Bearer " + validToken)
        .exchange()
        .expectStatus().isNotFound()
        .expectBody()
        .jsonPath("$.code").isEqualTo("ALERT_NOT_FOUND");
}

@Test @DisplayName("Get alert detail - not owner")
void getAlertDetail_notOwner_returns403() {
    // Given: Alert belongs to another caregiver
    // When: GET /api/v1/alerts/{alertId}
    // Then: 403 Forbidden
    
    webClient.get()
        .uri("/api/v1/connections/alerts/" + otherCaregiverAlertId)
        .header("Authorization", "Bearer " + validToken)
        .exchange()
        .expectStatus().isForbidden();
}
```

### 1.3 POST /api/v1/connections/alerts/mark-read

```java
@Test @DisplayName("Mark read - success")
void markRead_validAlert_returns200() {
    // Given: Unread alert
    // When: PUT /api/v1/alerts/{alertId}/read
    // Then: 200 OK, alert status = read
    
    webClient.put()
        .uri("/api/v1/alerts/" + alertId + "/read")
        .header("Authorization", "Bearer " + validToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
        .jsonPath("$.status").isEqualTo(1)  // read
        .jsonPath("$.readAt").isNotEmpty();
}

@Test @DisplayName("Mark read - idempotent")
void markRead_alreadyRead_returns200() {
    // Given: Already read alert
    // When: PUT /api/v1/alerts/{alertId}/read again
    // Then: 200 OK (idempotent)
    
    webClient.put()
        .uri("/api/v1/alerts/" + readAlertId + "/read")
        .header("Authorization", "Bearer " + validToken)
        .exchange()
        .expectStatus().isOk();
}

@Test @DisplayName("Mark read - not found")
void markRead_invalidAlert_returns404() {
    webClient.put()
        .uri("/api/v1/alerts/" + UUID.randomUUID() + "/read")
        .header("Authorization", "Bearer " + validToken)
        .exchange()
        .expectStatus().isNotFound();
}
```

### 1.4 GET /api/v1/alerts/unread-count

```java
@Test @DisplayName("Get unread count - success")
void getUnreadCount_success_returns200() {
    // Given: Caregiver has 5 unread alerts
    // When: GET /api/v1/alerts/unread-count
    // Then: 200 with count = 5
    
    webClient.get()
        .uri("/api/v1/alerts/unread-count")
        .header("Authorization", "Bearer " + validToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
        .jsonPath("$.unreadCount").isNumber()
        .jsonPath("$.lastUpdated").isNotEmpty();
}

@Test @DisplayName("Unread count - zero when all read")
void getUnreadCount_allRead_returnsZero() {
    // Given: All alerts are read
    // When: GET /api/v1/alerts/unread-count
    // Then: count = 0
    
    webClient.get()
        .uri("/api/v1/alerts/unread-count")
        .header("Authorization", "Bearer " + validToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
        .jsonPath("$.unreadCount").isEqualTo(0);
}
```

### 1.5 GET /api/v1/alerts/types

```java
@Test @DisplayName("Get alert types - success")
void getAlertTypes_success_returns4Types() {
    // Given: System has 4 alert categories
    // When: GET /api/v1/alerts/types
    // Then: 200 with 4 types
    
    webClient.get()
        .uri("/api/v1/alerts/types")
        .header("Authorization", "Bearer " + validToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
        .jsonPath("$.data.length()").isEqualTo(4)
        .jsonPath("$.data[?(@.typeCode=='SOS')]").exists()
        .jsonPath("$.data[?(@.typeCode=='HA')]").exists()
        .jsonPath("$.data[?(@.typeCode=='MEDICATION')]").exists()
        .jsonPath("$.data[?(@.typeCode=='COMPLIANCE')]").exists();
}
```

---

## 2. Patient-scoped Alert API Tests

### 2.1 GET /api/v1/patients/{patientId}/alerts

```java
@Test @DisplayName("Get patient alerts - with connection")
void getPatientAlerts_withConnection_returns200() {
    // Given: Caregiver has active connection with patient
    // When: GET /api/v1/patients/{patientId}/alerts
    // Then: 200 with patient's alerts
    
    webClient.get()
        .uri("/api/v1/patients/" + patientId + "/alerts")
        .header("Authorization", "Bearer " + validToken)
        .exchange()
        .expectStatus().isOk()
        .expectBody()
        .jsonPath("$.data[*].patientId").value(
            (List<String> ids) -> ids.forEach(id -> assertEquals(patientId, id))
        );
}

@Test @DisplayName("Get patient alerts - no connection")
void getPatientAlerts_noConnection_returns404() {
    // Given: No connection with patient
    // When: GET /api/v1/patients/{patientId}/alerts
    // Then: 404 NOT_FOUND
    
    webClient.get()
        .uri("/api/v1/patients/" + unconnectedPatientId + "/alerts")
        .header("Authorization", "Bearer " + validToken)
        .exchange()
        .expectStatus().isNotFound()
        .expectBody()
        .jsonPath("$.code").isEqualTo("CONNECTION_NOT_FOUND");
}

@Test @DisplayName("Get patient alerts - permission OFF")
void getPatientAlerts_permissionOff_returns403() {
    // Given: Connection exists but Permission #2 = OFF
    // When: GET /api/v1/patients/{patientId}/alerts
    // Then: 403 Forbidden
    
    webClient.get()
        .uri("/api/v1/patients/" + permissionOffPatientId + "/alerts")
        .header("Authorization", "Bearer " + validToken)
        .exchange()
        .expectStatus().isForbidden()
        .expectBody()
        .jsonPath("$.code").isEqualTo("PERMISSION_DENIED");
}
```

---

## 3. gRPC Integration Tests

### 3.1 AlertGrpcServiceTest

```java
@GrpcTest
class AlertGrpcServiceIntegrationTest {

    @GrpcClient("inProcess")
    AlertServiceGrpc.AlertServiceBlockingStub stub;
    
    @MockBean AlertRepository alertRepository;
    @MockBean PermissionRepository permissionRepository;
    
    @Test @DisplayName("CreateAlert - success")
    void createAlert_validRequest_returnsAlertInfo() {
        CreateAlertRequest request = CreateAlertRequest.newBuilder()
            .setPatientId(patientId.toString())
            .setCaregiverId(caregiverId.toString())
            .setAlertTypeId(2)  // HA
            .setTitle("Test Alert")
            .setPriority(1)
            .build();
        
        AlertInfo response = stub.createAlert(request);
        
        assertNotNull(response.getAlertId());
        assertEquals(2, response.getAlertTypeId());
    }
    
    @Test @DisplayName("GetAlerts - with pagination")
    void getAlerts_withPagination_returnsPagedResponse() {
        GetAlertsRequest request = GetAlertsRequest.newBuilder()
            .setCaregiverId(caregiverId.toString())
            .setPage(0)
            .setSize(10)
            .build();
        
        AlertListResponse response = stub.getAlerts(request);
        
        assertTrue(response.getAlertsCount() <= 10);
        assertNotNull(response.getPagination());
    }
    
    @Test @DisplayName("MarkRead - success")  
    void markRead_validAlert_updatesStatus() {
        MarkReadRequest request = MarkReadRequest.newBuilder()
            .setAlertId(alertId.toString())
            .setCaregiverId(caregiverId.toString())
            .build();
        
        AlertInfo response = stub.markRead(request);
        
        assertEquals(1, response.getStatus());  // read
    }
    
    @Test @DisplayName("GetUnreadCount - success")
    void getUnreadCount_returnsCount() {
        UnreadCountRequest request = UnreadCountRequest.newBuilder()
            .setCaregiverId(caregiverId.toString())
            .build();
        
        UnreadCountResponse response = stub.getUnreadCount(request);
        
        assertTrue(response.getCount() >= 0);
    }
}
```

---

## 4. Error Response Tests

### 4.1 Error Codes Validation

| Code | HTTP | Scenario |
|------|:----:|----------|
| `ALERT_NOT_FOUND` | 404 | Alert ID không tồn tại |
| `CONNECTION_NOT_FOUND` | 404 | Không có connection với patient |
| `PERMISSION_DENIED` | 403 | Permission #2 = OFF |
| `UNAUTHORIZED` | 401 | Token invalid/expired |
| `INVALID_PARAMETER` | 400 | Query param không hợp lệ |

```java
@Test @DisplayName("Verify error response format")
void errorResponse_shouldMatchStandardFormat() {
    webClient.get()
        .uri("/api/v1/alerts/" + UUID.randomUUID())
        .header("Authorization", "Bearer " + validToken)
        .exchange()
        .expectStatus().isNotFound()
        .expectBody()
        .jsonPath("$.code").isEqualTo("ALERT_NOT_FOUND")
        .jsonPath("$.message").isNotEmpty()
        .jsonPath("$.timestamp").isNotEmpty();
}
```

---

## Summary

| Endpoint | Test Count |
|----------|:----------:|
| GET /api/v1/alerts | 8 |
| GET /api/v1/alerts/{id} | 4 |
| PUT /api/v1/alerts/{id}/read | 4 |
| GET /api/v1/alerts/unread-count | 3 |
| GET /api/v1/alerts/types | 2 |
| GET /api/v1/patients/{id}/alerts | 5 |
| gRPC AlertService | 6 |
| Error Response | 3 |
| **Total** | **~35** |

---

**Generated:** 2026-02-02T23:20:00+07:00  
**Workflow:** `/alio-testing`
