import Foundation
import SwiftUI
import SwiftData
import PhotosUI
import CoreGraphics
import Observation
import UIKit
import Shared
import os.log

// MARK: - CGImageBox
// CGImage는 Apple 문서상 thread-safe하나 컴파일러 Sendable 보장 외 → @unchecked Sendable 박스로 래핑.
// strict concurrency(Swift 6) 경고 억제용.
private struct CGImageBox: @unchecked Sendable {
    let image: CGImage
}

private let logger = Logger(subsystem: "kr.zerolive.golf.roundon", category: "Import")

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

    /// 할당량 소진 팝업 표시 여부 (remaining == 0 시 true → ImportLandingView에서 AIAnalysisView 진입)
    public var showQuotaExhausted: Bool = false

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
    /// 할당량 소진 시 showQuotaExhausted = true로 AIAnalysisView 진입 유도.
    public func run(item: PhotosPickerItem, ownerName: String? = nil) async {
        logger.info("[Import] run 진입 — 동의 상태: \(ConsentManager.shared.isAccepted), canAnalyze: \(RewardedAdManager.shared.canAnalyze), remaining: \(RewardedAdManager.shared.remaining)")

        // 동의 미수락이면 팝업 표시 후 대기 (acceptConsentAndContinue가 Task를 생성)
        if !ConsentManager.shared.isAccepted {
            logger.info("[Import] 동의 미수락 → 동의 팝업 표시 후 대기")
            pendingItem = item
            pendingOwnerName = ownerName
            showConsentAlert = true
            return
        }
        // 할당량 소진 확인
        if !RewardedAdManager.shared.canAnalyze {
            logger.warning("[Import] 할당량 소진 → AIAnalysisView 유도 (remaining=\(RewardedAdManager.shared.remaining))")
            showQuotaExhausted = true
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
        // 동의 수락 후에도 할당량 재확인
        if !RewardedAdManager.shared.canAnalyze {
            logger.warning("[Import] 동의 수락 후 할당량 재확인 — 소진 (remaining=\(RewardedAdManager.shared.remaining))")
            showQuotaExhausted = true
            return
        }
        logger.info("[Import] 동의 수락 → OCR 재개")
        let task = Task {
            await performOCR(item: item, ownerName: ownerName)
        }
        ocrTask = task
    }

    /// 동의 거부 → Vision 폴백으로 실행
    public func rejectConsentAndFallback() {
        logger.info("[Import] 동의 거부 → Vision 폴백 실행")
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
        guard let draft else {
            logger.error("[Import] commit 호출 — draft가 nil, 저장 불가")
            return
        }
        logger.info("[Import] commit 시작 — makeRound 호출")
        do {
            _ = try ScorecardMapper.makeRound(from: draft, modelContext: modelContext)
            logger.info("[Import] commit 성공 — Round 저장 완료")
        } catch {
            logger.error("[Import] commit 실패: \(error.localizedDescription)")
            phase = .failed("저장에 실패했습니다: \(error.localizedDescription)")
            return
        }
        // 원본 이미지 참조 해제 (사진 미저장 정책)
        cgImageForOCR = nil
        sourceImage = nil
        self.draft = nil
        // completed 페이즈: ImportLandingView의 onChange가 fullScreenCover를 dismiss함
        logger.info("[Import] phase → .completed")
        phase = .completed
    }

    // MARK: Cancel

    public func cancel() {
        logger.info("[Import] cancel 호출 — OCR Task 취소")
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
        logger.info("[Import] phase → .running (Gemini 경로)")
        warnings = []
        draft = nil
        sourceImage = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                logger.error("[Import] 이미지 데이터 로드 실패 — loadTransferable nil")
                phase = .failed("이미지 데이터를 불러올 수 없습니다.")
                return
            }
            let imageSizeKB = data.count / 1024
            guard let uiImage = UIImage(data: data) else {
                logger.error("[Import] UIImage 변환 실패 — data size: \(imageSizeKB)KB")
                phase = .failed("이미지 변환에 실패했습니다.")
                return
            }
            let pixelSize = uiImage.size
            logger.info("[Import] 이미지 로드 완료 — \(Int(pixelSize.width))x\(Int(pixelSize.height))px, \(imageSizeKB)KB")
            sourceImage = uiImage

            // MIME 타입 추론 (PNG vs JPEG)
            let mime = detectMime(data: data)
            logger.info("[Import] MIME 추론: \(mime)")

            // Gemini 호출 시도
            do {
                let extractor = try GeminiScorecardExtractor.fromInfoPlist()
                logger.info("[Import] Gemini 호출 시작 — canAnalyze: \(RewardedAdManager.shared.canAnalyze), remaining: \(RewardedAdManager.shared.remaining)")
                let geminiCard = try await extractor.extract(imageData: data, mime: mime)
                logger.info("[Import] Gemini 응답 수신 — courseName: '\(geminiCard.courseName)', date: '\(geminiCard.date)', players: \(geminiCard.players.count)명")

                // 어댑터: GeminiScorecard → Scorecard
                let scorecard = GeminiScorecardAdapter.adapt(geminiCard, imageData: data)
                logger.info("[Import] adapt 완료 — warnings: \(scorecard.warnings.count)건")

                warnings = scorecard.warnings
                draft = try ScorecardMapper.makeDraft(from: scorecard, ownerName: ownerName)
                logger.info("[Import] makeDraft 완료 — sections: \(self.draft?.sections.count ?? 0), players: \(self.draft?.players.count ?? 0)")

                // Gemini 분석 성공 → 할당량 1 소비 (보상형 광고는 AIAnalysisView에서만 시청)
                RewardedAdManager.shared.consume()
                logger.info("[Import] 할당량 소비 완료 — remaining: \(RewardedAdManager.shared.remaining)")

                logger.info("[Import] phase → .review (Gemini 성공)")
                phase = .review
            } catch {
                // Gemini 실패 → Vision 폴백
                logger.warning("[Import] Gemini 실패: \(error.localizedDescription) → Vision 폴백 진입")
                let fallbackWarning = "AI 분석 실패(\(error.localizedDescription)). Vision으로 재시도합니다."
                await runVisionFallback(uiImage: uiImage, ownerName: ownerName, extraWarning: fallbackWarning)
            }

        } catch {
            logger.error("[Import] performOCR 예외: \(error.localizedDescription)")
            phase = .failed(error.localizedDescription)
        }
    }

    /// Vision on-device OCR만 실행 (동의 거부 경로)
    private func performOCRWithVision(item: PhotosPickerItem, ownerName: String?) async {
        phase = .running
        logger.info("[Import] phase → .running (Vision 직접 경로)")
        warnings = []
        draft = nil
        sourceImage = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                logger.error("[Import] Vision 경로 이미지 로드 실패")
                phase = .failed("이미지 데이터를 불러올 수 없습니다.")
                return
            }
            guard let uiImage = UIImage(data: data) else {
                logger.error("[Import] Vision 경로 UIImage 변환 실패")
                phase = .failed("이미지 변환에 실패했습니다.")
                return
            }
            guard let cgImage = uiImage.cgImage else {
                logger.error("[Import] Vision 경로 CGImage 변환 실패")
                phase = .failed("CGImage 변환에 실패했습니다.")
                return
            }
            let pixelSize = uiImage.size
            logger.info("[Import] Vision 경로 이미지 로드 — \(Int(pixelSize.width))x\(Int(pixelSize.height))px")
            sourceImage = uiImage
            cgImageForOCR = cgImage

            await runVisionFallback(uiImage: uiImage, ownerName: ownerName, extraWarning: nil)

        } catch {
            logger.error("[Import] performOCRWithVision 예외: \(error.localizedDescription)")
            phase = .failed(error.localizedDescription)
        }
    }

    /// Vision extractor를 Task.detached로 실행 (메인 스레드 차단 방지)
    private func runVisionFallback(uiImage: UIImage, ownerName: String?, extraWarning: String?) async {
        guard let cgImage = uiImage.cgImage ?? cgImageForOCR else {
            logger.error("[Import] Vision 폴백 — CGImage 획득 실패")
            phase = .failed("CGImage 변환에 실패했습니다.")
            return
        }
        logger.info("[Import] Vision 폴백 시작")
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
            logger.info("[Import] Vision 폴백 완료 — sections: \(self.draft?.sections.count ?? 0), players: \(self.draft?.players.count ?? 0), warnings: \(allWarnings.count)건")
            logger.info("[Import] phase → .review (Vision 폴백 성공)")
            phase = .review
        } catch {
            logger.error("[Import] Vision 폴백 실패: \(error.localizedDescription)")
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
