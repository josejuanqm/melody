import Foundation
import SwiftUI
import Core

// MARK: - Environment Key

private struct LocalStateKey: EnvironmentKey {
    static let defaultValue: LocalState? = nil
}

extension EnvironmentValues {
    var localState: LocalState? {
        get { self[LocalStateKey.self] }
        set { self[LocalStateKey.self] = newValue }
    }
}

// MARK: - Local State (NOT @Observable — observation is per-slot, reuses StateSlot)

/// Scoped state container for component-local variables, bridged to the Lua `scope` table.
@MainActor
final class LocalState {
    private var slots: [String: StateSlot] = [:]
    /// Mirror of slot values that can be read without triggering @Observable tracking.
    /// Kept in sync by update() and initialize().
    private var rawValues: [String: LuaValue] = [:]

    nonisolated init() {}

    func slot(for key: String) -> StateSlot {
        if let existing = slots[key] { return existing }
        let new = StateSlot()
        slots[key] = new
        return new
    }

    func update(key: String, value: LuaValue) {
        slot(for: key).value = value
        rawValues[key] = value
    }

    func get(key: String) -> LuaValue {
        slot(for: key).value
    }

    func initialize(from defaults: [String: StateValue]?) {
        guard let defaults else { return }
        for (key, sv) in defaults {
            let lv = sv.toLuaValue()
            slot(for: key).value = lv
            rawValues[key] = lv
        }
    }

    /// All values — reads through @Observable (registers tracking on every slot).
    var allValues: [String: LuaValue] {
        slots.mapValues { $0.value }
    }

    /// All values without triggering @Observable tracking.
    /// Use this when pushing scope to Lua during body evaluation.
    var allValuesUntracked: [String: LuaValue] {
        rawValues
    }
}
