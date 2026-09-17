import Foundation

struct HealthCitation: Identifiable, Equatable {
    let id: String
    let organization: String
    let title: String
    let url: URL
}

enum HealthCitations {
    static let all: [HealthCitation] = [
        HealthCitation(
            id: "issn-protein",
            organization: "ISSN",
            title: "Position Stand: protein and exercise",
            url: URL(string: "https://doi.org/10.1186/s12970-017-0177-8")!
        ),
        HealthCitation(
            id: "acsm-nutrition",
            organization: "ACSM / AND / DC",
            title: "Nutrition and Athletic Performance",
            url: URL(string: "https://doi.org/10.1249/MSS.0000000000000852")!
        ),
        HealthCitation(
            id: "issn-timing",
            organization: "ISSN",
            title: "Position Stand: nutrient timing",
            url: URL(string: "https://doi.org/10.1186/1550-2783-10-5")!
        ),
        HealthCitation(
            id: "acsm-fluid",
            organization: "ACSM",
            title: "Exercise and Fluid Replacement",
            url: URL(string: "https://doi.org/10.1249/MSS.0b013e31802ca597")!
        )
    ]

    static var disclaimer: String {
        L10n.tr(
            "Bobby è un coach di corsa, non un medico né un dietista. Le indicazioni su recupero, carico e alimentazione sono educative, food-first e non sostituiscono una diagnosi o un piano clinico. Se hai sintomi, patologie o dubbi, rivolgiti a un professionista sanitario.",
            english: "Bobby is a running coach, not a doctor or dietitian. Recovery, load and nutrition notes are educational and food-first; they are not a diagnosis or a clinical plan. If you have symptoms, a condition or doubts, see a healthcare professional."
        )
    }

    static var chatFooter: String {
        L10n.tr(
            "Non è consiglio medico. Fonti: ISSN e ACSM — Impostazioni > Fonti, oppure il menu Fonti in chat.",
            english: "This is not medical advice. Sources: ISSN and ACSM — Settings > Sources, or the Sources menu in chat."
        )
    }

    static func appendingFooter(to text: String) -> String {
        if text.contains(chatFooter) { return text }
        return text + "\n\n" + chatFooter
    }
}
