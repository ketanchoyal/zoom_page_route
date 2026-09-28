import SwiftUI

enum Brand {
    static let red = Color(red: 0.84, green: 0.13, blue: 0.16)
    static let yellow = Color(red: 0.98, green: 0.73, blue: 0.0)
    static let background = Color(uiColor: .systemGroupedBackground)
}

struct MenuCategory: Identifiable, Hashable {
    let id: Int
    let name: String
    let symbol: String
    let colors: [Color]

    static let all: [MenuCategory] = [
        .init(id: 1, name: "Rotisserie Chicken", symbol: "flame.fill", colors: [.orange, .red]),
        .init(id: 2, name: "Ribs", symbol: "fork.knife", colors: [.brown, .orange]),
        .init(id: 3, name: "Wings", symbol: "bird.fill", colors: [.red, .pink]),
        .init(id: 4, name: "Starters", symbol: "leaf.fill", colors: [.green, .teal]),
        .init(id: 5, name: "Sides", symbol: "takeoutbag.and.cup.and.straw.fill", colors: [.yellow, .orange]),
        .init(id: 6, name: "Desserts", symbol: "birthday.cake.fill", colors: [.purple, .pink]),
    ]

    var items: [MenuItem] {
        (1...12).map { MenuItem(id: id * 100 + $0, name: "\(name) #\($0)", price: 6.99 + Double($0)) }
    }
}

struct MenuItem: Identifiable, Hashable {
    let id: Int
    let name: String
    let price: Double
}

struct Order: Identifiable, Hashable {
    let id: Int
    let number: String
    let status: String
    let total: Double
    let progress: Int // 0...3

    static let all: [Order] = [
        .init(id: 13011499, number: "#20260925 1104018", status: "Cooking", total: 21.45, progress: 1),
        .init(id: 13009486, number: "#20260609 1103003", status: "Placed", total: 18.20, progress: 0),
        .init(id: 13008360, number: "#20260522 1104014", status: "On the way", total: 25.39, progress: 2),
        .init(id: 13008344, number: "#20260418 1139002", status: "Delivered", total: 32.10, progress: 3),
    ]
}

/// Every pushed screen, used both as the NavigationStack value and as the
/// zoom transition's source id.
enum Route: Hashable {
    case cart
    case menu(MenuCategory)
    case tracking(Order)
    case measure
    case measureSmall
    case springs

    var zoomID: String {
        switch self {
        case .cart: "cart"
        case .menu(let category): "menu-\(category.id)"
        case .tracking(let order): "order-\(order.id)"
        case .measure: "measure"
        case .measureSmall: "measure-small"
        case .springs: "springs"
        }
    }
}

/// Counts how often each screen's load ran, to compare with the Flutter app
/// (where HeroineZoomRoute ran a page's initState twice per transition).
@MainActor @Observable
final class LoadCounter {
    static let shared = LoadCounter()
    private(set) var counts: [String: Int] = [:]

    func record(_ key: String) -> Int {
        counts[key, default: 0] += 1
        return counts[key]!
    }
}
