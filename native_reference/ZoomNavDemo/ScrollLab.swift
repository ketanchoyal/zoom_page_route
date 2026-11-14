import SwiftUI

/// Where the zoom page's drag-down dismiss may start, next to scrollables.
/// Launch with `-scrollLab <layout>`: `plain` (a list), `nested` (a list on a
/// horizontally paged view, i.e. not the page's outermost scrollable) or
/// `header` (a fixed header above a list). A cyan card opens the page. The
/// example app's `--dart-define=SCROLL_LAB=<layout>` builds the same screens.
struct ScrollLabView: View {
    let layout: String
    @Namespace private var zoom
    @State private var open = false

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Button { open = true } label: {
                    Text("SOURCE")
                        .font(.headline)
                        .frame(width: 200, height: 120)
                        .background(Color.cyan, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.black)
                }
                .matchedTransitionSource(id: "lab", in: zoom)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $open) {
                ScrollLabPage(layout: layout)
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationTransition(.zoom(sourceID: "lab", in: zoom))
            }
        }
    }
}

struct ScrollLabPage: View {
    let layout: String

    var body: some View {
        switch layout {
        case "nested":
            TabView {
                ScrollLabRows(prefix: "A")
                ScrollLabRows(prefix: "B")
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        case "header":
            VStack(spacing: 0) {
                Text("HEADER")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Color.yellow)
                ScrollLabRows(prefix: "A")
            }
        default:
            ScrollLabRows(prefix: "A")
        }
    }
}

struct ScrollLabRows: View {
    let prefix: String

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<60, id: \.self) { i in
                    Text("\(prefix) Row \(i)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .frame(height: 56)
                        .background(i.isMultiple(of: 2) ? Color.white : Color(white: 0.92))
                }
            }
        }
        .background(Color.white)
    }
}

@MainActor
enum ScrollLabLaunch {
    /// The `-scrollLab` layout, nil when the app should open normally.
    static var layout: String? { UserDefaults.standard.string(forKey: "scrollLab") }
}
