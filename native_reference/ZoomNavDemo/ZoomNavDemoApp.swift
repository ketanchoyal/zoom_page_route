import SwiftUI

@main
struct ZoomNavDemoApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .tint(Brand.red)
                .preferredColorScheme(.light)
        }
    }
}
