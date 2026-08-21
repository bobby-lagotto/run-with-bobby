import Foundation

enum LocalModelFamily: String, Hashable {
    case qwen4bit
    case bonsai1bit
    case ternary2bit

    var badge: String {
        switch self {
        case .qwen4bit: return "4-bit"
        case .bonsai1bit: return "1-bit"
        case .ternary2bit: return "2-bit ternario"
        }
    }
}

struct LocalModelOption: Identifiable, Hashable {
    let id: String           // HuggingFace path, e.g. "mlx-community/Qwen2.5-1.5B-Instruct-4bit"
    let tier: String         // "Compatto" / "Bilanciato" / "Potente" / "Flagship"
    let shortName: String    // "Qwen 2.5 1.5B"
    let description: String
    let diskSizeMB: Int
    let minRamGB: Int
    let family: LocalModelFamily
    let requirementTextOverride: String?
    let supportsNativeToolCalling: Bool

    init(
        id: String,
        tier: String,
        shortName: String,
        description: String,
        diskSizeMB: Int,
        minRamGB: Int,
        family: LocalModelFamily,
        requirementTextOverride: String? = nil,
        supportsNativeToolCalling: Bool = true
    ) {
        self.id = id
        self.tier = tier
        self.shortName = shortName
        self.description = description
        self.diskSizeMB = diskSizeMB
        self.minRamGB = minRamGB
        self.family = family
        self.requirementTextOverride = requirementTextOverride
        self.supportsNativeToolCalling = supportsNativeToolCalling
    }

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
        requirementTextOverride ?? "Richiede iPhone con almeno \(minRamGB) GB di RAM."
    }
}

enum LocalModelCatalog {
    static let all: [LocalModelOption] = qwenModels + bonsaiModels

    static let qwenModels: [LocalModelOption] = [
        LocalModelOption(
            id: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
            tier: "Compatto",
            shortName: "Qwen 2.5 0.5B",
            description: "Ultra-leggero. Chat semplice; i piani usano il motore deterministico, non il tool-calling del modello. Fallback per iPhone più vecchi.",
            diskSizeMB: 400,
            minRamGB: 4,
            family: .qwen4bit,
            supportsNativeToolCalling: false
        ),
        LocalModelOption(
            id: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
            tier: "Bilanciato",
            shortName: "Qwen 2.5 1.5B",
            description: "Default consigliato. Buon equilibrio velocità/qualità. Tool-calling affidabile per generare e modificare piani.",
            diskSizeMB: 900,
            minRamGB: 6,
            family: .qwen4bit
        ),
        LocalModelOption(
            id: "mlx-community/Qwen2.5-3B-Instruct-4bit",
            tier: "Potente",
            shortName: "Qwen 2.5 3B",
            description: "Più ragionamento, italiano più naturale. Ideale per analisi salute complesse e ottimizzazioni del piano.",
            diskSizeMB: 1900,
            minRamGB: 8,
            family: .qwen4bit
        ),
    ]

    static let bonsaiModels: [LocalModelOption] = [
        LocalModelOption(
            id: "prism-ml/Ternary-Bonsai-4B-mlx-2bit",
            tier: "Ternario 4B",
            shortName: "Ternary Bonsai 4B",
            description: "Pesi {-1, 0, +1}. Qualità migliore del 1-bit a parità di classe, adatto a più iPhone. Circa 50 tok/s su iPhone 17 Pro Max.",
            diskSizeMB: 1130,
            minRamGB: 6,
            family: .ternary2bit
        ),
        LocalModelOption(
            id: "prism-ml/Bonsai-8B-mlx-1bit",
            tier: "Binario 8B",
            shortName: "Bonsai 8B",
            description: "Pesi 1-bit {-1, +1}. Più veloce del ternario 8B, buona per chat offline. Circa 44 tok/s su iPhone 17 Pro Max. Serve il runtime PrismML.",
            diskSizeMB: 1280,
            minRamGB: 6,
            family: .bonsai1bit
        ),
        LocalModelOption(
            id: "prism-ml/Bonsai-27B-mlx-1bit",
            tier: "Flagship 27B",
            shortName: "Bonsai 27B",
            description: "Classe 27B in 1-bit. Download MLX ~5.2 GB (include pesi vision non usati). Tool-calling meno affidabile dei Qwen 4-bit; tienilo come opzione high-end, non come default.",
            diskSizeMB: 5200,
            minRamGB: 12,
            family: .bonsai1bit,
            requirementTextOverride: "Richiede iPhone 17 Pro / Pro Max (12 GB RAM)."
        ),
    ]

    static let defaultId = "mlx-community/Qwen2.5-1.5B-Instruct-4bit"

    static func find(_ id: String) -> LocalModelOption? {
        all.first { $0.id == id }
    }
}
