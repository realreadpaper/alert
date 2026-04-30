import SwiftUI

struct HomeDeviceRow: Identifiable, Equatable {
    let id: String
    let name: String
    let stateText: String
    let stateColor: Color
}

struct HomeView: View {
    let mode: GuardMode
    let deviceRows: [HomeDeviceRow]
    let isGuarding: Bool
    let onToggleGuarding: () -> Void
    let onAddDevice: () -> Void
    let onSelectMode: (GuardMode) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GuardSpacing.lg) {
                header
                statusCard
                modeSelector
                deviceList
                GuardPrimaryButton(
                    title: isGuarding ? "停止看护" : "开始看护",
                    action: onToggleGuarding
                )
            }
            .padding(GuardSpacing.xl)
        }
        .background(GuardColor.surface50.ignoresSafeArea())
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("PRIVATE GUARD")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(GuardColor.ink500)
                Text("看护组")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(GuardColor.ink900)
            }
            Spacer()
            Button(action: onAddDevice) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(GuardColor.ink900)
                    .frame(width: 38, height: 38)
                    .background(GuardColor.surface0)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(GuardColor.line200, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var statusCard: some View {
        GuardCard {
            HStack {
                Text("当前状态")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(GuardColor.ink500)
                Spacer()
                GuardStatusPill(title: isGuarding ? "安全" : "未开启", color: isGuarding ? GuardColor.safe : GuardColor.ink500)
            }
            Text("\(deviceRows.count)")
                .font(.system(size: 46, weight: .heavy))
                .foregroundStyle(GuardColor.ink900)
            Text(isGuarding ? "台设备正在本地看护" : "开启后，将在设备离开时提醒你")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(GuardColor.ink500)
        }
    }

    private var modeSelector: some View {
        HStack(spacing: GuardSpacing.sm) {
            modeButton(.outing, title: "外出")
            modeButton(.indoor, title: "室内")
            modeButton(.silent, title: "静音")
        }
    }

    private func modeButton(_ value: GuardMode, title: String) -> some View {
        Button {
            onSelectMode(value)
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(mode == value ? .white : GuardColor.ink700)
                .background(mode == value ? GuardColor.ink900 : GuardColor.surface0)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(mode == value ? GuardColor.ink900 : GuardColor.line200, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var deviceList: some View {
        VStack(spacing: GuardSpacing.sm) {
            ForEach(deviceRows) { row in
                HStack {
                    Text(row.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(GuardColor.ink900)
                    Spacer()
                    Text(row.stateText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(row.stateColor)
                }
                .padding(.horizontal, GuardSpacing.md)
                .frame(height: 56)
                .background(GuardColor.surface0)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(GuardColor.line100, lineWidth: 1))
            }
        }
    }
}
