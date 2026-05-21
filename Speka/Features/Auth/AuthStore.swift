import Foundation
import SwiftUI
import Combine

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - AuthState

/// The learner's authentication state. Local-first: `signedOut` is a perfectly
/// valid, fully-functional state — sign-in only adds backup/sync.
enum AuthState: Equatable {
    case signedOut
    case signedIn(uid: String, email: String?, displayName: String?)

    var isSignedIn: Bool {
        if case .signedIn = self { return true }
        return false
    }
}

// MARK: - AuthError

/// User-facing auth errors. `notConfigured` is returned (never thrown as a
/// crash) when the app is running without a `GoogleService-Info.plist`.
enum AuthError: LocalizedError {
    case notConfigured
    case missingPresenter
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Sign-in isn't configured yet. You can keep using SPEKA locally — your progress is saved on this device."
        case .missingPresenter:
            return "Couldn't open Google sign-in. Please try again."
        case .underlying(let message):
            return message
        }
    }
}

// MARK: - AuthStore

/// Owns Firebase Auth + Google Sign-In and publishes the current ``AuthState``.
///
/// Designed to be **safe without configuration**: `FirebaseApp.configure()` runs
/// only when a `GoogleService-Info.plist` is bundled. With no plist,
/// ``isAuthAvailable`` is `false`, the app stays fully local-first, and every
/// sign-in method returns a friendly ``AuthError/notConfigured`` instead of
/// crashing.
///
/// Sync (Firestore) is intentionally **not** wired here — this store only
/// establishes identity so a later pass can plug sync into ``state`` changes.
@MainActor
final class AuthStore: ObservableObject {

    /// Current authentication state (drives UI).
    @Published private(set) var state: AuthState = .signedOut

    /// Whether Firebase Auth is configured and usable on this build. `false`
    /// when no `GoogleService-Info.plist` is present.
    let isAuthAvailable: Bool

    #if canImport(FirebaseAuth)
    private var authListener: AuthStateDidChangeListenerHandle?
    #endif

    init() {
        self.isAuthAvailable = AuthStore.configureFirebaseIfPossible()
        observeAuthChanges()
    }

    // MARK: - Guarded Firebase configuration

    /// Configures Firebase **only** if a `GoogleService-Info.plist` is bundled.
    /// Returns whether Firebase Auth is available afterwards. Safe to call once
    /// at startup; never crashes when the plist is absent.
    @discardableResult
    static func configureFirebaseIfPossible() -> Bool {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth)
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            return false
        }
        // Guard against double-configuration (e.g. previews / re-init).
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return FirebaseApp.app() != nil
        #else
        return false
        #endif
    }

    private func observeAuthChanges() {
        #if canImport(FirebaseAuth)
        guard isAuthAvailable else { return }
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.apply(user: user)
            }
        }
        #endif
    }

    #if canImport(FirebaseAuth)
    private func apply(user: User?) {
        if let user {
            state = .signedIn(uid: user.uid, email: user.email, displayName: user.displayName)
        } else {
            state = .signedOut
        }
    }
    #endif

    // MARK: - Sign-in methods

    /// Sign in with Google via the GoogleSignIn SDK, then exchange for a Firebase
    /// credential. Requires a presenting view controller and a configured app.
    func signInWithGoogle(presenting: UIViewController?) async throws {
        guard isAuthAvailable else { throw AuthError.notConfigured }

        #if canImport(FirebaseAuth) && canImport(GoogleSignIn)
        guard let presenter = presenting else { throw AuthError.missingPresenter }
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.notConfigured
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.underlying("Google sign-in returned no ID token.")
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            let authResult = try await Auth.auth().signIn(with: credential)
            apply(user: authResult.user)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.underlying(error.localizedDescription)
        }
        #else
        throw AuthError.notConfigured
        #endif
    }

    /// Sign in with an existing email + password.
    func signInWithEmail(_ email: String, password: String) async throws {
        guard isAuthAvailable else { throw AuthError.notConfigured }

        #if canImport(FirebaseAuth)
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            apply(user: result.user)
        } catch {
            throw AuthError.underlying(error.localizedDescription)
        }
        #else
        throw AuthError.notConfigured
        #endif
    }

    /// Create a new account with email + password.
    func createAccount(_ email: String, password: String) async throws {
        guard isAuthAvailable else { throw AuthError.notConfigured }

        #if canImport(FirebaseAuth)
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            apply(user: result.user)
        } catch {
            throw AuthError.underlying(error.localizedDescription)
        }
        #else
        throw AuthError.notConfigured
        #endif
    }

    /// Sign out (both Firebase and Google). No-op + local stays intact if auth
    /// isn't configured.
    func signOut() {
        #if canImport(FirebaseAuth)
        guard isAuthAvailable else { return }
        try? Auth.auth().signOut()
        #endif
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif
        state = .signedOut
    }
}
