import SwiftUI

/// Eine Zeile mit kleinem Cover für Merkliste und Gesehen.
@MainActor
struct TitleRow<Trailing: View>: View {
    let title: MediaTitle
    let trailing: () -> Trailing

    init(title: MediaTitle, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    private var subtitle: String {
        var parts: [String] = []
        let names = title.services.map { $0.name }.joined(separator: ", ")
        if !names.isEmpty { parts.append(names) }
        parts.append(title.kind)
        if !title.year.isEmpty { parts.append(title.year) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: title.thumbURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Rectangle().fill(Color.secondary.opacity(0.2))
                }
            }
            .frame(width: 54, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 4)
    }
}

@MainActor
struct WatchlistView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationStack {
            Group {
                if model.watchlist.isEmpty {
                    ContentUnavailableView(
                        "Noch leer",
                        systemImage: "heart",
                        description: Text("Wisch bei „Entdecken“ nach rechts, um dir Filme und Serien zu merken.")
                    )
                } else {
                    List {
                        ForEach(model.watchlist) { item in
                            TitleRow(title: item) {
                                Button {
                                    model.markSeen(item)
                                } label: {
                                    Text("Gesehen")
                                        .font(.caption.weight(.bold))
                                }
                                .buttonStyle(.bordered)
                                .tint(Theme.seen)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    model.remove(item)
                                } label: {
                                    Label("Entfernen", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Merkliste")
        }
    }
}

@MainActor
struct SeenView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationStack {
            Group {
                if model.seenList.isEmpty {
                    ContentUnavailableView(
                        "Noch nichts gesehen",
                        systemImage: "star",
                        description: Text("Wisch bei „Entdecken“ nach oben, wenn du einen Titel schon kennst und mochtest. So werden die Vorschläge besser.")
                    )
                } else {
                    List {
                        if !model.favoriteGenres.isEmpty {
                            Section {
                                Text("Du magst gerade besonders \(model.favoriteGenres.map { $0.rawValue }.joined(separator: ", ")). Davon zeigt dir Couchmatch jetzt mehr.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Section {
                            ForEach(model.seenList) { item in
                                TitleRow(title: item) {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(Theme.gold)
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        model.remove(item)
                                    } label: {
                                        Label("Entfernen", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Gesehen")
        }
    }
}
