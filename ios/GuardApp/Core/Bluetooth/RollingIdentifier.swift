import CryptoKit
import Foundation

struct RollingIdentifier: Equatable {
    let value: String
    let timeBucket: Int64
}

final class RollingIdentifierGenerator {
    private let bucketSeconds: Int64
    private let outputBytes: Int

    init(bucketSeconds: Int64 = 300, outputBytes: Int = 12) {
        precondition(bucketSeconds > 0)
        precondition(outputBytes > 0 && outputBytes <= 32)
        self.bucketSeconds = bucketSeconds
        self.outputBytes = outputBytes
    }

    func generate(groupSecret: Data, deviceId: String, date: Date) -> RollingIdentifier {
        let bucket = Int64(date.timeIntervalSince1970) / bucketSeconds
        let message = "\(deviceId):\(bucket)"
        let key = SymmetricKey(data: groupSecret)
        let signature = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
        let value = Data(signature).prefix(outputBytes).map { String(format: "%02x", $0) }.joined()
        return RollingIdentifier(value: value, timeBucket: bucket)
    }

    func candidates(groupSecret: Data, deviceIds: [String], date: Date, bucketDrift: Int64 = 1) -> [String: String] {
        var result: [String: String] = [:]
        let currentBucket = Int64(date.timeIntervalSince1970) / bucketSeconds
        for deviceId in deviceIds {
            for bucket in (currentBucket - bucketDrift)...(currentBucket + bucketDrift) {
                let message = "\(deviceId):\(bucket)"
                let key = SymmetricKey(data: groupSecret)
                let signature = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
                let value = Data(signature).prefix(outputBytes).map { String(format: "%02x", $0) }.joined()
                result[value] = deviceId
            }
        }
        return result
    }
}
