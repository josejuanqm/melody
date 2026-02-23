package com.melody.runtime.navigation

import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import com.melody.core.schema.ScreenDefinition
import com.melody.runtime.engine.LuaValue

/**
 * Manages path-based screen navigation.
 * Port of iOS Navigator.swift.
 */
class Navigator {
    /** The navigation stack of screen paths */
    val path = mutableStateListOf<String>()

    /** The root screen path */
    var rootPath = mutableStateOf("/")

    /** All registered screens by path (not tracked by Compose) */
    private var screens = mutableMapOf<String, ScreenDefinition>()

    /** Props passed via melody.navigate(path, props) — consumed once */
    val navigationProps = mutableMapOf<String, Map<String, LuaValue>>()

    /** Public accessor for registered screens */
    val registeredScreens: List<ScreenDefinition>
        get() = screens.values.toList()

    /** Current screen path */
    val currentPath: String
        get() = path.lastOrNull() ?: rootPath.value

    /** Register screens from app definition */
    fun registerScreens(screenDefs: List<ScreenDefinition>) {
        screens.clear()
        for (screen in screenDefs) {
            screens[screen.path] = screen
        }
    }

    /** Navigate to a path */
    fun navigate(targetPath: String) {
        if (currentPath == targetPath) return

        if (screens.containsKey(targetPath)) {
            path.add(targetPath)
        } else {
            for (registeredPath in screens.keys) {
                if (matchesRoute(registeredPath, targetPath)) {
                    path.add(targetPath)
                    return
                }
            }
            android.util.Log.w("Melody", "No screen found for path '$targetPath'")
        }
    }

    /** Replace the navigation stack */
    fun replace(targetPath: String) {
        if (rootPath.value == targetPath && path.isEmpty()) return
        path.clear()
        if (rootPath.value != targetPath) {
            rootPath.value = targetPath
        }
    }

    /** Go back one screen */
    fun goBack() {
        if (path.isNotEmpty()) {
            path.removeAt(path.lastIndex)
        }
    }

    /** Get the screen definition for a given path */
    fun screen(screenPath: String): ScreenDefinition? {
        screens[screenPath]?.let { return it }
        for ((registeredPath, screen) in screens) {
            if (matchesRoute(registeredPath, screenPath)) return screen
        }
        return null
    }

    /** Extract parameters from a path */
    fun extractParams(actualPath: String, route: String): Map<String, String> {
        val actualParts = actualPath.split("/").filter { it.isNotEmpty() }
        val routeParts = route.split("/").filter { it.isNotEmpty() }
        val params = mutableMapOf<String, String>()

        if (actualParts.size != routeParts.size) return params

        for ((actual, routePart) in actualParts.zip(routeParts)) {
            if (routePart.startsWith(":")) {
                params[routePart.drop(1)] = actual
            }
        }
        return params
    }

    private fun matchesRoute(registered: String, actual: String): Boolean {
        val regParts = registered.split("/").filter { it.isNotEmpty() }
        val actParts = actual.split("/").filter { it.isNotEmpty() }

        if (regParts.size != actParts.size) return false

        for ((reg, act) in regParts.zip(actParts)) {
            if (!reg.startsWith(":") && reg != act) return false
        }
        return true
    }
}

/**
 * Manages selected tab state.
 * Port of iOS TabCoordinator.
 */
class TabCoordinator(
    tabIds: List<String>,
    initialTabId: String
) {
    var tabIds = mutableStateOf(tabIds)
    var selectedTabId = mutableStateOf(initialTabId)

    fun switchTab(tabId: String) {
        if (tabIds.value.contains(tabId)) {
            selectedTabId.value = tabId
        } else {
            android.util.Log.w("Melody", "No tab with id '$tabId'")
        }
    }

    /** Update visible tab IDs. If selected tab is no longer visible, switch to first. */
    fun updateTabIds(newIds: List<String>) {
        tabIds.value = newIds
        if (!newIds.contains(selectedTabId.value) && newIds.isNotEmpty()) {
            selectedTabId.value = newIds.first()
        }
    }
}
