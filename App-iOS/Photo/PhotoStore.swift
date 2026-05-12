import Foundation
import UIKit
import SwiftData
import Shared

// MARK: - PhotoStore
// 사진 로컬 저장 + RoundPhoto 생성 (C3)
// Documents/photos/{photoId}.jpg 에 저장
// 10MB 압축 자동 적용

@MainActor
public final class PhotoStore {

    // MARK: Constants

    /// 최대 파일 크기 10MB (30-API §5.1)
    public static let maxFileSizeBytes = 10 * 1024 * 1024

    /// viewer당 최대 사진 수 (30-API §5.1)
    public static let maxPhotoCount = 30

    // MARK: Directories

    private var photosDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("photos", isDirectory: true)
    }

    // MARK: Init

    public init() {
        createDirectoryIfNeeded()
    }

    // MARK: Save Photo

    /// UIImage → Documents/photos/{id}.jpg 저장 + RoundPhoto 생성
    public func savePhoto(
        _ image: UIImage,
        holeNumber: Int? = nil,
        caption: String? = nil
    ) throws -> RoundPhoto {
        let photoId = UUID()
        let filename = photoId.uuidString + ".jpg"
        let fileURL = photosDirectory.appendingPathComponent(filename)

        let jpegData = compressedJPEG(from: image)
        try jpegData.write(to: fileURL)

        let photo = RoundPhoto(
            id: photoId,
            localPath: fileURL.path,
            remoteURL: nil,
            capturedAt: .now,
            holeNumber: holeNumber,
            caption: caption
        )
        return photo
    }

    /// 저장된 사진 UIImage 로드
    public func loadImage(for photo: RoundPhoto) -> UIImage? {
        UIImage(contentsOfFile: photo.localPath)
    }

    /// 로컬 사진 파일 삭제
    public func deletePhoto(_ photo: RoundPhoto) {
        try? FileManager.default.removeItem(atPath: photo.localPath)
    }

    /// JPEG 데이터 로드 (업로드용)
    public func jpegData(for photo: RoundPhoto) -> Data? {
        guard let image = loadImage(for: photo) else { return nil }
        return compressedJPEG(from: image)
    }

    // MARK: Compression

    /// 10MB 이하로 품질 단계적 압축
    private func compressedJPEG(from image: UIImage) -> Data {
        let qualities: [CGFloat] = [0.9, 0.7, 0.5, 0.3]

        for quality in qualities {
            if let data = image.jpegData(compressionQuality: quality),
               data.count <= Self.maxFileSizeBytes {
                return data
            }
        }

        // 최소 품질로 강제 반환
        return image.jpegData(compressionQuality: 0.1) ?? Data()
    }

    // MARK: Private

    private func createDirectoryIfNeeded() {
        let url = photosDirectory
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
