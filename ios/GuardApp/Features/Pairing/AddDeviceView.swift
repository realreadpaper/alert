import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct AddDeviceView: View {
    let inviteCode: String
    let expiresInText: String
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GuardSpacing.lg) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ADD DEVICE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(GuardColor.ink500)
                Text("添加设备")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(GuardColor.ink900)
            }

            GuardCard {
                Text("邀请二维码")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(GuardColor.ink700)
                GuardQRCodeView(payload: inviteCode)
                .aspectRatio(1, contentMode: .fit)
                Text(expiresInText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(GuardColor.ink500)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Text("新手机打开 App 后选择“加入看护组”，扫描此二维码。原设备确认后才会加入。")
                .font(.system(size: 15, weight: .medium))
                .lineSpacing(4)
                .foregroundStyle(GuardColor.ink500)
                .padding(GuardSpacing.md)
                .background(GuardColor.surface100)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(inviteCode)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(GuardColor.ink500)
                .lineLimit(2)

            Spacer()
            GuardSecondaryButton(title: "取消邀请", action: onCancel)
        }
        .padding(GuardSpacing.xl)
        .background(GuardColor.surface50.ignoresSafeArea())
    }
}

private struct GuardQRCodeView: View {
    let payload: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(GuardColor.surface0)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(GuardColor.line200, lineWidth: 1)

            if let image = qrImage {
                image
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(GuardSpacing.lg)
            } else {
                Text("无法生成二维码")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(GuardColor.danger)
            }
        }
    }

    private var qrImage: Image? {
        guard let ciImage = GuardQRCode.makeCIImage(from: payload) else { return nil }

        #if canImport(UIKit)
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return Image(uiImage: UIImage(cgImage: cgImage))
        #else
        return nil
        #endif
    }
}
