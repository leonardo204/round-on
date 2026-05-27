import SwiftUI
import MapKit
import Shared

// MARK: - StatsMapDetailView
// F9 지역별 라운드 지도 상세 화면 — 인터랙티브 줌/팬/회전 가능

struct StatsMapDetailView: View {
    let locations: [RoundLocation]
    var unmatchedCount: Int = 0

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        ZStack {
            Map(position: $position) {
                ForEach(locations) { loc in
                    Annotation(loc.courseName, coordinate: CLLocationCoordinate2D(latitude: loc.lat, longitude: loc.lng)) {
                        ZStack {
                            Circle()
                                .fill(Color.scoreBirdie)
                                .frame(width: 28, height: 28)
                                .shadow(color: Color.scoreBirdie.opacity(0.3), radius: 3, x: 0, y: 1)
                            Image(systemName: "flag.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .ignoresSafeArea(edges: .bottom)

            // 데이터 없음 오버레이
            if locations.isEmpty {
                VStack {
                    Spacer()
                    Text("표시할 라운드 위치가 없어요")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.inkSoft)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Spacer()
                }
            }
        }
        .overlay(alignment: .top) {
            if unmatchedCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.scoreBogey)
                    Text("위치 정보가 없는 라운드 \(unmatchedCount)곳은 표시되지 않아요")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.inkPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.top, 12)
            }
        }
        .navigationTitle("라운드 지도")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            applyRegion()
        }
    }

    // MARK: - Region 계산

    private func applyRegion() {
        if locations.isEmpty {
            position = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.5, longitude: 127.8),
                span: MKCoordinateSpan(latitudeDelta: 6.0, longitudeDelta: 5.0)
            ))
            return
        }
        let lats = locations.map(\.lat)
        let lngs = locations.map(\.lng)
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLng = lngs.min()!
        let maxLng = lngs.max()!
        let centerLat = (minLat + maxLat) / 2
        let centerLng = (minLng + maxLng) / 2
        let latDelta = max((maxLat - minLat) * 1.5, 1.0)
        let lngDelta = max((maxLng - minLng) * 1.5, 1.0)
        position = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)
        ))
    }
}
