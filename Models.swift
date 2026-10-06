import SwiftUI

/// Streaming-Abos, die man auswählen kann.
enum Service: String, CaseIterable, Codable, Identifiable {
    case netflix, prime, disney, apple, wow, paramount, rtl, joyn

    var id: String { rawValue }

    var name: String {
        switch self {
        case .netflix: return "Netflix"
        case .prime: return "Prime Video"
        case .disney: return "Disney+"
        case .apple: return "Apple TV"
        case .wow: return "WOW"
        case .paramount: return "Paramount+"
        case .rtl: return "RTL+"
        case .joyn: return "Joyn"
        }
    }

    var color: Color {
        switch self {
        case .netflix: return Color(red: 0.85, green: 0.12, blue: 0.15)
        case .prime: return Color(red: 0.10, green: 0.60, blue: 1.0)
        case .disney: return Color(red: 0.07, green: 0.24, blue: 0.81)
        case .apple: return Color(red: 0.17, green: 0.17, blue: 0.18)
        case .wow: return Color(red: 0.04, green: 0.56, blue: 0.42)
        case .paramount: return Color(red: 0.0, green: 0.39, blue: 1.0)
        case .rtl: return Color(red: 0.89, green: 0.0, blue: 0.10)
        case .joyn: return Color(red: 0.42, green: 0.25, blue: 0.94)
        }
    }

    /// Bekannte TMDB-Anbieter-IDs für Deutschland (werden beim Start zusätzlich live abgeglichen).
    var fallbackIDs: [Int] {
        switch self {
        case .netflix: return [8]
        case .prime: return [9]
        case .disney: return [337]
        case .apple: return [350]
        case .wow: return [30]
        case .paramount: return [531]
        case .rtl: return [298]
        case .joyn: return [304]
        }
    }

    /// Erkennt den Anbieter am Namen, den TMDB liefert.
    func matches(providerName: String) -> Bool {
        let n = providerName.lowercased()
        switch self {
        case .netflix: return n.contains("netflix")
        case .prime: return n.contains("amazon prime video")
        case .disney: return n.contains("disney plus") || n.contains("disney+")
        case .apple: return n.contains("apple tv")
        case .wow: return n == "wow"
        case .paramount: return n.contains("paramount")
        case .rtl: return n.contains("rtl+")
        case .joyn: return n.contains("joyn")
        }
    }
}

/// Genres, wie sie in der App angezeigt werden – mit den passenden TMDB-Genre-IDs.
enum Genre: String, CaseIterable, Codable, Identifiable {
    case action = "Action"
    case comedy = "Komödie"
    case drama = "Drama"
    case thriller = "Thriller"
    case crime = "Krimi"
    case horror = "Horror"
    case scifi = "Sci-Fi"
    case fantasy = "Fantasy"
    case romance = "Romantik"
    case animation = "Animation"
    case documentary = "Doku"
    case family = "Familie"

    var id: String { rawValue }

    var movieIDs: [Int] {
        switch self {
        case .action: return [28, 12]
        case .comedy: return [35]
        case .drama: return [18]
        case .thriller: return [53, 9648]
        case .crime: return [80]
        case .horror: return [27]
        case .scifi: return [878]
        case .fantasy: return [14]
        case .romance: return [10749]
        case .animation: return [16]
        case .documentary: return [99]
        case .family: return [10751]
        }
    }

    var tvIDs: [Int] {
        switch self {
        case .action: return [10759]
        case .comedy: return [35]
        case .drama: return [18]
        case .thriller: return [9648]
        case .crime: return [80]
        case .horror: return []
        case .scifi: return [10765]
        case .fantasy: return [10765]
        case .romance: return [10766]
        case .animation: return [16]
        case .documentary: return [99]
        case .family: return [10751, 10762]
        }
    }

    static func genres(for ids: [Int], isTV: Bool) -> [Genre] {
        var result: [Genre] = []
        for id in ids {
            for genre in Genre.allCases where (isTV ? genre.tvIDs : genre.movieIDs).contains(id) && !result.contains(genre) {
                result.append(genre)
            }
        }
        return result
    }
}

enum Decision: String, Codable {
    case like, nope, seen
}

/// Ein Film oder eine Serie.
struct MediaTitle: Codable, Identifiable, Hashable {
    let tmdbID: Int
    let isTV: Bool
    var title: String
    var overview: String
    var posterPath: String?
    var year: String
    var genreIDs: [Int]
    var rating: Double
    var popularity: Double
    var services: [Service]

    var id: String { (isTV ? "tv-" : "movie-") + String(tmdbID) }
    var genres: [Genre] { Genre.genres(for: genreIDs, isTV: isTV) }
    var kind: String { isTV ? "Serie" : "Film" }

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w780" + posterPath)
    }

    var thumbURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w185" + posterPath)
    }
}

/// Zentrale Daten der App: Auswahl, Entscheidungen, Kartenstapel.
@MainActor
final class AppModel: ObservableObject {
    @Published var onboarded = false
    @Published private(set) var services: Set<Service> = [.netflix, .prime, .disney]
    @Published private(set) var genres: Set<Genre> = [.action, .thriller, .scifi]
    @Published private(set) var decisions: [String: Decision] = [:]
    @Published private(set) var saved: [String: MediaTitle] = [:]
    @Published private(set) var order: [String] = []
    @Published private(set) var boost: [String: Double] = [:]
    @Published private(set) var deck: [MediaTitle] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var pool: [String: MediaTitle] = [:]
    private var nextPage = 1
    private var exhausted = false
    private var providerIDs: [Service: [Int]] = [:]
    private let client = TMDBClient()

    init() {
        load()
    }

    // MARK: Listen

    var watchlist: [MediaTitle] {
        order.reversed().compactMap { id in decisions[id] == .like ? saved[id] : nil }
    }

    var seenList: [MediaTitle] {
        order.reversed().compactMap { id in decisions[id] == .seen ? saved[id] : nil }
    }

    var canUndo: Bool { !order.isEmpty }

    var favoriteGenres: [Genre] {
        boost.filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .compactMap { Genre(rawValue: $0.key) }
            .prefix(3)
            .map { $0 }
    }

    // MARK: Bewertung

    private func genreScore(_ t: MediaTitle) -> Double {
        var s = 0.0
        for (index, genre) in t.genres.enumerated() {
            let weight = index == 0 ? 1.2 : 0.8
            if genres.contains(genre) { s += 2 * weight }
            s += (boost[genre.rawValue] ?? 0) * weight
        }
        return s
    }

    func score(_ t: MediaTitle) -> Double {
        var s = genreScore(t)
        s += log10(max(t.popularity, 1)) * 0.6
        if let y = Int(t.year), y >= Calendar.current.component(.year, from: Date()) - 1 {
            s += 0.5
        }
        return s
    }

    func matchPercent(_ t: MediaTitle) -> Int {
        min(98, max(55, Int(58 + genreScore(t) * 8)))
    }

    // MARK: Laden

    func startIfNeeded() async {
        if onboarded && deck.isEmpty && !isLoading {
            await loadMore()
        }
    }

    func loadMore() async {
        guard !isLoading, !exhausted else { return }
        guard client.hasKey else {
            errorMessage = "Der TMDB-Schlüssel fehlt. Trag ihn auf GitHub als Secret „TMDB_API_KEY“ ein und bau die App neu."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            if providerIDs.isEmpty {
                providerIDs = try await client.resolveProviders()
            }
            let page = nextPage
            var gotAny = false
            for service in services.sorted(by: { $0.rawValue < $1.rawValue }) {
                let ids = providerIDs[service] ?? service.fallbackIDs
                for isTV in [false, true] {
                    let results = try await client.discover(isTV: isTV, providerIDs: ids, page: page)
                    if !results.isEmpty { gotAny = true }
                    for item in results {
                        if var existing = pool[item.id] {
                            if !existing.services.contains(service) { existing.services.append(service) }
                            pool[item.id] = existing
                        } else {
                            var fresh = item
                            fresh.services = [service]
                            pool[item.id] = fresh
                        }
                    }
                }
            }
            nextPage += 1
            if !gotAny || nextPage > 20 { exhausted = true }
            isLoading = false
            rebuildDeck()
        } catch {
            isLoading = false
            errorMessage = "Konnte keine Titel laden. Prüf deine Internetverbindung und versuch es nochmal."
        }
    }

    private func rebuildDeck() {
        let current = deck.first
        var list = pool.values.filter { t in
            decisions[t.id] == nil && t.services.contains(where: { services.contains($0) })
        }
        list.sort { score($0) > score($1) }
        if let current, let index = list.firstIndex(where: { $0.id == current.id }) {
            let top = list.remove(at: index)
            list.insert(top, at: 0)
        }
        deck = list
        if deck.count < 8 && !exhausted {
            Task { await loadMore() }
        }
    }

    // MARK: Aktionen

    func decide(_ t: MediaTitle, _ decision: Decision) {
        decisions[t.id] = decision
        saved[t.id] = t
        order.removeAll { $0 == t.id }
        order.append(t.id)
        if decision == .seen {
            for genre in t.genres { boost[genre.rawValue, default: 0] += 1 }
        }
        deck.removeAll { $0.id == t.id }
        persist()
        if deck.count < 8 && !exhausted {
            Task { await loadMore() }
        }
    }

    func undo() {
        guard let last = order.last, let t = saved[last] else { return }
        if decisions[last] == .seen {
            for genre in t.genres {
                boost[genre.rawValue] = max(0, (boost[genre.rawValue] ?? 0) - 1)
            }
        }
        decisions.removeValue(forKey: last)
        order.removeLast()
        pool[last] = t
        deck.removeAll { $0.id == last }
        deck.insert(t, at: 0)
        persist()
    }

    func markSeen(_ t: MediaTitle) {
        decisions[t.id] = .seen
        saved[t.id] = t
        order.removeAll { $0 == t.id }
        order.append(t.id)
        for genre in t.genres { boost[genre.rawValue, default: 0] += 1 }
        persist()
    }

    func remove(_ t: MediaTitle) {
        decisions.removeValue(forKey: t.id)
        order.removeAll { $0 == t.id }
        saved.removeValue(forKey: t.id)
        persist()
    }

    func toggle(_ service: Service) {
        if services.contains(service) {
            guard services.count > 1 else { return }
            services.remove(service)
        } else {
            services.insert(service)
        }
        persist()
        if onboarded { resetFeed() }
    }

    func toggle(_ genre: Genre) {
        if genres.contains(genre) {
            genres.remove(genre)
        } else {
            genres.insert(genre)
        }
        persist()
        if onboarded { rebuildDeck() }
    }

    func finishOnboarding() {
        onboarded = true
        persist()
        resetFeed()
    }

    func resetFeed() {
        pool = [:]
        deck = []
        nextPage = 1
        exhausted = false
        Task { await loadMore() }
    }

    func resetAll() {
        decisions = [:]
        saved = [:]
        order = []
        boost = [:]
        persist()
        resetFeed()
    }

    // MARK: Speichern

    private struct Stored: Codable {
        var onboarded: Bool
        var services: [Service]
        var genres: [Genre]
        var decisions: [String: Decision]
        var saved: [String: MediaTitle]
        var order: [String]
        var boost: [String: Double]
    }

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("couchmatch.json")
    }

    private func load() {
        guard let raw = try? Data(contentsOf: AppModel.fileURL),
              let stored = try? JSONDecoder().decode(Stored.self, from: raw) else { return }
        onboarded = stored.onboarded
        if !stored.services.isEmpty { services = Set(stored.services) }
        genres = Set(stored.genres)
        decisions = stored.decisions
        saved = stored.saved
        order = stored.order
        boost = stored.boost
    }

    func persist() {
        let stored = Stored(onboarded: onboarded, services: Array(services), genres: Array(genres),
                            decisions: decisions, saved: saved, order: order, boost: boost)
        do {
            let raw = try JSONEncoder().encode(stored)
            try raw.write(to: AppModel.fileURL, options: .atomic)
        } catch {
            print("Speichern fehlgeschlagen: \(error)")
        }
    }
}
