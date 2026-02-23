import Foundation

/// Text input field variant determining keyboard, autocorrect, and secure entry behavior.
public enum InputVariant: String, Codable, Sendable, Equatable {
    case text
    case password
    case secure
    case textarea
    case url
    case email
    case number
    case phone
    case search

    public init(_ string: String?) {
        self = Self(rawValue: string?.lowercased() ?? "text") ?? .text
    }
}

/// Presentation style for picker controls.
public enum PickerVariant: String, Codable, Sendable, Equatable {
    case menu
    case segmented
    case wheel

    public init(_ string: String?) {
        self = Self(rawValue: string?.lowercased() ?? "menu") ?? .menu
    }
}

/// Presentation style for date picker controls.
public enum DatePickerVariant: String, Codable, Sendable, Equatable {
    case compact
    case graphical
    case wheel

    public init(_ string: String?) {
        self = Self(rawValue: string?.lowercased() ?? "compact") ?? .compact
    }
}

/// Date/time components shown in a date picker.
public enum DateDisplayComponents: String, Codable, Sendable, Equatable {
    case date
    case time
    case datetime

    public init(_ string: String?) {
        self = Self(rawValue: string?.lowercased() ?? "date") ?? .date
    }
}

/// Presentation style for form containers.
public enum FormVariant: String, Codable, Sendable, Equatable {
    case automatic
    case grouped
    case columns

    public init(_ string: String?) {
        self = Self(rawValue: string?.lowercased() ?? "automatic") ?? .automatic
    }
}

/// Container type wrapping a screen's body content.
public enum ScreenWrapper: String, Codable, Sendable, Equatable {
    case vstack
    case scroll
    case form

    public init(_ string: String?) {
        self = Self(rawValue: string?.lowercased() ?? "vstack") ?? .vstack
    }
}

/// UI component type identifier from the YAML schema.
public enum ComponentType: String, Codable, Sendable, Equatable {
    case text, button, group, stack, image, input, list, grid
    case stateProvider = "state_provider"
    case spacer, activity, toggle, divider, picker, slider
    case progress, stepper, datepicker, menu, link
    case disclosure, scroll, form, section, chart

    public init?(_ string: String?) {
        guard let string else { return nil }
        self.init(rawValue: string.lowercased())
    }
}

/// Chart mark type for Swift Charts rendering.
public enum ChartMarkType: String, Codable, Sendable, Equatable {
    case bar, line, point, area, rule, rectangle, sector

    public init(_ string: String?) {
        self = Self(rawValue: string?.lowercased() ?? "bar") ?? .bar
    }
}

/// Chart line interpolation method.
public enum ChartInterpolation: String, Codable, Sendable, Equatable {
    case linear
    case catmullRom = "catmullrom"
    case cardinal, monotone
    case stepStart = "stepstart"
    case stepCenter = "stepcenter"
    case stepEnd = "stepend"

    public init(_ string: String?) {
        self = Self(rawValue: string?.lowercased() ?? "linear") ?? .linear
    }
}

/// Chart legend visibility and position.
public enum ChartLegendPosition: String, Codable, Sendable, Equatable {
    case automatic, hidden, bottom, top, leading, trailing

    public init(_ string: String?) {
        self = Self(rawValue: string?.lowercased() ?? "automatic") ?? .automatic
    }
}

/// Sheet presentation style.
public enum SheetStyle: String, Codable, Sendable, Equatable {
    case sheet, fullscreen

    public init(_ string: String?) {
        self = Self(rawValue: string?.lowercased() ?? "sheet") ?? .sheet
    }
}

/// Sheet presentation detent size.
public enum SheetDetent: String, Codable, Sendable, Equatable {
    case medium, large

    public init(_ string: String?) {
        self = Self(rawValue: string?.lowercased() ?? "large") ?? .large
    }
}

/// Image content mode determining fill or fit behavior.
public enum ContentModeVariant: String, Codable, Sendable, Equatable {
    case fill, fit

    public init(_ string: String?) {
        self = Self(rawValue: string?.lowercased() ?? "fit") ?? .fit
    }
}

/// Navigation bar title display mode.
public enum TitleDisplayModeVariant: String, Codable, Sendable, Equatable {
    case inline, large, automatic

    public init(_ string: String?) {
        self = Self(rawValue: string?.lowercased() ?? "automatic") ?? .automatic
    }
}

/// Preferred color scheme for theming.
public enum ColorSchemePreference: String, Codable, Sendable, Equatable {
    case dark, light, system

    public init(_ string: String?) {
        self = Self(rawValue: string?.lowercased() ?? "system") ?? .system
    }
}

/// Content overflow behavior.
public enum OverflowMode: String, Codable, Sendable, Equatable {
    case hidden, visible

    public init(_ string: String?) {
        self = Self(rawValue: string?.lowercased() ?? "hidden") ?? .hidden
    }
}

/// Alert button role variant.
public enum AlertButtonVariant: String, Codable, Sendable, Equatable {
    case `default`, destructive, cancel

    public init(_ string: String?) {
        self = Self(rawValue: string?.lowercased() ?? "default") ?? .default
    }
}

/// Tab view presentation style.
public enum TabStyleVariant: String, Codable, Sendable, Equatable {
    case automatic, sidebaradaptable

    public init(_ string: String?) {
        self = Self(rawValue: string?.lowercased() ?? "automatic") ?? .automatic
    }
}

/// Toolbar item placement variant.
public enum ToolbarPlacementVariant: String, Codable, Sendable, Equatable {
    case automatic
    case bottomBar = "bottombar"

    public init(_ string: String?) {
        self = Self(rawValue: string?.lowercased() ?? "automatic") ?? .automatic
    }
}
