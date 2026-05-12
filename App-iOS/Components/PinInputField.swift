import SwiftUI

// MARK: - PinInputField
// 4자리 PIN 입력 박스 (C2, 11-COMPONENTS §8)
// 4개의 독립 박스 + .numberPad 키보드

public struct PinInputField: View {

    // MARK: Props

    @Binding public var pin: String
    public let isError: Bool

    // MARK: Init

    public init(pin: Binding<String>, isError: Bool = false) {
        self._pin = pin
        self.isError = isError
    }

    // MARK: Body

    public var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { idx in
                digitBox(index: idx)
            }
        }
        .overlay(
            // 숨겨진 TextField로 키보드 입력 받기
            TextField("", text: Binding(
                get: { pin },
                set: { newValue in
                    // 숫자만 허용, 4자리 제한
                    let filtered = newValue.filter { $0.isNumber }
                    pin = String(filtered.prefix(4))
                }
            ))
            .keyboardType(.numberPad)
            .opacity(0.01)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PIN 입력 4자리")
        .accessibilityValue(pin.isEmpty ? "비어있음" : "\(pin.count)자리 입력됨")
        .accessibilityHint("4자리 숫자를 입력해 주세요")
    }

    // MARK: Digit Box

    private func digitBox(index: Int) -> some View {
        let char: String = index < pin.count ? String(Array(pin)[index]) : ""
        let isFilled = index < pin.count
        let isActive = index == pin.count && pin.count < 4

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isError ? Color.red :
                    isActive ? Color.springGreenPrimary :
                    isFilled ? Color.springGreenSecondary :
                    Color.springBorder,
                    lineWidth: isActive ? 2 : 1
                )
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isFilled ? Color.springSurfaceElevated : Color.springSurface)
                )

            Text(char)
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.springTextPrimary)
        }
        .frame(width: 56, height: 64)
        .animation(.easeInOut(duration: 0.15), value: pin.count)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    @Previewable @State var pin = "12"
    VStack(spacing: 20) {
        PinInputField(pin: $pin, isError: false)
        PinInputField(pin: .constant("1234"), isError: false)
        PinInputField(pin: .constant("12"), isError: true)
    }
    .padding()
}
#endif
