import Foundation

public enum NameVisibility: String, Codable, Sendable {
    case real
    case anonymous
}

public enum AccessControl: Codable, Sendable, Equatable {
    case `public`
    case pin(String)  // bcrypt 해시는 서버측 처리, 클라에서는 평문 PIN 전송 (33-SECURITY §4)
}

public struct ShareOptions: Codable, Sendable, Equatable {
    public var nameVisibility: NameVisibility
    public var accessControl: AccessControl
    public init(nameVisibility: NameVisibility = .real, accessControl: AccessControl = .public) {
        self.nameVisibility = nameVisibility
        self.accessControl = accessControl
    }
}
