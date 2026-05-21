import SwiftUI
import SwiftData
import VocabularyKit
import SpekaUI

/// SPEKA — local-first English vocabulary trainer (Pass 1: no Firebase yet).
///
/// Sets up the SwiftData `ModelContainer` for the VocabularyKit `@Model` types,
/// seeds the A1 word list on first launch, and hands off to `AppRouter`.
@main
struct SpekaApp: App {
    /// Shared SwiftData container for all VocabularyKit persistent models.
    let modelContainer: ModelContainer

    @StateObject private var profileStore = ProfileStore()

    init() {
        // Register the bundled Fredoka display font (graceful fallback if absent).
        SpekaFont.registerFonts()

        do {
            let schema = Schema([
                Word.self,
                Translation.self,
                ReviewState.self,
                UserProgress.self,
                StudySession.self
            ])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            // A failed store is unrecoverable for the app; surface it loudly in
            // debug rather than limping along with a half-initialised stack.
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }

        // Seed the A1 vocabulary on first launch (idempotent, version-guarded).
        SeedLoader.seedIfNeeded(into: modelContainer.mainContext)

        #if DEBUG
        // TEMP VBR instrumentation: assert seed count + active level.
        let ctx = modelContainer.mainContext
        let total = (try? ctx.fetchCount(FetchDescriptor<Word>())) ?? -1
        let a1 = (try? ctx.fetchCount(FetchDescriptor<Word>(predicate: #Predicate { $0.cefrRaw == "a1" }))) ?? -1
        let a2 = (try? ctx.fetchCount(FetchDescriptor<Word>(predicate: #Predicate { $0.cefrRaw == "a2" }))) ?? -1
        let lvl = UserDefaults.standard.string(forKey: "speka.profile.level") ?? "nil"
        NSLog("SPEKA_VBR seedCount total=\(total) a1=\(a1) a2=\(a2) activeLevelDefault=\(lvl)")

        // TEMP VBR affordance: deterministically populate completed sessions so a
        // streak + daily-goal screenshot can be captured headlessly. Uses the same
        // `StatsStore.recordSession` path the live study loop uses on completion.
        if ProcessInfo.processInfo.arguments.contains("-speka-seed-sessions") {
            let cal = Calendar.current
            let now = Date()
            for daysAgo in 0..<3 {
                let day = cal.date(byAdding: .day, value: -daysAgo, to: now)!
                let cards = daysAgo == 0 ? 12 : 20
                StatsStore.recordSession(
                    language: .tr,
                    startedAt: day,
                    endedAt: day,
                    cardsReviewed: cards,
                    correctCount: cards - 2,
                    in: ctx
                )
            }
            NSLog("SPEKA_VBR seeded 3 completed sessions for streak demo")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environmentObject(profileStore)
                .preferredColorScheme(.light)
        }
        .modelContainer(modelContainer)
    }
}
