import SwiftUI

@main
struct RunWithBobbyApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var aiSettings = AISettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(aiSettings)
                .preferredColorScheme(.none) // Supporta sia light che dark mode
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        // Configurazione iniziale dell'app
        configureAppearance()
        
        // Verifica e crea le directory necessarie
        createDirectoriesIfNeeded()
        
        // Log di avvio (solo per debug)
        #if DEBUG
        print("🏃‍♂️ Run with Bobby avviato con successo!")
        print("📱 Versione iOS: \(UIDevice.current.systemVersion)")
        print("📊 Modello dispositivo: \(UIDevice.current.model)")
        #endif
    }
    
    private func configureAppearance() {
        // Light mode colors
        let titleColorLight = UIColor(red: 0.173, green: 0.094, blue: 0.063, alpha: 1.0) // #2C1810
        let bgColorLight = UIColor(red: 0.984, green: 0.976, blue: 0.969, alpha: 1.0) // #FBF9F7

        // Dark mode colors
        let titleColorDark = UIColor.white
        let bgColorDark = UIColor(red: 0.110, green: 0.078, blue: 0.071, alpha: 1.0) // #1C1412

        let accentUIColor = UIColor(red: 0.851, green: 0.271, blue: 0.271, alpha: 1.0) // #D94545

        // Colori adattivi che cambiano automaticamente con light/dark mode
        let adaptiveTitleColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? titleColorDark : titleColorLight
        }
        let adaptiveBgColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? bgColorDark : bgColorLight
        }

        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = adaptiveBgColor
        appearance.titleTextAttributes = [
            .foregroundColor: adaptiveTitleColor,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: adaptiveTitleColor,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = accentUIColor

        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = accentUIColor
    }
    
    private func createDirectoriesIfNeeded() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directories = [
            "TrainingPlans",
            "Conversations",
            "Exports",
            "Models" // Per i futuri modelli MLX personalizzati
        ]
        
        for directory in directories {
            let dirURL = documentsPath.appendingPathComponent(directory)
            if !FileManager.default.fileExists(atPath: dirURL.path) {
                try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            }
        }
    }
}

// MARK: - App Delegate (se necessario per configurazioni avanzate)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Configurazioni aggiuntive se necessarie
        return true
    }
    
    // Gestione della memoria per MLX
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        // Libera risorse MLX se necessario
        NotificationCenter.default.post(name: NSNotification.Name("MemoryWarning"), object: nil)
    }
    
    // Gestione background/foreground
    func applicationWillResignActive(_ application: UIApplication) {
        // Salva lo stato se necessario
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Ricarica risorse se necessario
    }
}