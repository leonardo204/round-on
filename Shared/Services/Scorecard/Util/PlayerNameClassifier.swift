// PlayerNameClassifier.swift
// 플레이어 이름 후보 식별 유틸

import Foundation

public enum PlayerNameClassifier {

    /// 토큰이 플레이어 이름 후보인지 판별.
    public static func isPlayerName(_ text: String) -> Bool {
        guard text.count >= 2 && text.count <= 8 else { return false }
        if Int(text) != nil { return false }
        let reserved = ["PAR", "Par", "파", "TOTAL", "합", "합계", "DATE", "TEE", "OFF",
                        "힐", "크리크", "동", "서", "남", "북"]
        return !reserved.contains(text)
    }
}
