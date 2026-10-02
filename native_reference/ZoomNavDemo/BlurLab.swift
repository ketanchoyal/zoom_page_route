import SwiftUI
import UIKit

/// UIKit zoom push with `ZoomOptions.dimmingVisualEffect`, which SwiftUI's
/// `.zoom` does not expose. Launch with `-blurLab <style>` (`none` for the
/// default dim, or a `UIBlurEffect.Style` name) and optionally
/// `-dimColor clear` to drop the dim, `-dark 1` for dark appearance. The
/// background is built to be measured from a recording (see BlurLabPattern),
/// with a cyan source that opens a solid magenta page. `-still 1` lays the
/// effect statically over flat blocks (or one `-fill r,g,b` colour) instead.
struct BlurLabView: UIViewControllerRepresentable {
    let style: String
    let clearDim: Bool

    func makeUIViewController(context: Context) -> UINavigationController {
        let nav = UINavigationController(rootViewController: BlurLabRoot(style: style, clearDim: clearDim))
        nav.overrideUserInterfaceStyle = BlurLabLaunch.dark ? .dark : .light
        nav.setNavigationBarHidden(true, animated: false)
        return nav
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}
}

@MainActor
enum BlurLabLaunch {
    /// The `-blurLab` style, nil when the app should open normally.
    static var style: String? { UserDefaults.standard.string(forKey: "blurLab") }
    static var clearDim: Bool { UserDefaults.standard.string(forKey: "dimColor") == "clear" }
    /// `-still 1`: no transition, the effect laid statically over large flat
    /// blocks, to read its full-strength colour transform.
    static var still: Bool { UserDefaults.standard.bool(forKey: "still") }
    /// `-fill r,g,b` (0–1) with `-still 1`: one flat colour under the effect,
    /// so its colour transform can be read with no blur bleed.
    static var fill: UIColor? {
        guard let parts = UserDefaults.standard.string(forKey: "fill")?.split(separator: ",").compactMap({ Double($0) }),
              parts.count == 3 else { return nil }
        return UIColor(red: parts[0], green: parts[1], blue: parts[2], alpha: 1)
    }
    /// `-dark 1`: dark appearance (the system materials adapt).
    static var dark: Bool { UserDefaults.standard.bool(forKey: "dark") }

    static func effect(_ name: String) -> UIBlurEffect? {
        let styles: [String: UIBlurEffect.Style] = [
            "regular": .regular, "prominent": .prominent, "light": .light, "dark": .dark,
            "extraLight": .extraLight,
            "systemUltraThinMaterial": .systemUltraThinMaterial, "systemThinMaterial": .systemThinMaterial,
            "systemMaterial": .systemMaterial, "systemThickMaterial": .systemThickMaterial,
            "systemChromeMaterial": .systemChromeMaterial,
        ]
        return styles[name].map { UIBlurEffect(style: $0) }
    }
}

final class BlurLabRoot: UIViewController {
    private let style: String
    private let clearDim: Bool
    private let source = UIView()

    init(style: String, clearDim: Bool) {
        self.style = style
        self.clearDim = clearDim
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        if BlurLabLaunch.still {
            if let fill = BlurLabLaunch.fill {
                view.backgroundColor = fill
            } else {
                let blocks = BlurLabBlocks(frame: view.bounds)
                blocks.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                view.addSubview(blocks)
            }
            let effect = UIVisualEffectView(effect: BlurLabLaunch.effect(style))
            effect.frame = view.bounds
            effect.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(effect)
            return
        }
        let pattern = BlurLabPattern()
        pattern.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pattern)
        NSLayoutConstraint.activate([
            pattern.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pattern.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pattern.topAnchor.constraint(equalTo: view.topAnchor),
            pattern.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        source.backgroundColor = UIColor(red: 0, green: 1, blue: 1, alpha: 1)
        source.layer.cornerRadius = 12
        source.frame = CGRect(x: 126, y: 400, width: 150, height: 100)
        source.accessibilityIdentifier = "LAB_SOURCE"
        source.isAccessibilityElement = true
        source.accessibilityLabel = "LAB_SOURCE"
        source.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(open)))
        view.addSubview(source)

        let label = UILabel()
        label.text = "style: \(style)\(clearDim ? " / clear dim" : "")"
        label.font = .boldSystemFont(ofSize: 13)
        label.backgroundColor = .white
        label.frame = CGRect(x: 16, y: 60, width: 370, height: 20)
        label.textColor = .black
        view.addSubview(label)
    }

    @objc private func open() {
        let page = UIViewController()
        page.view.backgroundColor = UIColor(red: 1, green: 0, blue: 1, alpha: 1)
        let options = UIViewController.Transition.ZoomOptions()
        options.dimmingVisualEffect = BlurLabLaunch.effect(style)
        if clearDim { options.dimmingColor = .clear }
        page.preferredTransition = .zoom(options: options) { [weak self] _ in self?.source }
        navigationController?.pushViewController(page, animated: true)
    }
}

/// Measured from a recording while the page is dragged (it then covers only
/// the lower middle). 100–300 pt: black left half, white right half (the
/// edge gives the blur radius, the far sides the tint). Below: full-width red,
/// green and blue bands (saturation), read at the screen edges.
final class BlurLabPattern: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let w = bounds.width, h = bounds.height
        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fill(CGRect(x: 0, y: 100, width: w / 2, height: 200))
        let bands: [UIColor] = [
            UIColor(red: 1, green: 0, blue: 0, alpha: 1), UIColor(red: 0, green: 1, blue: 0, alpha: 1),
            UIColor(red: 0, green: 0, blue: 1, alpha: 1),
        ]
        let bh = (h - 300) / CGFloat(bands.count)
        for (i, c) in bands.enumerated() {
            ctx.setFillColor(c.cgColor)
            ctx.fill(CGRect(x: 0, y: 300 + CGFloat(i) * bh, width: w, height: bh))
        }
    }
}

/// 2 × 3 flat blocks below 100 pt: black, white / red, green / blue, 50% grey.
final class BlurLabBlocks: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let colors: [UIColor] = [
            .black, .white, UIColor(red: 1, green: 0, blue: 0, alpha: 1), UIColor(red: 0, green: 1, blue: 0, alpha: 1),
            UIColor(red: 0, green: 0, blue: 1, alpha: 1), UIColor(white: 0.5, alpha: 1),
        ]
        let w = bounds.width / 2, h = (bounds.height - 100) / 3
        for (i, c) in colors.enumerated() {
            ctx.setFillColor(c.cgColor)
            ctx.fill(CGRect(x: CGFloat(i % 2) * w, y: 100 + CGFloat(i / 2) * h, width: w, height: h))
        }
    }
}
