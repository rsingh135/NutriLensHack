import Foundation

enum Auth0Config {
    // Replace with your Auth0 domain (e.g., "your-tenant.auth0.com")
    static let domain = "dev-5lhpd848xp251uwz.us.auth0.com"
    
    // Replace with your Auth0 application client ID
    static let clientId = "wQeGvBi7s8GJUVpWo3XUGpH1ZXSHQte7"
    
    // Replace with your app's bundle identifier (e.g., "com.yourdomain.fridgeaiapp")
    // This should match your Xcode project's bundle identifier
    static let redirectUri = "rsingh.FridgeAIApp://callback"
} 