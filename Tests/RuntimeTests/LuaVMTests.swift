import Testing
import Foundation
@testable import Runtime

@Suite("LuaVM")
struct LuaVMTests {

    @Test("Initializes a Lua VM")
    func initVM() throws {
        let vm = try LuaVM()
        _ = vm // just verify it doesn't throw
    }

    @Test("Executes a simple Lua script")
    func executeScript() throws {
        let vm = try LuaVM()
        let result = try vm.execute("return 1 + 2")
        #expect(result.numberValue == 3.0)
    }

    @Test("Evaluates string concatenation")
    func evalStringConcat() throws {
        let vm = try LuaVM()
        let result = try vm.evaluate("'Hello' .. ', ' .. 'World!'")
        #expect(result.stringValue == "Hello, World!")
    }

    @Test("Returns boolean values")
    func evalBoolean() throws {
        let vm = try LuaVM()
        #expect(try vm.evaluate("true").boolValue == true)
        #expect(try vm.evaluate("false").boolValue == false)
        #expect(try vm.evaluate("1 == 1").boolValue == true)
        #expect(try vm.evaluate("1 == 2").boolValue == false)
    }

    @Test("Returns nil")
    func evalNil() throws {
        let vm = try LuaVM()
        let result = try vm.evaluate("nil")
        if case .nil = result { /* ok */ }
        else { Issue.record("Expected nil") }
    }

    @Test("Handles Lua tables as dictionaries")
    func evalTable() throws {
        let vm = try LuaVM()
        let result = try vm.evaluate("{name = 'Alice', age = 30}")
        let table = result.tableValue!
        #expect(table["name"]?.stringValue == "Alice")
        #expect(table["age"]?.numberValue == 30.0)
    }

    @Test("Handles Lua tables as arrays")
    func evalArray() throws {
        let vm = try LuaVM()
        let result = try vm.evaluate("{10, 20, 30}")
        if case .array(let arr) = result {
            #expect(arr.count == 3)
            #expect(arr[0].numberValue == 10.0)
            #expect(arr[2].numberValue == 30.0)
        } else {
            Issue.record("Expected array")
        }
    }

    @Test("Reports syntax errors")
    func syntaxError() throws {
        let vm = try LuaVM()
        #expect(throws: LuaError.self) {
            try vm.execute("this is not valid lua !!!")
        }
    }

    @Test("Reports runtime errors")
    func runtimeError() throws {
        let vm = try LuaVM()
        #expect(throws: LuaError.self) {
            try vm.execute("error('boom')")
        }
    }

    // MARK: - State Table

    @Test("Sets and gets state values")
    func stateSetGet() throws {
        let vm = try LuaVM()
        vm.setState(key: "count", value: .number(42))
        let result = try vm.evaluate("state.count")
        #expect(result.numberValue == 42.0)
    }

    @Test("State changes from Lua trigger callback")
    func stateCallback() throws {
        let vm = try LuaVM()
        var changed: (String, LuaValue)?
        vm.onStateChanged = { key, value in
            changed = (key, value)
        }

        try vm.execute("state.count = 5")
        #expect(changed?.0 == "count")
        #expect(changed?.1.numberValue == 5.0)
    }

    @Test("State works with strings")
    func stateStrings() throws {
        let vm = try LuaVM()
        vm.setState(key: "name", value: .string("Alice"))
        let result = try vm.evaluate("'Hello, ' .. state.name")
        #expect(result.stringValue == "Hello, Alice")
    }

    @Test("State supports incrementing")
    func stateIncrement() throws {
        let vm = try LuaVM()
        vm.setState(key: "count", value: .number(0))

        var lastValue: Double = 0
        vm.onStateChanged = { key, value in
            if key == "count", let n = value.numberValue {
                lastValue = n
            }
        }

        try vm.execute("state.count = state.count + 1")
        #expect(lastValue == 1.0)

        try vm.execute("state.count = state.count + 1")
        #expect(lastValue == 2.0)
    }

    // MARK: - Melody Functions

    @Test("Registers and calls a melody function")
    func melodyFunction() throws {
        let vm = try LuaVM()
        var called = false
        var receivedArgs: [LuaValue] = []

        vm.registerMelodyFunction(name: "test") { args in
            called = true
            receivedArgs = args
            return .string("result")
        }

        let result = try vm.evaluate("melody.test('hello', 42)")
        #expect(called == true)
        #expect(receivedArgs.count == 2)
        #expect(receivedArgs[0].stringValue == "hello")
        #expect(receivedArgs[1].numberValue == 42.0)
        #expect(result.stringValue == "result")
    }

    @Test("melody.log works without crashing")
    func melodyLog() throws {
        let vm = try LuaVM()
        try vm.execute("melody.log('test message')")
        // Just verifying it doesn't crash
    }

    // MARK: - Complex Scenarios

    @Test("Conditional logic with state")
    func conditionalLogic() throws {
        let vm = try LuaVM()
        vm.setState(key: "count", value: .number(10))

        let result = try vm.evaluate("state.count >= 10")
        #expect(result.boolValue == true)

        let result2 = try vm.evaluate("state.count >= 20")
        #expect(result2.boolValue == false)
    }

    @Test("String concatenation with state")
    func stringConcatWithState() throws {
        let vm = try LuaVM()
        vm.setState(key: "count", value: .number(5))
        let result = try vm.evaluate("'Count: ' .. state.count")
        #expect(result.stringValue == "Count: 5")
    }

    @Test("Multi-line script with state mutations")
    func multiLineScript() throws {
        let vm = try LuaVM()
        vm.setState(key: "x", value: .number(0))

        try vm.execute("""
            state.x = 10
            state.x = state.x + 5
            state.x = state.x * 2
        """)

        let result = try vm.evaluate("state.x")
        #expect(result.numberValue == 30.0)
    }

    @Test("If/else in Lua scripts")
    func ifElseScript() throws {
        let vm = try LuaVM()
        vm.setState(key: "score", value: .number(85))

        let result = try vm.execute("""
            if state.score >= 90 then
                return "A"
            elseif state.score >= 80 then
                return "B"
            else
                return "C"
            end
        """)
        #expect(result.stringValue == "B")
    }
}
