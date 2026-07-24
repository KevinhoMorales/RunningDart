import SwiftUI

@main
struct SaintsWatchApp: App {
  @StateObject private var sessionStore = WatchSessionStore()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(sessionStore)
    }
  }
}
