import Foundation
import SwiftData

@Model
public final class Player {
    public var id: UUID
    public var name: String
    public var isOwner: Bool
    public var order: Int

    public init(id: UUID = UUID(), name: String, isOwner: Bool = false, order: Int = 0) {
        self.id = id
        self.name = name
        self.isOwner = isOwner
        self.order = order
    }
}
