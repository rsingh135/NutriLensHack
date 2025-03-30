import SwiftUI

struct LoginView: View {
    @StateObject private var auth0Service = Auth0Service()
    @Binding var isAuthenticated: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "fridge.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.primary)
            
            Text("NutriLens")
                .font(.largeTitle)
                .bold()
                .foregroundColor(Theme.text)
            
            Text("Your Smart Fridge Assistant")
                .font(.subheadline)
                .foregroundColor(Theme.text.opacity(0.8))
            
            Spacer()
            
            Button(action: {
                auth0Service.login()
            }) {
                HStack {
                    Image(systemName: "person.fill")
                    Text("Sign In")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.primary)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
            if let error = auth0Service.error {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
        }
        .padding()
        .background(Theme.background)
        .onChange(of: auth0Service.isAuthenticated) { _, newValue in
            isAuthenticated = newValue
        }
    }
} 