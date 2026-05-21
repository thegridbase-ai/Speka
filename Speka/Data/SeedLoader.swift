import Foundation
import SwiftData
import VocabularyKit

/// Loads the bundled seed JSON files into the SwiftData store on first launch.
///
/// Guarded by a `UserDefaults` seed-version flag so re-imports only happen when
/// the bundled seed bumps its version. The underlying `SeedImporter` is itself
/// idempotent (upsert keyed off `Word.id`), so a redundant import is harmless —
/// the flag is purely an optimisation to skip the work on every cold start.
enum SeedLoader {

    /// Bump when the bundled seed content changes to force a re-import.
    ///
    /// v1: A1 only. v2: adds A2 (478 words) — existing installs re-import to
    /// pick up the new level.
    static let currentSeedVersion = 2

    private static let seedVersionKey = "speka.seedVersion"

    /// Bundled seed resources, imported in order. The importer is idempotent and
    /// keyed off `Word.id`, so a level appearing across files would merge cleanly.
    private static let seedResourceNames = ["words_a1", "words_a2"]

    static func seedIfNeeded(
        into context: ModelContext,
        defaults: UserDefaults = .standard
    ) {
        let installedVersion = defaults.integer(forKey: seedVersionKey)
        guard installedVersion < currentSeedVersion else { return }

        for resource in seedResourceNames {
            guard let url = Bundle.main.url(
                forResource: resource,
                withExtension: "json"
            ) else {
                assertionFailure("Seed JSON '\(resource).json' missing from app bundle.")
                // Leave the version flag unset so a later launch retries.
                return
            }

            do {
                _ = try SeedImporter.import(contentsOf: url, into: context)
            } catch {
                // Leave the version flag unset so a later launch retries the import.
                assertionFailure("Seed import of '\(resource)' failed: \(error)")
                return
            }
        }

        defaults.set(currentSeedVersion, forKey: seedVersionKey)
    }
}
