import Foundation

struct PowerSnapshot: Equatable {
    let percent: Int
    let pluggedIn: Bool
    let charging: Bool
    var status: String {
        if !pluggedIn { return "On battery" }
        if percent >= 100 { return "Fully charged" }
        return charging ? "Charging" : "Connected · Not charging"
    }

    static func parse(_ values: [String: Any]) -> PowerSnapshot? {
        guard values["Type"] as? String == "InternalBattery",
              values["Is Present"] as? Bool != false,
              let current = values["Current Capacity"] as? Int,
              let maximum = values["Max Capacity"] as? Int, maximum > 0,
              let state = values["Power Source State"] as? String,
              ["AC Power", "Battery Power"].contains(state) else { return nil }
        let percent = Int((min(1, max(0, Double(current) / Double(maximum))) * 100).rounded())
        let pluggedIn = state == "AC Power"
        return PowerSnapshot(percent: percent, pluggedIn: pluggedIn,
                             charging: pluggedIn && (values["Is Charging"] as? Bool ?? false))
    }
}

struct PowerTransitions {
    private(set) var previous: PowerSnapshot?
    mutating func receive(_ snapshot: PowerSnapshot?) -> Bool? {
        guard let snapshot else { return nil }
        defer { previous = snapshot }
        guard let previous, previous.pluggedIn != snapshot.pluggedIn else { return nil }
        return snapshot.pluggedIn
    }
    mutating func reset() { previous = nil }
}
