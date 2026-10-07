import SwiftUI

@main
struct PiperApp: App {
    var body: some Scene {
        MenuBarExtra {
            PlaceholderMenu()
        } label: {
            Label("Piper", systemImage: "bell")
        }
        .menuBarExtraStyle(.menu)
    }
}
