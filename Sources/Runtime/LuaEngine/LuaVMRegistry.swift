import Foundation
import SwiftUI
import Observation

// MARK: - Environment Key

private struct LuaVMRegistryKey: EnvironmentKey {
    static let defaultValue = LuaVMRegistry()
}

extension EnvironmentValues {
    public var vmRegistry: LuaVMRegistry {
        get { self[LuaVMRegistryKey.self] }
        set { self[LuaVMRegistryKey.self] = newValue }
    }
}

// MARK: - VM Lifecycle Anchor

/// Ref-counted anchor that ties a ``LuaVM`` lifetime to a SwiftUI view identity.
public final class VMLifecycleAnchor {
    public let id = UUID()
    let key: String
    private weak var registry: LuaVMRegistry?

    init(key: String, registry: LuaVMRegistry) {
        self.key = key
        self.registry = registry
    }

    deinit {
        let key = key
        let anchorId = id
        let registry = registry
        Task { @MainActor in
            registry?.release(for: key, ownedBy: anchorId)
        }
    }
}

// MARK: - VM Registry

@MainActor
@Observable
/// Centralized owner of per-screen ``LuaVM`` instances, keyed by path.
public final class LuaVMRegistry {
    private struct Entry {
        let vm: LuaVM
        let anchorId: UUID
    }

    @ObservationIgnored private var entries: [String: Entry] = [:]

    nonisolated public init() {}

    /// Returns an existing VM for the path if the anchor matches, or creates a new one.
    /// When a different anchor acquires the same path (new view identity), the old VM
    /// is removed from the registry. The actual cleanup (shutdown + lua_close) happens
    /// in LuaVM.deinit when the last strong reference is released — this avoids freeing
    /// ClosureWrappers while in-flight async operations may still trigger Lua callbacks.
    func acquire(for path: String, anchorId: UUID, source: String? = nil) throws -> (vm: LuaVM, isNew: Bool) {
        if let entry = entries[path], entry.anchorId == anchorId {
            return (entry.vm, false)
        }
        // Different owner or no entry — drop registry reference to old VM.
        // Don't call shutdown() here: the old VM may still have in-flight
        // operations (fetches, coroutines). ARC will call deinit when safe.
        entries.removeValue(forKey: path)
        let vm = try LuaVM(source: source ?? path)
        entries[path] = Entry(vm: vm, anchorId: anchorId)
        return (vm, true)
    }

    /// Get the VM for a path without creating one.
    func vm(for path: String) -> LuaVM? {
        entries[path]?.vm
    }

    /// Release a path's VM, but only if the caller's anchor still owns it.
    /// Prevents a stale deferred deinit from removing a VM that a new view has already claimed.
    /// Does NOT call shutdown() — lets ARC + LuaVM.deinit handle cleanup atomically.
    func release(for path: String, ownedBy anchorId: UUID) {
        guard let entry = entries[path], entry.anchorId == anchorId else { return }
        entries.removeValue(forKey: path)
    }

    /// Remove all VMs from the registry.
    func shutdownAll() {
        entries.removeAll()
    }

    deinit {}
}
