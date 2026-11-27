import Foundation
import UIKit

@MainActor
enum DeviceIdentity {
    static var current: String {
        let key = "vibecodeGram.deviceID"
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let value = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(value, forKey: key)
        return value
    }
}
