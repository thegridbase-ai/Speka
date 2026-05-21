import Foundation
import SwiftData
@testable import VocabularyKit

/// A throwaway SwiftData store for a single test.
///
/// NOTE: we deliberately use a unique **on-disk temp file** rather than
/// `ModelConfiguration(isStoredInMemoryOnly: true)`. On the current toolchain
/// (Swift 6.2.3 / macOS 26 SDK) the in-memory store traps with SIGTRAP on the
/// second SQLite flush (e.g. a second `save()` or a post-mutation `fetch`),
/// which crashes the test process at teardown even though all assertions pass.
/// A fresh on-disk file per test avoids that and is fully isolated.
@MainActor
struct TestStore {
    let container: ModelContainer
    let context: ModelContext
    private let url: URL

    init() throws {
        let schema = Schema([
            Word.self, Translation.self, ReviewState.self,
            UserProgress.self, StudySession.self
        ])
        url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("speka-test-\(UUID().uuidString).store")
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(url: url)]
        )
        context = container.mainContext
    }

    /// Remove the backing store file (call at the end of a test).
    func cleanup() {
        try? FileManager.default.removeItem(at: url)
        // SQLite sidecar files.
        for suffix in ["-shm", "-wal"] {
            try? FileManager.default.removeItem(
                at: url.deletingPathExtension()
                    .appendingPathExtension("store\(suffix)")
            )
        }
    }
}
