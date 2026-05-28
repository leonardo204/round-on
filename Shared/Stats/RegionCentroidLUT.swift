import Foundation

/// 17개 광역시도 centroid 좌표. 정부 행안부 공개 청사 좌표 기반 hardcode.
/// 클럽하우스 좌표 노출 차단 가드: 통계 viewer 지도는 이 LUT만 사용.
public enum RegionCentroidLUT {
    private static let table: [String: (lat: Double, lng: Double)] = [
        "경기": (37.275, 127.0096),
        "강원": (37.8228, 128.1555),
        "충북": (36.6357, 127.4912),
        "충남": (36.6589, 126.6730),
        "전북": (35.8242, 127.1480),
        "전남": (34.8194, 126.8932),
        "경북": (36.5760, 128.5057),
        "경남": (35.4606, 128.2132),
        "제주": (33.4996, 126.5312),
        "서울": (37.5665, 126.9780),
        "부산": (35.1796, 129.0756),
        "대구": (35.8714, 128.6014),
        "인천": (37.4563, 126.7052),
        "광주": (35.1595, 126.8526),
        "대전": (36.3504, 127.3845),
        "울산": (35.5384, 129.3114),
        "세종": (36.4800, 127.2890),
    ]

    /// regionKey (예: "경기") → centroid 좌표. 미정의 시 nil.
    public static func centroid(for regionKey: String) -> (lat: Double, lng: Double)? {
        table[regionKey]
    }

    /// 모든 키 (테스트용)
    public static var allKeys: [String] { Array(table.keys) }
}
