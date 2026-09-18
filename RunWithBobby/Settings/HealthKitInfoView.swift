import SwiftUI

/// In-app disclosure for Guideline 2.5.1 — HealthKit integration (CareKit is not used).
struct HealthKitInfoView: View {
    @ObservedObject var healthManager: HealthKitManager
    var onConnectionChanged: (() -> Void)?
    var showsDismissButton = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var healthConnected = UserDefaults.standard.bool(forKey: "healthkit_connected")
    @State private var showingHealthError = false
    @State private var healthErrorMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerBlock
                careKitNotice
                dataTypesBlock
                usageBlock
                connectionBlock
                revokeBlock
            }
            .padding()
        }
        .background(BobbyTheme.background(for: colorScheme).ignoresSafeArea())
        .navigationTitle(L10n.tr("Apple Health (HealthKit)", english: "Apple Health (HealthKit)"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.tr("Chiudi", english: "Close")) { dismiss() }
                        .foregroundColor(.bobbyRed)
                }
            }
        }
        .alert(L10n.tr("Errore", english: "Error"), isPresented: $showingHealthError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(healthErrorMessage)
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(L10n.tr(
                    "Run with Bobby usa l'API HealthKit di Apple per leggere e, se lo consenti, salvare dati nell'app Salute.",
                    english: "Run with Bobby uses Apple's HealthKit API to read and, if you allow it, save data in the Health app."
                ))
                .font(.body)
                .foregroundColor(BobbyTheme.primaryText(for: colorScheme))
            } icon: {
                Image(systemName: "heart.text.square.fill")
                    .foregroundColor(.bobbyRed)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BobbyTheme.cardBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var careKitNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.bobbyCaramel)
            Text(L10n.tr(
                "L'app non usa CareKit.",
                english: "This app does not use CareKit."
            ))
            .font(.subheadline)
            .foregroundColor(BobbyTheme.secondaryText(for: colorScheme))
        }
    }

    private var dataTypesBlock: some View {
        disclosureSection(
            title: L10n.tr("Dati HealthKit", english: "HealthKit data"),
            icon: "list.bullet.rectangle",
            items: readItems + writeItems
        )
    }

    private var readItems: [String] {
        [
            L10n.tr("Sonno", english: "Sleep"),
            L10n.tr("Frequenza cardiaca e a riposo", english: "Heart rate and resting heart rate"),
            L10n.tr("Variabilità cardiaca (HRV)", english: "Heart rate variability (HRV)"),
            L10n.tr("Passi e distanza camminata/corsa", english: "Steps and walking/running distance"),
            L10n.tr("Energia attiva e VO₂ max", english: "Active energy and VO₂ max"),
            L10n.tr("Saturazione ossigeno", english: "Blood oxygen"),
            L10n.tr("Allenamenti registrati in Salute", english: "Workouts logged in Health")
        ]
    }

    private var writeItems: [String] {
        [
            L10n.tr("Scrittura (opzionale): allenamenti di corsa quando registri una seduta", english: "Write (optional): running workouts when you log a session")
        ]
    }

    private var usageBlock: some View {
        disclosureSection(
            title: L10n.tr("Dove li usiamo", english: "Where we use it"),
            icon: "sparkles",
            items: [
                L10n.tr("Chat con Bobby (stato di forma, recupero, briefing)", english: "Chat with Bobby (fitness status, recovery, briefings)"),
                L10n.tr("Schermata Oggi e suggerimenti di carico", english: "Today screen and load suggestions"),
                L10n.tr("Registrazione corsa (salvataggio allenamento in Salute)", english: "Run logging (saving workouts to Health)")
            ]
        )
    }

    private var connectionBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("Connessione", english: "Connection"))
                .font(.headline)
                .foregroundColor(.bobbyRed)

            if !healthManager.isAvailable {
                Text(L10n.tr(
                    "HealthKit non è disponibile su questo dispositivo.",
                    english: "HealthKit is not available on this device."
                ))
                .font(.body)
                .foregroundColor(BobbyTheme.secondaryText(for: colorScheme))
            } else {
                Toggle(isOn: $healthConnected) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.tr("Usa HealthKit con Bobby", english: "Use HealthKit with Bobby"))
                            .font(.body)
                        Text(connectionStatus)
                            .font(.caption)
                            .foregroundColor(.bobbyWarmGray)
                    }
                }
                .tint(.bobbyRed)
                .onChange(of: healthConnected) { _, newValue in
                    handleHealthToggle(newValue)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BobbyTheme.cardBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var revokeBlock: some View {
        Text(L10n.tr(
            "Puoi revocare i permessi in qualsiasi momento: Impostazioni di iOS > Salute > Accesso dati e dispositivi > Run with Bobby.",
            english: "You can revoke permissions anytime: iOS Settings > Health > Data Access & Devices > Run with Bobby."
        ))
        .font(.caption)
        .foregroundColor(BobbyTheme.secondaryText(for: colorScheme))
    }

    private var connectionStatus: String {
        if !healthConnected {
            return L10n.tr("Non collegato", english: "Not connected")
        }
        return healthManager.isAuthorized
            ? L10n.tr("Autorizzato", english: "Authorized")
            : L10n.tr("In attesa di autorizzazione in Salute", english: "Waiting for authorization in Health")
    }

    private func disclosureSection(title: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(.bobbyRed)

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text(item)
                        .font(.subheadline)
                        .foregroundColor(BobbyTheme.primaryText(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BobbyTheme.cardBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func handleHealthToggle(_ connect: Bool) {
        if connect {
            guard healthManager.isAvailable else {
                healthConnected = false
                healthErrorMessage = L10n.tr(
                    "HealthKit non è disponibile su questo dispositivo.",
                    english: "HealthKit is not available on this device."
                )
                showingHealthError = true
                return
            }
            Task {
                let authorized = await healthManager.requestAuthorization()
                await MainActor.run {
                    if !authorized {
                        healthConnected = false
                        healthErrorMessage = L10n.tr(
                            "Autorizzazione Health non concessa. Puoi attivarla in Impostazioni > Salute.",
                            english: "Health authorization was not granted. You can enable it in Settings > Health."
                        )
                        showingHealthError = true
                    }
                    UserDefaults.standard.set(healthConnected, forKey: "healthkit_connected")
                    onConnectionChanged?()
                }
            }
        } else {
            UserDefaults.standard.set(false, forKey: "healthkit_connected")
            onConnectionChanged?()
        }
    }
}
