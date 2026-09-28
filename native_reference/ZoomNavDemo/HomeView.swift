import SwiftUI

/// Demo home screen with the same three zoom entry points as the Flutter
/// app: the cart icon, menu category cards and order cards.
struct HomeView: View {
    @Namespace private var zoom
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    pickupBar
                    measureCard
                    springsLink
                    menuSection
                    ordersSection
                }
                .padding(.vertical)
            }
            .background(Palette.background)
            .navigationTitle("Demo Kitchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        path.append(.cart)
                    } label: {
                        Image(systemName: "bag.fill")
                            .overlay(alignment: .topTrailing) {
                                Text("4")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Circle().fill(Palette.red))
                                    .offset(x: 8, y: -8)
                            }
                    }
                }
                .matchedTransitionSource(id: Route.cart.zoomID, in: zoom)
            }
            .navigationDestination(for: Route.self) { route in
                destination(for: route)
                    .navigationTransition(.zoom(sourceID: route.zoomID, in: zoom))
            }
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .cart: CartView()
        case .menu(let category): MenuItemsView(category: category)
        case .tracking(let order): OrderTrackingView(order: order)
        case .measure, .measureSmall: MeasureView()
        case .springs: SpringsView()
        }
    }

    // MARK: Sections

    private var pickupBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pick-Up").font(.headline)
                Text("30 min | 123 Main Street")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Edit").foregroundStyle(Palette.red)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    /// Solid cyan source → solid magenta page, so the transition's rect can be
    /// tracked frame by frame from a screen recording.
    private var measureCard: some View {
        Button {
            path.append(.measure)
        } label: {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0, green: 1, blue: 1))
                .frame(width: 150, height: 100)
                .overlay { Text("MEASURE").font(.caption.bold()) }
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: Route.measure.zoomID, in: zoom) { source in
            source.clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
        .overlay(alignment: .trailing) { smallMeasureSource }
    }

    /// A cart-icon-sized (36×36) source inside the page content, to tell whether
    /// the faster native cart zoom comes from the source's size or from it being
    /// a toolbar item.
    private var smallMeasureSource: some View {
        Button {
            path.append(.measureSmall)
        } label: {
            Circle().fill(Color(red: 0, green: 1, blue: 1)).frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("SMALL")
        .matchedTransitionSource(id: Route.measureSmall.zoomID, in: zoom)
        .padding(.trailing, 40)
    }

    private var springsLink: some View {
        Button("SPRINGS") { path.append(.springs) }
            .font(.headline)
            .padding(.horizontal)
    }

    private var menuSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Menu").font(.title2.bold()).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MenuCategory.all) { category in
                        let route = Route.menu(category)
                        Button {
                            path.append(route)
                        } label: {
                            CategoryCard(category: category)
                        }
                        .buttonStyle(.plain)
                        .matchedTransitionSource(id: route.zoomID, in: zoom) { source in
                            source.clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var ordersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ongoing Orders").font(.title2.bold()).padding(.horizontal)
            ForEach(Order.all) { order in
                let route = Route.tracking(order)
                Button {
                    path.append(route)
                } label: {
                    OrderCard(order: order)
                }
                .buttonStyle(.plain)
                .matchedTransitionSource(id: route.zoomID, in: zoom) { source in
                    source.clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(.horizontal)
            }
        }
    }
}

struct CategoryCard: View {
    let category: MenuCategory

    var body: some View {
        ZStack {
            LinearGradient(colors: category.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: category.symbol)
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.35))
            Text(category.name.uppercased())
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(8)
        }
        .frame(width: 150, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct OrderCard: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Thank you for your order: \(order.number)").font(.subheadline.bold())
            Text("Status: \(order.status)").font(.footnote).foregroundStyle(.secondary)
            ProgressSteps(progress: order.progress)
            Text("Track Ongoing Order")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Palette.yellow, in: Capsule())
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 6))
    }
}

struct ProgressSteps: View {
    let progress: Int
    private let steps = ["Placed", "Cooking", "On the way", "Delivered"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(steps.indices, id: \.self) { index in
                VStack(spacing: 4) {
                    Circle()
                        .fill(index <= progress ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                    Text(steps[index]).font(.caption2)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
