import SwiftUI

struct LoginView: View {
    @StateObject private var auth0Service = Auth0Service()
    @Binding var isAuthenticated: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Simple fridge icon
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Theme.primary.opacity(0.2), Theme.primary.opacity(0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 150, height: 150)
                
                VStack(spacing: 2) {
                    // Fridge outline
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.primary, lineWidth: 4)
                        .frame(width: 70, height: 100)
                    
                    // Fridge feet
                    HStack(spacing: 40) {
                        Rectangle()
                            .fill(Theme.primary)
                            .frame(width: 8, height: 4)
                        Rectangle()
                            .fill(Theme.primary)
                            .frame(width: 8, height: 4)
                    }
                }
                
                // Fridge handles
                HStack {
                    Spacer()
                    VStack(spacing: 25) {
                        // Top handle (freezer)
                        Rectangle()
                            .fill(Theme.primary)
                            .frame(width: 4, height: 15)
                        
                        // Bottom handle (main compartment)
                        Rectangle()
                            .fill(Theme.primary)
                            .frame(width: 4, height: 15)
                    }
                    .offset(x: -8, y: -10)
                }
                .frame(width: 70, height: 100)
                
                // Fridge divider line
                Rectangle()
                    .fill(Theme.primary)
                    .frame(width: 70, height: 4)
                    .offset(y: -10)
            }
            .padding(.bottom, 20)
            
            Text("NutriLens")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(Theme.text)
                .shadow(color: Theme.text.opacity(0.2), radius: 5, x: 0, y: 2)
            
            Text("Your Smart Fridge Assistant")
                .font(.title3)
                .foregroundColor(Theme.text.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
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
                .shadow(color: Theme.primary.opacity(0.3), radius: 5, x: 0, y: 2)
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


extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
} 
