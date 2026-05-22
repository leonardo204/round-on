import SwiftUI

// MARK: - InlineScoreStepper
// 셀 탭 시 플레이어 카드 하단에 inline으로 펼치는 스텝퍼.
// holeNumber: 1-based 홀 번호
// par: 해당 홀 par (player 모드에서 사용)
// relative: PAR 대비 상대값 (nil = 미인식) — player 모드 전용
// parValue: 현재 par 값 (nil = 미인식) — par 모드 전용
// isParMode: true = PAR 행 편집, false = 선수 행 편집
// onChanged: 값 변경 시 콜백

struct InlineScoreStepper: View {
    let holeNumber: Int
    let par: Int
    let relative: Int?
    var isParMode: Bool = false
    var parValue: Int? = nil
    let onChanged: (Int) -> Void

    // player 모드: PAR 대비 상대값, 기본 0
    private var currentPlayerValue: Int { relative ?? 0 }

    // par 모드: 현재 par 값, 기본 4 (가장 흔한 par)
    private var currentParValue: Int { parValue ?? 4 }

    private var absoluteStrokes: Int {
        par + currentPlayerValue
    }

    // par 모드: 범위 1~6
    private var canDecrement: Bool {
        isParMode ? currentParValue > 1 : true
    }
    private var canIncrement: Bool {
        isParMode ? currentParValue < 6 : true
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider().padding(.horizontal, 0)

            HStack(spacing: 10) {
                // 라벨
                if isParMode {
                    Text("\(holeNumber)번 홀 · PAR (코스 기준)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(holeNumber)번 홀 · PAR \(par)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // − 버튼
                Button {
                    if isParMode {
                        guard canDecrement else { return }
                        onChanged(currentParValue - 1)
                    } else {
                        onChanged(currentPlayerValue - 1)
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .background(canDecrement ? Color(.systemGray5) : Color(.systemGray5).opacity(0.4))
                        .foregroundStyle(canDecrement ? .primary : Color(.systemGray3))
                        .clipShape(Circle())
                }
                .disabled(!canDecrement)

                // 현재 값
                if isParMode {
                    Text(parDisplayText)
                        .font(.system(size: 26, weight: .bold))
                        .monospacedDigit()
                        .frame(minWidth: 52, alignment: .center)
                } else {
                    Text(relativeDisplayText)
                        .font(.system(size: 26, weight: .bold))
                        .monospacedDigit()
                        .frame(minWidth: 52, alignment: .center)
                }

                // + 버튼
                Button {
                    if isParMode {
                        guard canIncrement else { return }
                        onChanged(currentParValue + 1)
                    } else {
                        onChanged(currentPlayerValue + 1)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .background(canIncrement ? Color.accentColor : Color.accentColor.opacity(0.3))
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
                .disabled(!canIncrement)

                // hint
                if isParMode {
                    Text("+/- PAR 조정")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text("내부 \(absoluteStrokes)타")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private var relativeDisplayText: String {
        guard let relative else { return "?" }
        if relative >= 0 { return "+\(relative)" }
        return "\(relative)"
    }

    private var parDisplayText: String {
        guard let pv = parValue else { return "?" }
        return "\(pv)"
    }
}
