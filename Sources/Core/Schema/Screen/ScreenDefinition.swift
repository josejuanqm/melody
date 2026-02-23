import Foundation


/// A single screen in the app
public struct ScreenDefinition: Codable, Sendable {
    public var id: String
    public var path: String
    public var title: String?
    public var titleDisplayMode: String?
    public var state: [String: StateValue]?
    public var onMount: String?
    public var body: [ComponentDefinition]?
    public var tabs: [TabDefinition]?
    public var tabStyle: String?
    public var toolbar: [ComponentDefinition]?
    public var titleMenu: [ComponentDefinition]?
    public var titleMenuBuilder: String?
    public var search: SearchConfig?
    public var scrollEnabled: Bool?
    public var wrapper: String?
    public var formStyle: String?
    public var contentInset: ContentInset?
    public var onRefresh: String?
    public var showsLoadingIndicator: Bool?

    public init(
        id: String,
        path: String,
        title: String? = nil,
        titleDisplayMode: String? = nil,
        state: [String: StateValue]? = nil,
        onMount: String? = nil,
        body: [ComponentDefinition]? = nil,
        tabs: [TabDefinition]? = nil,
        tabStyle: String? = nil,
        toolbar: [ComponentDefinition]? = nil,
        titleMenu: [ComponentDefinition]? = nil,
        titleMenuBuilder: String? = nil,
        search: SearchConfig? = nil,
        scrollEnabled: Bool? = nil,
        wrapper: String? = nil,
        formStyle: String? = nil,
        contentInset: ContentInset? = nil,
        onRefresh: String? = nil,
        showsLoadingIndicator: Bool? = nil
    ) {
        self.id = id
        self.path = path
        self.title = title
        self.titleDisplayMode = titleDisplayMode
        self.state = state
        self.onMount = onMount
        self.body = body
        self.tabs = tabs
        self.tabStyle = tabStyle
        self.toolbar = toolbar
        self.titleMenu = titleMenu
        self.titleMenuBuilder = titleMenuBuilder
        self.search = search
        self.scrollEnabled = scrollEnabled ?? true
        self.wrapper = wrapper
        self.formStyle = formStyle
        self.contentInset = contentInset
        self.onRefresh = onRefresh
        self.showsLoadingIndicator = showsLoadingIndicator ?? true
    }
}
