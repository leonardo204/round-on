import Foundation
import SwiftUI
import SwiftData
import PhotosUI
import CoreGraphics
import Observation
import UIKit
import Shared

// MARK: - CGImageBox
// CGImage는 Apple 문서상 thread-safe하나 컴파일러 Sendable 보장 외 → @unchecked Sendable 박스로 래핑.
// strict concurrency(Swift 6) 경고 억제용.
private struct CGImageBox: @unchecked Sendable {
    let image: CGImage
}

// MARK: - ImportViewModel
// OCR 가져오기 흐름의 상태 관리. Task 1: 사진 선택 → OCR → 드래프트 생성.
// Task 2: 사용자 편집 후 commit → Round 저장.

@Observable
@MainActor
public final class ImportViewModel {

    // MARK: State

    public enum Phase: Equatable {
        case idle
        case running
        case review
        case completed   // 저장 완료 → fullScreenCover dismiss 트리거
        case failed(String)
    }

    public var phase: Phase = .idle
    public var draft: ScorecardImportDraft?
    public var sourceImage: UIImage?

    /// OCR 경고 메시지 (null/suspect 셀 등)
    public var warnings: [String] = []

    // MARK: Private

    private var cgImageForOCR: CGImage?

    // MARK: Init

    public init() {}

    // MARK: Run OCR

    /// PhotosPickerItem에서 이미지 로드 → OCR 실행 → 드래프트 생성
    public func run(item: PhotosPickerItem, ownerName: String? = nil) async {
        phase = .running
        warnings = []
        draft = nil
        sourceImage = nil

        do {
            // PhotosPickerItem → Data → UIImage
            guard let data = try await item.loadTransferable(type: Data.self) else {
                phase = .failed("이미지 데이터를 불러올 수 없습니다.")
                return
            }
            guard let uiImage = UIImage(data: data) else {
                phase = .failed("이미지 변환에 실패했습니다.")
                return
            }
            guard let cgImage = uiImage.cgImage else {
                phase = .failed("CGImage 변환에 실패했습니다.")
                return
            }

            sourceImage = uiImage
            cgImageForOCR = cgImage

            // OCR은 백그라운드에서 실행 (메인 스레드 차단 방지)
            // CGImageBox: CGImage는 thread-safe하나 strict concurrency용 @unchecked Sendable 박스로 전달
            let box = CGImageBox(image: cgImage)
            let scorecard = try await Task.detached(priority: .userInitiated) {
                try GolfScorecardExtractor().extract(from: box.image)
            }.value

            // 경고 수집
            warnings = scorecard.warnings

            // 드래프트 생성
            draft = try ScorecardMapper.makeDraft(from: scorecard, ownerName: ownerName)
            phase = .review

        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: Commit → Round

    /// 드래프트를 SwiftData Round로 저장하고 상태를 초기화
    public func commit(modelContext: ModelContext) {
        guard let draft else { return }
        do {
            _ = try ScorecardMapper.makeRound(from: draft, modelContext: modelContext)
        } catch {
            phase = .failed("저장에 실패했습니다: \(error.localizedDescription)")
            return
        }
        // 원본 이미지 참조 해제 (사진 미저장 정책)
        cgImageForOCR = nil
        sourceImage = nil
        self.draft = nil
        // completed 페이즈: ImportLandingView의 onChange가 fullScreenCover를 dismiss함
        phase = .completed
    }

    // MARK: Cancel

    public func cancel() {
        cgImageForOCR = nil
        sourceImage = nil
        draft = nil
        phase = .idle
    }
}
