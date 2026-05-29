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
//
// Gemini Vision 우선 흐름:
//   동의 수락 → GeminiScorecardExtractor → GeminiScorecardAdapter → Scorecard → ScorecardMapper
//   동의 거부 / Gemini 실패 → GolfScorecardExtractor (Vision on-device 폴백)

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

    /// Gemini 동의 팝업 표시 여부 (동의 미확인 상태에서 import 시도 시 true)
    public var showConsentAlert: Bool = false

    // MARK: Private

    private var cgImageForOCR: CGImage?
    private var pendingItem: PhotosPickerItem?
    private var pendingOwnerName: String?
    /// 진행 중인 OCR Task 핸들 — cancel() 시 실제 Task 취소에 사용
    private var ocrTask: Task<Void, Never>?

    // MARK: Init

    public init() {}

    // MARK: Run OCR

    /// PhotosPickerItem에서 이미지 로드 → OCR 실행 → 드래프트 생성
    /// 동의 미수락 시 동의 팝업 요청 후 대기.
    public func run(item: PhotosPickerItem, ownerName: String? = nil) async {
        // 동의 미수락이면 팝업 표시 후 대기 (acceptConsentAndContinue가 Task를 생성)
        if !ConsentManager.shared.isAccepted {
            pendingItem = item
            pendingOwnerName = ownerName
            showConsentAlert = true
            return
        }
        // 이전 Task가 있으면 취소
        ocrTask?.cancel()
        let task = Task {
            await performOCR(item: item, ownerName: ownerName)
        }
        ocrTask = task
        await task.value
    }

    /// 동의 수락 후 보류 중인 import 재개
    public func acceptConsentAndContinue() {
        ConsentManager.shared.accept()
        showConsentAlert = false
        guard let item = pendingItem else { return }
        let ownerName = pendingOwnerName
        pendingItem = nil
        pendingOwnerName = nil
        let task = Task {
            await performOCR(item: item, ownerName: ownerName)
        }
        ocrTask = task
    }

    /// 동의 거부 → Vision 폴백으로 실행
    public func rejectConsentAndFallback() {
        showConsentAlert = false
        guard let item = pendingItem else { return }
        let ownerName = pendingOwnerName
        pendingItem = nil
        pendingOwnerName = nil
        let task = Task {
            await performOCRWithVision(item: item, ownerName: ownerName)
        }
        ocrTask = task
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
        // 진행 중인 OCR Task를 실제로 취소 (시각적 취소만이 아닌 작업 중단)
        ocrTask?.cancel()
        ocrTask = nil
        cgImageForOCR = nil
        sourceImage = nil
        draft = nil
        pendingItem = nil
        pendingOwnerName = nil
        phase = .idle
    }

    // MARK: - Private OCR 실행

    /// Gemini Vision 우선 → 실패 시 Vision 폴백
    private func performOCR(item: PhotosPickerItem, ownerName: String?) async {
        phase = .running
        warnings = []
        draft = nil
        sourceImage = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                phase = .failed("이미지 데이터를 불러올 수 없습니다.")
                return
            }
            guard let uiImage = UIImage(data: data) else {
                phase = .failed("이미지 변환에 실패했습니다.")
                return
            }
            sourceImage = uiImage

            // MIME 타입 추론 (PNG vs JPEG)
            let mime = detectMime(data: data)

            // Gemini 호출 시도
            do {
                let extractor = try GeminiScorecardExtractor.fromInfoPlist()
                let geminiCard = try await extractor.extract(imageData: data, mime: mime)

                // 어댑터: GeminiScorecard → Scorecard
                let scorecard = GeminiScorecardAdapter.adapt(geminiCard, imageData: data)

                warnings = scorecard.warnings
                draft = try ScorecardMapper.makeDraft(from: scorecard, ownerName: ownerName)
                phase = .review
            } catch {
                // Gemini 실패 → Vision 폴백
                let fallbackWarning = "AI 분석 실패(\(error.localizedDescription)). Vision으로 재시도합니다."
                await runVisionFallback(uiImage: uiImage, ownerName: ownerName, extraWarning: fallbackWarning)
            }

        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Vision on-device OCR만 실행 (동의 거부 경로)
    private func performOCRWithVision(item: PhotosPickerItem, ownerName: String?) async {
        phase = .running
        warnings = []
        draft = nil
        sourceImage = nil

        do {
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

            await runVisionFallback(uiImage: uiImage, ownerName: ownerName, extraWarning: nil)

        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Vision extractor를 Task.detached로 실행 (메인 스레드 차단 방지)
    private func runVisionFallback(uiImage: UIImage, ownerName: String?, extraWarning: String?) async {
        guard let cgImage = uiImage.cgImage ?? cgImageForOCR else {
            phase = .failed("CGImage 변환에 실패했습니다.")
            return
        }
        let box = CGImageBox(image: cgImage)
        do {
            let scorecard = try await Task.detached(priority: .userInitiated) {
                try GolfScorecardExtractor().extract(from: box.image)
            }.value

            var allWarnings = scorecard.warnings
            if let extra = extraWarning {
                allWarnings.insert(extra, at: 0)
            }
            warnings = allWarnings
            draft = try ScorecardMapper.makeDraft(from: scorecard, ownerName: ownerName)
            phase = .review
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: - MIME 타입 추론

    private func detectMime(data: Data) -> String {
        // PNG 시그니처: 0x89 0x50 0x4E 0x47
        if data.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]) {
            return "image/png"
        }
        return "image/jpeg"
    }
}
