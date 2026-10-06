import SwiftUI

@main
struct CouchmatchApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .tint(Theme.accent)
        }
    }
}

enum Theme {
    static let accent = Color(red: 0.42, green: 0.30, blue: 0.96)
    static let accent2 = Color(red: 1.0, green: 0.35, blue: 0.48)
    static let like = Color(red: 0.10, green: 0.76, blue: 0.49)
    static let nope = Color(red: 1.0, green: 0.30, blue: 0.37)
    static let seen = Color(red: 0.18, green: 0.55, blue: 1.0)
    static let gold = Color(red: 0.96, green: 0.72, blue: 0.04)

    static var gradient: LinearGradient {
        LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
    }
}

@MainActor
struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        TabView {
            SwipeView()
                .tabItem { Label("Entdecken", systemImage: "rectangle.stack.fill") }
            WatchlistView()
                .tabItem { Label("Merkliste", systemImage: "heart.fill") }
                .badge(model.watchlist.count)
            SeenView()
                .tabItem { Label("Gesehen", systemImage: "star.fill") }
            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.crop.circle.fill") }
        }
        .fullScreenCover(isPresented: Binding(get: { !model.onboarded }, set: { _ in })) {
            OnboardingView()
                .environmentObject(model)
        }
    }
}
