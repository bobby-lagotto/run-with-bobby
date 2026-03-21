import SwiftUI

@main
struct RunWithBobbyApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
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
        // Configurazione della UI generale
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Configurazione dei colori dell'app
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor.systemBlue
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