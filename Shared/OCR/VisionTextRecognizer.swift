import CoreGraphics
import Foundation
import Vision

public struct OCRConfiguration: Sendable {
    public enum RecognitionLevel: Sendable {
        case accurate
        case fast
    }

    public var languages: [String]
    public var usesLanguageCorrection: Bool
    public var minimumTextHeight: Float
    public var recognitionLevel: RecognitionLevel

    public init(
        languages: [String],
        usesLanguageCorrection: Bool = false,
        minimumTextHeight: Float = 0,
        recognitionLevel: RecognitionLevel = .accurate
    ) {
        self.languages = languages
        self.usesLanguageCorrection = usesLanguageCorrection
        self.minimumTextHeight = minimumTextHeight
        self.recognitionLevel = recognitionLevel
    }
}

public struct RecognizedToken {
    var text: String
    var confidence: Float
    var rect: CGRect

    var midX: CGFloat { rect.midX }
    var midY: CGFloat { rect.midY }
}

public protocol TextRecognizing {
    func recognizeText(in image: CGImage, configuration: OCRConfiguration) throws -> [RecognizedToken]
}

public final class VisionTextRecognizer: TextRecognizing {
    public init() {}

    public func recognizeText(in image: CGImage, configuration: OCRConfiguration) throws -> [RecognizedToken] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = configuration.recognitionLevel == .accurate ? .accurate : .fast
        request.recognitionLanguages = configuration.languages
        request.usesLanguageCorrection = configuration.usesLanguageCorrection
        request.minimumTextHeight = configuration.minimumTextHeight
        request.automaticallyDetectsLanguage = false

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        let width = CGFloat(image.width)
        let height = CGFloat(image.height)

        return (request.results ?? []).flatMap { observation -> [RecognizedToken] in
            guard let candidate = observation.topCandidates(1).first else {
                return []
            }

            let words = splitObservation(candidate, width: width, height: height)
            if !words.isEmpty {
                return words
            }

            return [
                RecognizedToken(
                    text: candidate.string.trimmingCharacters(in: .whitespacesAndNewlines),
                    confidence: candidate.confidence,
                    rect: imageRect(from: observation.boundingBox, width: width, height: height)
                )
            ]
        }
    }

    private func splitObservation(_ candidate: VNRecognizedText, width: CGFloat, height: CGFloat) -> [RecognizedToken] {
        let raw = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = raw.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count > 1 else {
            return []
        }

        var tokens: [RecognizedToken] = []
        var searchStart = raw.startIndex

        for part in parts {
            guard
                let range = raw.range(of: part, range: searchStart..<raw.endIndex),
                let box = try? candidate.boundingBox(for: range)
            else {
                return []
            }

            tokens.append(
                RecognizedToken(
                    text: part,
                    confidence: candidate.confidence,
                    rect: imageRect(from: box.boundingBox, width: width, height: height)
                )
            )
            searchStart = range.upperBound
        }

        return tokens
    }

    private func imageRect(from normalized: CGRect, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(
            x: normalized.minX * width,
            y: (1 - normalized.maxY) * height,
            width: normalized.width * width,
            height: normalized.height * height
        )
    }
}
