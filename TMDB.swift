import Foundation

enum TMDBError: Error {
    case missingKey
    case http(Int)
}

/// Holt Filme, Serien und Anbieter von The Movie Database (TMDB).
struct TMDBClient {
    /// Der Schlüssel wird beim Bauen auf GitHub aus dem Secret TMDB_API_KEY eingesetzt.
    let apiKey: String = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "TMDBApiKey") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.hasPrefix("$(") ? "" : raw
    }()

    var hasKey: Bool { !apiKey.isEmpty }

    private func get<T: Decodable>(_ path: String, _ query: [String: String]) async throws -> T {
        guard hasKey else { throw TMDBError.missingKey }
        guard var components = URLComponents(string: "https://api.themoviedb.org/3" + path) else {
            throw TMDBError.http(0)
        }
        var items = [URLQueryItem(name: "api_key", value: apiKey)]
        for (key, value) in query {
            items.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = items
        guard let url = components.url else { throw TMDBError.http(0) }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw TMDBError.http(http.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Findet die TMDB-IDs der Abos für Deutschland.
    func resolveProviders() async throws -> [Service: [Int]] {
        var found: [Service: Set<Int>] = [:]
        for kind in ["movie", "tv"] {
            let list: ProviderList = try await get("/watch/providers/\(kind)", ["watch_region": "DE", "language": "de-DE"])
            for provider in list.results {
                for service in Service.allCases where service.matches(providerName: provider.provider_name) {
                    found[service, default: []].insert(provider.provider_id)
                }
            }
        }
        var result: [Service: [Int]] = [:]
        for service in Service.allCases {
            let ids = (found[service] ?? []).union(service.fallbackIDs)
            result[service] = Array(ids).sorted()
        }
        return result
    }

    /// Beliebte Titel, die in Deutschland im Abo laufen.
    func discover(isTV: Bool, providerIDs: [Int], page: Int) async throws -> [MediaTitle] {
        let query: [String: String] = [
            "language": "de-DE",
            "watch_region": "DE",
            "with_watch_providers": providerIDs.map { String($0) }.joined(separator: "|"),
            "with_watch_monetization_types": "flatrate",
            "sort_by": "popularity.desc",
            "include_adult": "false",
            "vote_count.gte": "20",
            "page": String(page)
        ]
        let response: DiscoverPage = try await get(isTV ? "/discover/tv" : "/discover/movie", query)
        return response.results.compactMap { (item: DiscoverItem) -> MediaTitle? in
            let name = (isTV ? item.name : item.title) ?? item.title ?? item.name ?? ""
            guard !name.isEmpty, item.poster_path != nil else { return nil }
            let date = (isTV ? item.first_air_date : item.release_date) ?? ""
            return MediaTitle(
                tmdbID: item.id,
                isTV: isTV,
                title: name,
                overview: item.overview ?? "",
                posterPath: item.poster_path,
                year: String(date.prefix(4)),
                genreIDs: item.genre_ids ?? [],
                rating: item.vote_average ?? 0,
                popularity: item.popularity ?? 0,
                services: []
            )
        }
    }
}

struct ProviderList: Decodable {
    let results: [Provider]
}

struct Provider: Decodable {
    let provider_id: Int
    let provider_name: String
}

struct DiscoverPage: Decodable {
    let page: Int
    let results: [DiscoverItem]
}

struct DiscoverItem: Decodable {
    let id: Int
    let title: String?
    let name: String?
    let overview: String?
    let poster_path: String?
    let release_date: String?
    let first_air_date: String?
    let genre_ids: [Int]?
    let vote_average: Double?
    let popularity: Double?
}
