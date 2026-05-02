# iOS 与 Android 平台实现细节

## 1. 原则

平台实现必须服务于同一个产品体验：本地编组、即时报警、本地优先、无云端依赖、商务优雅 UI。不同平台可以使用不同底层机制，但对用户暴露的状态、文案和流程应一致。

## 2. iOS 实现

### 2.1 推荐技术栈

- Language: Swift
- UI: SwiftUI
- BLE: CoreBluetooth
- Local network: Network.framework
- Notification: UserNotifications
- Storage: Keychain + FileProtection enabled local store

### 2.2 iOS 权限

需要处理：

- Bluetooth permission。
- Local Network permission。
- Notification permission。
- Background Modes 中的 Bluetooth 相关能力。

权限引导文案应避免技术化：

- 蓝牙：“用于发现看护组内的手机是否仍在身边。”
- 本地网络：“当几台手机在同一 Wi-Fi 下时，用于减少误报。”
- 通知：“设备可能离开时及时提醒你。”

### 2.3 CoreBluetooth 设计

iOS 端包含两个角色：

- Peripheral role：广播本机短期 rollingId。
- Central role：扫描组内其他设备 rollingId。

后台能力受系统调度影响，不能承诺秒级稳定。GuardEngine 应把 iOS 后台扫描视为“可能延迟的信号”，并通过状态窗口缓冲。

建议：

- 前台和锁屏时更积极扫描。
- 后台时降低心跳频率，依赖系统唤醒。
- App 回到前台后立即做一次状态刷新。
- 不把单次未扫描到作为离组。

### 2.4 iOS 本地网络

使用 Network.framework 在局域网内进行发现和心跳。

可选方案：

- Bonjour 服务发现：适合发现组内设备。
- UDP 心跳：实现简单，但需要处理局域网广播限制。

首版建议优先 Bonjour + TCP/UDP 小包确认。所有包都必须带 HMAC 签名。

### 2.5 iOS 通知与响铃

预警阶段：

- 发送本地通知。
- 触发震动。

强提醒阶段：

- App 前台：展示全屏报警页并播放本地音频。
- App 后台：通过通知声音提醒；用户点通知进入 App 后继续显示报警页。

iOS 对后台连续播放音频有审核和系统限制，首版不要把“后台无限响铃”作为承诺。产品文案应强调“提醒”，不是“强制报警器”。

### 2.6 iOS 存储

- `deviceId` 与 `groupSecret` 存 Keychain。
- 设备列表和模式配置存在本地加密文件或数据库。
- 文件保护级别建议使用 `completeUntilFirstUserAuthentication`，保证重启解锁后可正常工作。

## 3. Android 实现

### 3.1 推荐技术栈

- Language: Kotlin
- UI: Jetpack Compose
- BLE: Android Bluetooth LE APIs
- Background: Foreground Service for active guarding
- Notification: Android notification channels
- Storage: Android Keystore + encrypted local storage

### 3.2 Android 权限

需要按系统版本处理：

- Bluetooth scan/connect/advertise permissions。
- Notification permission。
- Foreground service permission and type。
- Nearby devices 相关权限。
- 厂商电量优化提示。

权限文案：

- “允许附近设备权限，用于发现看护组内手机。”
- “允许通知，用于设备可能离开时提醒。”
- “开启持续看护时，系统会显示看护状态通知。”

### 3.3 Android BLE 设计

Android 端同样包含：

- Advertiser：广播本机 rollingId。
- Scanner：扫描组内 rollingId。

建议：

- 外出模式下启动前台服务，提高后台可靠性。
- 室内模式降低扫描频率。
- 静音模式保留状态检测，但不强响。
- 对不同厂商显示针对性后台限制提示。

### 3.4 Android 前台服务

看护开启时启动前台服务，并显示常驻通知：

标题：`设备看护中`

内容：`3 台设备正在本地看护`

操作：

- `停止看护`
- `切换静音`

前台服务停止条件：

- 用户点击停止看护。
- 用户退出当前看护组。
- 系统权限被撤销后进入受限状态。

### 3.5 Android 通知与响铃

通知渠道建议：

- `guard_status`：低优先级，看护状态常驻通知。
- `guard_alert`：高优先级，设备可能离开。
- `guard_alarm`：高优先级，强提醒响铃。

强提醒时：

- 前台展示报警页。
- 后台发高优先级通知。
- 可播放本地报警音，但必须提供明显停止入口。

### 3.6 Android 存储

- `deviceId` 和密钥由 Android Keystore 保护。
- 组配置使用加密 DataStore 或 Room + SQLCipher。
- 报警状态和最近心跳状态可本地保存，便于 App 重启后恢复。

## 4. 双端一致协议

### 4.1 BLE 广播字段

建议广播内容尽量短：

```text
protocolVersion: UInt8
rollingId: Bytes(8-16)
capabilityFlags: UInt8
```

不广播明文设备昵称、组 ID、手机号或长期设备 ID。

### 4.2 局域网心跳字段

```json
{
  "protocolVersion": 1,
  "groupHash": "short_hash",
  "deviceId": "uuid",
  "deviceNameHash": "hash",
  "timestamp": 1777559668,
  "nonce": "random",
  "mode": "outing",
  "signature": "hmac"
}
```

`deviceNameHash` 仅用于诊断和冲突检查，不应替代设备 ID。

### 4.3 加入确认字段

```json
{
  "inviteId": "uuid",
  "expiresAt": 1777560000,
  "groupId": "uuid",
  "ownerDeviceId": "uuid",
  "joinToken": "one_time_token",
  "protocolVersion": 1
}
```

二维码不应包含长期明文组密钥。加入后通过本地加密握手完成密钥分发。

## 5. 权限降级策略

| 权限缺失 | 产品状态 | 技术行为 |
| --- | --- | --- |
| 蓝牙关闭 | 无法近距离看护 | 停止 BLE 扫描和广播，首页提示恢复 |
| 通知关闭 | 可能无法及时提醒 | 继续检测，但提示开启通知 |
| 本地网络关闭 | 室内可靠性下降 | 只使用 BLE |
| Android 前台服务受限 | 后台可靠性下降 | 显示系统设置指引 |
| iOS 后台受限 | 后台提醒可能延迟 | 回到前台立即刷新状态 |

## 6. 后续云端扩展边界

当前实现不包含云端辅助、账号、远程推送或服务端请求，也不声明 `INTERNET` 权限。后续如扩展云端，只能作为单独阶段重新设计、重新做隐私审查，并保持默认本地模式不变。

## 7. 官方文档参考

- Apple Core Bluetooth Background Processing: https://developer.apple.com/documentation/corebluetooth/background-processing-for-ios-apps
- Android Bluetooth permissions: https://developer.android.com/develop/connectivity/bluetooth/bt-permissions
- Android Foreground service types: https://developer.android.com/develop/background-work/services/fgs/service-types
