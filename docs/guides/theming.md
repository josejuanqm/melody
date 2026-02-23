# Theming

Define your color palette once and reference it everywhere.

## Basic theme

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
      warning: "#ff9500"
      error: "#ff3b30"
```

`primary`, `secondary`, and `background` are top-level shortcuts. Everything else goes in `colors`.

## Using theme colors

### In YAML styles

```yaml
style:
  color: "theme.textPrimary"
  backgroundColor: "theme.surface"
  borderColor: "theme.border"
```

### In Lua

```lua
melody.log(theme.primary)   -- "#6366f1"
melody.log(theme.surface)   -- "#ffffff"
```

### In render functions

```lua
return {
  component = "text",
  text = item.title,
  style = { color = theme.textPrimary, fontSize = 16 }
}
```

## Adaptive dark/light mode

Add `dark` and `light` blocks to override colors per appearance:

```yaml
theme:
  primary: "#6366f1"
  background: "#f2f2f7"
  colors:
    surface: "#ffffff"
    textPrimary: "#000000"
    textSecondary: "#8e8e93"

  dark:
    background: "#000000"
    colors:
      surface: "#1c1c1e"
      textPrimary: "#ffffff"
      textSecondary: "#8e8e93"

  light:
    background: "#f2f2f7"
    colors:
      surface: "#ffffff"
      textPrimary: "#000000"
```

<img src="./images/light-mode.png" width="300"/>
<img src="./images/dark-mode.png" width="300"/>

Overrides merge on top of the base colors. Only specify what changes — anything you omit falls through from the base.

## Forcing a color scheme

```yaml
theme:
  colorScheme: dark    # or "light"
```

This locks the app to that appearance regardless of the system setting.

## Recommended palettes

| Vibe | Primary | Secondary |
|------|---------|-----------|
| Electric purple | `#6C5CE7` | `#A29BFE` |
| Ocean blue | `#0A84FF` | `#64D2FF` |
| Coral warm | `#FF6B6B` | `#FFA07A` |
| Mint fresh | `#00C9A7` | `#72F2EB` |
| Sunset | `#FF6348` | `#FFB142` |
| Rose | `#FF2D55` | `#FF6B8A` |
| Emerald | `#00C853` | `#69F0AE` |
| Slate pro | `#6366F1` | `#818CF8` |

## Tips

- Define every color in the theme. Don't scatter hex values across screens — if a color appears more than once, it belongs in `theme.colors`.
- The only exception is alpha variants (e.g., `"#6C5CE720"` for a tinted background) since theme colors don't support alpha directly.
- Use semantic names: `textPrimary`, `surface`, `danger` — not `darkGray` or `red`.
- Pick `colorScheme: dark` for media-heavy apps (video, music, photos). Pick `light` for productivity and content. Omit it to follow the system.
