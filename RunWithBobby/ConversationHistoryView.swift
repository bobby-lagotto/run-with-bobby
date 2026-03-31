import SwiftUI

struct ConversationHistoryView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var sortedConversations: [Conversation] {
        appState.conversations.sorted { $0.lastMessageAt > $1.lastMessageAt }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if sortedConversations.isEmpty {
                        emptyState
                    } else {
                        ForEach(sortedConversations) { conversation in
                            ConversationRowView(
                                conversation: conversation,
                                isActive: conversation.id == appState.currentConversation?.id,
                                onTap: {
                                    appState.switchToConversation(conversation)
                                    dismiss()
                                },
                                onDelete: {
                                    appState.deleteConversation(conversation)
                                }
                            )
                            .bobbyCard()
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .background(BobbyTheme.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Storico Chat")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { dismiss() }
                        .foregroundColor(.bobbyRed)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.bobbyWarmGray.opacity(0.5))
            Text("Nessuna conversazione")
                .font(.subheadline)
                .foregroundColor(.bobbyWarmGray)
        }
        .padding(.top, 40)
    }
}

// MARK: - Conversation Row
struct ConversationRowView: View {
    let conversation: Conversation
    let isActive: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirm = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(conversation.title)
                        .font(.headline)
                        .foregroundColor(.bobbyCharcoal)
                        .lineLimit(1)

                    Spacer()

                    if isActive {
                        Text("ATTIVA")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.bobbyRed.opacity(0.12))
                            .foregroundColor(.bobbyRed)
                            .clipShape(Capsule())
                    }
                }

                if let lastMessage = conversation.messages.last {
                    Text(lastMessage.content.prefix(80).description)
                        .font(.caption)
                        .foregroundColor(.bobbyWarmGray)
                        .lineLimit(2)
                }

                HStack {
                    Text(relativeDateString(from: conversation.lastMessageAt))
                        .font(.caption2)
                        .foregroundColor(.bobbyWarmGray)

                    Text("\(conversation.messages.count) messaggi")
                        .font(.caption2)
                        .foregroundColor(.bobbyWarmGray)

                    Spacer()

                    Button { showingDeleteConfirm = true } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.bobbyWarmGray)
                            .padding(6)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .alert("Eliminare questa conversazione?", isPresented: $showingDeleteConfirm) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) { onDelete() }
        } message: {
            Text("Questa azione non può essere annullata.")
        }
    }

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
