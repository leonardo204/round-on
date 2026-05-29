import SwiftUI
import Shared

extension SeasonTheme {
    func heroGradient(dark: Bool) -> LinearGradient {
        let c: [Color]
        switch self {
        case .spring:
            c = dark
                ? [Color(red: 0.243, green: 0.478, blue: 0.180), Color(red: 0.353, green: 0.604, blue: 0.259)]
                : [Color(red: 0.435, green: 0.690, blue: 0.290), Color(red: 0.639, green: 0.847, blue: 0.420)]
        case .summer:
            c = dark
                ? [Color(red: 0.078, green: 0.388, blue: 0.227), Color(red: 0.122, green: 0.541, blue: 0.298)]
                : [Color(red: 0.122, green: 0.541, blue: 0.298), Color(red: 0.184, green: 0.702, blue: 0.420)]
        case .autumn:
            c = dark
                ? [Color(red: 0.659, green: 0.388, blue: 0.133), Color(red: 0.557, green: 0.165, blue: 0.102)]
                : [Color(red: 0.851, green: 0.557, blue: 0.184), Color(red: 0.722, green: 0.227, blue: 0.149)]
        case .winter:
            c = dark
                ? [Color(red: 0.118, green: 0.310, blue: 0.286), Color(red: 0.243, green: 0.502, blue: 0.467)]
                : [Color(red: 0.180, green: 0.431, blue: 0.400), Color(red: 0.525, green: 0.780, blue: 0.729)]
        }
        return LinearGradient(colors: c, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
