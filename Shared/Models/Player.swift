import Foundation
import SwiftData

@Model
public final class Player {
    // MARK: - CloudKit 호환 속성 (모두 default 값 제공)
    public var id: UUID = UUID()
    public var name: String = ""
    public var isOwner: Bool = false
    public var order: Int = 0

    // MARK: - CloudKit 호환 inverse 관계
    public var round: Round?

    public init(id: UUID = UUID(), name: String = "", isOwner: Bool = false, order: Int = 0) {
        self.id = id
        self.name = name
        self.isOwner = isOwner
        self.order = order
    }
}
