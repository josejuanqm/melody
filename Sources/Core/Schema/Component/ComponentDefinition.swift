import Foundation

/// Declarative description of a UI component with its properties, style, children, and event handlers.
public struct ComponentDefinition: Codable, Sendable, Equatable, Hashable {
    public var component: String
    public var id: String?

    public var text: Value<String>?
    public var label: Value<String>?
    public var visible: Value<Bool>?
    public var disabled: Value<Bool>?
    public var value: Value<String>?
    public var src: Value<String>?
    public var systemImage: Value<String>?
    public var url: Value<String>?
    public var placeholder: Value<String>?
    public var transition: Value<String>?
    public var columns: Value<Double>?
    public var minColumnWidth: Value<Double>?
    public var maxColumnWidth: Value<Double>?
    public var direction: Value<DirectionAxis>?
    public var props: [String: Value<String>]?

    public var items: String?
    public var render: String?
    public var onTap: String?
    public var onChanged: String?
    public var onSubmit: String?
    public var onHover: String?

    public var usesSharedObjectTransition: Bool?
    public var inputType: String?
    public var style: ComponentStyle?
    public var children: [ComponentDefinition]?
    public var bindings: [String]?
    public var localState: [String: StateValue]?
    public var background: ComponentRef?
    public var stateKey: String?
    public var min: Double?
    public var max: Double?
    public var step: Double?
    public var options: OptionsSource?
    public var pickerStyle: String?
    public var datePickerStyle: String?
    public var displayedComponents: String?
    public var header: ComponentHeaderFooterContent?
    public var footer: ComponentHeaderFooterContent?
    public var formStyle: String?
    public var shouldGrowToFitParent: Bool?
    public var contextMenu: [ContextMenuItem]?
    public var lazy: Bool?
    public var marks: [MarkDefinition]?
    public var legendPosition: String?
    public var hideXAxis: Bool?
    public var hideYAxis: Bool?
    public var colors: [String]?

    public init(
        component: String,
        id: String? = nil,
        text: Value<String>? = nil,
        label: Value<String>? = nil,
        visible: Value<Bool>? = nil,
        disabled: Value<Bool>? = nil,
        value: Value<String>? = nil,
        src: Value<String>? = nil,
        systemImage: Value<String>? = nil,
        url: Value<String>? = nil,
        placeholder: Value<String>? = nil,
        transition: Value<String>? = nil,
        columns: Value<Double>? = nil,
        minColumnWidth: Value<Double>? = nil,
        maxColumnWidth: Value<Double>? = nil,
        direction: Value<DirectionAxis>? = nil,
        props: [String: Value<String>]? = nil,
        items: String? = nil,
        render: String? = nil,
        onTap: String? = nil,
        onChanged: String? = nil,
        onSubmit: String? = nil,
        onHover: String? = nil,
        usesSharedObjectTransition: Bool? = nil,
        inputType: String? = nil,
        style: ComponentStyle? = nil,
        children: [ComponentDefinition]? = nil,
        bindings: [String]? = nil,
        localState: [String: StateValue]? = nil,
        background: ComponentRef? = nil,
        stateKey: String? = nil,
        min: Double? = nil,
        max: Double? = nil,
        step: Double? = nil,
        options: OptionsSource? = nil,
        pickerStyle: String? = nil,
        datePickerStyle: String? = nil,
        displayedComponents: String? = nil,
        header: ComponentHeaderFooterContent? = nil,
        footer: ComponentHeaderFooterContent? = nil,
        formStyle: String? = nil,
        shouldGrowToFitParent: Bool? = nil,
        contextMenu: [ContextMenuItem]? = nil,
        lazy: Bool? = nil,
        marks: [MarkDefinition]? = nil,
        legendPosition: String? = nil,
        hideXAxis: Bool? = nil,
        hideYAxis: Bool? = nil,
        colors: [String]? = nil
    ) {
        self.component = component
        self.id = id
        self.text = text
        self.label = label
        self.visible = visible
        self.disabled = disabled
        self.value = value
        self.src = src
        self.systemImage = systemImage
        self.url = url
        self.placeholder = placeholder
        self.transition = transition
        self.columns = columns
        self.minColumnWidth = minColumnWidth
        self.maxColumnWidth = maxColumnWidth
        self.direction = direction
        self.props = props
        self.items = items
        self.render = render
        self.onTap = onTap
        self.onChanged = onChanged
        self.onSubmit = onSubmit
        self.onHover = onHover
        self.usesSharedObjectTransition = usesSharedObjectTransition
        self.inputType = inputType
        self.style = style
        self.children = children
        self.bindings = bindings
        self.localState = localState
        self.background = background
        self.stateKey = stateKey
        self.min = min
        self.max = max
        self.step = step
        self.options = options
        self.pickerStyle = pickerStyle
        self.datePickerStyle = datePickerStyle
        self.displayedComponents = displayedComponents
        self.header = header
        self.footer = footer
        self.formStyle = formStyle
        self.shouldGrowToFitParent = shouldGrowToFitParent
        self.contextMenu = contextMenu
        self.lazy = lazy
        self.marks = marks
        self.legendPosition = legendPosition
        self.hideXAxis = hideXAxis
        self.hideYAxis = hideYAxis
        self.colors = colors
    }

    private enum CodingKeys: String, CodingKey {
        case component, id, text, label, visible, disabled, value, src, systemImage, url
        case placeholder, transition, columns, minColumnWidth, maxColumnWidth
        case direction, props, items, render, onTap, onChanged, onSubmit, onHover
        case usesSharedObjectTransition, inputType, style, children, bindings, localState, background, stateKey
        case min, max, step, options, pickerStyle, datePickerStyle, displayedComponents
        case header, footer, formStyle, shouldGrowToFitParent, contextMenu
        case lazy, marks, legendPosition, hideXAxis, hideYAxis, colors
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        component = try c.decode(String.self, forKey: .component)
        id = try c.decodeIfPresent(String.self, forKey: .id)

        text = try c.decodeIfPresent(Value<String>.self, forKey: .text)
        label = try c.decodeIfPresent(Value<String>.self, forKey: .label)
        value = try c.decodeIfPresent(Value<String>.self, forKey: .value)
        src = try c.decodeIfPresent(Value<String>.self, forKey: .src)
        systemImage = try c.decodeIfPresent(Value<String>.self, forKey: .systemImage)
        url = try c.decodeIfPresent(Value<String>.self, forKey: .url)
        placeholder = try c.decodeIfPresent(Value<String>.self, forKey: .placeholder)
        transition = try c.decodeIfPresent(Value<String>.self, forKey: .transition)

        visible = Value.yamlDecode(from: c, key: .visible)
        disabled = Value.yamlDecode(from: c, key: .disabled)

        columns = Value.yamlDecode(from: c, key: .columns)
        minColumnWidth = Value.yamlDecode(from: c, key: .minColumnWidth)
        maxColumnWidth = Value.yamlDecode(from: c, key: .maxColumnWidth)

        direction = try c.decodeIfPresent(Value<DirectionAxis>.self, forKey: .direction)
        props = try c.decodeIfPresent([String: Value<String>].self, forKey: .props)

        items = try c.decodeIfPresent(String.self, forKey: .items)
        render = try c.decodeIfPresent(String.self, forKey: .render)
        onTap = try c.decodeIfPresent(String.self, forKey: .onTap)
        onChanged = try c.decodeIfPresent(String.self, forKey: .onChanged)
        onSubmit = try c.decodeIfPresent(String.self, forKey: .onSubmit)
        onHover = try c.decodeIfPresent(String.self, forKey: .onHover)
        usesSharedObjectTransition = try c.decodeIfPresent(Bool.self, forKey: .usesSharedObjectTransition)
        inputType = try c.decodeIfPresent(String.self, forKey: .inputType)
        style = try c.decodeIfPresent(ComponentStyle.self, forKey: .style)
        children = try c.decodeIfPresent([ComponentDefinition].self, forKey: .children)
        bindings = try c.decodeIfPresent([String].self, forKey: .bindings)
        localState = try c.decodeIfPresent([String: StateValue].self, forKey: .localState)
        background = try c.decodeIfPresent(ComponentRef.self, forKey: .background)
        stateKey = try c.decodeIfPresent(String.self, forKey: .stateKey)
        min = Value<Double>.yamlDecodeRaw(from: c, key: .min)
        max = Value<Double>.yamlDecodeRaw(from: c, key: .max)
        step = Value<Double>.yamlDecodeRaw(from: c, key: .step)
        options = try c.decodeIfPresent(OptionsSource.self, forKey: .options)
        pickerStyle = try c.decodeIfPresent(String.self, forKey: .pickerStyle)
        datePickerStyle = try c.decodeIfPresent(String.self, forKey: .datePickerStyle)
        displayedComponents = try c.decodeIfPresent(String.self, forKey: .displayedComponents)
        header = try c.decodeIfPresent(ComponentHeaderFooterContent.self, forKey: .header)
        footer = try c.decodeIfPresent(ComponentHeaderFooterContent.self, forKey: .footer)
        formStyle = try c.decodeIfPresent(String.self, forKey: .formStyle)
        shouldGrowToFitParent = try c.decodeIfPresent(Bool.self, forKey: .shouldGrowToFitParent)
        contextMenu = try c.decodeIfPresent([ContextMenuItem].self, forKey: .contextMenu)
        lazy = try c.decodeIfPresent(Bool.self, forKey: .lazy)
        marks = try c.decodeIfPresent([MarkDefinition].self, forKey: .marks)
        legendPosition = try c.decodeIfPresent(String.self, forKey: .legendPosition)
        hideXAxis = try c.decodeIfPresent(Bool.self, forKey: .hideXAxis)
        hideYAxis = try c.decodeIfPresent(Bool.self, forKey: .hideYAxis)
        colors = try c.decodeIfPresent([String].self, forKey: .colors)
    }
}
