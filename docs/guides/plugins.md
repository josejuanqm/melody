# Plugins

Plugins extend Melody with native functionality that Lua can't do on its own — things like keychain access, biometrics, analytics, in-app purchases, or anything that needs platform APIs.

## Using plugins

Declare plugins in your `app.yaml` as a name-to-git-URL mapping:

```yaml
app:
  name: MyApp
  plugins:
    keychain: https://github.com/example/melody-plugin-keychain.git
    analytics: https://github.com/example/melody-plugin-analytics.git
```

Install them:

```bash
melody plugins install
```

This clones each repo, copies the native sources into your project, and generates the plugin registry. Run it again to pull updates.

After installing, the plugin's functions are available in Lua under their namespace:

```lua
local token = keychain.get("auth_token")
analytics.track("page_view", { screen = "home" })
```

## Creating a plugin

A plugin is a git repo with a `plugin.yaml` manifest and native source files.

### Directory structure

```
melody-plugin-keychain/
  plugin.yaml
  iOS/
    KeychainPlugin.swift
  android/
    KeychainPlugin.kt
  lua/                      # optional
    keychain.lua
```

### Manifest

The `plugin.yaml` declares what files each platform needs:

```yaml
name: keychain
version: 1.0.0
description: Secure keychain/keystore access

ios:
  sources:
    - iOS/KeychainPlugin.swift
  frameworks:
    - Security
  dependencies:
    - KeychainAccess

android:
  sources:
    - android/KeychainPlugin.kt
  frameworks:
    - android.security

lua:
  - lua/keychain.lua
```

| Field | What it does |
|-------|-------------|
| `ios.sources` | Swift files to copy into the Xcode project |
| `ios.frameworks` | System frameworks to link |
| `ios.dependencies` | SPM or CocoaPods dependencies |
| `android.sources` | Kotlin files to copy into the Android project |
| `android.frameworks` | Android libraries |
| `lua` | Lua files bundled as a prelude (runs before any screen) |

### Swift implementation

```swift
import Runtime

class KeychainPlugin: MelodyPlugin {
    var name = "keychain"

    func register(vm: LuaVM) {
        vm.registerPluginFunction(namespace: "keychain", name: "get") { args in
            guard let key = args.first?.stringValue else { return .nil }
            // look up value in keychain
            if let value = KeychainAccess.get(key) {
                return .string(value)
            }
            return .nil
        }

        vm.registerPluginFunction(namespace: "keychain", name: "set") { args in
            guard args.count >= 2,
                  let key = args[0].stringValue,
                  let value = args[1].stringValue else { return .bool(false) }
            KeychainAccess.set(key, value: value)
            return .bool(true)
        }

        vm.registerPluginFunction(namespace: "keychain", name: "delete") { args in
            guard let key = args.first?.stringValue else { return .bool(false) }
            KeychainAccess.delete(key)
            return .bool(true)
        }
    }
}
```

### Kotlin implementation

```kotlin
class KeychainPlugin : MelodyPlugin {
    override val name = "keychain"

    override fun register(vm: LuaVM) {
        vm.registerPluginFunction("keychain", "get") { args ->
            val key = args.firstOrNull()?.stringValue ?: return@registerPluginFunction LuaValue.Nil
            val value = EncryptedPrefs.getString(key, null)
            if (value != null) LuaValue.String(value) else LuaValue.Nil
        }

        vm.registerPluginFunction("keychain", "set") { args ->
            val key = args.getOrNull(0)?.stringValue ?: return@registerPluginFunction LuaValue.Bool(false)
            val value = args.getOrNull(1)?.stringValue ?: return@registerPluginFunction LuaValue.Bool(false)
            EncryptedPrefs.putString(key, value)
            LuaValue.Bool(true)
        }

        vm.registerPluginFunction("keychain", "delete") { args ->
            val key = args.firstOrNull()?.stringValue ?: return@registerPluginFunction LuaValue.Bool(false)
            EncryptedPrefs.remove(key)
            LuaValue.Bool(true)
        }
    }
}
```

### Lua helpers (optional)

If your plugin needs helper functions, add them as Lua files. They run as a prelude before any screen mounts:

```lua
-- lua/keychain.lua

-- convenience wrapper
function keychain.getOrDefault(key, default)
  local val = keychain.get(key)
  if val == nil then return default end
  return val
end
```

## How it works under the hood

When you run `melody plugins install`:

1. Each plugin repo is cloned (shallow) to `.melody/plugins/{name}/`
2. iOS sources are copied to `{AppName}/Plugins/{name}/`
3. Android sources are copied to `android/{app}/src/main/java/plugins/{name}/`
4. A registry file is generated for each platform that instantiates all plugins
5. Lua files from all plugins are combined into `.melody/plugins/prelude.lua`

At runtime, the generated registry passes all plugins to `MelodyAppView` (Swift) or `MelodyActivity` (Kotlin). Each plugin's `register()` is called once per Lua VM, making its functions available under the plugin's namespace.

## LuaValue types

When writing plugin functions, you'll work with `LuaValue`:

| Type | Swift | Kotlin |
|------|-------|--------|
| String | `.string("hello")` | `LuaValue.String("hello")` |
| Number | `.number(42.0)` | `LuaValue.Number(42.0)` |
| Boolean | `.bool(true)` | `LuaValue.Bool(true)` |
| Nil | `.nil` | `LuaValue.Nil` |
| Table | `.table(["key": .string("val")])` | `LuaValue.Table(mapOf("key" to LuaValue.String("val")))` |
| Array | `.array([.string("a"), .number(1)])` | `LuaValue.Array(listOf(...))` |

Arguments arrive as `[LuaValue]` (Swift) or `List<LuaValue>` (Kotlin). Return a single `LuaValue`.
