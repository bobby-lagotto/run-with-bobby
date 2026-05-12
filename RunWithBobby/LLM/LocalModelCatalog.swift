import Foundation

struct LocalModelOption: Identifiable, Hashable {
    let id: String           // HuggingFace path, e.g. "mlx-community/Qwen2.5-1.5B-Instruct-4bit"
    let tier: String         // "Compatto" / "Bilanciato" / "Potente"
    let shortName: String    // "Qwen 2.5 1.5B"
    let description: String
    let diskSizeMB: Int
    let minRamGB: Int

    var formattedSize: String {
        if diskSizeMB >= 1000 {
            return String(format: "%.1f GB", Double(diskSizeMB) / 1000.0)
        }
        return "\(diskSizeMB) MB"
    }

    /// iOS reports slightly less than the nominal RAM (e.g. an 8 GB iPhone reports ~7.4 GB).
    /// The 0.9 multiplier gives headroom so the threshold isn't tripped by reporting noise.
    var isSupportedOnThisDevice: Bool {
        let availableBytes = Double(ProcessInfo.processInfo.physicalMemory)
        let requiredBytes = Double(minRamGB) * 1_000_000_000 * 0.9
        return availableBytes >= requiredBytes
    }

    var requirementText: String {
        "Richiede iPhone con almeno \(minRamGB) GB di RAM."
    }
}

enum LocalModelCatalog {
    static let all: [LocalModelOption] = [
        LocalModelOption(
            id: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
            tier: "Compatto",
            shortName: "Qwen 2.5 0.5B",
            description: "Ultra-leggero. OK per chat base ma poco affidabile per generare piani di allenamento. Solo come fallback per iPhone più vecchi.",
            diskSizeMB: 400,
            minRamGB: 4
        ),
        LocalModelOption(
            id: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
            tier: "Bilanciato",
            shortName: "Qwen 2.5 1.5B",
            description: "Default consigliato. Buon equilibrio velocità/qualità. Tool-calling affidabile per generare e modificare piani.",
            diskSizeMB: 900,
            minRamGB: 6
        ),
        LocalModelOption(
            id: "mlx-community/Qwen2.5-3B-Instruct-4bit",
            tier: "Potente",
            shortName: "Qwen 2.5 3B",
            description: "Più ragionamento, italiano più naturale. Ideale per analisi salute complesse e ottimizzazioni del piano.",
            diskSizeMB: 1900,
            minRamGB: 8
        ),
    ]

    static let defaultId = "mlx-community/Qwen2.5-1.5B-Instruct-4bit"

    static func find(_ id: String) -> LocalModelOption? {
        all.first { $0.id == id }
    }
}
