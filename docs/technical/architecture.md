# 本地编组手机看护技术架构文档

## 1. 技术目标

本 App 的核心目标是在不依赖账号、云端、定位和远程服务器的前提下，让多台手机组成一个本地看护组。当任意设备离开看护范围时，其余设备能尽早、准确、克制地提醒用户。

技术优先级：

1. 本地隐私优先：设备状态、密钥、看护判断都在本机和组内设备之间完成。
2. 报警可靠性优先：宁可通过分级预警减少误报，也不能单次信号波动就强提醒。
3. 平台能力优先：iOS 与 Android 的后台蓝牙、通知、局域网能力差异较大，核心实现应原生化。
4. UI 一致性优先：双端视觉、文案和交互一致，但权限引导和后台策略按平台定制。

## 2. 推荐技术路线

推荐首版采用原生双端实现：

- iOS：Swift + SwiftUI + CoreBluetooth + UserNotifications + Network.framework。
- Android：Kotlin + Jetpack Compose + Bluetooth LE APIs + Foreground Service + Notifications + NSD/UDP local heartbeat。

不建议首版把 BLE、后台保活和报警核心完全放在跨平台框架里。原因是该产品的关键风险正好集中在系统后台能力、权限、蓝牙调度和厂商策略上，原生实现更可控。

可以共享的部分不通过共享代码实现，而通过共享协议文档、状态机、UI token、文案和验收测试保持一致。

## 3. 系统边界

首版不包含以下后端组件：

- 用户账号服务。
- 云端设备状态服务。
- 远程推送服务。
- 云端定位或轨迹服务。
- 跨网络远程控制服务。

所有通信发生在以下通道：

- BLE 广播与扫描。
- 同一 Wi-Fi 或热点内的局域网心跳。
- 用户面对面扫码时的二维码邀请。

## 4. 核心模块

### 4.1 Pairing

职责：

- 创建一次性邀请。
- 展示邀请二维码。
- 扫码解析邀请。
- 发起加入请求。
- 由已有设备确认加入。
- 派生并保存组密钥。

输入：

- 当前看护组信息。
- 创建者设备 ID。
- 邀请有效期。
- 新设备昵称和平台类型。

输出：

- 新设备加入结果。
- 本地持久化的组配置。

### 4.2 LocalIdentity

职责：

- 生成和保存本机稳定设备 ID。
- 保存用户可见设备昵称。
- 保存组 ID、设备列表、组密钥版本。
- 提供本地加密存储读写接口。

设备 ID 不使用系统可追踪广告 ID，也不使用手机号、账号或真实设备序列号。首次安装时随机生成 UUID，并保存在系统安全存储中。

### 4.3 BleHeartbeat

职责：

- 周期性广播本机组内短期标识。
- 扫描组内其他设备广播。
- 输出每台设备的最近发现时间、RSSI 区间、连续丢失时长。

BLE 不直接暴露长期设备 ID。广播内容应使用组密钥派生出的短期滚动标识，降低被外部长期跟踪的风险。

### 4.4 LanHeartbeat

职责：

- 在同一局域网内发现组内设备。
- 发送加密心跳。
- 接收对端确认。
- 输出局域网在线状态。

局域网只作为增强通道。没有 Wi-Fi、热点或本地网络权限时，系统仍通过 BLE 工作。

### 4.5 GuardEngine

职责：

- 融合 BLE 与局域网信号。
- 根据当前模式计算每台设备状态。
- 维护状态机。
- 输出报警事件。

GuardEngine 不直接响铃，只输出状态变化和报警建议，由 AlarmEngine 执行。

### 4.6 AlarmEngine

职责：

- 发出本地通知。
- 触发震动。
- 播放响铃。
- 处理“我知道了”“暂停 10 分钟”“设备恢复连接”。
- 避免重复报警。

### 4.7 PermissionsGuide

职责：

- 检查蓝牙、通知、本地网络、后台能力、电量优化等权限状态。
- 用平台原生方式引导用户开启。
- 将权限问题转化为清楚的产品状态。

## 5. 数据模型

### GuardGroup

```text
GuardGroup
- groupId: String
- displayName: String
- keyVersion: Int
- createdAt: Date
- devices: [GuardDevice]
- currentMode: GuardMode
```

### GuardDevice

```text
GuardDevice
- deviceId: String
- displayName: String
- platform: iOS | Android
- role: owner | member
- joinedAt: Date
- lastSeenAt: Date?
- lastBleSeenAt: Date?
- lastLanSeenAt: Date?
- state: DeviceState
```

### GuardMode

```text
GuardMode
- outing
- indoor
- silent
```

### DeviceState

```text
DeviceState
- online
- unstable
- preAlert
- alarming
- paused
- permissionLimited
- lowPowerRisk
```

### AlarmEvent

```text
AlarmEvent
- eventId: String
- deviceId: String
- level: unstable | preAlert | strong
- startedAt: Date
- acknowledgedAt: Date?
- pausedUntil: Date?
- resolvedAt: Date?
```

## 6. 状态机

每台被看护设备独立维护状态。

```text
online
  -> unstable       连续短时间 BLE/LAN 弱化或丢失
  -> preAlert       丢失时间达到当前模式预警阈值
  -> alarming       预警后仍持续失联
  -> paused         用户暂停提醒
  -> online         任一可靠通道恢复
```

状态转换原则：

- 单次 BLE 丢包不能触发预警。
- 同一局域网在线可以抵消 BLE 短暂异常。
- 外出模式阈值最短，室内模式阈值更长，静音模式不进入响铃。
- 用户主动暂停只影响报警动作，不删除设备状态。

## 7. 模式阈值建议

首版阈值需要真机校准，初始建议如下：

| 模式 | 连接不稳定 | 预警 | 强提醒 | 响铃 |
| --- | --- | --- | --- | --- |
| 外出 | 5-8 秒 | 12-18 秒 | 25-35 秒 | 是 |
| 室内 | 15-25 秒 | 45-60 秒 | 90-120 秒 | 是，可降低音量 |
| 静音 | 15-25 秒 | 45-60 秒 | 不强响 | 否 |

阈值不是产品承诺，应作为 App 内本地默认值随版本发布更新。

## 8. 跨平台 Wire Contract

首版本地协议必须以文档为准，不直接使用 Swift `rawValue` 或 Kotlin `enum.name` 作为隐式协议。所有跨平台 JSON 枚举使用小写字符串：

```text
mode: outing | indoor | silent
platform: ios | android
role: owner | member
deviceState: online | unstable | pre_alert | alarming | paused | permission_limited | low_power_risk
```

### 8.1 Pairing Invite

二维码邀请使用版本化 envelope：

```json
{
  "type": "device_guard_pairing_invite",
  "protocolVersion": 1,
  "inviteId": "invite-1",
  "groupId": "group-1",
  "ownerDeviceId": "owner-1",
  "joinToken": "token-1",
  "expiresAtEpochSeconds": 1710000300
}
```

接收方必须拒绝未知 `type`、不支持的 `protocolVersion`、已过期的 `expiresAtEpochSeconds`，以及缺失必要字段的 payload。

### 8.2 LAN Heartbeat

局域网心跳 JSON：

```json
{
  "protocolVersion": 1,
  "groupHash": "abcd1234abcd1234",
  "deviceId": "ios-1",
  "deviceNameHash": "ef567890ef567890",
  "timestamp": 1710000000,
  "nonce": "nonce-1",
  "mode": "outing",
  "signature": "hex-hmac"
}
```

签名 payload 固定为：

```text
protocolVersion|groupHash|deviceId|deviceNameHash|timestamp|nonce|mode
```

示例：

```text
1|abcd1234abcd1234|ios-1|ef567890ef567890|1710000000|nonce-1|outing
```

`signature` 为 `HMAC-SHA256(groupSecret, payload)` 的小写十六进制字符串。接收方必须验证协议版本、时间窗口、签名和 `mode` 枚举。

### 8.3 BLE Discovery

BLE 发现采用两阶段协议：

1. 广播阶段：iOS 与 Android 都广播同一个 service UUID：`75B9D2B7-7D40-4B10-9F4B-9D3592D4E101`。
2. 读取阶段：扫描到 service 后读取 rolling ID characteristic：`75B9D2B8-7D40-4B10-9F4B-9D3592D4E101`。

Android 可以额外在 service data 中放入 rolling ID 作为快速路径，但跨平台互通不能依赖 service data，因为 iOS 外设广播不可靠支持该字段。

## 9. 本地安全设计

### 9.1 设备身份

设备首次启动生成随机 `deviceId`。该 ID 只在看护组内使用，不应上传或用于广告追踪。

### 9.2 组密钥

创建看护组时生成 `groupSecret`。加入流程完成后，新设备本地保存密钥。

iOS 保存到 Keychain。Android 保存到 Android Keystore 保护的加密存储。

### 9.3 短期广播标识

BLE 广播不直接发送 `groupId` 或 `deviceId`。建议使用：

```text
rollingId = HMAC_SHA256(groupSecret, deviceId + timeBucket).prefix(8-16 bytes)
```

`timeBucket` 可按 1-5 分钟滚动。组内设备可本地计算候选 rollingId 并识别对端，外部观察者难以长期关联同一设备。

### 9.4 心跳签名

局域网心跳使用组密钥签名，避免陌生设备伪造在线状态。

```text
payload = protocolVersion + groupHash + deviceId + deviceNameHash + timestamp + nonce + mode
signature = HMAC_SHA256(groupSecret, payload)
```

接收方必须校验时间窗口、nonce 和签名。

## 10. 本地存储

iOS：

- Keychain：组密钥、本机设备 ID。
- App sandbox encrypted store：设备列表、模式配置、最近状态。

Android：

- Android Keystore：加密密钥。
- EncryptedSharedPreferences 或 DataStore + 加密层：组配置、设备列表、模式配置。

不应存储历史位置和历史轨迹。最近状态只用于当前看护判断，可被用户清空。

## 11. 日志策略

为了调试误报，需要本地诊断日志，但必须默认克制。

允许保存：

- 最近 24 小时内的连接状态摘要。
- 权限状态变化。
- 报警触发原因。
- 设备恢复连接时间。

禁止保存：

- 经纬度。
- Wi-Fi SSID 明文。
- 手机号。
- 通讯录。
- 长期原始 BLE 扫描记录。

诊断日志只留在本机。若未来提供“导出日志给客服”，必须由用户手动导出并明确确认。

## 12. 关键风险

1. iOS 后台 BLE 调度不保证实时，需要真实设备长期测试。
2. Android 厂商系统可能限制后台扫描和前台服务，需要设备适配指引。
3. BLE RSSI 不能等同真实距离，只能作为状态窗口的一部分。
4. 无云端意味着无法远距离找回，产品文案不能暗示“找回手机”。
5. 局域网权限在 iOS 上会引发系统弹窗，首次引导必须解释清楚用途。
