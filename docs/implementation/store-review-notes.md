# 上架审查说明

## 产品说明

本 App 是一款本地设备看护工具，用于用户拥有多台手机时，在某台设备离开看护范围时及时提醒。App 不提供云端找回、地图定位或远程追踪能力。

## iOS App Review 说明

### Bluetooth

用途：App 使用 CoreBluetooth 在用户已加入的看护组设备之间进行本地发现，用于判断设备是否仍在附近。

建议审核说明：

```text
The app uses Bluetooth only to detect nearby devices that the user has explicitly added to a local guard group. It does not track location and does not upload device state to a server.
```

### Local Network

用途：当几台设备处于同一 Wi-Fi 或热点环境时，使用本地网络心跳减少误报。

建议审核说明：

```text
The app uses local network communication only between devices in the same user-created guard group to improve local detection reliability.
```

### Notifications

用途：当设备可能离开看护范围时提醒用户。

建议审核说明：

```text
Notifications are used to alert the user when a guarded device may have left the local guard range.
```

### Background Modes

用途：支持本地看护在合理后台条件下继续工作。

注意事项：

- 不承诺后台无限运行。
- 不使用与看护无关的后台能力。
- 不把 App 描述为远程追踪或定位工具。

## Android Play Review 说明

### Nearby Devices / Bluetooth

用途：发现看护组内的附近手机。

建议审核说明：

```text
Bluetooth permissions are used to discover nearby devices that the user has explicitly paired into a local guard group.
```

### Notifications

用途：设备可能离开时发出预警或强提醒。

建议审核说明：

```text
Notifications are used for local device guard alerts. The user can stop guarding or pause alerts at any time.
```

### Foreground Service

用途：用户开启看护时，Android 通过前台服务显示持续看护状态，提高本地检测可靠性。

建议审核说明：

```text
The foreground service runs only while the user has enabled active guarding. It displays an ongoing notification and can be stopped by the user.
```

## 商店页面边界

推荐表达：

- `本地看护你的多台手机`
- `不需要账号`
- `不上传位置`
- `设备离开时及时提醒`
- `适合商务出行、办公室、酒店和多设备用户`

避免表达：

- `找回丢失手机`
- `实时定位`
- `远程追踪`
- `防盗神器`
- `后台永不掉线`

## 隐私标签

首版预期：

- 不收集位置。
- 不收集联系人。
- 不收集用户身份。
- 不收集使用数据到服务器。
- 不用于广告追踪。

如果未来加入崩溃分析、日志上传、账号或云端备份，必须重新评估商店隐私标签。

## 发布前检查

| 项目 | 检查方式 | 状态 |
| --- | --- | --- |
| iOS 权限说明 | 检查 Info.plist | 待 App 工程创建后执行 |
| Android 权限声明 | 检查 AndroidManifest.xml | 待 App 工程创建后执行 |
| 无定位权限 | 检查双端 manifest | 待 App 工程创建后执行 |
| 无云端请求 | 抓包验证 | 待 App 工程创建后执行 |
| 前台服务可停止 | 真机操作 | 待 App 工程创建后执行 |
| 报警可停止 | 真机操作 | 待 App 工程创建后执行 |

