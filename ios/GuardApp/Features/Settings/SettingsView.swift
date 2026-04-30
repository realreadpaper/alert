import SwiftUI

struct SettingsView: View {
    let rows: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GuardSpacing.lg) {
                Text("设置")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(GuardColor.ink900)

                GuardCard {
                    ForEach(rows, id: \.self) { row in
                        HStack {
                            Text(row)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(GuardColor.ink900)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(GuardColor.ink500)
                        }
                        .frame(height: 44)
                    }
                }
            }
            .padding(GuardSpacing.xl)
        }
        .background(GuardColor.surface50.ignoresSafeArea())
    }
}
