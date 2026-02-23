<p align="center">
  <img src="https://img.shields.io/badge/iOS%2017%2B-blue" />
  <img src="https://img.shields.io/badge/iPadOS%2017%2B-blue" />
  <img src="https://img.shields.io/badge/macOS%2014%2B-blue" />
  <img src="https://img.shields.io/badge/tvOS%2026%2B-blue" />
  <img src="https://img.shields.io/badge/visionOS%202%2B-blue" />
  <img src="https://img.shields.io/badge/Android-34C759" />
  <img src="https://img.shields.io/badge/lua-5.4-purple" />
</p>

# Melody

Build native apps with YAML and Lua. One codebase, every Apple platform + Android.

No JSX, no bridge, no bundler — describe your UI in YAML, write your logic in Lua, and Melody renders it as real native UI. SwiftUI on Apple platforms, Jetpack Compose on Android.

```yaml
app:
  name: MyApp
  theme:
    primary: "#6366f1"

screens:
  - id: home
    path: /
    title: Home
    state:
      count: 0

    body:
      - component: text
        text: "{{ 'Tapped ' .. state.count .. ' times' }}"
        style:
          fontSize: 24
          fontWeight: bold

      - component: button
        label: Tap me
        onTap: |
          state.count = state.count + 1
          melody.log("count is now " .. state.count)
```

That's a full screen. Change the YAML, hot reload, see it instantly.

## Why

I wanted to build apps fast without fighting tooling. React Native is great but it's a lot of moving parts. SwiftUI is great but iteration is slow. Melody sits in between — native performance with the speed of a scripting language.

- **YAML** for layout. Declarative, readable, diffable.
- **Lua** for logic. Tiny, fast, embeddable. No npm, no bundler.
- **Truly native** under the hood. SwiftUI on iOS/iPadOS/macOS/tvOS/visionOS, Jetpack Compose on Android. Not a web view, not a canvas — real platform components.

Web, Windows, and Linux support is planned.

## Getting Started

> Full walkthrough: [Getting Started Guide](docs/getting-started.md) | [Tutorial: Build a Notes App](docs/tutorial.md)

### Install the CLI

```bash
git clone https://github.com/aspect-build/melody.git
cd melody
swift build -c release
cp .build/release/melody /usr/local/bin/
```

### Create a project

```bash
melody create MyApp
cd MyApp
open MyApp.xcodeproj
```

This scaffolds everything — YAML, Xcode project, Android boilerplate, asset directories. Hit Run in Xcode and you're live.

### Dev server with hot reload

```bash
melody dev
```

Edit your YAML, save, and the app updates instantly over WebSocket. Works on the simulator, a physical device, or a macOS preview window.

```bash
melody dev --platform ios --simulator "iPhone 16 Pro"
melody dev --platform macos
melody dev --platform ios --device
```

Press `r` + Enter to force a reload.

## Components

> Full reference: [Components Guide](docs/guides/components.md)

23+ built-in components that map to native views on each platform — SwiftUI on Apple, Jetpack Compose on Android:

| Component | What it does |
|-----------|-------------|
| `text` | Labels, headings, dynamic expressions |
| `button` | Tappable actions with labels and icons |
| `stack` | HStack / VStack / ZStack via `direction` |
| `image` | Remote URLs or SF Symbols |
| `input` | Text fields, secure fields, text areas |
| `toggle` | Boolean switches |
| `picker` | Segmented, wheel, or menu selection |
| `datepicker` | Compact, graphical, or wheel date pickers |
| `slider` | Range selection |
| `stepper` | Increment / decrement |
| `list` | Dynamic scrollable lists with Lua render functions |
| `grid` | Adaptive or fixed column grids |
| `form` | Native grouped form layouts |
| `section` | Headers, footers, grouped content |
| `chart` | Bar, line, area, point, sector (pie) charts |
| `menu` | Dropdown menus |
| `link` | Open URLs in system browser |
| `disclosure` | Expandable sections |
| `progress` | Determinate / indeterminate progress |
| `spacer` | Flexible space |
| `divider` | Visual separator |
| `scroll` | Scrollable containers |
| `state_provider` | Scoped local state for self-contained widgets |

Every component supports `style`, `visible`, `disabled`, `onTap`, `onHover`, and `contextMenu`.

### Styling

All styling goes in the `style` block — layout, typography, colors, borders, shadows, animations:

```yaml
- component: stack
  direction: vertical
  style:
    backgroundColor: "theme.surface"
    borderRadius: 16
    padding: 16
    spacing: 12
    shadow: { radius: 4, y: 2 }
    animation: spring
  children:
    - component: text
      text: "{{ state.title }}"
      style:
        fontSize: 20
        fontWeight: semibold
        color: "theme.textPrimary"
    - component: text
      text: "{{ state.subtitle }}"
      style:
        fontSize: 15
        color: "theme.textSecondary"
```

Style supports `fontSize`, `fontWeight`, `fontDesign`, `color`, `backgroundColor`, `padding` (all sides or per-side), `margin`, `width`, `height`, `minWidth`, `maxWidth`, `borderRadius`, `borderWidth`, `borderColor`, `opacity`, `scale`, `rotation`, `shadow`, `alignment`, `spacing`, `aspectRatio`, `contentMode`, and `animation`.

Use `"theme.colorName"` anywhere you'd put a hex — it resolves from your theme automatically.

### Dynamic lists

The `list` and `grid` components use Lua render functions to generate items:

```yaml
- component: list
  items: "state.todos"
  style:
    spacing: 8
    padding: 16
  render: |
    local item = state._current_item
    return {
      component = "stack",
      direction = "horizontal",
      style = { spacing = 12, padding = 12, backgroundColor = theme.surface, borderRadius = 12 },
      children = {
        { component = "image", systemImage = item.done and "checkmark.circle.fill" or "circle",
          style = { width = 24, height = 24, color = item.done and theme.success or theme.textTertiary } },
        { component = "text", text = item.title or "", style = { fontSize = 16, color = theme.textPrimary } },
        { component = "spacer" }
      }
    }
```

### Charts

Native Swift Charts — bar, line, area, point, sector (pie/donut):

```yaml
- component: chart
  items: "state.revenue"
  marks:
    - type: bar
      xKey: month
      yKey: amount
  style:
    height: 250

# Donut chart
- component: chart
  items: "state.categories"
  marks:
    - type: sector
      angleKey: count
      groupKey: name
      innerRadius: 0.6
      angularInset: 2
```

### Forms

Native `Form` + `Section` for settings screens. Use `wrapper: form` on the screen or nest a `form` component:

```yaml
screens:
  - id: settings
    path: /settings
    title: Settings
    wrapper: form
    state:
      darkMode: false
      language: "en"

    body:
      - component: section
        label: Preferences
        footer: Changes are saved automatically
        children:
          - component: toggle
            label: Dark Mode
            stateKey: darkMode
          - component: picker
            label: Language
            stateKey: language
            options:
              - { label: English, value: en }
              - { label: Spanish, value: es }
      - component: section
        label: About
        children:
          - component: link
            label: Privacy Policy
            url: "https://example.com/privacy"
```

## State

> Deep dive: [Core Concepts](docs/guides/core-concepts.md)

State is reactive. Assign to `state.key` in Lua and the UI updates automatically. Only the components that reference that key re-render — fine-grained reactivity, no diffing.

```yaml
state:
  user: null
  loading: true

onMount: |
  local res = melody.fetch("https://api.example.com/me")
  if res.ok then
    state.user = res.data
  end
  state.loading = false
```

State types: strings, numbers, booleans, null, arrays, and tables. Initialize everything with sensible defaults.

## Lua API

### Navigation

```lua
melody.navigate("/profile/123")       -- push screen
melody.navigate("/detail", { id = 42 }) -- push with props
melody.goBack()                        -- pop
melody.replace("/home")                -- replace entire stack
melody.switchTab("search")             -- switch tab
```

Path params are accessed via `params.key` (always strings — use `tonumber()` for numbers).

### Networking

```lua
local res = melody.fetch(url, {
  method = "POST",
  headers = { ["Authorization"] = "Bearer " .. token },
  body = { title = "New item", done = false }
})
-- body tables are auto-serialized to JSON
-- res = { ok = bool, status = number, data = any, headers = {}, cookies = {} }

-- concurrent requests
local results = melody.fetchAll({
  { url = "/api/user" },
  { url = "/api/posts", method = "GET" }
})
```

Fetch is non-blocking — it uses coroutines under the hood, so your Lua code reads linearly but doesn't freeze the UI.

### Alerts and sheets

```lua
melody.alert("Confirm", "Delete this item?", {
  { title = "Cancel", style = "cancel" },
  { title = "Delete", style = "destructive", onTap = "deleteItem()" }
})

melody.sheet("/edit-profile", { detent = "medium" })
melody.sheet("/onboarding", { style = "fullscreen" })
melody.dismiss() -- close current sheet
```

### Persistence

```lua
melody.storeSave("token", res.data.token) -- persists to disk
melody.storeSet("temp", value)            -- session only
local token = melody.storeGet("token")    -- reads from cache then disk
```

### Events

Cross-screen communication via pub/sub:

```lua
-- screen A
melody.emit("cartUpdated", { count = #state.items })

-- screen B
melody.on("cartUpdated", function(data)
  state.cartCount = data.count
end)
```

### Timers

```lua
local id = melody.setInterval(function()
  state.elapsed = state.elapsed + 1
end, 1000)

melody.clearInterval(id)
```

### WebSockets

```lua
local ws = melody.wsConnect("wss://api.example.com/ws")
ws:on("open", function() melody.log("connected") end)
ws:on("message", function(msg) state.messages = msg end)
ws:send({ type = "subscribe", channel = "updates" }) -- tables auto-serialize to JSON
ws:close()
```

### Misc

```lua
melody.log("debug info")              -- console + dev overlay
melody.copyToClipboard(state.code)    -- system clipboard
melody.setTitle("New Title")          -- update nav title dynamically
melody.trustHost("localhost")         -- trust self-signed SSL
melody.clearCookies()                 -- for logout flows
```

### Expressions

Use `{{ }}` in any string property to evaluate Lua inline:

```yaml
- component: text
  text: "{{ 'Hello, ' .. state.name }}"
  visible: "{{ state.isLoggedIn }}"
  style:
    color: "theme.textPrimary"
    expressions:
      opacity: "state.visible and 1 or 0"
```

Static strings don't need inner quotes — `text: "Hello World"` just works. Only quote when mixing with expressions: `text: "'Count: ' .. state.count"`.

## Custom Components

Define once, use anywhere. Inline in `app.yaml` or as `*.component.yaml` files:

```yaml
components:
  UserCard:
    props:
      name: ""
      avatar: ""
      role: ""
    body:
      - component: stack
        direction: horizontal
        style:
          spacing: 12
          padding: 16
          backgroundColor: "theme.surface"
          borderRadius: 16
        children:
          - component: image
            src: "{{ props.avatar }}"
            style: { width: 48, height: 48, borderRadius: 24, contentMode: fill }
          - component: stack
            direction: vertical
            style: { spacing: 2 }
            children:
              - component: text
                text: "{{ props.name }}"
                style: { fontSize: 17, fontWeight: semibold, color: "theme.textPrimary" }
              - component: text
                text: "{{ props.role }}"
                style: { fontSize: 13, color: "theme.textSecondary" }
```

Then use it like any other component:

```yaml
- component: UserCard
  props:
    name: "{{ state.user.name }}"
    avatar: "{{ state.user.avatarUrl }}"
    role: "{{ state.user.role }}"
```

## Navigation

> Full reference: [Navigation Guide](docs/guides/navigation.md)

Path-based with dynamic route params:

```yaml
screens:
  - id: home
    path: /
    body:
      - component: button
        label: View Profile
        onTap: "melody.navigate('/profile/123')"

  - id: profile
    path: /profile/:id
    onMount: |
      local res = melody.fetch("https://api.example.com/user/" .. params.id)
      if res.ok then state.user = res.data end
    body:
      - component: text
        text: "{{ state.user.name }}"
```

### Tabs

```yaml
screens:
  - id: main
    path: /
    tabStyle: sidebarAdaptable  # sidebar on iPad/Mac, tab bar on iPhone
    tabs:
      - id: home
        title: Home
        icon: house.fill
        screen: /home
      - id: search
        title: Search
        icon: magnifyingglass
        screen: /search
      - id: profile
        title: Profile
        icon: person.fill
        screen: /profile
```

Each tab gets its own navigation stack. `melody.navigate()` pushes within the current tab, `melody.replace()` resets the whole app (useful for auth flows).

## Theming

> Full reference: [Theming Guide](docs/guides/theming.md)

Define your palette once. Reference it everywhere with `"theme.colorName"`.

```yaml
app:
  name: MyApp
  theme:
    primary: "#6366f1"
    secondary: "#a855f7"
    background: "#f2f2f7"
    colors:
      surface: "#ffffff"
      surfaceElevated: "#f9f9f9"
      border: "#e5e5ea"
      textPrimary: "#000000"
      textSecondary: "#8e8e93"
      textTertiary: "#aeaeb2"
      success: "#34c759"
      error: "#ff3b30"

    dark:
      background: "#000000"
      colors:
        surface: "#1c1c1e"
        surfaceElevated: "#2c2c2e"
        border: "#38383a"
        textPrimary: "#ffffff"
        textSecondary: "#8e8e93"
        textTertiary: "#636366"
```

The `dark` and `light` blocks are overrides — they merge on top of the base colors depending on the system appearance. Set `colorScheme: dark` or `colorScheme: light` to force a mode.

Theme colors work everywhere: YAML styles (`color: "theme.textPrimary"`), Lua expressions (`theme.primary`), and render functions (`style = { color = theme.success }`).

## Plugins

> Full reference: [Plugins Guide](docs/guides/plugins.md)

Extend Melody with native plugins. A plugin is a git repo that contains platform-specific source files and a `plugin.yaml` manifest. Plugins register functions that become callable from Lua under their own namespace.

### Installing plugins

Declare plugins in your `app.yaml`:

```yaml
app:
  name: MyApp
  plugins:
    keychain: https://github.com/example/melody-plugin-keychain.git
    analytics: https://github.com/example/melody-plugin-analytics.git
```

Then run:

```bash
melody plugins install
```

This clones each plugin repo, copies the platform sources into your Xcode and Android projects, and generates the plugin registry automatically. Run it again to pull updates.

### Creating a plugin

A plugin repo needs a `plugin.yaml` manifest at the root:

```yaml
name: keychain
version: 1.0.0
description: Secure keychain/keystore access
ios:
  sources:
    - iOS/KeychainPlugin.swift
  frameworks:
    - Security
android:
  sources:
    - android/KeychainPlugin.kt
lua:
  - lua/keychain.lua
```

The `ios.sources` and `android.sources` paths point to native implementations. Optional `lua` files get bundled as a prelude that runs before any screen loads — useful for helper functions.

Plugin repo structure:

```
melody-plugin-keychain/
  plugin.yaml
  iOS/
    KeychainPlugin.swift
  android/
    KeychainPlugin.kt
  lua/
    keychain.lua          # optional Lua helpers
```

### Writing the native code

#### Swift (iOS / macOS / tvOS / visionOS)

```swift
import Runtime

class KeychainPlugin: MelodyPlugin {
    var name = "keychain"

    func register(vm: LuaVM) {
        vm.registerPluginFunction(namespace: "keychain", name: "get") { args in
            let key = args.first?.stringValue ?? ""
            // ... keychain lookup
            return .string(value)
        }
        vm.registerPluginFunction(namespace: "keychain", name: "set") { args in
            // ... keychain write
            return .bool(true)
        }
    }
}
```

#### Kotlin (Android)

```kotlin
class KeychainPlugin : MelodyPlugin {
    override val name = "keychain"

    override fun register(vm: LuaVM) {
        vm.registerPluginFunction("keychain", "get") { args ->
            val key = args.firstOrNull()?.stringValue ?: ""
            // ... keystore lookup
            LuaValue.String(value)
        }
        vm.registerPluginFunction("keychain", "set") { args ->
            // ... keystore write
            LuaValue.Bool(true)
        }
    }
}
```

Same Lua API on both sides:

```lua
local token = keychain.get("auth_token")
keychain.set("auth_token", newToken)
```

## CLI

| Command | What it does |
|---------|-------------|
| `melody create <name>` | Scaffold a new project with Xcode + Android boilerplate |
| `melody dev` | Start dev server with hot reload over WebSocket |
| `melody build` | Bundle app for distribution |
| `melody validate` | Check your YAML for errors |

## Project Structure

```
my-app/
  app.yaml               # App config, theme, screens
  app.lua                 # Shared Lua helpers (optional, loaded via app.lua field)
  screens/                # Screen files (auto-loaded *.yaml)
  components/             # Reusable components (*.component.yaml)
  assets/                 # Images and static files
  icon.png                # App icon (1024x1024, optional)
  MyApp.xcodeproj/        # Generated Xcode project
  android/                # Generated Android project
```

## Platform Support

| Platform | Runtime | Min Version |
|----------|---------|-------------|
| iOS | SwiftUI | 17+ |
| iPadOS | SwiftUI | 17+ |
| macOS | SwiftUI | 14+ |
| tvOS | SwiftUI | 26+ |
| visionOS | SwiftUI | 2+ |
| Android | Jetpack Compose | API 26+ |

Requires Swift 6.2+ and Xcode 26+ for Apple platforms.

## As a dependency

Add Melody as a Swift Package:

```swift
dependencies: [
    .package(url: "https://github.com/aspect-build/melody.git", from: "0.1.0"),
]
```

Then add `Core` and `Runtime` to your target:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "Core", package: "Melody"),
        .product(name: "Runtime", package: "Melody"),
    ]
)
```

## License

MIT
