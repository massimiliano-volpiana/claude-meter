import Foundation

// MARK: - Claude.ai usage limits

public struct UsageLimit: Identifiable {
    public let id: String
    public let label: String
    public let percent: Double
    public let resetsAt: Date?

    public init(id: String, label: String, percent: Double, resetsAt: Date?) {
        self.id = id
        self.label = label
        self.percent = percent
        self.resetsAt = resetsAt
    }

    public var resetsInText: String {
        guard let d = resetsAt else { return "" }
        let secs = d.timeIntervalSinceNow
        if secs <= 0 { return "now" }
        let h = Int(secs / 3600)
        let m = Int((secs.truncatingRemainder(dividingBy: 3600)) / 60)
        if h >= 24 { return "in \(h / 24)d" }
        if h > 0   { return "in \(h)h \(m)m" }
        return "in \(m)m"
    }
}

// MARK: - Raw API response shapes

public struct UsageResponse: Codable {
    public let fiveHour: UsageWindow?
    public let sevenDay: UsageWindow?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

public struct UsageWindow: Codable {
    public let utilization: Double?
    public let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

// MARK: - Shared data file (no App Group needed)

public let kSharedDataURL: URL = {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let dir = appSupport.appendingPathComponent("ClaudeMeter")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("limits.json")
}()

// MARK: - Double helpers

extension Double {
    public var nonZero: Double? { self == 0 ? nil : self }
    public func clamped(_ lo: Double, _ hi: Double) -> Double { min(max(self, lo), hi) }
}
