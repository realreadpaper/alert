import SwiftUI

struct AlarmView: View {
    let deviceName: String
    let elapsedText: String
    let isStrongAlarm: Bool
    let onPause: () -> Void
    let onAcknowledge: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GuardSpacing.lg) {
            VStack(alignment: .leading, spacing: 8) {
                Text(isStrongAlarm ? "ALARM" : "ATTENTION")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(GuardColor.danger)
                Text(isStrongAlarm ? "设备已离开看护范围" : "设备可能离开")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(GuardColor.ink900)
            }

            GuardCard {
                Text("失联设备")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(GuardColor.ink500)
                Text(deviceName)
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(GuardColor.ink900)
                Text(isStrongAlarm ? "\(elapsedText)。正在响铃提醒。" : "\(elapsedText)。若仍未恢复连接，将启动响铃提醒。")
                    .font(.system(size: 16, weight: .medium))
                    .lineSpacing(4)
                    .foregroundStyle(GuardColor.ink700)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(GuardColor.danger.opacity(0.35), lineWidth: 1)
            )

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(GuardColor.danger.opacity(0.12))
                    Capsule().fill(GuardColor.danger).frame(width: proxy.size.width * (isStrongAlarm ? 1 : 0.68))
                }
            }
            .frame(height: 8)

            Spacer()

            HStack(spacing: GuardSpacing.sm) {
                GuardSecondaryButton(title: "暂停 10 分钟", action: onPause)
                GuardPrimaryButton(title: "我知道了", action: onAcknowledge)
            }
        }
        .padding(GuardSpacing.xl)
        .background(GuardColor.surface50.ignoresSafeArea())
    }
}
