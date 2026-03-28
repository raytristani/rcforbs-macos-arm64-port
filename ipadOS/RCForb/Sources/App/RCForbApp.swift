import SwiftUI

@main
struct RCForbApp: App {
    @StateObject private var connectionManager = ConnectionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectionManager)
                .statusBarHidden(false)
        }
    }
}
