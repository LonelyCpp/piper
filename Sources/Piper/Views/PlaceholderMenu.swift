import AppKit
import SwiftUI

struct PlaceholderMenu: View {
    var body: some View {
        Text("Piper")
        Divider()
        Text("Phase 0 scaffold — no reminders yet")
        Divider()
        Button("Quit Piper") {
            NSApplication.shared.terminate(nil)
        }
    }
}
