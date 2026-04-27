import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

final class SpotifyOAuthManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    struct TokenResponse: Decodable {
        let access_token: String
        let token_type: String
        let scope: String?
        let expires_in: Int
        let refresh_token: String?
    }

    private let tokenStore = SpotifyTokenStore()
    private var continuation: CheckedContinuation<String, Error>?
    private var webAuthSession: ASWebAuthenticationSession?
    private var codeVerifier: String = ""

    func currentAccessToken() async throws -> String {

        if let token = tokenStore.accessToken, !token.isEmpty {
            await MainActor.run{
                DriveDJViewModel.debugText  = token
            }
            return token
        }
        return try await authorize()
    }

    func authorize() async throws -> String {
        if let dic = Bundle.main.infoDictionary {
//            await MainActor.run{
//                DriveDJViewModel.debugText  = dic.reduce(into : "" ){result, item in
//                    result += "\(item.key): \(item.value)\n"
//                }
            //}
        }
        guard !AppConfig.spotifyClientID.isEmpty, !AppConfig.spotifyRedirectURI.isEmpty else {
            throw SpotifyAuthError.missingConfiguration
        }

        codeVerifier = Self.generateCodeVerifier()
        let codeChallenge = Self.codeChallenge(for: codeVerifier)

        let authURL = try makeAuthorizationURL(codeChallenge: codeChallenge)
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: Self.redirectScheme(from: AppConfig.spotifyRedirectURI)
            ) { [weak self] callbackURL, error in
                guard let self else { return }
                if let error {
                    self.finish(with: .failure(error))
                    return
                }
                guard
                    let callbackURL,
                    let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?
                        .first(where: { $0.name == "code" })?
                        .value
                else {
                    self.finish(with: .failure(SpotifyAuthError.invalidCallback))
                    return
                }

                Task {
                    do {
                        let token = try await self.exchangeCodeForToken(code: code)
                        self.tokenStore.accessToken = token.access_token
                        self.tokenStore.refreshToken = token.refresh_token
                        self.finish(with: .success(token.access_token))
                    } catch {
                        self.finish(with: .failure(error))
                    }
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            self.webAuthSession = session
            _ = session.start()
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow ?? ASPresentationAnchor()
    }

    private func finish(with result: Result<String, Error>) {
        continuation?.resume(with: result)
        continuation = nil
        webAuthSession = nil
    }

    private func makeAuthorizationURL(codeChallenge: String) throws -> URL {
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: AppConfig.spotifyClientID),
            .init(name: "redirect_uri", value: AppConfig.spotifyRedirectURI),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: codeChallenge)
        ]
        return components.url!
    }

    private func exchangeCodeForToken(code: String) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyItems: [String: String] = [
            "client_id": AppConfig.spotifyClientID,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": AppConfig.spotifyRedirectURI,
            "code_verifier": codeVerifier
        ]

        request.httpBody = bodyItems
            .map { "\($0.key)=\($0.value.urlFormEncoded())" }
            .sorted()
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SpotifyAuthError.tokenExchangeFailed
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func makeRandomString(length: Int) -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }

    static func generateCodeVerifier() -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<96).compactMap { _ in chars.randomElement() })
    }

    static func codeChallenge(for verifier: String) -> String {
        let input = Data(verifier.utf8)
        let hash = SHA256.hash(data: input)
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func redirectScheme(from redirectURI: String) -> String {
        if let url = URL(string: redirectURI), let scheme = url.scheme {
            return scheme
        }
        return redirectURI.components(separatedBy: ":").first ?? ""
    }
}

enum SpotifyAuthError: LocalizedError {
    case missingConfiguration
    case invalidCallback
    case tokenExchangeFailed

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Spotify configuration is missing."
        case .invalidCallback:
            return "Spotify authorization callback was invalid."
        case .tokenExchangeFailed:
            return "Spotify token exchange failed."
        }
    }
}

final class SpotifyTokenStore {
    private let keyAccessToken = "DriveDJ.Spotify.accessToken"
    private let keyRefreshToken = "DriveDJ.Spotify.refreshToken"

    var accessToken: String? {
        get { KeychainHelper.read(keyAccessToken) }
        set {
            if let newValue {
                KeychainHelper.write(newValue, for: keyAccessToken)
            } else {
                KeychainHelper.delete(keyAccessToken)
            }
        }
    }

    var refreshToken: String? {
        get { KeychainHelper.read(keyRefreshToken) }
        set {
            if let newValue {
                KeychainHelper.write(newValue, for: keyRefreshToken)
            } else {
                KeychainHelper.delete(keyRefreshToken)
            }
        }
    }
}

final class KeychainHelper {
    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String, for key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        let item = query.merging(attributes) { _, new in new }
        SecItemAdd(item as CFDictionary, nil)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private extension String {
    func urlFormEncoded() -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}
