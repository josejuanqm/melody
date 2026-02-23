import Testing
import Foundation
@testable import Core

@Suite("AppParser")
struct AppParserTests {

    let parser = AppParser()

    @Test("Parses a minimal app definition")
    func parseMinimalApp() throws {
        let yaml = """
        app:
          name: Test
        screens:
          - id: home
            path: /
            body:
              - component: Text
                text: "Hello"
        """
        let app = try parser.parse(yaml)
        #expect(app.app.name == "Test")
        #expect(app.screens.count == 1)
        #expect(app.screens[0].id == "home")
        #expect(app.screens[0].path == "/")
        #expect(app.screens[0].body?.count == 1)
        #expect(app.screens[0].body?[0].component == "Text")
    }

    @Test("Parses theme config")
    func parseTheme() throws {
        let yaml = """
        app:
          name: Themed
          theme:
            primary: "#ff0000"
            secondary: "#00ff00"
        screens:
          - id: home
            path: /
            body: []
        """
        let app = try parser.parse(yaml)
        #expect(app.app.theme?.primary == "#ff0000")
        #expect(app.app.theme?.secondary == "#00ff00")
    }

    @Test("Parses screen state with mixed types")
    func parseState() throws {
        let yaml = """
        app:
          name: Stateful
        screens:
          - id: home
            path: /
            state:
              count: 0
              name: "World"
              active: true
              data: null
            body: []
        """
        let app = try parser.parse(yaml)
        let state = app.screens[0].state!

        if case .int(let v) = state["count"] { #expect(v == 0) }
        else { Issue.record("count should be int") }

        if case .string(let v) = state["name"] { #expect(v == "World") }
        else { Issue.record("name should be string") }

        if case .bool(let v) = state["active"] { #expect(v == true) }
        else { Issue.record("active should be bool") }

        if case .null = state["data"] { /* ok */ }
        else { Issue.record("data should be null") }
    }

    @Test("Parses component with children")
    func parseChildren() throws {
        let yaml = """
        app:
          name: Nested
        screens:
          - id: home
            path: /
            body:
              - component: Stack
                direction: vertical
                style:
                  spacing: 8
                children:
                  - component: Text
                    text: "Child 1"
                  - component: Text
                    text: "Child 2"
        """
        let app = try parser.parse(yaml)
        let stack = app.screens[0].body![0]
        #expect(stack.component == "Stack")
        #expect(stack.direction == .literal(.vertical))
        #expect(stack.style?.spacing == .literal(8))
        #expect(stack.children?.count == 2)
        #expect(stack.children?[0].text == .literal("Child 1"))
    }

    @Test("Parses component styles")
    func parseStyles() throws {
        let yaml = """
        app:
          name: Styled
        screens:
          - id: home
            path: /
            body:
              - component: Text
                text: "Styled"
                style:
                  fontSize: 24
                  fontWeight: bold
                  color: "#333"
                  backgroundColor: "#fff"
                  padding: 16
                  borderRadius: 12
        """
        let app = try parser.parse(yaml)
        let style = app.screens[0].body![0].style!
        #expect(style.fontSize == .literal(24))
        #expect(style.fontWeight == "bold")
        #expect(style.color == .literal("#333"))
        #expect(style.backgroundColor == .literal("#fff"))
        #expect(style.padding == .literal(16))
        #expect(style.borderRadius == .literal(12))
    }

    @Test("Parses onMount and onTap Lua blocks")
    func parseLuaBlocks() throws {
        let yaml = """
        app:
          name: Lua
        screens:
          - id: home
            path: /
            onMount: |
              state.count = 1
            body:
              - component: Button
                label: "Tap"
                onTap: |
                  state.count = state.count + 1
        """
        let app = try parser.parse(yaml)
        #expect(app.screens[0].onMount?.contains("state.count = 1") == true)
        #expect(app.screens[0].body?[0].onTap?.contains("state.count + 1") == true)
    }

    @Test("Parses multiple screens")
    func parseMultipleScreens() throws {
        let yaml = """
        app:
          name: Multi
        screens:
          - id: home
            path: /
            body:
              - component: Text
                text: "Home"
          - id: about
            path: /about
            title: About
            body:
              - component: Text
                text: "About"
        """
        let app = try parser.parse(yaml)
        #expect(app.screens.count == 2)
        #expect(app.screens[0].id == "home")
        #expect(app.screens[1].id == "about")
        #expect(app.screens[1].title == "About")
    }

    @Test("Parses reusable components section")
    func parseComponents() throws {
        let yaml = """
        app:
          name: Components
        components:
          PosterCard:
            props:
              poster: ""
              title: ""
              mediaType: "movie"
            body:
              - component: Stack
                direction: z
                children:
                  - component: Image
                    src: "{{ props.poster }}"
                  - component: Text
                    text: "{{ props.title }}"
        screens:
          - id: home
            path: /
            body:
              - component: PosterCard
                props:
                  poster: "{{ 'https://example.com/' .. state.movie.poster }}"
                  title: "{{ state.movie.title }}"
        """
        let app = try parser.parse(yaml)

        // Verify components section
        #expect(app.components != nil)
        #expect(app.components?.count == 1)

        let posterCard = app.components?["PosterCard"]
        #expect(posterCard != nil)

        // Verify props defaults
        let props = posterCard?.props
        if case .string(let v) = props?["poster"] { #expect(v == "") }
        else { Issue.record("poster should be string") }

        if case .string(let v) = props?["title"] { #expect(v == "") }
        else { Issue.record("title should be string") }

        if case .string(let v) = props?["mediaType"] { #expect(v == "movie") }
        else { Issue.record("mediaType should be string") }

        // Verify body
        #expect(posterCard?.body.count == 1)
        #expect(posterCard?.body[0].component == "Stack")
        #expect(posterCard?.body[0].children?.count == 2)
        #expect(posterCard?.body[0].children?[0].component == "Image")
        #expect(posterCard?.body[0].children?[1].component == "Text")
        #expect(posterCard?.body[0].children?[1].text == .expression("props.title"))

        // Verify usage in screen body
        let usage = app.screens[0].body![0]
        #expect(usage.component == "PosterCard")
        #expect(usage.props?["title"] == .expression("state.movie.title"))
    }

    @Test("Parses sample_app.yaml fixture file")
    func parseFixtureFile() throws {
        let fixtureURL = Bundle.module.url(forResource: "sample_app", withExtension: "yaml", subdirectory: "Fixtures")!
        let yaml = try String(contentsOf: fixtureURL, encoding: .utf8)
        let app = try parser.parse(yaml)
        #expect(app.app.name == "Test App")
        #expect(app.screens.count == 2)
        #expect(app.screens[0].state?["count"] != nil)
    }

    @Test("Parses {{ expression }} syntax")
    func parseExpressions() throws {
        let yaml = """
        app:
          name: Expressions
        screens:
          - id: home
            path: /
            body:
              - component: Text
                text: "{{ 'Hello, ' .. state.name }}"
                visible: "{{ state.count > 0 }}"
              - component: Text
                text: "Plain text"
        """
        let app = try parser.parse(yaml)
        let body = app.screens[0].body!
        #expect(body[0].text == .expression("'Hello, ' .. state.name"))
        #expect(body[0].visible == .expression("state.count > 0"))
        #expect(body[1].text == .literal("Plain text"))
    }

    @Test("Parses visible as bool literal")
    func parseVisibleBool() throws {
        let yaml = """
        app:
          name: Bool
        screens:
          - id: home
            path: /
            body:
              - component: Text
                text: "Hidden"
                visible: false
        """
        let app = try parser.parse(yaml)
        #expect(app.screens[0].body?[0].visible == .literal(false))
    }

    @Test("Parses style expressions with {{ }}")
    func parseStyleExpressions() throws {
        let yaml = """
        app:
          name: StyleExpr
        screens:
          - id: home
            path: /
            body:
              - component: Stack
                style:
                  opacity: "{{ state.isVisible and 1 or 0 }}"
                  maxWidth: full
                  spacing: 8
        """
        let app = try parser.parse(yaml)
        let style = app.screens[0].body![0].style!
        #expect(style.opacity == .expression("state.isVisible and 1 or 0"))
        #expect(style.maxWidth == .literal(-1))
        #expect(style.spacing == .literal(8))
    }
}
