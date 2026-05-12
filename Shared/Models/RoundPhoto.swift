import Foundation
import SwiftData

@Model
public final class RoundPhoto {
    public var id: UUID
    public var localPath: String
    public var remoteURL: String?
    public var capturedAt: Date
    public var holeNumber: Int?
    public var caption: String?

    public init(id: UUID = UUID(), localPath: String, remoteURL: String? = nil,
                capturedAt: Date = .now, holeNumber: Int? = nil, caption: String? = nil) {
        self.id = id
        self.localPath = localPath
        self.remoteURL = remoteURL
        self.capturedAt = capturedAt
        self.holeNumber = holeNumber
        self.caption = caption
    }
}
