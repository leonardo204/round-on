import SwiftUI
import PhotosUI
import SwiftData
import Shared

// MARK: - ImportLandingView
// 스코어보드 가져오기 진입 화면.
// 1단계: PhotosPicker로 이미지 선택
// 2단계: OCR 진행 중 표시 (ProgressView)
// 완료 시 ImportReviewView push

struct ImportLandingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = ImportViewModel()
    @State private var pickerItem: PhotosPickerItem?
    @State private var showReview = false
    @State private var showAIAnalysis = false

    // 본인 이름 (OCR 결과에서 owner 행 자동 매칭용)
    @AppStorage("ownerName") private var ownerName: String = ""

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("스코어보드 가져오기")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") {
                            viewModel.cancel()
                            dismiss()
                        }
                    }
                }
                .navigationDestination(isPresented: $showReview) {
                    if let draft = viewModel.draft, let image = viewModel.sourceImage {
                        ImportReviewView(
                            viewModel: viewModel,
                            draft: draft,
                            sourceImage: image
                        )
                    }
                }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await viewModel.run(
                    item: newItem,
                    ownerName: ownerName.isEmpty ? nil : ownerName
                )
            }
        }
        .alert(
            "스코어카드 분석 데이터 전송 안내",
            isPresented: $viewModel.showConsentAlert
        ) {
            Button("동의하고 분석") {
                viewModel.acceptConsentAndContinue()
            }
            Button("취소", role: .cancel) {
                viewModel.rejectConsentAndFallback()
            }
        } message: {
            Text("스코어카드 자동 인식을 위해 선택하신 사진이 외부 AI 서버(Google)로 전송됩니다. 사진에 적힌 동반자 이름 등도 함께 전송될 수 있습니다. 전송된 사진은 분석에만 사용되며 별도 저장되지 않습니다.")
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            switch newPhase {
            case .review:
                showReview = true
            case .completed:
                // 저장 완료 — fullScreenCover(SettingsView) 전체 dismiss
                dismiss()
            default:
                break
            }
        }
        .onChange(of: viewModel.showQuotaExhausted) { _, exhausted in
            if exhausted {
                showAIAnalysis = true
                viewModel.showQuotaExhausted = false
            }
        }
        .sheet(isPresented: $showAIAnalysis) {
            AIAnalysisView()
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle:
            idleView
        case .running:
            runningView
        case .review:
            // NavigationDestination이 처리하므로 빈 뷰
            Color.clear
        case .failed(let message):
            failedView(message: message)
        case .completed:
            // dismiss()가 호출되어 뷰가 사라지는 전환 중 — 빈 뷰
            Color.clear
        }
    }

    // MARK: Idle — 사진 선택 유도

    private var idleView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.accentColor)

                Text("스코어카드 사진을 선택하세요")
                    .font(.system(size: 20, weight: .semibold))

                Text("스마트스코어 앱의 스코어카드를\n캡처한 사진을 가져옵니다.\n원본 이미지는 저장되지 않습니다.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            PhotosPicker(
                selection: $pickerItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("사진 보관함에서 선택", systemImage: "photo.on.rectangle")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: Running — OCR 진행 중

    private var runningView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 90, height: 90)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 8) {
                Text("AI가 스코어카드를 분석하고 있어요")
                    .font(.system(size: 17, weight: .semibold))

                Text("점수·코스·날짜를 정밀하게 읽는 중이에요.\n최대 20초쯤 걸릴 수 있어요. 잠시만요!")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            ProgressView()
                .controlSize(.large)
                .padding(.top, 8)

            Button("취소") {
                viewModel.cancel()
            }
            .foregroundStyle(.secondary)
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: Failed

    private func failedView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 56))
                .foregroundStyle(.red)

            VStack(spacing: 8) {
                Text("인식에 실패했습니다")
                    .font(.system(size: 18, weight: .semibold))
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            PhotosPicker(
                selection: $pickerItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Text("다시 선택")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}
