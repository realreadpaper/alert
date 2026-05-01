# Cloud Assist Go Backend Design

## 1. 背景

当前 Android 原型已经加入“云端辅助”开关、云端心跳模型和内存版 `InMemoryCloudPresenceRepository`。这个原型可以演示 `远程在线` 与 `云端失联` 的 UI 状态，但它不是真实云端：数据只存在本机内存中，不能让不同网络下的多台手机同步在线状态。

真实产品需要支持以下场景：

- 手机 A 使用 Wi-Fi，手机 B 使用蜂窝网络。
- 两台手机不在同一个局域网，BLE/LAN 无法互相发现。
- 用户主动开启“云端辅助”后，设备仍能知道对方最近是否在线。
- 云端辅助只证明“设备还有网络”，不证明“设备还在身边”。

## 2. 目标

- 使用 Go 实现一个最小可用的云端在线状态服务。
- 设备定期向服务端上报匿名、签名的心跳。
- 同组设备可以查询彼此最近在线状态。
- 服务端不保存位置、轨迹、真实设备名、组密钥、手机号、账号或远程控制指令。
- Android 端后续可以用真实 HTTP 仓库替换当前内存仓库。

## 3. 非目标

- 不做账号体系。
- 不做地图定位或轨迹。
- 不做远程锁机、远程响铃、远程擦除。
- 不做聊天或通用消息转发。
- 不把云端在线当成本地看护在线。
- 不由服务端持有 `groupSecret`，服务端不验证 HMAC。

## 4. 推荐架构

采用“本地优先 + 云端盲 presence 存储”的架构：

```text
Android device
  |
  | signed heartbeat
  v
Go cloud presence API
  |
  | upsert anonymous latest status
  v
PostgreSQL cloud_presence table

Other Android device
  |
  | query groupHash + deviceHashes
  v
Go cloud presence API
  |
  | anonymous latest status
  v
Android verifies HMAC locally with groupSecret
```

服务端只看见匿名哈希和签名载荷，不知道原始组 ID、设备 ID 或组密钥。同组设备查询结果后，使用本地保存的 `groupSecret` 验证签名。验证通过才允许 UI 显示 `远程在线`。

## 5. 数据模型

### 5.1 心跳字段

```json
{
  "protocolVersion": 1,
  "groupHash": "64_hex_chars",
  "deviceHash": "64_hex_chars",
  "timestamp": 1777590000,
  "nonce": "uuid-or-random-token",
  "mode": "OUTING",
  "signature": "hmac_sha256_hex"
}
```

### 5.2 签名规则

客户端签名：

```text
signature = HMAC_SHA256(
  groupSecret,
  protocolVersion + "|" +
  groupHash + "|" +
  deviceHash + "|" +
  timestamp + "|" +
  nonce + "|" +
  mode
)
```

当前 Android 原型使用短 hash。真实云端接入时应升级为完整 SHA-256 hex，降低碰撞和枚举风险：

```text
groupHash = SHA256(groupId)
deviceHash = SHA256(deviceId)
```

### 5.3 服务端保存字段

服务端只保存：

- `group_hash`
- `device_hash`
- `protocol_version`
- `last_seen_at`
- `mode`
- `nonce`
- `signature`
- `expires_at`
- `updated_at`

服务端不得保存：

- 明文 `groupId`
- 明文 `deviceId`
- `groupSecret`
- 真实设备名
- 用户姓名、手机号、邮箱
- 经纬度、Wi-Fi 名称、蓝牙扫描明细
- 历史轨迹

## 6. API 设计

### 6.1 Health Check

```http
GET /healthz
```

响应：

```json
{
  "ok": true
}
```

### 6.2 上报心跳

```http
POST /v1/cloud/heartbeat
Content-Type: application/json
```

请求：

```json
{
  "protocolVersion": 1,
  "groupHash": "64_hex_chars",
  "deviceHash": "64_hex_chars",
  "timestamp": 1777590000,
  "nonce": "b1b3f84e-c2a7-4a32-8e0e-9bb7a7c06a1f",
  "mode": "OUTING",
  "signature": "64_hex_chars"
}
```

响应：

```json
{
  "accepted": true,
  "serverTime": 1777590001,
  "expiresAt": 1777590180
}
```

服务端行为：

- 校验 JSON 格式。
- 校验 `protocolVersion == 1`。
- 校验 `groupHash`、`deviceHash`、`signature` 为 64 位 hex。
- 校验 `timestamp` 与服务器时间偏差不超过 120 秒。
- 校验 `mode` 属于已知枚举。
- 设置 `expiresAt = serverTime + 180`。
- 使用 upsert 保存最新心跳。
- 如果收到更旧的 `timestamp`，不覆盖较新的 presence。

### 6.3 查询在线状态

```http
POST /v1/cloud/presence/query
Content-Type: application/json
```

请求：

```json
{
  "protocolVersion": 1,
  "groupHash": "64_hex_chars",
  "deviceHashes": [
    "64_hex_chars",
    "64_hex_chars"
  ]
}
```

响应：

```json
{
  "serverTime": 1777590001,
  "devices": [
    {
      "deviceHash": "64_hex_chars",
      "lastSeenAt": 1777590000,
      "mode": "OUTING",
      "nonce": "b1b3f84e-c2a7-4a32-8e0e-9bb7a7c06a1f",
      "signature": "64_hex_chars",
      "expiresAt": 1777590180
    }
  ]
}
```

服务端行为：

- 只返回未过期的 presence。
- 请求最多允许 32 个 `deviceHashes`。
- 查询不到的设备不返回条目。
- 服务端不判断“在线/离线”，只返回最近状态；App 根据 `serverTime`、`expiresAt` 和本地 HMAC 验证结果做 UI 判断。

## 7. 状态判断

Android 端最终状态应按以下顺序判断：

| 条件 | 首页状态 |
| --- | --- |
| BLE/LAN 最近可靠发现 | `在线` |
| BLE/LAN 失联，但云端 presence 未过期且签名有效 | `远程在线` |
| BLE/LAN 失联，云端无记录、过期或签名无效 | `云端失联` 或进入本地失联报警流程 |
| 云端辅助关闭 | 不显示云端状态 |

`远程在线` 的产品含义必须固定为“设备仍有网络连接”，不能解释为“设备还在附近”。

## 8. Go 服务端结构

```text
server/
  go.mod
  cmd/deviceguard-cloud/main.go
  internal/config/config.go
  internal/http/router.go
  internal/http/handlers.go
  internal/presence/model.go
  internal/presence/service.go
  internal/presence/store.go
  internal/presence/postgres_store.go
  internal/presence/memory_store.go
  internal/security/validation.go
  internal/security/ratelimit.go
  migrations/001_create_cloud_presence.sql
```

职责划分：

- `cmd/deviceguard-cloud/main.go`：加载配置、连接数据库、启动 HTTP 服务。
- `internal/config`：读取端口、数据库 DSN、TTL、限流配置。
- `internal/http`：路由、请求响应 DTO、错误映射。
- `internal/presence`：业务模型、服务、存储接口和存储实现。
- `internal/security`：字段校验、时间偏差校验、限流。
- `migrations`：数据库建表脚本。

## 9. 数据库设计

PostgreSQL 表：

```sql
CREATE TABLE cloud_presence (
  group_hash TEXT NOT NULL,
  device_hash TEXT NOT NULL,
  protocol_version INTEGER NOT NULL,
  last_seen_at BIGINT NOT NULL,
  mode TEXT NOT NULL,
  nonce TEXT NOT NULL,
  signature TEXT NOT NULL,
  expires_at BIGINT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (group_hash, device_hash)
);

CREATE INDEX idx_cloud_presence_expires_at
ON cloud_presence (expires_at);
```

Upsert 规则：

```sql
INSERT INTO cloud_presence (
  group_hash,
  device_hash,
  protocol_version,
  last_seen_at,
  mode,
  nonce,
  signature,
  expires_at,
  updated_at
) VALUES (
  $1, $2, $3, $4, $5, $6, $7, $8, now()
)
ON CONFLICT (group_hash, device_hash)
DO UPDATE SET
  protocol_version = EXCLUDED.protocol_version,
  last_seen_at = EXCLUDED.last_seen_at,
  mode = EXCLUDED.mode,
  nonce = EXCLUDED.nonce,
  signature = EXCLUDED.signature,
  expires_at = EXCLUDED.expires_at,
  updated_at = now()
WHERE cloud_presence.last_seen_at <= EXCLUDED.last_seen_at;
```

清理任务：

```sql
DELETE FROM cloud_presence
WHERE expires_at < $1;
```

生产环境可以每 60 秒执行一次过期清理。

## 10. 配置

环境变量：

```text
DEVICEGUARD_HTTP_ADDR=:8080
DEVICEGUARD_DATABASE_DSN=postgres://deviceguard:password@localhost:5432/deviceguard?sslmode=disable
DEVICEGUARD_PRESENCE_TTL_SECONDS=180
DEVICEGUARD_ALLOWED_CLOCK_SKEW_SECONDS=120
DEVICEGUARD_MAX_QUERY_DEVICES=32
DEVICEGUARD_RATE_LIMIT_PER_IP_PER_MINUTE=120
DEVICEGUARD_RATE_LIMIT_PER_GROUP_PER_MINUTE=240
```

## 11. 错误响应

统一错误格式：

```json
{
  "error": {
    "code": "invalid_request",
    "message": "invalid groupHash"
  }
}
```

错误码：

| HTTP 状态 | code | 场景 |
| --- | --- | --- |
| 400 | `invalid_request` | JSON 无效、字段缺失、字段格式错误 |
| 408 | `clock_skew` | 时间偏差过大 |
| 413 | `too_many_devices` | 查询设备数量超过限制 |
| 429 | `rate_limited` | 触发限流 |
| 500 | `internal_error` | 服务端内部错误 |

## 12. Android 接入设计

新增真实 HTTP 仓库：

```text
android/app/src/main/java/com/deviceguard/core/cloud/HttpCloudPresenceRepository.kt
```

接口保持接近现有 `CloudPresenceRepository`，但真实网络需要 suspend/异步形态。后续实现时建议拆分：

```kotlin
interface CloudPresenceClient {
    suspend fun publish(message: CloudHeartbeatMessage): CloudHeartbeatPublishResult
    suspend fun query(groupHash: String, deviceHashes: List<String>): CloudPresenceQueryResult
}
```

Android 端行为：

- 云端辅助默认关闭。
- 用户开启后，本机每 30 到 60 秒上报一次心跳。
- 每 30 到 60 秒查询组内其他设备 presence。
- 查询结果必须用本地 `groupSecret` 校验 HMAC。
- 签名无效、过期、网络失败都不能显示为 `远程在线`。
- 网络失败不应直接触发强报警，强报警仍以本地 BLE/LAN 看护策略为主。

## 13. 安全和隐私

- 所有生产请求必须使用 HTTPS。
- 服务端日志不得打印请求 body、`signature`、`nonce` 全量值。
- 日志可以记录请求路径、状态码、耗时和截断后的 `groupHash` 前 6 位。
- 服务端不设置跨组查询能力；查询必须指定单个 `groupHash`。
- 服务端不提供历史查询接口。
- 服务端不提供“列出一个组所有设备”的接口。
- 客户端不应把云端状态描述为定位、找回或附近确认。

## 14. 测试策略

Go 单元测试：

- `POST /v1/cloud/heartbeat` 接收合法心跳。
- 非 64 位 hex 的 `groupHash` 被拒绝。
- 时间偏差超过 120 秒被拒绝。
- 更旧心跳不会覆盖新心跳。
- 过期 presence 不会被查询返回。
- 查询超过 32 个设备返回 `too_many_devices`。

Go 集成测试：

- 使用 `memory_store` 验证完整 HTTP 流程。
- 使用 PostgreSQL 测试容器或本地测试库验证 upsert 和 TTL 清理。

Android 测试：

- HTTP 返回新鲜 presence 且签名有效时显示 `远程在线`。
- HTTP 返回新鲜 presence 但签名无效时显示 `云端失联`。
- presence 过期时显示 `云端失联`。
- 云端辅助关闭时不发请求。

## 15. 发布与部署

首个可测环境：

- Go binary 部署到一台公网服务器。
- PostgreSQL 单实例。
- Nginx 或 Caddy 终止 TLS。
- `/healthz` 接入基础监控。
- 日志输出到 stdout。

后续生产增强：

- 数据库备份策略。
- 指标监控：请求量、错误率、延迟、presence 数量。
- 按 IP 和 groupHash 的限流统计。
- 灰度开关：客户端可以隐藏云端辅助入口或切换 API base URL。

## 16. 验收标准

- 两台手机不在同一局域网时，开启云端辅助后可以看到对方 `远程在线`。
- 关闭其中一台手机网络后，另一台在 TTL 之后看到 `云端失联`。
- 服务端数据库中没有明文设备名、组密钥、位置或历史轨迹。
- 服务端重启后，未过期 presence 仍可从 PostgreSQL 查询。
- Android 端签名验证失败时不会显示 `远程在线`。
- 云端辅助关闭时 Android 不向云端发送心跳或查询 presence。

## 17. 实施顺序

1. 建立 Go 服务骨架和 `memory_store`，完成 API 单元测试。
2. 加入 PostgreSQL store 和 migration，完成数据库集成测试。
3. 在 Android 端抽象 `CloudPresenceClient`，先用 fake client 保持 UI 可测。
4. 接入真实 HTTP client，替换当前内存模拟。
5. 使用两台模拟器或真机验证跨网络远程在线。
6. 补充隐私文案和网络失败降级逻辑。
