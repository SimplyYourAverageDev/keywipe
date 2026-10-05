import SwiftUI

@main
struct KeywipeApp: App {
    @ViewState private var controller = LockController()

    var body: some Scene {
        // A single-window scene: closing the window quits the app, which also unlocks.
        Window("Keywipe", id: "main") {
            TerminalView(controller: controller)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .help) {}
        }
    }
}

/// The macOS 27 SDK resolves `@State` to a macro whose compiler plugin ships only inside
/// Xcode. Reaching the property wrapper through an alias skips the macro, so the package
/// also builds with just the Command Line Tools.
typealias ViewState = SwiftUI.State
