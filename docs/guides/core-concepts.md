# Core Concepts

The mental model for Melody: YAML describes what's on screen, Lua handles what happens.

## App structure

Every Melody app starts with an `app.yaml`:

```yaml
app:
  name: MyApp
  id: com.example.myapp
  theme:
    primary: "#6366f1"
  lua: |
    -- shared code that runs in every screen's VM

screens:
  - id: home
    path: /
    title: Home
    body:
      - component: text
        text: Hello World

components:
  Card:
    props:
      title: ""
    body:
      - component: text
        text: "{{ props.title }}"
```

Three top-level sections:
- **`app`** — name, bundle ID, theme, shared Lua
- **`screens`** — your app's screens
- **`components`** — reusable templates

You can split screens into separate files in the `screens/` directory and components into `*.component.yaml` files in `components/`. They're loaded automatically.

## Screens

A screen is a full page of content with its own state and lifecycle:

```yaml
- id: profile
  path: /profile/:id
  title: Profile
  titleDisplayMode: large
  wrapper: scroll
  state:
    user: null
    loading: true

  onMount: |
    local res = melody.fetch("https://api.example.com/user/" .. params.id)
    if res.ok then state.user = res.data end
    state.loading = false

  onRefresh: |
    -- pull-to-refresh handler

  body:
    - component: text
      text: "{{ state.user.name }}"
```

Key screen properties:

| Property | What it does |
|----------|-------------|
| `id` | Unique identifier |
| `path` | Route path (supports `:param` segments) |
| `title` | Navigation bar title |
| `titleDisplayMode` | `large`, `inline`, or `automatic` |
| `wrapper` | `vstack` (default), `scroll`, or `form` |
| `state` | Initial state values |
| `onMount` | Lua that runs when the screen appears |
| `onRefresh` | Enables pull-to-refresh |
| `body` | Array of components |
| `toolbar` | Navigation bar buttons |
| `search` | Search bar configuration |
| `tabs` | Makes this a tab container (mutually exclusive with `body`) |

## Components

Components are the building blocks. Every component has a `component` field that determines its type:

```yaml
- component: stack
  direction: horizontal
  style:
    spacing: 12
    padding: 16
  children:
    - component: image
      systemImage: star.fill
      style:
        width: 24
        height: 24
        color: "theme.primary"
    - component: text
      text: "{{ state.rating }}"
      style:
        fontSize: 17
        fontWeight: semibold
```

All components share these fields:

| Field | What it does |
|-------|-------------|
| `visible` | Lua expression — hides when false/nil |
| `disabled` | Lua expression — disables interaction |
| `style` | Layout, typography, colors, effects |
| `onTap` | Lua code on tap |
| `onHover` | Lua code on hover |
| `contextMenu` | Long-press menu items |

See the [Components Guide](./components.md) for every component and its properties.

## State

Each screen has its own reactive state. Assign to `state.key` in Lua and any component referencing that key re-renders automatically.

```yaml
state:
  count: 0
  name: "World"
  items: null
  loading: true
```

State supports strings, numbers, booleans, null, arrays, and tables. Initialize everything with sensible defaults.

```lua
-- in onMount or event handlers
state.count = state.count + 1
state.user = res.data
state.items = { { title = "First" }, { title = "Second" } }
```

Melody tracks state at the key level — only components that reference `state.count` re-render when `count` changes. No virtual DOM, no diffing.

### Persistent storage

State resets when you leave a screen. For data that survives across screens and app launches:

```lua
melody.storeSave("token", value)     -- persist to disk
melody.storeSet("temp", value)       -- session only (in-memory)
local token = melody.storeGet("token")
```

### Cross-screen events

When multiple screens need to react to the same thing:

```lua
-- screen A: broadcast
melody.emit("cartUpdated", { count = #state.items })

-- screen B: listen
melody.on("cartUpdated", function(data)
  state.cartCount = data.count
end)
```

## Expressions

Use `{{ }}` to evaluate Lua inline in any string property:

```yaml
text: "{{ 'Hello, ' .. state.name }}"
visible: "{{ state.isLoggedIn }}"
```

**Static strings don't need expressions.** Just write `text: "Hello World"` — the runtime detects literals automatically. Only use expressions when mixing text with state:

```yaml
text: "Hello World"                          # static, just works
text: "{{ 'Count: ' .. state.count }}"       # dynamic, needs {{ }}
```

### Style expressions

Most style values are static. For dynamic styles, use the `expressions` sub-object:

```yaml
style:
  opacity: 1
  fontSize: 16
  expressions:
    opacity: "state.visible and 1 or 0"
    fontSize: "state.isLarge and 24 or 16"
```

Color fields (`color`, `backgroundColor`, `borderColor`) accept `theme.*` references directly:

```yaml
style:
  color: "theme.textPrimary"
  backgroundColor: "theme.surface"
```

## Lua globals

These are available in every script:

| Global | What it is |
|--------|-----------|
| `state` | Screen state (read/write, triggers UI updates) |
| `params` | Route params (read-only, always strings) |
| `props` | Custom component props (read-only) |
| `scope` | Component-local state (inside `state_provider`) |
| `theme` | Theme colors as a table |
| `platform` | `"ios"`, `"macos"`, or `"android"` |
| `isDesktop` | `true` on macOS |
| `isDebug` | `true` in debug builds |
| `context.isSheet` | `true` when presented as a sheet |
| `value` | New text value in `onChanged` handlers |

Plus the full `melody.*` API — see the [README](../README.md#lua-api) for the complete reference.
