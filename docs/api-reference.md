# API Reference

Complete reference for every component, attribute, style property, and Lua API in Melody.

---

## Table of Contents

- [App Configuration](#app-configuration)
- [Screens](#screens)
- [Components](#components)
  - [Common Attributes](#common-attributes)
  - [text](#text)
  - [button](#button)
  - [stack](#stack)
  - [image](#image)
  - [input](#input)
  - [toggle](#toggle)
  - [picker](#picker)
  - [datepicker](#datepicker)
  - [slider](#slider)
  - [stepper](#stepper)
  - [list](#list)
  - [grid](#grid)
  - [form](#form)
  - [section](#section)
  - [chart](#chart)
  - [menu](#menu)
  - [link](#link)
  - [disclosure](#disclosure)
  - [progress](#progress)
  - [activity](#activity)
  - [scroll](#scroll)
  - [spacer](#spacer)
  - [divider](#divider)
  - [state_provider](#state_provider)
  - [Custom Components](#custom-components)
- [Style](#style)
- [Lua API](#lua-api)
- [Enums](#enums)

---

## App Configuration

The top-level `app.yaml` file defines your app:

```yaml
app:
  name: MyApp
  id: com.example.myapp
  theme: { ... }
  window: { ... }
  lua: |
    -- shared Lua code loaded in every screen

screens:
  - id: home
    path: /
    body: [...]

components:
  Card:
    props: { ... }
    body: [...]
```

### `app`

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | yes | App display name |
| `id` | string | no | Bundle identifier (e.g. `com.example.app`) |
| `theme` | [ThemeConfig](#themeconfig) | no | Color theme |
| `window` | [WindowConfig](#windowconfig) | no | macOS window sizing |
| `lua` | string | no | Shared Lua code loaded before every screen |
| `plugins` | map | no | Plugin declarations (`name: gitUrl`) |

### ThemeConfig

| Attribute | Type | Description |
|-----------|------|-------------|
| `primary` | string | Primary color (hex) |
| `secondary` | string | Secondary color (hex) |
| `background` | string | Background color (hex) |
| `colorScheme` | string | `"light"`, `"dark"`, or `"system"` |
| `colors` | map | Custom named colors (`name: "#hex"`) |
| `dark` | [ThemeModeOverride](#thememodeoverride) | Dark mode color overrides |
| `light` | [ThemeModeOverride](#thememodeoverride) | Light mode color overrides |

### ThemeModeOverride

| Attribute | Type | Description |
|-----------|------|-------------|
| `primary` | string | Primary color override (hex) |
| `secondary` | string | Secondary color override (hex) |
| `background` | string | Background color override (hex) |
| `colors` | map | Custom color overrides |

### WindowConfig

macOS window sizing.

| Attribute | Type | Description |
|-----------|------|-------------|
| `minWidth` | number | Minimum window width |
| `minHeight` | number | Minimum window height |
| `idealWidth` | number | Preferred window width |
| `idealHeight` | number | Preferred window height |

---

## Screens

A screen is a full page with its own state and lifecycle.

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
  body:
    - component: text
      text: "{{ state.user.name }}"
```

### Screen Attributes

| Attribute | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `id` | string | yes | — | Unique screen identifier |
| `path` | string | yes | — | Route path (supports `:param` segments) |
| `title` | string | no | — | Navigation bar title |
| `titleDisplayMode` | string | no | `"automatic"` | `"large"`, `"inline"`, or `"automatic"` |
| `wrapper` | string | no | `"vstack"` | `"vstack"`, `"scroll"`, or `"form"` |
| `formStyle` | string | no | `"automatic"` | `"automatic"`, `"grouped"`, or `"columns"` |
| `state` | map | no | — | Initial state values (strings, numbers, bools, null, arrays, tables) |
| `body` | array | no | — | Array of components (mutually exclusive with `tabs`) |
| `tabs` | array | no | — | Array of [TabDefinition](#tabdefinition) (mutually exclusive with `body`) |
| `tabStyle` | string | no | `"automatic"` | `"automatic"` or `"sidebarAdaptable"` |
| `toolbar` | array | no | — | Navigation bar buttons (component array) |
| `titleMenu` | array | no | — | Dropdown menu items on the title |
| `titleMenuBuilder` | string | no | — | Lua function building dynamic title menu |
| `search` | [SearchConfig](#searchconfig) | no | — | Search bar configuration |
| `scrollEnabled` | bool | no | `true` | Enable scrolling |
| `contentInset` | [ContentInset](#contentinset) | no | — | Top/bottom content insets |
| `onMount` | string | no | — | Lua code that runs when the screen appears |
| `onRefresh` | string | no | — | Lua code for pull-to-refresh |
| `showsLoadingIndicator` | bool | no | `true` | Show loading indicator during onMount |

### TabDefinition

```yaml
tabs:
  - id: home
    title: Home
    icon: house.fill
    screen: /home
    group: Main
    platforms: [ios, macos]
```

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string | yes | Unique tab identifier |
| `title` | string | yes | Tab bar label |
| `icon` | string | yes | SF Symbol name |
| `screen` | string | yes | Root screen path for this tab |
| `platforms` | array | no | Platform filter: `"ios"`, `"android"`, `"macos"`, `"desktop"` |
| `group` | string | no | Sidebar section name (for `sidebarAdaptable` style) |
| `visible` | expression | no | Lua expression for dynamic visibility |

### SearchConfig

```yaml
search:
  stateKey: query
  prompt: Search...
  onSubmit: |
    state.results = melody.fetch("/search?q=" .. state.query).data
```

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `stateKey` | string | yes | Binds search text to this state key |
| `prompt` | string | no | Placeholder text |
| `onSubmit` | string | no | Lua code on search submit |
| `placement` | string | no | `"bottomBar"` (iOS 26+) |
| `minimized` | bool | no | Collapse to button (iOS 26+) |

### ContentInset

| Attribute | Type | Description |
|-----------|------|-------------|
| `top` | number | Top inset |
| `bottom` | number | Bottom inset |
| `leading` | number | Leading inset |
| `trailing` | number | Trailing inset |
| `vertical` | number | Shorthand for top + bottom |
| `horizontal` | number | Shorthand for leading + trailing |

---

## Components

### Common Attributes

Every component supports these attributes:

| Attribute | Type | Description |
|-----------|------|-------------|
| `component` | string | **Required.** Component type name |
| `id` | string | Unique identifier |
| `visible` | expression | Lua expression — hides when false/nil |
| `disabled` | expression | Lua expression — disables interaction |
| `onTap` | string | Lua code executed on tap |
| `onHover` | string | Lua code executed on hover |
| `style` | [Style](#style) | Layout, typography, colors, effects |
| `contextMenu` | array | Long-press menu items ([ContextMenuItem](#contextmenuitem)) |
| `transition` | expression | Animation/transition effect |
| `background` | component | Background component |
| `shouldGrowToFitParent` | bool | Grow to fill available space |
| `usesSharedObjectTransition` | bool | Shared animation context |

#### ContextMenuItem

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `label` | string | yes | Menu item label |
| `systemImage` | string | no | SF Symbol icon |
| `style` | string | no | `"default"` or `"destructive"` |
| `onTap` | string | no | Lua code on tap |
| `section` | bool | no | Visual section divider |

---

### text

Display static or dynamic text.

```yaml
- component: text
  text: "{{ 'Hello, ' .. state.name }}"
  style:
    fontSize: 24
    fontWeight: bold
    color: "theme.primary"
    lineLimit: 2
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `text` | expression | Text content |

**Relevant style properties:** `fontSize`, `fontWeight`, `fontDesign`, `color`, `lineLimit`, `alignment`.

---

### button

Tappable action with a label and optional icon.

```yaml
- component: button
  label: Save
  systemImage: checkmark
  onTap: "saveData()"
  style:
    backgroundColor: "theme.primary"
    color: "#ffffff"
    padding: 16
    borderRadius: 14
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `label` | expression | Button text |
| `systemImage` | expression | SF Symbol icon |
| `onTap` | string | Lua code on tap |

When `backgroundColor` is set, the button expands to full width.

---

### stack

Layout container that arranges children in a direction.

```yaml
- component: stack
  direction: horizontal
  style:
    spacing: 12
    alignment: center
    padding: 16
  children:
    - component: text
      text: Left
    - component: spacer
    - component: text
      text: Right
```

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `direction` | expression | `"vertical"` | `"horizontal"`, `"vertical"`, `"z"` (or `"stacked"`) |
| `children` | array | — | Child components |

**Relevant style properties:** `spacing`, `alignment`, `padding`.

---

### image

SF Symbols or remote images.

```yaml
# SF Symbol
- component: image
  systemImage: heart.fill
  style:
    width: 32
    height: 32
    color: "theme.primary"

# Remote image
- component: image
  src: "{{ state.avatarUrl }}"
  style:
    width: 64
    height: 64
    borderRadius: 32
    contentMode: fill
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `systemImage` | expression | SF Symbol name |
| `src` | expression | Remote image URL |

**Relevant style properties:** `width`, `height`, `contentMode` (`"fit"` or `"fill"`), `borderRadius`, `color`.

---

### input

Text fields, secure fields, and text areas.

```yaml
- component: input
  placeholder: Email address
  inputType: email
  stateKey: email
  onChanged: "validate()"
  onSubmit: "submit()"
```

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `inputType` | string | `"text"` | `"text"`, `"email"`, `"url"`, `"number"`, `"phone"`, `"password"`, `"search"`, `"textarea"` |
| `placeholder` | expression | — | Placeholder text |
| `stateKey` | string | — | Binds value to this state key |
| `value` | expression | — | Manual value control (alternative to `stateKey`) |
| `onChanged` | string | — | Lua code when value changes (`value` holds new text) |
| `onSubmit` | string | — | Lua code on return/submit |

Use `stateKey` for automatic two-way binding, or `value` + `onChanged` for manual control.

---

### toggle

Boolean switch bound to state.

```yaml
- component: toggle
  label: Dark Mode
  stateKey: darkMode
  onChanged: "melody.storeSave('darkMode', tostring(state.darkMode))"
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `label` | expression | Toggle label |
| `stateKey` | string | State key to bind (boolean) |
| `onChanged` | string | Lua code when toggled |

---

### picker

Selection control — dropdown, segmented, or wheel.

```yaml
- component: picker
  label: Sort by
  stateKey: sortOrder
  pickerStyle: segmented
  options:
    - { label: Recent, value: recent }
    - { label: Name, value: name }
```

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `label` | expression | — | Picker label |
| `stateKey` | string | — | State key to bind (string) |
| `pickerStyle` | string | `"menu"` | `"menu"`, `"segmented"`, `"wheel"` |
| `options` | array or expression | — | Static array of `{label, value}` or expression (`"state.options"`) |
| `onChanged` | string | — | Lua code when selection changes |

---

### datepicker

Date and time selection.

```yaml
- component: datepicker
  label: Due date
  stateKey: dueDate
  datePickerStyle: graphical
  displayedComponents: datetime
```

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `label` | expression | — | Label text |
| `stateKey` | string | — | State key to bind (ISO 8601 string) |
| `datePickerStyle` | string | `"compact"` | `"compact"`, `"graphical"`, `"wheel"` |
| `displayedComponents` | string | `"date"` | `"date"`, `"time"`, `"datetime"` |
| `onChanged` | string | — | Lua code when date changes |

---

### slider

Range selection control.

```yaml
- component: slider
  stateKey: volume
  min: 0
  max: 100
  step: 5
```

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `stateKey` | string | — | State key to bind (number) |
| `min` | number | — | Minimum value |
| `max` | number | — | Maximum value |
| `step` | number | — | Step increment |
| `onChanged` | string | — | Lua code when value changes |

---

### stepper

Increment/decrement control.

```yaml
- component: stepper
  label: "{{ 'Quantity: ' .. tostring(state.qty) }}"
  stateKey: qty
  min: 1
  max: 99
  step: 1
```

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `label` | expression | — | Display label |
| `stateKey` | string | — | State key to bind (number) |
| `min` | number | — | Minimum value |
| `max` | number | — | Maximum value |
| `step` | number | — | Step increment |
| `onChanged` | string | — | Lua code when value changes |

---

### list

Dynamic scrollable list rendered with a Lua function.

```yaml
- component: list
  items: "state.contacts"
  direction: vertical
  lazy: true
  style:
    spacing: 8
  render: |
    local item = state._current_item
    return {
      component = "text",
      text = item.name
    }
```

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `items` | string | — | Reference to state array (`"state.items"`) |
| `render` | string | — | Lua function returning a component table |
| `direction` | expression | `"vertical"` | `"vertical"` or `"horizontal"` (carousel) |
| `lazy` | bool | — | Enable lazy rendering for performance |

Inside render functions:
- `state._current_item` — the current item
- `state._current_index` — 1-based index

---

### grid

Multi-column adaptive grid.

```yaml
- component: grid
  items: "state.photos"
  columns: 3
  style:
    spacing: 4
  render: |
    local item = state._current_item
    return {
      component = "image",
      src = item.url,
      style = { aspectRatio = 1, contentMode = "fill" }
    }
```

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `items` | string | — | Reference to state array |
| `render` | string | — | Lua function returning a component table |
| `columns` | expression | — | Number of columns |
| `minColumnWidth` | expression | — | Minimum column width (adaptive) |
| `maxColumnWidth` | expression | — | Maximum column width (adaptive) |
| `lazy` | bool | — | Enable lazy rendering |

---

### form

Native grouped form container. Best for settings screens.

```yaml
- component: form
  formStyle: grouped
  children:
    - component: section
      label: Account
      children:
        - component: toggle
          label: Notifications
          stateKey: notifications
```

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `formStyle` | string | `"automatic"` | `"automatic"`, `"grouped"`, `"columns"` |
| `children` | array | — | Child components (typically sections) |

You can also use `wrapper: form` on the screen itself instead of nesting a form component.

---

### section

Groups content with an optional header and footer.

```yaml
- component: section
  label: Recent
  footer: Updated 5 minutes ago
  children:
    - component: text
      text: Item 1
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `label` | expression | Section header text |
| `header` | array | Rich header (component array, alternative to `label`) |
| `footer` | expression | Footer text |
| `footerContent` | array | Rich footer (component array, alternative to `footer`) |
| `children` | array | Section content |

---

### chart

Data visualization with Swift Charts.

```yaml
# Bar chart
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
  style:
    height: 250
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `items` | string | Reference to data array |
| `marks` | array | Array of [MarkDefinition](#markdefinition) |
| `legendPosition` | string | `"automatic"`, `"hidden"`, `"bottom"`, `"top"`, `"leading"`, `"trailing"` |
| `hideXAxis` | bool | Hide X-axis labels |
| `hideYAxis` | bool | Hide Y-axis labels |
| `colors` | array | Custom color strings for marks |

#### MarkDefinition

| Attribute | Type | Applies To | Description |
|-----------|------|------------|-------------|
| `type` | string | all | **Required.** `"bar"`, `"line"`, `"point"`, `"area"`, `"rule"`, `"rectangle"`, `"sector"` |
| `xKey` | string | bar, line, point, area, rule | Data key for X-axis |
| `yKey` | string | bar, line, point, area, rule | Data key for Y-axis |
| `groupKey` | string | all | Group/series key |
| `angleKey` | string | sector | Data key for pie/donut angle |
| `xStartKey` | string | rule, rectangle | X range start key |
| `xEndKey` | string | rule, rectangle | X range end key |
| `yStartKey` | string | rule, rectangle | Y range start key |
| `yEndKey` | string | rule, rectangle | Y range end key |
| `label` | string | all | Mark label |
| `xValue` | string | rule | Fixed X position |
| `yValue` | number | rule | Fixed Y position |
| `innerRadius` | number | sector | Inner radius for donut (0.0–1.0) |
| `angularInset` | number | sector | Angle spacing in radians |
| `interpolation` | string | line | `"linear"`, `"catmullrom"`, `"cardinal"`, `"monotone"`, `"stepstart"`, `"stepcenter"`, `"stepend"` |
| `lineWidth` | number | line | Line thickness |
| `cornerRadius` | number | bar | Corner radius of bars |
| `symbolSize` | number | point | Point symbol size |
| `stacking` | string | bar, area | Stacking strategy |
| `color` | string | all | Fixed color for this mark |

---

### menu

Dropdown menu triggered by a button.

```yaml
- component: menu
  label: Actions
  systemImage: ellipsis.circle
  children:
    - component: button
      label: Edit
      systemImage: pencil
      onTap: "editItem()"
    - component: button
      label: Delete
      systemImage: trash
      onTap: "deleteItem()"
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `label` | expression | Button label |
| `systemImage` | expression | SF Symbol icon |
| `children` | array | Button components as menu items |

---

### link

Opens a URL in the system browser.

```yaml
- component: link
  label: View Docs
  url: "https://example.com/docs"
  systemImage: safari
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `label` | expression | Link text |
| `url` | expression | URL to open |
| `systemImage` | expression | SF Symbol icon |

---

### disclosure

Expandable/collapsible section.

```yaml
- component: disclosure
  label: Advanced Settings
  children:
    - component: toggle
      label: Debug Mode
      stateKey: debugMode
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `label` | expression | Header label |
| `children` | array | Collapsible content |

---

### progress

Determinate progress bar.

```yaml
- component: progress
  value: "{{ tostring(state.progress) }}"
  label: "{{ tostring(math.floor(state.progress * 100)) .. '%' }}"
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `value` | expression | Progress value (0.0–1.0) |
| `label` | expression | Label text |

---

### activity

Indeterminate loading spinner.

```yaml
- component: activity
  visible: "{{ state.loading }}"
```

No specific attributes beyond [Common Attributes](#common-attributes).

---

### scroll

Scrollable container.

```yaml
- component: scroll
  children:
    - component: text
      text: Long content here...
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `children` | array | Scrollable content |

---

### spacer

Flexible space that fills available room in a stack.

```yaml
- component: spacer
```

No specific attributes.

---

### divider

Visual separator line.

```yaml
- component: divider
```

No specific attributes.

---

### state_provider

Scoped local state for self-contained widgets. Children use `scope.key` instead of `state.key`.

```yaml
- component: state_provider
  localState:
    expanded: false
  children:
    - component: button
      label: "{{ scope.expanded and 'Hide' or 'Show' }}"
      onTap: "scope.expanded = not scope.expanded"
    - component: text
      visible: "{{ scope.expanded }}"
      text: Now you see me
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `localState` | map | Initial scoped state (`scope.key` in children) |
| `children` | array | Child components |

---

### Custom Components

Define reusable templates in the top-level `components` section:

```yaml
components:
  Badge:
    props:
      label: ""
      color: "theme.primary"
    body:
      - component: text
        text: "{{ props.label }}"
        style:
          fontSize: 12
          fontWeight: semibold
          color: "{{ props.color }}"
          paddingHorizontal: 10
          paddingVertical: 4
          borderRadius: 100
```

Use like any built-in component:

```yaml
- component: Badge
  props:
    label: "{{ state.status }}"
    color: "theme.success"
```

#### CustomComponentDefinition

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `props` | map | no | Default prop values |
| `body` | array | yes | Component template |

---

## Style

All components accept a `style` object for layout, typography, colors, and effects.

```yaml
style:
  fontSize: 16
  fontWeight: bold
  color: "theme.primary"
  backgroundColor: "#f5f5f5"
  padding: 16
  borderRadius: 12
  shadow:
    y: 2
    blur: 8
    color: "#00000020"
```

### Typography

| Property | Type | Values |
|----------|------|--------|
| `fontSize` | number/expression | Point size (e.g. `16`, `24`) |
| `fontWeight` | string | `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black` |
| `fontDesign` | string | `default`, `monospaced`, `rounded`, `serif` |
| `lineLimit` | int/expression | Max lines (`0` = unlimited) |

### Colors

| Property | Type | Description |
|----------|------|-------------|
| `color` | expression | Text/foreground color. Hex (`"#6366f1"`) or theme reference (`"theme.primary"`) |
| `backgroundColor` | expression | Background color |
| `borderColor` | expression | Border color |

### Padding

| Property | Type | Description |
|----------|------|-------------|
| `padding` | number/expression | All sides equally |
| `paddingTop` | number/expression | Top only |
| `paddingBottom` | number/expression | Bottom only |
| `paddingLeft` | number/expression | Left only |
| `paddingRight` | number/expression | Right only |
| `paddingHorizontal` | number/expression | Left + right |
| `paddingVertical` | number/expression | Top + bottom |

### Margin

| Property | Type | Description |
|----------|------|-------------|
| `margin` | number/expression | All sides equally |
| `marginTop` | number/expression | Top only |
| `marginBottom` | number/expression | Bottom only |
| `marginLeft` | number/expression | Left only |
| `marginRight` | number/expression | Right only |
| `marginHorizontal` | number/expression | Left + right |
| `marginVertical` | number/expression | Top + bottom |

### Sizing

| Property | Type | Description |
|----------|------|-------------|
| `width` | number/expression | Fixed width |
| `height` | number/expression | Fixed height |
| `minWidth` | number/expression | Minimum width |
| `minHeight` | number/expression | Minimum height |
| `maxWidth` | number/expression | Maximum width |
| `maxHeight` | number/expression | Maximum height |
| `aspectRatio` | number/expression | Width/height ratio |

### Borders

| Property | Type | Description |
|----------|------|-------------|
| `borderRadius` | number/expression | Corner radius |
| `cornerRadius` | number/expression | Alias for `borderRadius` |
| `borderWidth` | number/expression | Border thickness |

### Layout

| Property | Type | Values |
|----------|------|--------|
| `spacing` | number/expression | Space between children (stacks) |
| `alignment` | expression | See [ViewAlignment](#viewalignment) values |
| `contentMode` | string | `"fit"` (default), `"fill"` |
| `overflow` | string | `"hidden"` (default), `"visible"` |
| `layoutPriority` | number/expression | Layout priority in stacks |

### Effects

| Property | Type | Description |
|----------|------|-------------|
| `opacity` | number/expression | Transparency (0.0–1.0) |
| `scale` | number/expression | Scale factor (1.0 = normal) |
| `rotation` | number/expression | Rotation in degrees |
| `shadow` | [ShadowStyle](#shadowstyle) | Drop shadow |
| `animation` | string | `"spring"`, `"easeInOut"`, `"linear"`, `"easeIn"`, `"easeOut"` |

### ShadowStyle

| Property | Type | Description |
|----------|------|-------------|
| `x` | number | Horizontal offset |
| `y` | number | Vertical offset |
| `blur` | number | Blur radius |
| `color` | string | Shadow color (hex) |

### Dynamic Style Expressions

Most style values are static. For dynamic styles, use the `expressions` sub-object:

```yaml
style:
  opacity: 1
  fontSize: 16
  expressions:
    opacity: "state.visible and 1 or 0"
    fontSize: "state.isLarge and 24 or 16"
```

---

## Lua API

### Globals

Available in every Lua script:

| Global | Type | Description |
|--------|------|-------------|
| `state` | table | Screen state (read/write — triggers UI updates) |
| `params` | table | Route parameters (read-only, always strings) |
| `props` | table | Custom component props (read-only) |
| `scope` | table | Component-local state (inside `state_provider`) |
| `theme` | table | Theme colors as `{name = "#hex"}` |
| `platform` | string | `"ios"`, `"macos"`, or `"android"` |
| `isDesktop` | bool | `true` on macOS |
| `isDebug` | bool | `true` in debug builds |
| `context.isSheet` | bool | `true` when presented as a sheet |
| `value` | string | New text value in `onChanged` handlers |

### melody.navigate(path, props?)

Push a screen onto the navigation stack.

```lua
melody.navigate("/profile/123")
melody.navigate("/detail", { id = 42 })
```

### melody.goBack()

Pop the current screen.

```lua
melody.goBack()
```

### melody.replace(path, options?)

Replace the entire navigation stack. Use for post-login redirects.

```lua
melody.replace("/home")
melody.replace("/home", { local = true })  -- tab-only: replaces just this tab's stack
```

### melody.switchTab(tabId)

Switch to a tab programmatically.

```lua
melody.switchTab("search")
```

### melody.sheet(path, options?)

Present a screen as a modal sheet.

```lua
melody.sheet("/edit-profile")
melody.sheet("/filter", { detent = "medium" })       -- half sheet
melody.sheet("/onboarding", { style = "fullscreen" }) -- full screen
```

**Options:**

| Option | Values | Description |
|--------|--------|-------------|
| `detent` | `"medium"`, `"large"` | Initial sheet height |
| `style` | `"sheet"`, `"fullscreen"` | Presentation style |

### melody.dismiss()

Dismiss the current sheet.

```lua
melody.dismiss()
```

### melody.alert(title, message, buttons?)

Show a native alert dialog.

```lua
-- Simple alert
melody.alert("Done!", "Your changes have been saved.")

-- With actions
melody.alert("Delete?", "This can't be undone.", {
  { title = "Cancel", style = "cancel" },
  { title = "Delete", style = "destructive", onTap = "deleteItem()" }
})
```

**Button fields:**

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Button text |
| `style` | string | `"default"`, `"destructive"`, `"cancel"` |
| `onTap` | string | Lua code on tap |

### melody.fetch(url, options?)

Make an HTTP request. Returns a response table.

```lua
local res = melody.fetch("https://api.example.com/data")
if res.ok then
  state.items = res.data
end

-- POST request
local res = melody.fetch("https://api.example.com/items", {
  method = "POST",
  headers = { ["Content-Type"] = "application/json" },
  body = json.encode({ name = state.name })
})
```

### melody.fetchAll(requests)

Make multiple HTTP requests concurrently.

```lua
local results = melody.fetchAll({
  { url = "/api/user" },
  { url = "/api/posts" }
})
```

### melody.storeSave(key, value)

Persist a value to disk (survives app restarts).

```lua
melody.storeSave("token", res.data.token)
```

### melody.storeSet(key, value)

Store a value in session memory (lost on restart).

```lua
melody.storeSet("temp", value)
```

### melody.storeGet(key)

Read a value from storage.

```lua
local token = melody.storeGet("token")
```

### melody.emit(event, data?)

Broadcast an event to all screens.

```lua
melody.emit("cartUpdated", { count = #state.items })
```

### melody.on(event, callback)

Listen for an event.

```lua
melody.on("cartUpdated", function(data)
  state.cartCount = data.count
end)
```

### melody.setInterval(fn, ms)

Start a repeating timer. Returns an interval ID.

```lua
local id = melody.setInterval(function()
  state.elapsed = state.elapsed + 1
end, 1000)
```

### melody.clearInterval(id)

Cancel a repeating timer.

```lua
melody.clearInterval(id)
```

### melody.wsConnect(url)

Open a WebSocket connection.

```lua
melody.wsConnect("wss://example.com/ws")
```

### melody.log(msg)

Log a message to the console / dev overlay.

```lua
melody.log("Debug: " .. tostring(state.count))
```

### melody.copyToClipboard(text)

Copy text to the system clipboard.

```lua
melody.copyToClipboard(state.shareUrl)
```

### melody.setTitle(title)

Update the screen title dynamically.

```lua
melody.setTitle("Chat (" .. tostring(state.unread) .. ")")
```

### melody.trustHost(hostname)

Trust a self-signed SSL certificate for a hostname.

```lua
melody.trustHost("dev.local")
```

### melody.clearCookies()

Clear all HTTP cookies.

```lua
melody.clearCookies()
```

---

## Enums

### ViewAlignment

Used in `style.alignment`:

`center`, `top`, `bottom`, `leading`, `trailing`, `left`, `right`, `topLeading`, `topLeft`, `topTrailing`, `topRight`, `bottomLeading`, `bottomLeft`, `bottomTrailing`, `bottomRight`

### DirectionAxis

Used in `direction` for stacks and lists:

| Value | Description |
|-------|-------------|
| `vertical` | Top to bottom (default) |
| `horizontal` | Leading to trailing |
| `z` / `stacked` | Layered on top of each other |

### InputVariant

Used in `inputType` for input components:

`text`, `password`, `secure`, `textarea`, `url`, `email`, `number`, `phone`, `search`

### PickerVariant

Used in `pickerStyle`:

| Value | Description |
|-------|-------------|
| `menu` | Dropdown menu (default) |
| `segmented` | Segmented control |
| `wheel` | Scroll wheel |

### DatePickerVariant

Used in `datePickerStyle`:

| Value | Description |
|-------|-------------|
| `compact` | Compact inline (default) |
| `graphical` | Full calendar |
| `wheel` | Scroll wheels |

### DateDisplayComponents

Used in `displayedComponents`:

| Value | Description |
|-------|-------------|
| `date` | Date only (default) |
| `time` | Time only |
| `datetime` | Date and time |

### FormVariant

Used in `formStyle`:

| Value | Description |
|-------|-------------|
| `automatic` | Platform default |
| `grouped` | Grouped sections |
| `columns` | Multi-column layout |

### ChartMarkType

Used in chart `marks[].type`:

`bar`, `line`, `point`, `area`, `rule`, `rectangle`, `sector`

### ChartInterpolation

Used in chart line mark `interpolation`:

`linear`, `catmullrom`, `cardinal`, `monotone`, `stepstart`, `stepcenter`, `stepend`

### ChartLegendPosition

Used in chart `legendPosition`:

`automatic`, `hidden`, `bottom`, `top`, `leading`, `trailing`

### ScreenWrapper

Used in screen `wrapper`:

| Value | Description |
|-------|-------------|
| `vstack` | Vertical stack (default) |
| `scroll` | Scrollable container |
| `form` | Native form container |

### TitleDisplayMode

Used in screen `titleDisplayMode`:

| Value | Description |
|-------|-------------|
| `automatic` | Platform decides (default) |
| `large` | Large title |
| `inline` | Inline title |

### SheetStyle

Used in `melody.sheet()` options:

| Value | Description |
|-------|-------------|
| `sheet` | Standard sheet (default) |
| `fullscreen` | Full-screen modal |

### SheetDetent

Used in `melody.sheet()` options:

| Value | Description |
|-------|-------------|
| `medium` | Half sheet (draggable to full) |
| `large` | Full height (default) |

### TabStyle

Used in screen `tabStyle`:

| Value | Description |
|-------|-------------|
| `automatic` | Platform default |
| `sidebarAdaptable` | Sidebar on iPad/Mac, tab bar on iPhone |

### ColorScheme

Used in theme `colorScheme`:

| Value | Description |
|-------|-------------|
| `system` | Follow system setting |
| `light` | Force light mode |
| `dark` | Force dark mode |

### AlertButtonVariant

Used in alert button `style`:

| Value | Description |
|-------|-------------|
| `default` | Standard button |
| `destructive` | Red destructive action |
| `cancel` | Cancel/dismiss |

### AnimationStyle

Used in `style.animation`:

`spring`, `easeInOut`, `linear`, `easeIn`, `easeOut`

### ContentMode

Used in `style.contentMode`:

| Value | Description |
|-------|-------------|
| `fit` | Scale to fit (default) |
| `fill` | Scale to fill |

### OverflowMode

Used in `style.overflow`:

| Value | Description |
|-------|-------------|
| `hidden` | Clip overflow (default) |
| `visible` | Show overflow |
