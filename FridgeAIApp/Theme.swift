import SwiftUI

struct Theme {
    static let primary = Color("ForestGreen")
    static let secondary = Color("SageGreen")
    static let accent = Color("DarkGreen")
    static let background = Color("LightMint")
    static let text = Color("Black")
    
    static let cardBackground = Color.white
    static let shadowColor = Color.black.opacity(0.1)
    
    static func cardStyle() -> some ViewModifier {
        return CardModifier()
    }
    
    static func primaryButton() -> some ViewModifier {
        return PrimaryButtonModifier()
    }
}

private struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Theme.background)
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

private struct PrimaryButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity)
            .background(Theme.primary)
            .foregroundColor(.white)
            .cornerRadius(15)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(Theme.cardStyle())
    }
    
    func primaryButton() -> some View {
        modifier(Theme.primaryButton())
    }
} 
