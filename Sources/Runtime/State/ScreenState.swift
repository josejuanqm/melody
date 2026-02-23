import Foundation
import SwiftUI
import Observation
import Core

// MARK: - Environment Key

private struct ScreenStateKey: EnvironmentKey {
    static let defaultValue = ScreenState()
}

extension EnvironmentValues {
    public var screenState: ScreenState {
        get { self[ScreenStateKey.self] }
        set { self[ScreenStateKey.self] = newValue }
    }
}

// MARK: - Per-Key Observable Slot

/// Per-key observable container so SwiftUI re-renders only views that read a specific state key.
@Observable
public final class StateSlot: @unchecked Sendable {
    public var value: LuaValue = .nil
}

// MARK: - Screen State (NOT @Observable — observation is per-slot)

/// State container for a screen, bridged to Lua.
/// Each key gets its own @Observable StateSlot so SwiftUI only
/// re-renders views that read that specific key.
@MainActor
public final class ScreenState {
    private var slots: [String: StateSlot] = [:]

    /// Callback to sync changes back to Lua
    var _syncToLua: (@Sendable (String, LuaValue) -> Void)?

    nonisolated public init() {}

    /// Get or create the slot for a given key
    public func slot(for key: String) -> StateSlot {
        if let existing = slots[key] { return existing }
        let new = StateSlot()
        slots[key] = new
        return new
    }

    /// Initialize with state defaults from YAML
    public func initialize(from stateDefaults: [String: StateValue]?) {
        guard let defaults = stateDefaults else { return }
        for (key, stateValue) in defaults {
            slot(for: key).value = stateValue.toLuaValue()
        }
    }

    /// Update callback to sync changes back to Lua
    public func syncToLua(_ syncToLua: @Sendable @escaping (String, LuaValue) -> Void) {
        self._syncToLua = syncToLua
    }

    /// Update a value (called from Lua metatable __newindex)
    public func update(key: String, value: LuaValue) {
        slot(for: key).value = value
    }

    /// Set a value from SwiftUI and sync to Lua
    public func set(key: String, value: LuaValue) {
        slot(for: key).value = value
        _syncToLua?(key, value)
    }

    /// Get a value by key
    public func get(key: String) -> LuaValue {
        return slot(for: key).value
    }

    /// Snapshot of all values for Lua VM initialization (NOT for SwiftUI observation)
    public var allValues: [String: LuaValue] {
        slots.mapValues { $0.value }
    }
}

extension StateValue {
    /// Convert a YAML StateValue to a LuaValue
    public func toLuaValue() -> LuaValue {
        switch self {
        case .string(let s): return .string(s)
        case .int(let i): return .number(Double(i))
        case .double(let d): return .number(d)
        case .bool(let b): return .bool(b)
        case .null: return .nil
        case .array(let arr): return .array(arr.map { $0.toLuaValue() })
        case .dictionary(let dict):
            return .table(dict.mapValues { $0.toLuaValue() })
        }
    }
}
