import SwiftUI
import Core

struct StateProviderView: View {
    let definition: ComponentDefinition
    @State private var localState = LocalState()

    var body: some View {
        Group {
            if let children = definition.children {
                ComponentRenderer(components: children)
            }
        }
        .environment(\.localState, localState)
        .onAppear {
            localState.initialize(from: definition.localState)
        }
    }
}
