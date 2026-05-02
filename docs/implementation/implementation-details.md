# 实现细节说明

## 1. 开发阶段划分

### Phase 0: 原型验证

目标：验证 iOS 与 Android 在前台、锁屏、后台的 BLE 广播/扫描能力，以及局域网增强可行性。

产物：

- iOS BLE 原型。
- Android BLE 原型。
- 双端 rollingId 识别。
- 同 Wi-Fi 心跳原型。
- 后台行为测试记录。

不做：

- 完整 UI。
- 完整加密握手。
- App Store / Play Store 上架准备。

### Phase 1: MVP

目标：实现可用的本地编组看护。

功能：

- 创建看护组。
- 扫码加入。
- 创建者确认。
- BLE 心跳。
- 局域网增强。
- 首页状态。
- 三种模式。
- 分级报警。
- 权限引导。
- 本地加密存储。

### Phase 2: 稳定性打磨

目标：降低误报，提高后台可靠性。

工作：

- 真机矩阵测试。
- 阈值校准。
- Android 厂商后台策略适配。
- iOS 后台行为优化。
- 本地诊断日志。
- UI 细节和动效打磨。

## 2. 代码结构建议

### iOS

```text
ios/GuardApp/
  App/
    GuardApp.swift
  Features/
    Onboarding/
    Pairing/
    Home/
    Alarm/
    Settings/
  Core/
    Identity/
    Pairing/
    Bluetooth/
    LocalNetwork/
    GuardEngine/
    AlarmEngine/
    Permissions/
    Storage/
  DesignSystem/
    Colors.swift
    Typography.swift
    Components/
  Tests/
```

### Android

```text
android/app/src/main/java/com/deviceguard/
  app/
  features/
    onboarding/
    pairing/
    home/
    alarm/
    settings/
  core/
    identity/
    pairing/
    bluetooth/
    localnetwork/
    guardengine/
    alarmengine/
    permissions/
    storage/
  design/
  test/
```

## 3. GuardEngine 规则

GuardEngine 输入：

- `BleObservation`
- `LanObservation`
- `GuardMode`
- `DevicePauseState`
- `PermissionState`

输出：

- `DeviceState`
- `AlarmIntent`

伪代码：

```text
for each device in group.devices:
  signal = combine(bleObservation, lanObservation)
  elapsed = now - signal.lastReliableSeenAt

  if device.pausedUntil > now:
    state = paused
    alarm = none
  else if permission blocks core sensing:
    state = permissionLimited
    alarm = none
  else if elapsed < unstableThreshold(mode):
    state = online
    alarm = none
  else if elapsed < preAlertThreshold(mode):
    state = unstable
    alarm = none
  else if elapsed < strongAlertThreshold(mode):
    state = preAlert
    alarm = notifyAndVibrate
  else if mode == silent:
    state = preAlert
    alarm = notifyAndVibrate
  else:
    state = alarming
    alarm = ringAndVibrate
```

`lastReliableSeenAt` 计算规则：

- LAN 心跳签名通过，优先级最高。
- BLE rollingId 命中且连续多次出现，认为可靠。
- 单次 BLE 命中只更新弱信号，不直接恢复所有报警。

## 4. BLE 细节

### 广播频率

建议初始值：

- 外出：较高频率。
- 室内：中等频率。
- 静音：低频率。

实际数值需由真机测试确定，避免写死无法调整。配置应集中在 `GuardModeConfig`。

### 扫描窗口

不要持续满功率扫描。按模式和平台能力使用扫描窗口：

- 前台：较积极。
- 锁屏：中等。
- 后台：保守，依赖系统能力。

### 去抖动

同一设备的 BLE 观察值需要去抖：

- RSSI 瞬时低值不触发状态变化。
- 连续丢失才进入预警。
- 恢复也需要至少一次可靠命中或局域网确认。

## 5. 局域网细节

局域网心跳用途：

- 同 Wi-Fi 下确认设备仍在附近。
- 降低室内误报。
- 辅助设备列表状态刷新。

不用于：

- 跨网络远程控制。
- 云端同步。
- 定位。

发现策略：

- 优先使用平台推荐的服务发现能力。
- 心跳包必须签名。
- 未签名或签名错误的包直接丢弃。

## 5.5 跨平台协议实现细节

### 配对二维码

iOS 与 Android 必须编码同一份 invite envelope：

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

实现要求：

- `type` 必须等于 `device_guard_pairing_invite`。
- `protocolVersion` 必须等于 `1`。
- `expiresAtEpochSeconds` 必须大于当前本机 epoch seconds。
- iOS 不再把 invite 的过期时间作为 JSON `Date` 字段输出。
- Android 不再把 Kotlin enum `name` 当作跨平台协议值。

### 局域网心跳

签名 payload 必须固定为：

```text
protocolVersion|groupHash|deviceId|deviceNameHash|timestamp|nonce|mode
```

`mode` 必须是 `outing`、`indoor`、`silent` 之一。Android 需要通过 `wireValue` 显式映射，不能使用 `GuardMode.OUTING.name`。

### BLE 发现

固定 UUID：

```text
serviceUuid: 75B9D2B7-7D40-4B10-9F4B-9D3592D4E101
rollingIdCharacteristicUuid: 75B9D2B8-7D40-4B10-9F4B-9D3592D4E101
```

互通路径：

```text
scan serviceUuid -> connect peripheral/GATT server -> read rollingIdCharacteristicUuid -> update lastBleSeenAt
```

Android 的 service data 只能作为快速路径。iOS 与 Android 的真实联调验收必须验证 characteristic 读取路径。

## 6. 报警音与震动

报警音原则：

- 专业、短促、清晰。
- 不使用刺耳廉价警笛。
- 强提醒可循环，但必须容易停止。

震动原则：

- 预警阶段短震。
- 强提醒阶段节奏更明显。
- 静音模式下只通知和震动。

## 7. 本地诊断

本地诊断页面只在设置中隐藏展示。

展示：

- 当前权限状态。
- 最近设备心跳摘要。
- 最近一次报警原因。
- 当前模式阈值。

不展示：

- 经纬度。
- 原始扫描列表。
- 可被误解为监控他人的信息。

## 8. 测试矩阵

基础设备：

- iPhone 近两代系统版本。
- 常见 Android：Pixel、Samsung、小米、华为、OPPO 或 vivo。

场景：

- 前台。
- 锁屏。
- 后台 5 分钟。
- 后台 30 分钟。
- 同 Wi-Fi。
- 无 Wi-Fi。
- 热点。
- 电梯。
- 车内。
- 酒店/餐厅。
- 会议室。

指标：

- 预警触发时间。
- 强提醒触发时间。
- 误报次数。
- 设备恢复时间。
- 1 小时耗电。
- 权限关闭后的提示准确性。

## 9. 上架注意

iOS：

- 权限说明必须与实际用途一致。
- 不要暗示后台无限制运行。
- 不要使用与看护无关的后台能力。

Android：

- 前台服务类型必须与用途匹配。
- 通知渠道必须清晰。
- 需要解释持续看护通知。

## 10. 首版完成定义

首版可以进入内测的条件：

- 两台 iPhone、两台 Android、iPhone + Android 混合编组均可完成加入。
- 外出模式能在设备离开后触发预警和强提醒。
- 室内模式误报明显低于外出模式。
- 静音模式不主动响铃。
- 权限关闭时提示准确。
- UI 达到商务、优雅、可信赖的视觉标准。
- 不产生云端请求。
- 不请求定位权限。
