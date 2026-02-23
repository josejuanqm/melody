import Foundation
import SwiftUI
import Observation
import Core

// MARK: - Environment Key

private struct NavigatorKey: EnvironmentKey {
    static let defaultValue = Navigator()
}

extension EnvironmentValues {
    public var navigator: Navigator {
        get { self[NavigatorKey.self] }
        set { self[NavigatorKey.self] = newValue }
    }
}

@MainActor
@Observable
/// Observable navigation stack that maps screen paths to ``ScreenDefinition`` values.
public final class Navigator: Sendable {
    private let id = UUID()

    /// The navigation stack of screen paths
    public var path: [String] = []

    /// The root screen path (can be changed by replace())
    public var rootPath: String = "/"

    /// All registered screens by path (not tracked by @Observable to avoid re-render loops)
    @ObservationIgnored private var screens: [String: ScreenDefinition] = [:]

    /// Bumped each time registerScreens() is called — tracked by @Observable so
    /// dependents (e.g. TabContainerView) can detect hot-reload screen updates.
    public var screenRegistrationVersion: Int = 0

    /// Props passed via melody.navigate(path, props) — consumed once by the destination screen
    @ObservationIgnored public var navigationProps: [String: [String: LuaValue]] = [:]

    /// Public accessor so per-tab navigators can copy all registered screens
    public var registeredScreens: [ScreenDefinition] {
        Array(screens.values)
    }

    /// The current screen path
    public var currentPath: String {
        path.last ?? rootPath
    }

    nonisolated public init() {}

    /// Register screens from app definition
    public func registerScreens(_ screenDefs: [ScreenDefinition]) {
        screens = [:]
        for screen in screenDefs {
            screens[screen.path] = screen
        }
        screenRegistrationVersion += 1
    }

    /// Navigate to a path
    public func navigate(to targetPath: String) {
        guard currentPath != targetPath else {
            return
        }

        if screens[targetPath] != nil {
            path.append(targetPath)
        } else {
            for (registeredPath, _) in screens {
                if matchesRoute(registered: registeredPath, actual: targetPath) {
                    path.append(targetPath)
                    return
                }
            }
            print("[Melody] Warning: No screen found for path '\(targetPath)'")
        }
    }

    /// Replace the navigation stack — clears history and sets a new root screen
    public func replace(with targetPath: String) {
        guard rootPath != targetPath || !path.isEmpty else { return }
        if !path.isEmpty {
            path = []
        }
        if rootPath != targetPath {
            DispatchQueue.main.async { [self] in
                self.rootPath = targetPath
            }
        }
    }

    /// Go back one screen
    public func goBack() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    /// Get the screen definition for a given path
    public func screen(for screenPath: String) -> ScreenDefinition? {
        if let direct = screens[screenPath] {
            return direct
        }
        for (registeredPath, screen) in screens {
            if matchesRoute(registered: registeredPath, actual: screenPath) {
                return screen
            }
        }
        return nil
    }

    /// Extract parameters from a path (e.g., /profile/123 with route /profile/:id → ["id": "123"])
    public func extractParams(from actualPath: String, route: String) -> [String: String] {
        let actualParts = actualPath.split(separator: "/")
        let routeParts = route.split(separator: "/")
        var params: [String: String] = [:]

        guard actualParts.count == routeParts.count else { return params }

        for (actual, route) in zip(actualParts, routeParts) {
            if route.hasPrefix(":") {
                let paramName = String(route.dropFirst())
                params[paramName] = String(actual)
            }
        }
        return params
    }

    private func matchesRoute(registered: String, actual: String) -> Bool {
        let registeredParts = registered.split(separator: "/")
        let actualParts = actual.split(separator: "/")

        guard registeredParts.count == actualParts.count else { return false }

        for (reg, act) in zip(registeredParts, actualParts) {
            if !reg.hasPrefix(":") && reg != act {
                return false
            }
        }
        return true
    }
}

// MARK: - Root Navigator Environment Key

private struct RootNavigatorKey: EnvironmentKey {
    static let defaultValue: Navigator? = nil
}

extension EnvironmentValues {
    /// The top-level (app-level) navigator. Used by melody.replace() to break out of tabs.
    public var rootNavigator: Navigator? {
        get { self[RootNavigatorKey.self] }
        set { self[RootNavigatorKey.self] = newValue }
    }
}

// MARK: - Tab Coordinator

@MainActor
@Observable
/// Observable coordinator that tracks the selected tab and visible tab IDs.
public final class TabCoordinator: Sendable {
    public var selectedTabId: String
    public var tabIds: [String]

    public init(tabIds: [String], initialTabId: String) {
        self.tabIds = tabIds
        self.selectedTabId = initialTabId
    }

    public func switchTab(to tabId: String) {
        guard tabIds.contains(tabId) else {
            print("[Melody] Warning: No tab with id '\(tabId)'")
            return
        }
        selectedTabId = tabId
    }

    /// Update the set of visible tab IDs. If the currently selected tab
    /// is no longer in the list, switch to the first available tab.
    public func updateTabIds(_ newIds: [String]) {
        tabIds = newIds
        if !newIds.contains(selectedTabId), let first = newIds.first {
            selectedTabId = first
        }
    }
}

// MARK: - Tab Coordinator Environment Key

private struct TabCoordinatorKey: EnvironmentKey {
    static let defaultValue: TabCoordinator? = nil
}

extension EnvironmentValues {
    public var tabCoordinator: TabCoordinator? {
        get { self[TabCoordinatorKey.self] }
        set { self[TabCoordinatorKey.self] = newValue }
    }
}
