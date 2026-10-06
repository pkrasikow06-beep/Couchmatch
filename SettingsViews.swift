import SwiftUI

/// Auswahl der Abos als farbige Kacheln.
@MainActor
struct ServicePicker: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(Service.allCases) { service in
                let isOn = model.services.contains(service)
                Button {
                    model.toggle(service)
                } label: {
                    HStack {
                        Text(service.name)
                            .font(.subheadline.weight(.heavy))
                        Spacer()
                        if isOn {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 54)
                    .background(isOn ? service.color : Color.gray.opacity(0.45),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
    }
}

/// Auswahl der Lieblingsgenres als Chips.
@MainActor
struct GenrePicker: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
            ForEach(Genre.allCases) { genre in
                let isOn = model.genres.contains(genre)
                Button {
                    model.toggle(genre)
                } label: {
                    Text(genre.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(isOn ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color.secondary.opacity(0.12)))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
    }
}

@MainActor
struct ProfileView: View {
    @EnvironmentObject var model: AppModel
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ServicePicker()
                } header: {
                    Text("Meine Abos")
                } footer: {
                    Text("Es werden nur Filme und Serien gezeigt, die in Deutschland auf diesen Abos laufen.")
                }

                Section {
                    GenrePicker()
                } header: {
                    Text("Lieblingsgenres")
                } footer: {
                    Text("Passende Titel rutschen im Stapel nach oben. Was du nach oben wischst, zählt zusätzlich.")
                }

                Section {
                    Button("Alle Wischer zurücksetzen", role: .destructive) {
                        confirmReset = true
                    }
                }

                Section {
                    Text("Filmdaten und Cover stammen von TMDB, die Verfügbarkeit bei den Streamingdiensten von JustWatch.")
                        .font(.footnote)
                    Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Datenquelle")
                }
            }
            .navigationTitle("Profil")
            .confirmationDialog("Alle Wischer zurücksetzen?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Zurücksetzen", role: .destructive) {
                    model.resetAll()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Merkliste und Gesehen werden geleert und alle Titel tauchen wieder auf.")
            }
        }
    }
}

@MainActor
struct OnboardingView: View {
    @EnvironmentObject var model: AppModel
    @State private var step = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Capsule().fill(Theme.gradient).frame(height: 4)
                Capsule()
                    .fill(step >= 1 ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color.secondary.opacity(0.2)))
                    .frame(height: 4)
            }
            .padding(.bottom, 28)

            Text(step == 0 ? "Welche Abos hast du?" : "Was schaust du gern?")
                .font(.largeTitle.weight(.heavy))
            Text(step == 0
                 ? "Wir zeigen dir nur Filme und Serien, die du auch wirklich schauen kannst."
                 : "Wähl ein paar Genres. Je mehr du später nach oben wischst, desto besser werden die Vorschläge.")
                .foregroundStyle(.secondary)
                .padding(.top, 6)
                .padding(.bottom, 22)

            ScrollView {
                if step == 0 {
                    ServicePicker()
                } else {
                    GenrePicker()
                }
            }

            Button {
                if step == 0 {
                    withAnimation { step = 1 }
                } else {
                    model.finishOnboarding()
                }
            } label: {
                Text(step == 0 ? "Weiter" : "Los geht’s")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.gradient, in: Capsule())
            }
            .disabled(step == 1 && model.genres.isEmpty)
            .opacity(step == 1 && model.genres.isEmpty ? 0.4 : 1)

            if step == 1 {
                Button("Zurück") { withAnimation { step = 0 } }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
            }
        }
        .padding(24)
        .interactiveDismissDisabled()
    }
}
