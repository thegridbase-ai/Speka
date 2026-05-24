import Foundation
import SwiftData
import VocabularyKit

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - SyncService

/// Optional, **local-first** Firestore sync of the learner's progress.
///
/// SwiftData remains the on-device source of truth; sync only mirrors it to a
/// single Firestore document per user at `spekaProgress/{uid}`. (This Firebase
/// project is shared with another app, so SPEKA uses its own `spekaProgress`
/// collection rather than the shared `users` collection.) Signed-out = no sync and
/// the app is fully usable. The UI never blocks on the network — `pull`/`push`
/// run in detached tasks and Firestore's built-in offline persistence absorbs
/// connectivity gaps.
///
/// Conflict policy is **doc-level last-write-wins**: on sign-in we `pull` (apply
/// remote if its `updatedAt` is newer than our last-sync marker, else `push` the
/// local state up). After a session / profile change we debounce a `push`.
///
/// Firestore (and Firebase) may be entirely absent at runtime (no
/// `GoogleService-Info.plist`); every entry point is guarded so the app behaves
/// exactly as before when sync is unavailable.
@MainActor
final class SyncService: ObservableObject {

    /// The SwiftData context to read/write local models against.
    private let modelContext: ModelContext
    /// The profile store mirrored to/from the doc's `profile` block.
    private let profileStore: ProfileStore

    /// Currently-signed-in uid, or `nil` when signed out / unavailable.
    private(set) var activeUID: String?

    /// Pending debounced push task (cancelled + replaced on each request).
    private var pushDebounce: Task<Void, Never>?

    /// Local marker of the last successfully-synced remote `updatedAt`, per uid.
    private let lastSyncDefaultsKeyPrefix = "speka.sync.lastUpdatedAt."

    /// Whether Firestore is compiled in AND a Firebase app is configured.
    var isSyncAvailable: Bool {
        #if canImport(FirebaseFirestore)
        return FirebaseApp.app() != nil
        #else
        return false
        #endif
    }

    init(modelContext: ModelContext, profileStore: ProfileStore) {
        self.modelContext = modelContext
        self.profileStore = profileStore
    }

    // MARK: - Auth lifecycle hooks

    /// Begin syncing for a signed-in user: pull remote, then push local.
    func start(uid: String) {
        guard isSyncAvailable else { return }
        activeUID = uid
        Task { [weak self] in
            await self?.pull(uid: uid)
            await self?.push(uid: uid)
        }
    }

    /// Stop syncing (on sign-out). Local data is untouched and stays usable.
    func stop() {
        pushDebounce?.cancel()
        pushDebounce = nil
        activeUID = nil
    }

    /// Debounced push triggered by session completion / profile / goal changes.
    /// No-ops when signed out or sync unavailable.
    func schedulePush(delay: TimeInterval = 2.0) {
        guard isSyncAvailable, let uid = activeUID else { return }
        pushDebounce?.cancel()
        pushDebounce = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.push(uid: uid)
        }
    }

    // MARK: - Pull

    /// Read `spekaProgress/{uid}`; if it exists and is newer than our last-sync marker,
    /// apply remote → local. If the remote doc is missing, do nothing (the
    /// follow-up `push` seeds it from local).
    func pull(uid: String) async {
        #if canImport(FirebaseFirestore)
        guard isSyncAvailable else { return }
        do {
            let snapshot = try await Firestore.firestore().collection("spekaProgress").document(uid).getDocument()
            guard snapshot.exists, let data = snapshot.data() else { return }

            // Doc-level last-write-wins: only apply if remote is strictly newer
            // than the last remote state we already applied.
            let remoteUpdated = (data["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
            if remoteUpdated <= lastSyncedAt(uid: uid) { return }

            applyRemote(data)
            setLastSyncedAt(remoteUpdated, uid: uid)
        } catch {
            #if DEBUG
            print("[SyncService] pull failed: \(error.localizedDescription)")
            #endif
        }
        #endif
    }

    // MARK: - Push

    /// Serialize local state → write `spekaProgress/{uid}` with a server timestamp, then
    /// record the local last-sync marker (read back from the written doc).
    func push(uid: String) async {
        #if canImport(FirebaseFirestore)
        guard isSyncAvailable else { return }
        let payload = serializeLocal()
        do {
            let ref = Firestore.firestore().collection("spekaProgress").document(uid)
            var doc = payload
            doc["updatedAt"] = FieldValue.serverTimestamp()
            try await ref.setData(doc, merge: true)

            // Read back the resolved server timestamp so our marker matches what
            // a subsequent pull would see (prevents a redundant re-apply).
            if let written = try? await ref.getDocument().data(),
               let ts = (written["updatedAt"] as? Timestamp)?.dateValue() {
                setLastSyncedAt(ts, uid: uid)
            }
        } catch {
            #if DEBUG
            print("[SyncService] push failed: \(error.localizedDescription)")
            #endif
        }
        #endif
    }

    // MARK: - Serialization (local → dictionary)

    /// Build the Firestore document payload from local SwiftData + profile state.
    /// Pure and side-effect free so it can be unit-tested without Firebase.
    func serializeLocal() -> [String: Any] {
        var doc: [String: Any] = [:]

        // profile
        var profile: [String: Any] = [:]
        if let level = profileStore.level { profile["level"] = level.rawValue }
        if let lang = profileStore.nativeLanguage { profile["nativeLanguage"] = lang.rawValue }
        profile["dailyGoal"] = StatsStore.dailyGoal()
        doc["profile"] = profile

        // reviewStates keyed by word id
        var reviewStates: [String: Any] = [:]
        let words = (try? modelContext.fetch(FetchDescriptor<Word>())) ?? []
        for word in words {
            guard let rs = word.reviewState else { continue }
            reviewStates[word.id] = Self.encode(reviewState: rs)
        }
        doc["reviewStates"] = reviewStates

        // stats snapshot (display continuity; streak is also recomputable locally)
        let summary = StatsStore.summary(in: modelContext)
        doc["stats"] = [
            "streak": summary.streak,
            "cardsToday": summary.cardsToday,
            "goal": summary.goal
        ]

        // completed sessions — so streak, daily goal and the weekly chart survive
        // a reinstall / restore on a new device (the streak is derived from these).
        let sessions = (try? modelContext.fetch(FetchDescriptor<StudySession>())) ?? []
        doc["sessions"] = sessions.map { Self.encode(session: $0) }

        return doc
    }

    /// Encode a single `ReviewState` to a Firestore-friendly dictionary.
    static func encode(reviewState rs: ReviewState) -> [String: Any] {
        var dict: [String: Any] = [
            "wordState": rs.wordState.rawValue,
            "easeFactor": rs.easeFactor,
            "intervalDays": rs.interval,
            "repetitions": rs.repetitions,
            "dueDate": rs.dueDate.timeIntervalSince1970,
            "updatedAt": rs.updatedAt.timeIntervalSince1970
        ]
        if let last = rs.lastReviewed {
            dict["lastReviewed"] = last.timeIntervalSince1970
        }
        return dict
    }

    /// Encode a completed `StudySession` to a Firestore-friendly dictionary.
    static func encode(session s: StudySession) -> [String: Any] {
        var dict: [String: Any] = [
            "id": s.id,
            "languageRaw": s.languageRaw,
            "startedAt": s.startedAt.timeIntervalSince1970,
            "cardsReviewed": s.cardsReviewed,
            "correctCount": s.correctCount,
            "newWordsIntroduced": s.newWordsIntroduced,
            "updatedAt": s.updatedAt.timeIntervalSince1970
        ]
        if let ended = s.endedAt { dict["endedAt"] = ended.timeIntervalSince1970 }
        return dict
    }

    // MARK: - Deserialization (dictionary → local)

    /// Apply a fetched Firestore document onto local state. Profile → UserDefaults
    /// via `ProfileStore`; review states merged onto matching `Word`s by id.
    func applyRemote(_ data: [String: Any]) {
        // profile
        if let profile = data["profile"] as? [String: Any] {
            if let raw = profile["level"] as? String, let level = CEFRLevel(rawValue: raw) {
                profileStore.setLevel(level)
            }
            if let raw = profile["nativeLanguage"] as? String, let lang = SourceLanguage(rawValue: raw) {
                profileStore.setLanguage(lang)
            }
            if let goal = profile["dailyGoal"] as? Int {
                StatsStore.setDailyGoal(goal)
            }
        }

        // reviewStates → merge onto local Words by id (only when remote is newer
        // per-row, so a fresher local grade isn't clobbered)
        if let remoteStates = data["reviewStates"] as? [String: Any] {
            let words = (try? modelContext.fetch(FetchDescriptor<Word>())) ?? []
            let byID = Dictionary(uniqueKeysWithValues: words.map { ($0.id, $0) })
            for (wordID, value) in remoteStates {
                guard let dict = value as? [String: Any], let word = byID[wordID] else { continue }
                Self.merge(dict: dict, into: word, in: modelContext)
            }
            try? modelContext.save()
        }

        // sessions → insert any the local store lacks (dedup by unique id), so the
        // streak / daily goal / weekly stats survive reinstall + cross-device.
        if let remoteSessions = data["sessions"] as? [[String: Any]] {
            let existing = (try? modelContext.fetch(FetchDescriptor<StudySession>())) ?? []
            let existingIDs = Set(existing.map { $0.id })
            for sdict in remoteSessions {
                guard let id = sdict["id"] as? String, !existingIDs.contains(id),
                      let startedTS = sdict["startedAt"] as? TimeInterval else { continue }
                let langRaw = sdict["languageRaw"] as? String ?? SourceLanguage.tr.rawValue
                let session = StudySession(
                    id: id,
                    language: SourceLanguage(rawValue: langRaw) ?? .tr,
                    startedAt: Date(timeIntervalSince1970: startedTS),
                    endedAt: (sdict["endedAt"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) },
                    cardsReviewed: sdict["cardsReviewed"] as? Int ?? 0,
                    correctCount: sdict["correctCount"] as? Int ?? 0,
                    newWordsIntroduced: sdict["newWordsIntroduced"] as? Int ?? 0,
                    updatedAt: Date(timeIntervalSince1970: sdict["updatedAt"] as? TimeInterval ?? startedTS),
                    dirty: false
                )
                modelContext.insert(session)
            }
            try? modelContext.save()
        }
    }

    /// Merge one decoded review-state dict onto a `Word`, creating the local
    /// `ReviewState` if absent. Skips when the local row is at least as fresh.
    static func merge(dict: [String: Any], into word: Word, in context: ModelContext) {
        let remoteUpdated = Date(timeIntervalSince1970: dict["updatedAt"] as? TimeInterval ?? 0)
        if let existing = word.reviewState, existing.updatedAt >= remoteUpdated {
            return // local is newer or equal — keep it
        }

        let rs = word.reviewState ?? {
            let fresh = ReviewState()
            context.insert(fresh)
            word.reviewState = fresh
            return fresh
        }()

        if let raw = dict["wordState"] as? String, let ws = WordState(rawValue: raw) {
            rs.wordState = ws
        }
        if let ease = dict["easeFactor"] as? Double { rs.easeFactor = ease }
        if let interval = dict["intervalDays"] as? Int { rs.interval = interval }
        if let reps = dict["repetitions"] as? Int { rs.repetitions = reps }
        if let due = dict["dueDate"] as? TimeInterval { rs.dueDate = Date(timeIntervalSince1970: due) }
        if let last = dict["lastReviewed"] as? TimeInterval {
            rs.lastReviewed = Date(timeIntervalSince1970: last)
        }
        rs.updatedAt = remoteUpdated
        rs.dirty = false
    }

    // MARK: - Last-sync marker

    private func lastSyncedAt(uid: String) -> Date {
        let ts = UserDefaults.standard.double(forKey: lastSyncDefaultsKeyPrefix + uid)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : .distantPast
    }

    private func setLastSyncedAt(_ date: Date, uid: String) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: lastSyncDefaultsKeyPrefix + uid)
    }
}
