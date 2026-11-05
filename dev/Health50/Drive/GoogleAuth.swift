import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

/// Small wrapper around the iPhone's Keychain for the Google sign-in key.
enum Keychain {
    private static let service = "com.66ideas.health50.google"

    static func set(_ value: String, for key: String) {
        delete(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: Data(value.utf8),
            // Readable by background runs after the first unlock, never synced to other devices.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum GoogleAuthError: Error, Equatable {
    /// The build has no Google client ID (see Config/Health50.xcconfig).
    case notConfigured
    case cancelled
    case failed
    /// Google no longer accepts the stored key; the user must sign in again.
    case needsReconnect
}

/// Sign-in with Google, entirely on the phone: Google's own page, opened by iOS, with PKCE and no server.
/// The app only asks for the narrow Drive permission (files and folders it created itself).
actor GoogleAuth {
    static let shared = GoogleAuth()

    static let scope = "https://www.googleapis.com/auth/drive.file"
    private static let refreshKey = "refreshToken"

    private var accessToken: String?
    private var accessExpiry = Date.distantPast

    nonisolated var clientID: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String,
              !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return value
    }

    nonisolated var isConfigured: Bool { clientID != nil }
    nonisolated var isConnected: Bool { Keychain.get(Self.refreshKey) != nil }

    /// Google's redirect scheme for iOS clients is the client ID in reverse order.
    private nonisolated func redirectScheme(_ clientID: String) -> String {
        clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    // MARK: Sign-in

    func signIn() async throws {
        guard let clientID else { throw GoogleAuthError.notConfigured }
        let scheme = redirectScheme(clientID)
        let redirect = "\(scheme):/oauth2redirect"
        let verifier = Self.randomString(64)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirect),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: Self.scope),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
        ]

        let callback = try await WebAuthPresenter.authenticate(url: components.url!, scheme: scheme)
        guard let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else { throw GoogleAuthError.failed }

        let response = try await tokenRequest([
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirect,
        ])
        guard let refresh = response.refresh_token else { throw GoogleAuthError.failed }
        Keychain.set(refresh, for: Self.refreshKey)
        store(response)
    }

    /// A valid access key for Drive requests, renewed when needed.
    func token(forceRefresh: Bool = false) async throws -> String {
        if !forceRefresh, let accessToken, accessExpiry > Date.now.addingTimeInterval(60) { return accessToken }
        guard let clientID else { throw GoogleAuthError.notConfigured }
        guard let refresh = Keychain.get(Self.refreshKey) else { throw GoogleAuthError.needsReconnect }
        let response = try await tokenRequest([
            "client_id": clientID,
            "refresh_token": refresh,
            "grant_type": "refresh_token",
        ])
        store(response)
        return response.access_token
    }

    /// Ends the connection: tells Google to withdraw the key and removes it from the Keychain.
    func disconnect() async {
        if let refresh = Keychain.get(Self.refreshKey) {
            var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/revoke")!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data("token=\(refresh.formEncoded)".utf8)
            _ = try? await URLSession.shared.data(for: request)
        }
        Keychain.delete(Self.refreshKey)
        accessToken = nil
        accessExpiry = .distantPast
    }

    // MARK: Internals

    private struct TokenResponse: Decodable {
        let access_token: String
        let expires_in: Double?
        let refresh_token: String?
    }

    private struct TokenFailure: Decodable { let error: String }

    private func store(_ response: TokenResponse) {
        accessToken = response.access_token
        accessExpiry = Date.now.addingTimeInterval(response.expires_in ?? 3000)
    }

    private func tokenRequest(_ fields: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(fields.map { "\($0.key)=\($0.value.formEncoded)" }.joined(separator: "&").utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleAuthError.failed }
        if http.statusCode == 200, let decoded = try? JSONDecoder().decode(TokenResponse.self, from: data) { return decoded }
        if let failure = try? JSONDecoder().decode(TokenFailure.self, from: data), failure.error == "invalid_grant" {
            throw GoogleAuthError.needsReconnect
        }
        throw GoogleAuthError.failed
    }

    private static func randomString(_ length: Int) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in alphabet.randomElement(using: &generator)! })
    }
}

/// Presents Google's sign-in page in the system browser sheet.
@MainActor
private final class WebAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    private static var current: WebAuthPresenter?
    private var session: ASWebAuthenticationSession?

    static func authenticate(url: URL, scheme: String) async throws -> URL {
        let presenter = WebAuthPresenter()
        current = presenter
        defer { current = nil }
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callback: .customScheme(scheme)) { callback, error in
                if let callback {
                    continuation.resume(returning: callback)
                } else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                    continuation.resume(throwing: GoogleAuthError.cancelled)
                } else {
                    continuation.resume(throwing: GoogleAuthError.failed)
                }
            }
            session.presentationContextProvider = presenter
            presenter.session = session
            if !session.start() { continuation.resume(throwing: GoogleAuthError.failed) }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.compactMap(\.keyWindow).first ?? ASPresentationAnchor(windowScene: scenes[0])
    }
}

extension Data {
    var base64URL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension String {
    var formEncoded: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}
