import Foundation
import AuthenticationServices
import SwiftUI

class Auth0Service: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var userProfile: UserProfile?
    @Published var error: Error?
    
    private var webAuthSession: ASWebAuthenticationSession?
    
    struct UserProfile: Codable {
        let sub: String
        let name: String?
        let email: String?
        let picture: String?
    }
    
    func login() {
        let authURL = "https://\(Auth0Config.domain)/authorize"
        let queryItems = [
            URLQueryItem(name: "client_id", value: Auth0Config.clientId),
            URLQueryItem(name: "redirect_uri", value: Auth0Config.redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid profile email")
        ]
        
        var urlComponents = URLComponents(string: authURL)!
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            self.error = NSError(domain: "Auth0Service", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            return
        }
        
        webAuthSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: URL(string: Auth0Config.redirectUri)?.scheme
        ) { [weak self] callbackURL, error in
            if let error = error {
                self?.error = error
                return
            }
            
            guard let callbackURL = callbackURL,
                  let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "code" })?
                    .value else {
                self?.error = NSError(domain: "Auth0Service", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authorization code received"])
                return
            }
            
            self?.exchangeCodeForToken(code)
        }
        
        webAuthSession?.presentationContextProvider = self
        webAuthSession?.start()
    }
    
    func logout() {
        isAuthenticated = false
        userProfile = nil
    }
    
    private func exchangeCodeForToken(_ code: String) {
        let tokenURL = "https://\(Auth0Config.domain)/oauth/token"
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = [
            "grant_type": "authorization_code",
            "client_id": Auth0Config.clientId,
            "code": code,
            "redirect_uri": Auth0Config.redirectUri
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.error = error
                }
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String else {
                DispatchQueue.main.async {
                    self?.error = NSError(domain: "Auth0Service", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get access token"])
                }
                return
            }
            
            self?.getUserProfile(accessToken)
        }.resume()
    }
    
    private func getUserProfile(_ accessToken: String) {
        let profileURL = "https://\(Auth0Config.domain)/userinfo"
        var request = URLRequest(url: URL(string: profileURL)!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.error = error
                }
                return
            }
            
            guard let data = data,
                  let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
                DispatchQueue.main.async {
                    self?.error = NSError(domain: "Auth0Service", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode user profile"])
                }
                return
            }
            
            DispatchQueue.main.async {
                self?.userProfile = profile
                self?.isAuthenticated = true
            }
        }.resume()
    }
}

extension Auth0Service: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.windows.first ?? ASPresentationAnchor()
    }
} 