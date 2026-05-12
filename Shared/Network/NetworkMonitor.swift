import Foundation
import Network
import Observation

// MARK: - NetworkMonitor
// NWPathMonitor 래퍼 (23-OFFLINE §2)
// 오프라인 상태 감지 + BannerNotice 연동용
// @Observable로 SwiftUI 자동 구독

#if canImport(Network)

@Observable
@MainActor
public final class NetworkMonitor {

    // MARK: Shared

    public static let shared = NetworkMonitor()

    // MARK: State

    public private(set) var isConnected: Bool = true
    public private(set) var connectionType: ConnectionType = .unknown

    // MARK: Types

    public enum ConnectionType {
        case wifi
        case cellular
        case wiredEthernet
        case unknown
    }

    // MARK: Private

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "kr.zerolive.golf.roundon.networkmonitor", qos: .utility)

    // MARK: Init

    private init() {
        startMonitoring()
    }

    // MARK: Monitoring

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = path.status == .satisfied
                self?.connectionType = Self.connectionType(from: path)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    // MARK: Helpers

    private static func connectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wiredEthernet }
        return .unknown
    }
}

#endif
