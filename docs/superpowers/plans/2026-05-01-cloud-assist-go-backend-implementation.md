# Cloud Assist Go Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现一个 Go 云端 presence 服务，并让 Android 端具备真实 HTTP 云端辅助接入能力。

**Architecture:** Go 服务提供 `/healthz`、`POST /v1/cloud/heartbeat`、`POST /v1/cloud/presence/query`，服务端只保存匿名哈希和最近在线状态。Android 端保留当前内存原型，同时新增 `CloudPresenceClient` 和 HTTP client，为后续替换本地模拟打通协议边界。

**Tech Stack:** Go 1.26 stdlib `net/http` + `database/sql` + in-memory store + PostgreSQL SQL migration；Android Kotlin + `HttpURLConnection` + `org.json` + JVM unit tests。

---

## File Structure

- Create `server/go.mod`: Go module definition.
- Create `server/cmd/deviceguard-cloud/main.go`: 服务启动入口。
- Create `server/internal/config/config.go`: 环境变量配置。
- Create `server/internal/presence/model.go`: presence 领域模型。
- Create `server/internal/presence/store.go`: 存储接口。
- Create `server/internal/presence/memory_store.go`: 内存存储，供测试和本地启动使用。
- Create `server/internal/presence/postgres_store.go`: PostgreSQL 存储骨架和 SQL 调用。
- Create `server/internal/presence/service.go`: 心跳上报和查询业务逻辑。
- Create `server/internal/security/validation.go`: hex、枚举、时间偏差校验。
- Create `server/internal/httpapi/router.go`: HTTP 路由和 handler。
- Create `server/internal/httpapi/router_test.go`: API 行为测试。
- Create `server/migrations/001_create_cloud_presence.sql`: 数据库建表。
- Modify `android/app/src/main/java/com/deviceguard/core/cloud/CloudHeartbeatMessage.kt`: 使用完整 SHA-256 hex 支持真实云端。
- Create `android/app/src/main/java/com/deviceguard/core/cloud/CloudPresenceClient.kt`: Android 云端协议客户端接口和 DTO。
- Create `android/app/src/main/java/com/deviceguard/core/cloud/HttpCloudPresenceClient.kt`: Android HTTP client。
- Create `android/app/src/test/java/com/deviceguard/core/cloud/HttpCloudPresenceClientTest.kt`: HTTP 序列化和结果解析测试。

## Task 1: Go Presence Service Core

**Files:**
- Create: `server/go.mod`
- Create: `server/internal/presence/model.go`
- Create: `server/internal/presence/store.go`
- Create: `server/internal/presence/memory_store.go`
- Create: `server/internal/presence/service.go`
- Test: `server/internal/presence/service_test.go`

- [ ] **Step 1: Write failing service tests**

```go
func TestServiceAcceptsHeartbeatAndReturnsFreshPresence(t *testing.T) {
	now := int64(1777590000)
	store := presence.NewMemoryStore()
	service := presence.NewService(store, presence.Config{
		TTLSeconds:              180,
		AllowedClockSkewSeconds: 120,
		MaxQueryDevices:         32,
		Now:                     func() int64 { return now },
	})

	heartbeat := presence.Heartbeat{
		ProtocolVersion: 1,
		GroupHash:       strings.Repeat("a", 64),
		DeviceHash:      strings.Repeat("b", 64),
		Timestamp:       now,
		Nonce:           "nonce-a",
		Mode:            "OUTING",
		Signature:       strings.Repeat("c", 64),
	}

	result, err := service.AcceptHeartbeat(context.Background(), heartbeat)
	if err != nil {
		t.Fatalf("AcceptHeartbeat returned error: %v", err)
	}

	devices, err := service.QueryPresence(context.Background(), presence.PresenceQuery{
		ProtocolVersion: 1,
		GroupHash:       heartbeat.GroupHash,
		DeviceHashes:    []string{heartbeat.DeviceHash},
	})
	if err != nil {
		t.Fatalf("QueryPresence returned error: %v", err)
	}

	if !result.Accepted || result.ExpiresAt != now+180 {
		t.Fatalf("unexpected publish result: %+v", result)
	}
	if len(devices.Devices) != 1 || devices.Devices[0].DeviceHash != heartbeat.DeviceHash {
		t.Fatalf("unexpected query result: %+v", devices)
	}
}
```

- [ ] **Step 2: Run tests and confirm red**

Run: `cd server && go test ./internal/presence`

Expected: FAIL because package/files are not implemented yet.

- [ ] **Step 3: Implement minimal presence core**

Implement:

```go
type Heartbeat struct {
	ProtocolVersion int
	GroupHash       string
	DeviceHash      string
	Timestamp       int64
	Nonce           string
	Mode            string
	Signature       string
}

type Presence struct {
	DeviceHash string
	LastSeenAt int64
	Mode       string
	Nonce      string
	Signature  string
	ExpiresAt  int64
}
```

`Service.AcceptHeartbeat` validates, computes `expiresAt = now + TTLSeconds`, then upserts. `Service.QueryPresence` returns only non-expired rows.

- [ ] **Step 4: Run tests and confirm green**

Run: `cd server && go test ./internal/presence`

Expected: PASS.

## Task 2: Go HTTP API

**Files:**
- Create: `server/internal/httpapi/router.go`
- Test: `server/internal/httpapi/router_test.go`

- [ ] **Step 1: Write failing HTTP tests**

```go
func TestHeartbeatAndQueryHTTPFlow(t *testing.T) {
	now := int64(1777590000)
	service := presence.NewService(presence.NewMemoryStore(), presence.Config{
		TTLSeconds:              180,
		AllowedClockSkewSeconds: 120,
		MaxQueryDevices:         32,
		Now:                     func() int64 { return now },
	})
	handler := httpapi.NewRouter(service)

	body := `{"protocolVersion":1,"groupHash":"` + strings.Repeat("a", 64) + `","deviceHash":"` + strings.Repeat("b", 64) + `","timestamp":1777590000,"nonce":"nonce-a","mode":"OUTING","signature":"` + strings.Repeat("c", 64) + `"}`
	heartbeatReq := httptest.NewRequest(http.MethodPost, "/v1/cloud/heartbeat", strings.NewReader(body))
	heartbeatReq.Header.Set("Content-Type", "application/json")
	heartbeatRes := httptest.NewRecorder()
	handler.ServeHTTP(heartbeatRes, heartbeatReq)
	if heartbeatRes.Code != http.StatusOK {
		t.Fatalf("heartbeat status = %d body = %s", heartbeatRes.Code, heartbeatRes.Body.String())
	}

	queryBody := `{"protocolVersion":1,"groupHash":"` + strings.Repeat("a", 64) + `","deviceHashes":["` + strings.Repeat("b", 64) + `"]}`
	queryReq := httptest.NewRequest(http.MethodPost, "/v1/cloud/presence/query", strings.NewReader(queryBody))
	queryReq.Header.Set("Content-Type", "application/json")
	queryRes := httptest.NewRecorder()
	handler.ServeHTTP(queryRes, queryReq)
	if queryRes.Code != http.StatusOK || !strings.Contains(queryRes.Body.String(), `"devices"`) {
		t.Fatalf("query status = %d body = %s", queryRes.Code, queryRes.Body.String())
	}
}
```

- [ ] **Step 2: Run tests and confirm red**

Run: `cd server && go test ./internal/httpapi`

Expected: FAIL because HTTP router is not implemented yet.

- [ ] **Step 3: Implement HTTP router and handlers**

Use stdlib `http.NewServeMux()`. Implement:

- `GET /healthz`
- `POST /v1/cloud/heartbeat`
- `POST /v1/cloud/presence/query`

Return JSON errors in this shape:

```json
{"error":{"code":"invalid_request","message":"invalid groupHash"}}
```

- [ ] **Step 4: Run tests and confirm green**

Run: `cd server && go test ./internal/httpapi`

Expected: PASS.

## Task 3: Go Config, Main, Migration

**Files:**
- Create: `server/internal/config/config.go`
- Create: `server/cmd/deviceguard-cloud/main.go`
- Create: `server/migrations/001_create_cloud_presence.sql`
- Create: `server/internal/presence/postgres_store.go`

- [ ] **Step 1: Add config and entrypoint**

Implement environment variables:

```text
DEVICEGUARD_HTTP_ADDR=:8080
DEVICEGUARD_PRESENCE_TTL_SECONDS=180
DEVICEGUARD_ALLOWED_CLOCK_SKEW_SECONDS=120
DEVICEGUARD_MAX_QUERY_DEVICES=32
```

`main.go` starts with `memory_store` by default so local testing does not require PostgreSQL.

- [ ] **Step 2: Add migration and PostgreSQL store skeleton**

Add `cloud_presence` table SQL from the design. Add `PostgresStore` using `database/sql`; keep it compilable and ready for DSN wiring, while the default executable uses memory store until production config is added.

- [ ] **Step 3: Verify Go server builds**

Run: `cd server && go test ./...`

Expected: PASS.

## Task 4: Android Cloud HTTP Client

**Files:**
- Modify: `android/app/src/main/java/com/deviceguard/core/cloud/CloudHeartbeatMessage.kt`
- Create: `android/app/src/main/java/com/deviceguard/core/cloud/CloudPresenceClient.kt`
- Create: `android/app/src/main/java/com/deviceguard/core/cloud/HttpCloudPresenceClient.kt`
- Test: `android/app/src/test/java/com/deviceguard/core/cloud/HttpCloudPresenceClientTest.kt`

- [ ] **Step 1: Write failing Android HTTP client test**

```kotlin
@Test
fun publishesHeartbeatAndQueriesPresenceOverHttp() {
    val server = FakeCloudServer()
    val client = HttpCloudPresenceClient(server.baseUrl)
    val signer = CloudHeartbeatSigner()
    val message = signer.create(
        groupId = "group-a",
        groupSecret = "group-secret".toByteArray(),
        deviceId = "device-a",
        mode = GuardMode.OUTING,
        timestamp = 1_777_590_000L,
        nonce = "nonce-a"
    )

    val publish = client.publish(message)
    val query = client.query(message.groupHash, listOf(message.deviceHash))

    assertTrue(publish.accepted)
    assertEquals(1, query.devices.size)
}
```

- [ ] **Step 2: Run test and confirm red**

Run: `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :android:app:testDebugUnitTest --tests com.deviceguard.core.cloud.HttpCloudPresenceClientTest`

Expected: FAIL because `HttpCloudPresenceClient` does not exist yet.

- [ ] **Step 3: Implement client and DTOs**

Implement:

```kotlin
data class CloudHeartbeatPublishResult(
    val accepted: Boolean,
    val serverTime: Long,
    val expiresAt: Long
)

data class CloudPresenceQueryResult(
    val serverTime: Long,
    val devices: List<CloudPresenceResult>
)

interface CloudPresenceClient {
    fun publish(message: CloudHeartbeatMessage): CloudHeartbeatPublishResult
    fun query(groupHash: String, deviceHashes: List<String>): CloudPresenceQueryResult
}
```

Use `HttpURLConnection` and `org.json`.

- [ ] **Step 4: Run Android tests**

Run: `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :android:app:testDebugUnitTest`

Expected: PASS.

## Task 5: Full Verification

**Files:**
- All changed files.

- [ ] **Step 1: Run backend verification**

Run: `cd server && go test ./...`

Expected: PASS.

- [ ] **Step 2: Run Android verification**

Run: `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :android:app:testDebugUnitTest :android:app:assembleDebug`

Expected: BUILD SUCCESSFUL.

- [ ] **Step 3: Run whitespace verification**

Run: `git diff --check`

Expected: no output and exit code 0.

- [ ] **Step 4: Install Android app to emulator**

Run:

```bash
/opt/homebrew/share/android-commandlinetools/platform-tools/adb -s emulator-5554 install -r android/app/build/outputs/apk/debug/app-debug.apk
/opt/homebrew/share/android-commandlinetools/platform-tools/adb -s emulator-5554 shell am start -n com.deviceguard/.MainActivity
```

Expected: install `Success` and activity starts.

## Self Review

- Spec coverage: covers Go API, storage, validation, migration, Android HTTP client, and final verification.
- Placeholder scan: no `TBD` or unfinished task.
- Type consistency: `CloudPresenceClient`, `CloudHeartbeatPublishResult`, and `CloudPresenceQueryResult` names are used consistently across Android tasks.
