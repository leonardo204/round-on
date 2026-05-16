import Foundation
import SwiftData

@Model
public final class RoundPhoto {
    // MARK: - CloudKit 호환 속성 (모두 default 값 제공)
    public var id: UUID = UUID()
    public var localPath: String = ""
    public var remoteURL: String?
    public var capturedAt: Date = Date.now
    public var holeNumber: Int?
    public var caption: String?

    // MARK: - CloudKit 호환 inverse 관계
    public var round: Round?

    public init(id: UUID = UUID(), localPath: String = "", remoteURL: String? = nil,
                capturedAt: Date = .now, holeNumber: Int? = nil, caption: String? = nil) {
        self.id = id
        self.localPath = localPath
        self.remoteURL = remoteURL
        self.capturedAt = capturedAt
        self.holeNumber = holeNumber
        self.caption = caption
    }
}
