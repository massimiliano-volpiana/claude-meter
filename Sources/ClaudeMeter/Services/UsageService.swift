import Foundation
import Combine
import WidgetKit
import Shared

final class UsageService: ObservableObject {
    @Published var limits: [UsageLimit] = []
    @Published var lastUpdated: Date?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var menuBarText = "--"

    // MARK: - Settings

    var sessionKey: String {
        get { UserDefaults.standard.string(forKey: "claude_session_key") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "claude_session_key")
            orgID = nil
            refresh()
        }
    }

    var refreshInterval: Double {
        get { UserDefaults.standard.double(forKey: "refreshInterval").nonZero ?? 120 }
        set {
            UserDefaults.standard.set(newValue, forKey: "refreshInterval")
            restartTimer()
        }
    }

    // MARK: - Private

    private var orgID: String?
    private var timer: Timer?

    init() {
        restartTimer()
        if !sessionKey.isEmpty { refresh() }
    }

    private func restartTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // MARK: - Public

    func refresh() {
        guard !sessionKey.isEmpty else {
            DispatchQueue.main.async { self.errorMessage = "Set up your Session Key in settings" }
            return
        }
        isLoading = true
        errorMessage = nil

        if let id = orgID {
            fetchLimits(orgID: id)
        } else {
            fetchOrgID { [weak self] id in
                guard let self, let id else { return }
                self.orgID = id
                self.fetchLimits(orgID: id)
            }
        }
    }

    // MARK: - Step 1: get org UUID

    private func fetchOrgID(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://claude.ai/api/account") else { return completion(nil) }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("https://claude.ai", forHTTPHeaderField: "Referer")

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { self.errorMessage = error.localizedDescription; self.isLoading = false }
                return completion(nil)
            }
            guard let data else { return completion(nil) }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let memberships = json["memberships"] as? [[String: Any]] else {
                DispatchQueue.main.async { self.errorMessage = "Invalid or expired session key"; self.isLoading = false }
                return completion(nil)
            }

            // Raccoglie tutti gli org UUID
            let orgIDs = memberships.compactMap { ($0["organization"] as? [String: Any])?["uuid"] as? String }
            guard !orgIDs.isEmpty else { return completion(nil) }

            // Prova ogni org e usa quella con utilization > 0, altrimenti la prima
            self.findActiveOrg(orgIDs: orgIDs, completion: completion)
        }.resume()
    }

    // MARK: - Find active org (the one with actual usage)

    private func findActiveOrg(orgIDs: [String], completion: @escaping (String?) -> Void) {
        var remaining = orgIDs
        func tryNext() {
            guard let id = remaining.first else { return completion(orgIDs.first) }
            remaining.removeFirst()
            let url = URL(string: "https://claude.ai/api/organizations/\(id)/usage")!
            var req = URLRequest(url: url, timeoutInterval: 8)
            req.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("https://claude.ai", forHTTPHeaderField: "Referer")
            URLSession.shared.dataTask(with: req) { data, _, _ in
                if let data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let fiveHour = json["five_hour"] as? [String: Any],
                   let util = fiveHour["utilization"] as? Double, util > 0 {
                    completion(id)
                } else if let data,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let sevenDay = json["seven_day"] as? [String: Any],
                          let util = sevenDay["utilization"] as? Double, util > 0 {
                    completion(id)
                } else {
                    tryNext()
                }
            }.resume()
        }
        tryNext()
    }

    // MARK: - Step 2: fetch usage

    private func fetchLimits(orgID: String) {
        let url = URL(string: "https://claude.ai/api/organizations/\(orgID)/usage")!
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("https://claude.ai", forHTTPHeaderField: "Referer")

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            defer { DispatchQueue.main.async { self.isLoading = false } }

            if let error {
                DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
                return
            }

            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            if httpStatus == 401 || httpStatus == 403 {
                DispatchQueue.main.async { self.errorMessage = "Session key expired — update it in settings" }
                return
            }

            guard let data else { return }

            let rawString = String(data: data, encoding: .utf8) ?? "nil"
            print("[ClaudeMeter] usage response:", rawString.prefix(300))

            let parsed = self.parseUsage(data: data)
            DispatchQueue.main.async {
                self.limits = parsed
                self.lastUpdated = Date()
                if parsed.isEmpty {
                    let preview = String(rawString.prefix(120))
                    self.errorMessage = "Parse failed. Raw: \(preview)"
                } else {
                    self.errorMessage = nil
                }
                self.updateMenuBar()
                self.writeToAppGroup()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }.resume()
    }

    // MARK: - Parser — formato reale: { five_hour: { utilization: 0.13, resets_at: "..." }, seven_day: { ... } }

    private func parseUsage(data: Data) -> [UsageLimit] {
        guard let resp = try? JSONDecoder().decode(UsageResponse.self, from: data) else { return [] }

        let iso1 = ISO8601DateFormatter()
        iso1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso2 = ISO8601DateFormatter()

        func date(_ s: String?) -> Date? {
            guard let s else { return nil }
            return iso1.date(from: s) ?? iso2.date(from: s)
        }

        var result: [UsageLimit] = []
        if let w = resp.fiveHour, let u = w.utilization {
            result.append(UsageLimit(id: "five_hour", label: "5-hour limit",
                                     percent: u.clamped(0, 100),
                                     resetsAt: date(w.resetsAt)))
        }
        if let w = resp.sevenDay, let u = w.utilization {
            result.append(UsageLimit(id: "seven_day", label: "Weekly · all models",
                                     percent: u.clamped(0, 100),
                                     resetsAt: date(w.resetsAt)))
        }
        return result
    }

    private func updateMenuBar() {
        let parts = limits.map { String(format: "%.0f%%", $0.percent) }
        menuBarText = parts.joined(separator: " · ")
    }

    private func writeToAppGroup() {
        let payload: [String: Any] = [
            "limits": limits.map { ["id": $0.id, "label": $0.label,
                                    "percent": $0.percent,
                                    "resetsAt": $0.resetsAt?.timeIntervalSince1970 ?? 0] },
            "last_updated": Date().timeIntervalSince1970
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            try? data.write(to: kSharedDataURL, options: .atomic)
        }
    }
}

extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
    func clamped(_ lo: Double, _ hi: Double) -> Double { min(max(self, lo), hi) }
}
