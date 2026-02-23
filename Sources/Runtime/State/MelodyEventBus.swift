import Foundation
import SwiftUI

// MARK: - Environment Key

private struct MelodyEventBusKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue = MelodyEventBus()
}

extension EnvironmentValues {
    public var melodyEventBus: MelodyEventBus {
        get { self[MelodyEventBusKey.self] }
        set { self[MelodyEventBusKey.self] = newValue }
    }
}

/// Pub/sub event bus that broadcasts named events to all registered VMs and Swift observers.
public final class MelodyEventBus {
    private struct WeakVM {
        weak var value: LuaVM?
    }

    private var vms: [ObjectIdentifier: WeakVM] = [:]
    private var observers: [UUID: (String, (LuaValue) -> Void)] = [:]

    public init() {}

    /// Register a VM to receive events
    func register(vm: LuaVM) {
        vms[ObjectIdentifier(vm)] = WeakVM(value: vm)
    }

    /// Unregister a VM (e.g., when a screen is torn down)
    func unregister(vm: LuaVM) {
        vms.removeValue(forKey: ObjectIdentifier(vm))
    }

    /// Register a Swift-level observer for a specific event.
    /// Returns an ID that can be used to remove the observer later.
    func observe(event: String, handler: @escaping (LuaValue) -> Void) -> UUID {
        let id = UUID()
        observers[id] = (event, handler)
        return id
    }

    /// Remove a Swift-level observer by ID.
    func removeObserver(_ id: UUID) {
        observers.removeValue(forKey: id)
    }

    /// Broadcast an event to all registered VMs and Swift observers
    func emit(event: String, data: LuaValue) {
        let matchingObservers = observers.filter { $0.value.0 == event }.count
        print("[Melody:EventBus] emit('\(event)') — \(vms.count) VMs, \(matchingObservers) Swift observers")

        var stale: [ObjectIdentifier] = []
        for (id, weak) in vms {
            if let vm = weak.value {
                vm.dispatchEvent(name: event, data: data)
            } else {
                stale.append(id)
            }
        }
        for id in stale { vms.removeValue(forKey: id) }

        for (_, entry) in observers where entry.0 == event {
            entry.1(data)
        }
    }
}
