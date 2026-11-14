import SwiftUI

@main
struct ZoomNavDemoApp: App {
    var body: some Scene {
        WindowGroup {
            if let layout = ScrollLabLaunch.layout {
                ScrollLabView(layout: layout)
                    .preferredColorScheme(.light)
            } else if let style = BlurLabLaunch.style {
                BlurLabView(style: style, clearDim: BlurLabLaunch.clearDim)
                    .ignoresSafeArea()
                    .preferredColorScheme(BlurLabLaunch.dark ? .dark : .light)
            } else {
                HomeView()
                    .tint(Palette.red)
                    .preferredColorScheme(.light)
            }
        }
    }
}
