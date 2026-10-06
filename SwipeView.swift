import SwiftUI
import UIKit

@MainActor
struct SwipeView: View {
    @EnvironmentObject var model: AppModel
    @State private var offset: CGSize = .zero
    @State private var expanded = false
    @State private var isAnimatingOut = false

    private var visible: [(offset: Int, element: MediaTitle)] {
        Array(Array(model.deck.prefix(2)).enumerated().reversed())
    }

    private var dragProgress: CGFloat {
        min(1, sqrt(offset.width * offset.width + offset.height * offset.height) / 150)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                if model.deck.isEmpty {
                    emptyState
                } else {
                    ForEach(visible, id: \.element.id) { pair in
                        let isTop = pair.offset == 0
                        CardView(title: pair.element,
                                 match: model.matchPercent(pair.element),
                                 offset: isTop ? offset : .zero,
                                 expanded: isTop && expanded)
                            .scaleEffect(isTop ? 1 : 0.95 + 0.05 * dragProgress)
                            .offset(x: isTop ? offset.width : 0,
                                    y: isTop ? offset.height : 10 - 10 * dragProgress)
                            .rotationEffect(.degrees(isTop ? Double(offset.width / 20) : 0))
                            .allowsHitTesting(isTop)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                            }
                            .gesture(dragGesture)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            actionBar
        }
        .task { await model.startIfNeeded() }
    }

    // MARK: Teile

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "play.rectangle.fill")
            Text("couchmatch")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(Theme.gradient)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 14) {
            if model.isLoading {
                ProgressView()
                Text("Suche Filme und Serien auf deinen Abos …")
                    .foregroundStyle(.secondary)
            } else if let error = model.errorMessage {
                Image(systemName: "wifi.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(error)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Nochmal versuchen") { Task { await model.loadMore() } }
                    .buttonStyle(.borderedProminent)
            } else {
                Image(systemName: "film.stack")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.gradient)
                Text("Alles durchgeswiped")
                    .font(.title3.bold())
                Text("Füg im Profil ein Abo hinzu oder setz deine Wischer zurück.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Mehr laden") { model.resetFeed() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var actionBar: some View {
        let hasCard = !model.deck.isEmpty
        return HStack(spacing: 16) {
            circleButton("arrow.uturn.backward", color: Theme.gold, size: 46, enabled: model.canUndo) { undo() }
            circleButton("xmark", color: Theme.nope, size: 62, enabled: hasCard) { swipe(.nope) }
            circleButton("star.fill", color: Theme.seen, size: 52, enabled: hasCard) { swipe(.seen) }
            circleButton("heart.fill", color: Theme.like, size: 62, enabled: hasCard) { swipe(.like) }
            circleButton("info", color: Theme.accent, size: 46, enabled: hasCard) {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            }
        }
        .padding(.vertical, 14)
    }

    private func circleButton(_ symbol: String, color: Color, size: CGFloat, enabled: Bool,
                              action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .background(Circle().fill(Color(UIColor.systemBackground)))
                .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    // MARK: Wischen

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isAnimatingOut else { return }
                offset = value.translation
            }
            .onEnded { value in
                guard !isAnimatingOut else { return }
                let t = value.translation
                if t.height < -110 && abs(t.height) > abs(t.width) {
                    swipe(.seen)
                } else if t.width > 110 {
                    swipe(.like)
                } else if t.width < -110 {
                    swipe(.nope)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { offset = .zero }
                }
            }
    }

    private func swipe(_ decision: Decision) {
        guard let top = model.deck.first, !isAnimatingOut else { return }
        isAnimatingOut = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let target: CGSize
        switch decision {
        case .like: target = CGSize(width: 650, height: offset.height + 40)
        case .nope: target = CGSize(width: -650, height: offset.height + 40)
        case .seen: target = CGSize(width: offset.width, height: -1100)
        }
        withAnimation(.easeIn(duration: 0.25)) { offset = target }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 260_000_000)
            model.decide(top, decision)
            offset = .zero
            expanded = false
            isAnimatingOut = false
        }
    }

    private func undo() {
        guard !isAnimatingOut else { return }
        model.undo()
        offset = .zero
        expanded = false
    }
}

/// Eine Karte: oben das Cover, unten die Infos.
@MainActor
struct CardView: View {
    let title: MediaTitle
    let match: Int
    let offset: CGSize
    let expanded: Bool

    private var likeOpacity: Double { min(max(Double(offset.width) / 100, 0), 1) }
    private var nopeOpacity: Double { min(max(Double(-offset.width) / 100, 0), 1) }
    private var seenOpacity: Double { min(max(Double(-offset.height - abs(offset.width) * 0.6) / 100, 0), 1) }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                cover
                    .frame(width: geo.size.width, height: geo.size.height * (expanded ? 0.42 : 0.6))
                    .clipped()
                info
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.18), radius: 14, y: 8)
        }
    }

    private var cover: some View {
        ZStack {
            AsyncImage(url: title.posterURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    placeholder
                default:
                    placeholder.overlay(ProgressView().tint(.white))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            LinearGradient(colors: [Color.black.opacity(0.35), .clear, .clear, Color.black.opacity(0.35)],
                           startPoint: .top, endPoint: .bottom)

            VStack {
                HStack(alignment: .top) {
                    Text(title.kind.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.35), in: Capsule())
                    Spacer()
                    Text("\(match) % Match")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.35), in: Capsule())
                }
                Spacer()
            }
            .padding(14)

            stamp("MERKEN", color: Theme.like, angle: -15)
                .opacity(likeOpacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 54)
                .padding(.leading, 22)
            stamp("NÖ", color: Theme.nope, angle: 15)
                .opacity(nopeOpacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 54)
                .padding(.trailing, 22)
            stamp("GESEHEN ★", color: Theme.seen, angle: -6)
                .opacity(seenOpacity)
        }
    }

    private var placeholder: some View {
        LinearGradient(colors: [Theme.accent, Theme.accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(
                Text(title.title)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
            )
    }

    private func stamp(_ text: String, color: Color, angle: Double) -> some View {
        Text(text)
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 4))
            .rotationEffect(.degrees(angle))
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.title)
                    .font(.title2.weight(.heavy))
                    .lineLimit(2)
                Spacer(minLength: 8)
                if !title.year.isEmpty {
                    Text(title.year)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 6) {
                ForEach(title.services) { service in
                    Text(service.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(service.color, in: Capsule())
                }
                if title.rating > 0 {
                    Label(String(format: "%.1f", title.rating), systemImage: "star.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.gold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }
                ForEach(Array(title.genres.prefix(2))) { genre in
                    Text(genre.rawValue)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            Text(title.overview.isEmpty ? "Für diesen Titel gibt es noch keine deutsche Beschreibung." : title.overview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(expanded ? nil : 3)
        }
        .padding(16)
    }
}
