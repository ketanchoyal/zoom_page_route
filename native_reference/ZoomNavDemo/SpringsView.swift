import SwiftUI
import QuartzCore

/// One dot per SwiftUI spring preset, all moving 300 pt at once, so a screen
/// recording can be fitted per colour and compared with the Flutter presets.
struct SpringsView: View {
    @State private var on = false

    private let presets: [(String, Color, Animation)] = [
        ("smooth", Color(red: 1, green: 0, blue: 0), .smooth),
        ("snappy", Color(red: 0, green: 1, blue: 0), .snappy),
        ("bouncy", Color(red: 0, green: 0, blue: 1), .bouncy),
        ("spring", Color(red: 1, green: 1, blue: 0), .spring),
        ("interactiveSpring", Color(red: 0, green: 1, blue: 1), .interactiveSpring),
        ("spring(response:0.55, dampingFraction:0.825)", Color(red: 1, green: 0.5, blue: 0),
         .spring(response: 0.55, dampingFraction: 0.825)),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            ForEach(presets.indices, id: \.self) { index in
                let (name, color, animation) = presets[index]
                VStack(alignment: .leading, spacing: 6) {
                    Text(name).font(.caption)
                    Circle()
                        .fill(color)
                        .frame(width: 28, height: 28)
                        .modifier(LoggedOffset(x: on ? 300 : 0, name: name))
                        .animation(animation, value: on)
                }
            }
            Button(on ? "Reset" : "Animate") { on.toggle() }
                .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
        .navigationTitle("Springs")
    }
}

/// Offsets its content and logs every animated value SwiftUI hands it
/// (`SPRING <name> <CACurrentMediaTime> <x>`), giving the exact native curve
/// without relying on a screen recording.
struct LoggedOffset: GeometryEffect {
    var x: CGFloat
    let name: String

    var animatableData: CGFloat {
        get { x }
        set {
            x = newValue
            print("SPRING \(name) \(CACurrentMediaTime()) \(newValue)")
        }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}
