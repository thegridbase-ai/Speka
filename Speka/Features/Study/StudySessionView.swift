import SwiftUI
import SwiftData
import VocabularyKit
import SpekaUI

/// The core study loop and shared host for every practice mode.
///
/// `StudySessionView` owns the daily queue, the progress indicator, the
/// advance/finish logic, SM-2 persistence and the end-of-session summary. The
/// per-card UI is delegated to a mode-specific view (flashcard / type / listen /
/// multiple choice) which reports a `ReviewGrade` back through `applyGrade`.
struct StudySessionView: View {
    let level: CEFRLevel
    let language: SourceLanguage
    var mode: StudyMode = .flashcard

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var queue: [Word] = []
    @State private var index = 0
    @State private var isFlipped = false
    @State private var reviewedCount = 0
    @State private var correctCount = 0
    @State private var didFinish = false
    @State private var startedAt = Date()
    @State private var endedAt: Date?
    @State private var didRecord = false

    /// Celebration state: bumped on a correct grade to fire confetti + Pip.
    @State private var celebrateTrigger = 0
    @State private var showConfetti = false

    /// Per-card feedback overlay: Pip cheers a correct grade or gently
    /// encourages after a miss (which also shakes the card). `shakeTrigger`
    /// bumps on a wrong grade to drive the `KeyframeAnimator` wobble.
    @State private var feedback: GradeFeedback?
    @State private var shakeTrigger = 0

    /// A short-lived reaction shown over the card after grading.
    private enum GradeFeedback: Equatable {
        case correct
        case wrong

        var pip: SpekaMascot.PipState { self == .correct ? .cheer : .kind }
        var accent: SpekaAccent { self == .correct ? .mint : .coral }
        var message: String { self == .correct ? "Nice!" : "Keep going" }
    }

    #if DEBUG
    /// DEBUG-only scripted auto-demo. Non-`nil` only when the `-speka-demo`
    /// launch arg is present; otherwise the driver is never constructed and the
    /// view behaves exactly as in release.
    @StateObject private var demo = DemoDriver()
    #endif

    private var accent: SpekaAccent { mode.spekaAccent }

    var body: some View {
        ZStack {
            SpekaBackground()

            if didFinish {
                SessionSummaryView(
                    reviewed: reviewedCount,
                    correct: correctCount,
                    durationSeconds: (endedAt ?? Date()).timeIntervalSince(startedAt),
                    streak: StatsStore.summary(in: modelContext).streak,
                    onDone: { dismiss() }
                )
            } else if queue.isEmpty {
                emptyState
            } else {
                sessionContent
            }

            // Correct-answer celebration overlay (cheap, GPU emitter).
            SpekaConfetti(isActive: showConfetti)
                .allowsHitTesting(false)

            // Per-card Pip reaction (cheer / kind) over the card.
            feedbackOverlay
                .allowsHitTesting(false)
        }
        .sensoryFeedback(.success, trigger: celebrateTrigger)
        .onAppear(perform: loadQueue)
        #if DEBUG
        .onAppear {
            // Deterministic QA: jump straight to the end-of-session summary.
            if ProcessInfo.processInfo.arguments.contains("-speka-summary") {
                reviewedCount = 20
                correctCount = 18
                startedAt = Date().addingTimeInterval(-240) // ~4 min elapsed
                endedAt = Date()
                didFinish = true
                return
            }
            // Arm the scripted demo only when explicitly requested at launch.
            guard ProcessInfo.processInfo.arguments.contains("-speka-demo") else { return }
            demo.start(host: DemoHost(
                flip: { withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { isFlipped.toggle() } },
                grade: { grade in
                    if let word = currentWord { applyGrade(grade, to: word) }
                },
                isFinished: { didFinish }
            ))
        }
        .onDisappear { demo.stop() }
        #endif
    }

    /// The transient Pip reaction shown after a grade. Pops in, lingers, fades.
    @ViewBuilder
    private var feedbackOverlay: some View {
        if let feedback, !didFinish {
            VStack(spacing: 8) {
                SpekaMascot(state: feedback.pip, idle: false)
                    .frame(width: 132, height: 132)
                    .popIn()
                Text(feedback.message)
                    .font(SpekaFont.font(.headline))
                    .foregroundStyle(feedback.accent.edge)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(feedback.accent.soft))
            }
            .transition(.scale(scale: 0.85).combined(with: .opacity))
            .id(feedback)
        }
    }

    // MARK: - Loading

    private func loadQueue() {
        guard queue.isEmpty, !didFinish else { return }
        startedAt = Date()
        var built = WordStore.dailyQueue(at: level, now: Date(), in: modelContext)
        #if DEBUG
        // Auto-demo: cap the queue so the full arc (flip → correct → wrong →
        // summary) fits inside a short screen recording. DEBUG + arg only.
        if ProcessInfo.processInfo.arguments.contains("-speka-demo") {
            built = Array(built.prefix(4))
        }
        #endif
        queue = built
    }

    /// Persist a completed/partial session exactly once so streak + daily goal
    /// reflect the cards just reviewed. Called both on natural completion and on
    /// an early close (if at least one card was reviewed).
    private func recordSessionIfNeeded() {
        guard !didRecord, reviewedCount > 0 else { return }
        didRecord = true
        StatsStore.recordSession(
            language: language,
            startedAt: startedAt,
            cardsReviewed: reviewedCount,
            correctCount: correctCount,
            in: modelContext
        )
    }

    private var currentWord: Word? {
        guard index < queue.count else { return nil }
        return queue[index]
    }

    // MARK: - Content

    private var sessionContent: some View {
        VStack(spacing: 0) {
            topBar

            SpekaProgressBar(
                progress: Double(index) / Double(max(queue.count, 1)),
                gradientStops: SpekaColor.brandStops
            )
            .padding(.horizontal, 24)
            .padding(.top, 4)

            cardArea
        }
    }

    /// The mode-specific card + grading affordance, filling the area between the
    /// progress bar and the bottom safe area.
    @ViewBuilder
    private var cardArea: some View {
        if let word = currentWord {
            switch mode {
            case .flashcard:
                flashcardArea(word)
            case .type:
                TypeTranslationView(
                    word: word,
                    language: language,
                    onGrade: { applyGrade($0, to: word) }
                )
                .id(word.id)
            case .listen:
                ListenAndSpellView(
                    word: word,
                    onGrade: { applyGrade($0, to: word) }
                )
                .id(word.id)
            case .multipleChoice:
                MultipleChoiceView(
                    word: word,
                    language: language,
                    options: options(for: word),
                    onGrade: { applyGrade($0, to: word) }
                )
                .id(word.id)
            }
        }
    }

    /// Flashcard keeps its flip-card + four-grade bar layout, hosted here so the
    /// flip state lives alongside the queue cursor.
    private func flashcardArea(_ word: Word) -> some View {
        VStack(spacing: 0) {
            Spacer()
            FlashcardView(word: word, language: language, isFlipped: $isFlipped, accent: accent)
                .padding(.horizontal, 24)
                .id(word.id)
                .shake(trigger: shakeTrigger)
            Spacer()
            gradeBar(for: word)
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                recordSessionIfNeeded()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(SpekaColor.textSecondary)
                    .frame(width: 40, height: 40)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(mode.title)
                    .font(SpekaFont.font(.label))
                    .textCase(.uppercase)
                    .foregroundStyle(accent.base)
                HStack(spacing: 2) {
                    Text("\(min(index + 1, queue.count))")
                        .contentTransition(.numericText())
                    Text("/ \(queue.count)")
                }
                .spekaFont(.subhead)
                .foregroundStyle(SpekaColor.textSecondary)
            }

            Spacer()

            // Symmetry spacer to keep the counter centered.
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    // MARK: - Flashcard grade bar

    private func gradeBar(for word: Word) -> some View {
        Group {
            if isFlipped {
                HStack(spacing: 10) {
                    gradeButton(.again, title: "Again", accent: .coral, word: word)
                    gradeButton(.hard, title: "Hard", accent: .sunflower, word: word)
                    gradeButton(.good, title: "Good", accent: .sky, word: word)
                    gradeButton(.easy, title: "Easy", accent: .mint, word: word)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Text("Tap the card to see the answer")
                    .spekaFont(.subhead)
                    .foregroundStyle(SpekaColor.textTertiary)
                    .frame(height: 60)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isFlipped)
    }

    private func gradeButton(_ grade: ReviewGrade, title: String, accent: SpekaAccent, word: Word) -> some View {
        Button {
            applyGrade(grade, to: word)
        } label: {
            Text(title)
        }
        .buttonStyle(SpekaButtonStyle(variant: .filled(accent), depth: 4, cornerRadius: 14, fullWidth: true))
    }

    // MARK: - Multiple-choice options

    /// Build four Turkish options for a word: the correct translation plus three
    /// distractors sampled from the same level, preferring the same part of
    /// speech, then shuffled.
    private func options(for word: Word) -> [String] {
        let correct = word.translation(for: language)?.text ?? "—"
        let correctKey = AnswerMatch.normalize(correct)

        // Candidate pool: every other word at this level that has a translation.
        let pool = queue + WordStore.words(at: level, in: modelContext)
        var seen = Set<String>([correctKey])
        var samePOS: [String] = []
        var others: [String] = []

        for candidate in pool where candidate.id != word.id {
            guard let text = candidate.translation(for: language)?.text else { continue }
            let key = AnswerMatch.normalize(text)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            if candidate.partOfSpeech == word.partOfSpeech, word.partOfSpeech != nil {
                samePOS.append(text)
            } else {
                others.append(text)
            }
        }

        var distractors = samePOS.shuffled()
        if distractors.count < 3 {
            distractors += others.shuffled()
        }
        let chosen = Array(distractors.prefix(3))

        return ([correct] + chosen).shuffled()
    }

    // MARK: - Grading

    private func applyGrade(_ grade: ReviewGrade, to word: Word?) {
        guard let word else { return }

        // Lazily create the review state on first grade.
        let state: ReviewState
        if let existing = word.reviewState {
            state = existing
        } else {
            let fresh = ReviewState()
            modelContext.insert(fresh)
            word.reviewState = fresh
            state = fresh
        }

        let now = Date()
        state.review(grade: grade, now: now)
        try? modelContext.save()

        reviewedCount += 1
        let wasCorrect = grade.quality >= ReviewGrade.good.quality
        if wasCorrect { correctCount += 1 }

        playGradeHaptic(grade)
        if wasCorrect {
            celebrate()
        } else {
            commiserate()
        }
        advance()
    }

    /// Fire the confetti burst + bump the success sensory-feedback trigger, and
    /// pop a cheering Pip over the card.
    private func celebrate() {
        celebrateTrigger += 1
        showConfetti = true
        showFeedback(.correct)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            showConfetti = false
        }
    }

    /// Wrong answer: shake the card and show a kind, encouraging Pip.
    private func commiserate() {
        shakeTrigger += 1
        showFeedback(.wrong)
    }

    /// Show a transient Pip reaction, then clear it after a short beat.
    private func showFeedback(_ kind: GradeFeedback) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { feedback = kind }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeOut(duration: 0.25)) { feedback = nil }
        }
    }

    private func playGradeHaptic(_ grade: ReviewGrade) {
        switch grade {
        case .again: GradeHaptics.play(.heavy)
        case .hard: GradeHaptics.play(.medium)
        case .good: GradeHaptics.play(.light)
        case .easy: GradeHaptics.play(.success)
        }
    }

    private func advance() {
        let next = index + 1
        if next >= queue.count {
            recordSessionIfNeeded()
            // Clear any transient per-card reaction (Pip + "Keep going"/"Nice!")
            // and the card's confetti so they don't linger ON TOP of the summary,
            // then switch instantly — a cross-fade would show the card through the
            // summary's opaque background.
            feedback = nil
            showConfetti = false
            endedAt = Date()
            didFinish = true
        } else {
            // Reset the flip state, then move to the next card on the next runloop
            // tick so the card flips back to its front before swapping content.
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                isFlipped = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                index = next
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            SpekaMascot(state: .hero)
                .frame(width: 140, height: 140)
            Text("Nothing to study right now")
                .font(SpekaFont.font(.title))
                .foregroundStyle(SpekaColor.textPrimary)
            SpekaButton("Back to home", systemImage: "house.fill", variant: .filled(level.accent)) {
                dismiss()
            }
        }
        .padding(32)
    }
}
