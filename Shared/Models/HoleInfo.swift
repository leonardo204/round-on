import Foundation

public struct HoleInfo: Codable, Sendable {
    public var number: Int
    public var par: Int
    public var teeLat: Double
    public var teeLng: Double
    public var greenLat: Double
    public var greenLng: Double

    public init(number: Int, par: Int, teeLat: Double, teeLng: Double, greenLat: Double, greenLng: Double) {
        self.number = number
        self.par = par
        self.teeLat = teeLat
        self.teeLng = teeLng
        self.greenLat = greenLat
        self.greenLng = greenLng
    }
}
