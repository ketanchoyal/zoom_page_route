import SwiftUI

/// Shows how many times this screen's load has run. With a correct zoom
/// transition it goes up by exactly one per push.
struct LoadBadge: View {
    let count: Int

    var body: some View {
        Label("load ran \(count)×", systemImage: "arrow.down.circle")
            .font(.caption.monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
    }
}

struct CartView: View {
    @State private var loads = 0
    @State private var quantity = 4

    var body: some View {
        List {
            Section {
                LabeledContent("Pickup location", value: "123 Main Street")
                LabeledContent("Pickup time", value: "30 min")
            }
            Section("\(quantity) Items") {
                HStack {
                    Text("Veggie Spring Rolls")
                    Spacer()
                    Stepper("\(quantity)", value: $quantity, in: 1...20).fixedSize()
                }
            }
            Section("Your Recommended Items") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(["Caesar Salad", "Chicken Soup", "Garlic Bread"], id: \.self) { name in
                            VStack {
                                RoundedRectangle(cornerRadius: 8).fill(.orange.gradient).frame(width: 120, height: 80)
                                Text(name).font(.caption)
                            }
                        }
                    }
                }
            }
            Section {
                Button("Checkout") {}
                    .frame(maxWidth: .infinity)
                    .bold()
            }
        }
        // Launched with -measure: magenta behind the list so the cart zoom can be
        // tracked frame by frame (same trick as MeasureView).
        .scrollContentBackground(Measure.enabled ? .hidden : .automatic)
        .background(Measure.enabled ? Color(red: 1, green: 0, blue: 1) : Color.clear)
        .navigationTitle("Cart")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { LoadBadge(count: loads) } }
        .task { loads = LoadCounter.shared.record("cart") }
    }
}

struct MenuItemsView: View {
    let category: MenuCategory
    @State private var loads = 0

    var body: some View {
        List(category.items) { item in
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: category.colors, startPoint: .top, endPoint: .bottom))
                    .frame(width: 72, height: 72)
                    .overlay { Image(systemName: category.symbol).foregroundStyle(.white) }
                VStack(alignment: .leading) {
                    Text(item.name).font(.headline)
                    Text(item.price, format: .currency(code: "CAD")).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(category.name)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { LoadBadge(count: loads) } }
        .task { loads = LoadCounter.shared.record("menu-\(category.id)") }
    }
}

struct OrderTrackingView: View {
    let order: Order
    @State private var loads = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Thank you for your order!").font(.title3.bold())
                    Text("PICKUP TIME").font(.caption).foregroundStyle(.secondary)
                    Text("4:35 pm")
                }
                ProgressSteps(progress: order.progress)
                Image(systemName: "flame.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(Palette.red.gradient)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                ForEach(1...8, id: \.self) { line in
                    HStack {
                        Text("Receipt line \(line)")
                        Spacer()
                        Text("$\(line).99").foregroundStyle(.secondary)
                    }
                    Divider()
                }
                HStack {
                    Text("ORDER ID: \(order.number)").font(.caption.bold())
                    Spacer()
                    Text(order.total, format: .currency(code: "CAD")).font(.caption.bold())
                }
            }
            .padding()
        }
        .background(Palette.background)
        .navigationTitle("Order Tracking")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { LoadBadge(count: loads) } }
        .task { loads = LoadCounter.shared.record("order-\(order.id)") }
    }
}

/// Solid magenta page used only for measuring the zoom transition.
struct MeasureView: View {
    @Environment(\.dismiss) private var dismiss

    /// A plain scrolling list over the magenta page, to compare how dismiss
    /// gestures and scrolling interact (same layout as the Flutter example).
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
                    .padding(.vertical, 8)
                ForEach(1...30, id: \.self) { row in
                    Text("Row \(row)")
                        .font(.system(size: 17))
                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        .padding(.horizontal, 16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(16)
        }
        .background(Color(red: 1, green: 0, blue: 1).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

enum Measure {
    static let enabled = ProcessInfo.processInfo.arguments.contains("-measure")
}
