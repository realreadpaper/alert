import CoreImage
import Foundation

enum GuardQRCode {
    static func makeCIImage(from payload: String) -> CIImage? {
        guard let data = payload.data(using: .utf8), !data.isEmpty else { return nil }
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setValue(data, forKey: "inputMessage")
        filter?.setValue("M", forKey: "inputCorrectionLevel")
        return filter?.outputImage
    }
}
