import SwiftUI

struct SourcesList: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(HealthCitations.disclaimer)
                .font(.body)
                .foregroundColor(BobbyTheme.secondaryText(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            ForEach(HealthCitations.all) { citation in
                Link(destination: citation.url) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(citation.organization)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.bobbyRed)
                        Text(citation.title)
                            .font(.body)
                            .foregroundColor(BobbyTheme.primaryText(for: colorScheme))
                            .multilineTextAlignment(.leading)
                        Text(citation.url.absoluteString)
                            .font(.caption)
                            .foregroundColor(.bobbyWarmGray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(BobbyTheme.cardBackground(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

struct SourcesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    var showsDismissButton = true

    var body: some View {
        NavigationView {
            ScrollView {
                SourcesList()
                    .padding()
            }
            .background(BobbyTheme.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle(L10n.tr("Fonti e sicurezza", english: "Sources and safety"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsDismissButton {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(L10n.tr("Chiudi", english: "Close")) { dismiss() }
                            .foregroundColor(.bobbyRed)
                    }
                }
            }
        }
    }
}

struct SourcesDetailView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            SourcesList()
                .padding()
        }
        .background(BobbyTheme.background(for: colorScheme).ignoresSafeArea())
        .navigationTitle(L10n.tr("Fonti e sicurezza", english: "Sources and safety"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
