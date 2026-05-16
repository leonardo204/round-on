import SwiftUI
import PhotosUI
import Shared

// MARK: - PhotoAttachView
// iphone-2.5: PHPicker + 30장 제한 (12-SCREENS 2.5)

struct PhotoAttachView: View {

    // MARK: Props

    @Environment(\.modelContext) private var modelContext
    let round: Round
    let onDismiss: () -> Void

    // MARK: State

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let photoStore = PhotoStore()
    private let maxCount = PhotoStore.maxPhotoCount

    var body: some View {
        NavigationStack {
            ZStack {
                Color.springSurface.ignoresSafeArea()

                VStack(spacing: 16) {
                    // 현재 사진 수 / 최대
                    Text("\(round.photoList.count) / \(maxCount)장")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.springTextSecondary)
                        .padding(.top, 8)

                    // 에러 배너
                    if let error = errorMessage {
                        BannerNotice(message: error, severity: .error, dismissAction: {
                            errorMessage = nil
                        })
                    }

                    // 사진 갤러리
                    if round.photoList.isEmpty {
                        emptyState
                    } else {
                        PhotoGalleryGrid(
                            photos: round.photoList,
                            isEditable: true,
                            onDelete: { photo in
                                deletePhoto(photo)
                            }
                        )
                        .padding(.horizontal, 16)
                    }

                    Spacer()

                    // 사진 추가 버튼
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: maxCount - round.photoList.count,
                        matching: .images
                    ) {
                        Label("사진 선택", systemImage: "photo.on.rectangle.angled")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.springTextPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(round.photoList.count >= maxCount
                                ? Color.springBorder
                                : Color.springGreenPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 16)
                    }
                    .disabled(round.photoList.count >= maxCount || isLoading)
                    .padding(.bottom, 32)
                }

                if isLoading {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView("사진 저장 중...")
                        .tint(Color.springGreenPrimary)
                }
            }
            .navigationTitle("사진 첨부")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { onDismiss() }
                        .foregroundStyle(Color.springGreenPrimary)
                }
            }
            .onChange(of: selectedItems) { _, items in
                Task { await loadSelectedPhotos(items) }
            }
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(Color.springGreenPrimary.opacity(0.5))
            Text("사진을 추가하면\n공유 viewer에 포함돼요")
                .font(.system(size: 15))
                .foregroundStyle(Color.springTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    // MARK: Load Selected Photos

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        for item in items {
            guard round.photoList.count < maxCount else {
                errorMessage = "사진은 최대 \(maxCount)장까지 첨부할 수 있어요."
                break
            }

            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data) else { continue }

                let photo = try photoStore.savePhoto(uiImage)
                round.photos = round.photoList + [photo]
                Task { await HapticEngine.shared.play(.photoAttach) }
            } catch {
                errorMessage = "사진 저장 중 오류가 발생했어요."
            }
        }

        try? modelContext.save()
        selectedItems = []
    }

    // MARK: Delete Photo

    private func deletePhoto(_ photo: RoundPhoto) {
        photoStore.deletePhoto(photo)
        round.photos = round.photoList.filter { $0.id != photo.id }
        try? modelContext.save()
    }
}
