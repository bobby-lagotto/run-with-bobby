import SwiftUI

struct NutritionPlanView: View {
    @ObservedObject var nutritionManager: NutritionPlanManager
    @ObservedObject var planManager: TrainingPlanManager
    var onAskBobby: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            ScrollView {
                if let plan = nutritionManager.currentNutritionPlan {
                    VStack(spacing: 16) {
                        // Hero card
                        heroCard(plan: plan)
                            .bobbyCard()
                            .padding(.horizontal, 16)

                        // Ask Bobby button
                        if let onAskBobby {
                            Button(action: onAskBobby) {
                                Label("Chiedi a Bobby di modificare", systemImage: "bubble.left.fill")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.bobbyRed)
                                    .clipShape(RoundedRectangle(cornerRadius: BobbyTheme.cornerRadiusSmall))
                            }
                            .padding(.horizontal, 16)
                        }

                        // Weekly nutrition
                        SectionHeader(title: "Piano Settimanale")
                            .padding(.horizontal, 16)

                        ForEach(plan.weeklyNutrition) { day in
                            DayNutritionRowView(dayNutrition: day)
                                .bobbyCard()
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 16)
                } else {
                    emptyState
                }
            }
            .background(BobbyTheme.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Piano Alimentare")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { dismiss() }
                        .foregroundColor(.bobbyRed)
                }
            }
        }
    }

    private func heroCard(plan: NutritionPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(plan.title)
                .font(.title2.weight(.bold))
                .foregroundColor(.bobbyCharcoal)

            if let trainingPlan = planManager.currentActivePlan,
               plan.linkedTrainingPlanId == trainingPlan.id {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.caption)
                    Text("Collegato a: \(trainingPlan.title)")
                        .font(.caption)
                }
                .foregroundColor(.bobbyCaramel)
            }

            // Weekly totals
            let totals = weeklyTotals(for: plan)
            HStack(spacing: 16) {
                MacroTotalPill(label: "Proteine", grams: totals.proteine, color: .bobbyRed)
                MacroTotalPill(label: "Carbo", grams: totals.carboidrati, color: .bobbyCaramel)
                MacroTotalPill(label: "Verd/Fr", grams: totals.verdure, color: .workoutEasy)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife")
                .font(.system(size: 40))
                .foregroundColor(.bobbyWarmGray.opacity(0.5))
            Text("Nessun piano alimentare")
                .font(.subheadline)
                .foregroundColor(.bobbyWarmGray)
            Text("Chiedi a Bobby di crearne uno!")
                .font(.caption)
                .foregroundColor(.bobbyWarmGray)
        }
        .padding(.top, 60)
    }

    private func weeklyTotals(for plan: NutritionPlan) -> (proteine: Int, carboidrati: Int, verdure: Int) {
        let p = plan.weeklyNutrition.reduce(0) { $0 + $1.proteine_g }
        let c = plan.weeklyNutrition.reduce(0) { $0 + $1.carboidrati_g }
        let v = plan.weeklyNutrition.reduce(0) { $0 + $1.verdure_frutta_g }
        return (p, c, v)
    }
}

// MARK: - Macro Total Pill
struct MacroTotalPill: View {
    let label: String
    let grams: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(grams)g")
                .font(.caption.weight(.bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.bobbyWarmGray)
        }
    }
}

// MARK: - Day Nutrition Row
struct DayNutritionRowView: View {
    let dayNutrition: DayNutrition

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text(dayNutrition.dayOfWeek)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.bobbyCharcoal)

                Spacer()

                intensityBadge
            }

            // Macro bars
            VStack(spacing: 6) {
                MacroRowView(label: "Proteine", grams: dayNutrition.proteine_g, color: .bobbyRed, icon: "fish.fill")
                MacroRowView(label: "Carboidrati", grams: dayNutrition.carboidrati_g, color: .bobbyCaramel, icon: "leaf.fill")
                MacroRowView(label: "Verdure/Frutta", grams: dayNutrition.verdure_frutta_g, color: .workoutEasy, icon: "carrot.fill")
                MacroRowView(label: "Dolci", grams: dayNutrition.dolci_g, color: .workoutTempo, icon: "birthday.cake.fill")
            }

            // Food examples
            if !dayNutrition.note.isEmpty {
                Text(dayNutrition.note)
                    .font(.caption)
                    .foregroundColor(.bobbyWarmGray)
                    .padding(.top, 2)
            }

            if !dayNutrition.foodExamples.isEmpty {
                HStack(spacing: 8) {
                    ForEach(dayNutrition.foodExamples.prefix(4)) { example in
                        Text("\(example.grams)g \(example.foodName)")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(macroColor(for: example.macroCategory).opacity(0.08))
                            .foregroundColor(macroColor(for: example.macroCategory))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var intensityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: intensityIcon)
            Text(dayNutrition.trainingIntensity.capitalized)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(intensityColor.opacity(0.12))
        .foregroundColor(intensityColor)
        .clipShape(Capsule())
    }

    private var intensityIcon: String {
        switch dayNutrition.trainingIntensity.lowercased() {
        case "riposo": return "bed.double.fill"
        case "leggero": return "figure.walk"
        case "moderato": return "figure.run"
        case "intenso": return "bolt.fill"
        default: return "circle.fill"
        }
    }

    private var intensityColor: Color {
        switch dayNutrition.trainingIntensity.lowercased() {
        case "riposo": return .workoutRest
        case "leggero": return .workoutEasy
        case "moderato": return .workoutTempo
        case "intenso": return .workoutIntervals
        default: return .bobbyWarmGray
        }
    }

    private func macroColor(for category: String) -> Color {
        switch category {
        case "proteine": return .bobbyRed
        case "carboidrati": return .bobbyCaramel
        case "verdure_frutta": return .workoutEasy
        case "dolci": return .workoutTempo
        default: return .bobbyWarmGray
        }
    }
}

// MARK: - Macro Row
struct MacroRowView: View {
    let label: String
    let grams: Int
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 20)

            Text(label)
                .font(.caption)
                .foregroundColor(.bobbyWarmGray)

            Spacer()

            Text("\(grams)g")
                .font(.caption.weight(.bold))
                .foregroundColor(color)
        }
    }
}
