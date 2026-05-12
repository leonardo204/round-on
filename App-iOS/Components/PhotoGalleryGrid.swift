import SwiftUI
import Shared

// MARK: - PhotoGalleryGrid
// 사진 갤러리 3열 그리드 (11-COMPONENTS §8, 12-SCREENS iphone-2.5)

public struct PhotoGalleryGrid: View {

    // MARK: Props

    public let photos: [RoundPhoto]
    public let isEditable: Bool
    public let onDelete: ((RoundPhoto) -> Void)?
    public let onTap: ((RoundPhoto) -> Void)?

    // MARK: Init

    public init(
        photos: [RoundPhoto],
        isEditable: Bool = false,
        onDelete: ((RoundPhoto) -> Void)? = nil,
        onTap: ((RoundPhoto) -> Void)? = nil
    ) {
        self.photos = photos
        self.isEditable = isEditable
        self.onDelete = onDelete
        self.onTap = onTap
    }

    // MARK: Grid Layout

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    // MARK: Body

    public var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(photos) { photo in
                photoCell(photo: photo)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("사진 갤러리 \(photos.count)장")
    }

    // MARK: Photo Cell

    private func photoCell(photo: RoundPhoto) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                // 사진 이미지
                if let image = PhotoStore().loadImage(for: photo) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                } else {
                    Color.springBorder
                        .frame(width: geo.size.width, height: geo.size.width)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(Color.springTextSecondary)
                        )
                }

                // 삭제 버튼 (editable 모드)
                if isEditable, let onDelete = onDelete {
                    Button {
                        onDelete(photo)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                            .background(Color.black.opacity(0.5), in: Circle())
                    }
                    .padding(4)
                    .accessibilityLabel("사진 삭제")
                }

                // 홀 번호 배지
                if let holeNum = photo.holeNumber {
                    VStack {
                        Spacer()
                        HStack {
                            Text("\(holeNum)H")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Capsule())
                                .padding(4)
                            Spacer()
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.width)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?(photo)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(photo.caption ?? (photo.holeNumber.map { "\($0)번 홀 사진" } ?? "사진"))
        .accessibilityAddTraits(.isImage)
    }
}
