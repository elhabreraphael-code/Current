import Foundation

@main
struct PowerStateTests {
    static func main() {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }
        let raw: [String: Any] = ["Type": "InternalBattery", "Is Present": true,
            "Current Capacity": 68, "Max Capacity": 100,
            "Power Source State": "AC Power", "Is Charging": true]
        let charging = PowerSnapshot.parse(raw)!
        check(charging.percent == 68 && charging.pluggedIn && charging.charging, "Read charging state")
        var modified = raw
        modified["Is Charging"] = false
        let paused = PowerSnapshot.parse(modified)!
        check(paused.status == "Connected · Not charging", "Paused charging is still connected")
        modified["Power Source State"] = "Battery Power"
        let battery = PowerSnapshot.parse(modified)!
        check(!battery.pluggedIn && !battery.charging, "Read unplug state")
        modified["Current Capacity"] = 300
        check(PowerSnapshot.parse(modified)?.percent == 100, "Clamp high values")
        modified["Current Capacity"] = -1
        check(PowerSnapshot.parse(modified)?.percent == 0, "Clamp low values")
        modified["Max Capacity"] = 0
        check(PowerSnapshot.parse(modified) == nil, "Reject zero capacity")
        modified = raw
        modified["Type"] = "UPS"
        check(PowerSnapshot.parse(modified) == nil, "Ignore external UPS")
        modified = raw
        modified["Is Present"] = false
        check(PowerSnapshot.parse(modified) == nil, "Ignore absent batteries")
        modified = raw
        modified["Power Source State"] = "Off Line"
        check(PowerSnapshot.parse(modified) == nil, "Ignore transient offline state")
        check(PowerSnapshot.parse([:]) == nil, "Handle missing data")
        modified = raw
        modified["Current Capacity"] = 100
        check(PowerSnapshot.parse(modified)?.status == "Fully charged", "Full battery status")
        var transitions = PowerTransitions()
        check(transitions.receive(charging) == nil, "No launch animation")
        check(transitions.receive(charging) == nil, "No duplicate animation")
        check(transitions.receive(paused) == nil, "No animation for charging pause")
        check(transitions.receive(nil) == nil, "No false unplug on missing data")
        check(transitions.receive(battery) == false, "Unplug transition")
        check(transitions.receive(battery) == nil, "Deduplicate unplug")
        check(transitions.receive(charging) == true, "Plug transition")
        for _ in 0..<100 {
            check(transitions.receive(battery) == false, "Repeated unplug")
            check(transitions.receive(charging) == true, "Repeated plug")
        }
        transitions.reset()
        check(transitions.receive(battery) == nil, "No stale wake transition")
        print("Passed \(checks) power-state and transition checks.")
    }
}
