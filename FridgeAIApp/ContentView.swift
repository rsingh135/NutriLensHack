import SwiftUI
import AVFoundation

struct ContentView: View {
    init() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    @StateObject private var viewModel = FridgeViewModel()
    @State private var showingCamera = false
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeTabView(viewModel: viewModel, showingCamera: $showingCamera)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            RecipesTabView(viewModel: viewModel)
                .tabItem {
                    Label("Recipes", systemImage: "fork.knife")
                }
                .tag(1)
            
            WorkoutsTabView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.run")
                }
                .tag(2)
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(image: $viewModel.fridgeImage)
        }
        .sheet(item: $viewModel.selectedRecipe) { recipe in
            RecipeDetailView(recipe: recipe, viewModel: viewModel)
        }
        .onChange(of: viewModel.fridgeImage) { oldImage, newImage in
            if newImage != nil {
                viewModel.analyzeFridgeImage()
            }
        }
    }
}

struct HomeTabView: View {
    @ObservedObject var viewModel: FridgeViewModel
    @Binding var showingCamera: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    CameraSectionView(viewModel: viewModel, showingCamera: $showingCamera)
                    SustainableModeToggleView(viewModel: viewModel)
                    
                    if viewModel.isAnalyzing {
                        AnalysisProgressView()
                    }
                    
                    if let error = viewModel.errorMessage {
                        ErrorMessageView(message: error)
                    }
                    
                    if !viewModel.detectedIngredients.isEmpty {
                        DetectedIngredientsView(ingredients: viewModel.detectedIngredients)
                    }
                    
                    if !viewModel.recipes.isEmpty {
                        SuggestedRecipesView(recipes: viewModel.recipes, viewModel: viewModel)
                    }
                }
                .padding(.vertical)
            }
            .background(Theme.background)
            .navigationTitle("FridgeAI")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        NavigationLink(destination: FavoritesView(viewModel: viewModel)) {
                            Label("Favorites", systemImage: "heart.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(Theme.primary)
                    }
                }
            }
        }
    }
}

struct CameraSectionView: View {
    @ObservedObject var viewModel: FridgeViewModel
    @Binding var showingCamera: Bool
    
    var body: some View {
        VStack {
            if let image = viewModel.fridgeImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
                    .cornerRadius(15)
                    .shadow(radius: 5)
                    .padding(.horizontal)
            } else {
                CameraPlaceholderView()
            }
            
            Button(action: {
                showingCamera = true
            }) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Take Fridge Photo")
                }
                .primaryButton()
            }
            .padding(.horizontal)
        }
    }
}

struct SustainableModeToggleView: View {
    @ObservedObject var viewModel: FridgeViewModel
    
    var body: some View {
        Toggle(isOn: $viewModel.isSustainableMode) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundColor(Theme.primary)
                Text("Sustainable Mode")
                    .foregroundColor(Theme.text)
            }
        }
        .padding()
        .background(Theme.background)
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct RecipesTabView: View {
    @ObservedObject var viewModel: FridgeViewModel
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("All Recipes")) {
                    ForEach(viewModel.recipes) { recipe in
                        RecipeCard(recipe: recipe, viewModel: viewModel)
                            .onTapGesture {
                                viewModel.selectedRecipe = recipe
                            }
                    }
                }
                
                Section(header: Text("Favorites")) {
                    ForEach(viewModel.favoriteRecipes) { recipe in
                        RecipeCard(recipe: recipe, viewModel: viewModel)
                            .onTapGesture {
                                viewModel.selectedRecipe = recipe
                            }
                    }
                }
            }
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

struct WorkoutsTabView: View {
    var body: some View {
        NavigationView {
            WorkoutsView()
                .navigationTitle("Workouts")
                .navigationBarTitleDisplayMode(.large)
                .toolbarColorScheme(.light, for: .navigationBar)
                .toolbarBackground(Theme.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

struct WorkoutsView: View {
    @State private var selectedWorkoutType = "All"
    let workoutTypes = ["All", "Running", "Cycling", "Swimming", "Walking"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Workout Type Picker
                Picker("Workout Type", selection: $selectedWorkoutType) {
                    ForEach(workoutTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Weekly Progress Card
                WeeklyProgressCard()
                
                // Recent Workouts
                RecentWorkoutsSection()
                
                // Workout Stats
                WorkoutStatsSection()
            }
            .padding(.vertical)
        }
        .background(Theme.background)
        .navigationTitle("Workouts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Add new workout action
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Theme.primary)
                }
            }
        }
    }
}

struct WeeklyProgressCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly Progress")
                .font(.headline)
                .foregroundColor(Theme.text)
            
            HStack {
                ForEach(0..<7) { day in
                    VStack {
                        Text("\(day + 1)")
                            .font(.caption)
                            .foregroundColor(Theme.text)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.primary.opacity(0.3))
                            .frame(height: 40)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Theme.primary.opacity(0.1))
        .cornerRadius(15)
        .padding(.horizontal)
    }
}

struct RecentWorkoutsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Workouts")
                .font(.headline)
                .foregroundColor(Theme.text)
                .padding(.horizontal)
            
            ForEach(0..<3) { _ in
                WorkoutCard()
            }
        }
    }
}

struct WorkoutCard: View {
    var body: some View {
        HStack {
            Image(systemName: "figure.run")
                .font(.title)
                .foregroundColor(Theme.primary)
                .frame(width: 50, height: 50)
                .background(Theme.primary.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Morning Run")
                    .font(.headline)
                    .foregroundColor(Theme.text)
                Text("5.2 km • 28 min")
                    .font(.subheadline)
                    .foregroundColor(Theme.text.opacity(0.8))
            }
            
            Spacer()
            
            Text("320")
                .font(.title2)
                .bold()
                .foregroundColor(Theme.primary)
            Text("cal")
                .font(.caption)
                .foregroundColor(Theme.text.opacity(0.8))
        }
        .padding()
        .background(Theme.primary.opacity(0.1))
        .cornerRadius(15)
        .padding(.horizontal)
    }
}

struct WorkoutStatsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This Month")
                .font(.headline)
                .foregroundColor(Theme.text)
                .padding(.horizontal)
            
            HStack {
                StatCard(title: "Distance", value: "42.5", unit: "km")
                StatCard(title: "Time", value: "4h 20m", unit: "")
                StatCard(title: "Calories", value: "2,850", unit: "cal")
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.text.opacity(0.8))
            Text(value)
                .font(.title2)
                .bold()
                .foregroundColor(Theme.primary)
            if !unit.isEmpty {
                Text(unit)
                    .font(.caption)
                    .foregroundColor(Theme.text.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.primary.opacity(0.1))
        .cornerRadius(15)
    }
}

// MARK: - Supporting Views
struct CameraPlaceholderView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(Theme.background)
                .frame(height: 300)
                .overlay(
                    VStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 50))
                            .foregroundColor(Theme.primary)
                        Text("Take a photo of your fridge")
                            .foregroundColor(Theme.text)
                            .padding(.top, 8)
                    }
                )
                .padding(.horizontal)
        }
    }
}

struct AnalysisProgressView: View {
    var body: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Theme.primary)
            Text("Analyzing your fridge...")
                .foregroundColor(Theme.primary)
                .padding(.top, 8)
        }
        .padding()
    }
}

struct ErrorMessageView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .foregroundColor(.red)
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
    }
}

struct DetectedIngredientsView: View {
    let ingredients: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Detected Ingredients")
                .font(.headline)
                .foregroundColor(Theme.text)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ingredients, id: \.self) { ingredient in
                        Text(ingredient)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.primary.opacity(0.1))
                            .foregroundColor(Theme.primary)
                            .cornerRadius(15)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct SuggestedRecipesView: View {
    let recipes: [Recipe]
    @ObservedObject var viewModel: FridgeViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggested Recipes")
                .font(.headline)
                .foregroundColor(.black)
                .padding(.horizontal)
            
            ForEach(recipes) { recipe in
                RecipeCard(recipe: recipe, viewModel: viewModel)
                    .onTapGesture {
                        viewModel.selectedRecipe = recipe
                    }
            }
        }
    }
}

struct RecipeCard: View {
    let recipe: Recipe
    @ObservedObject var viewModel: FridgeViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(recipe.name)
                    .font(.headline)
                    .foregroundColor(Theme.text)
                
                Spacer()
                
                Button(action: { viewModel.toggleFavorite(recipe) }) {
                    Image(systemName: viewModel.isFavorite(recipe) ? "heart.fill" : "heart")
                        .foregroundColor(viewModel.isFavorite(recipe) ? .red : Theme.primary)
                }
            }
            
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundColor(Theme.primary)
                Text("Carbon Footprint: \(String(format: "%.1f", recipe.carbonFootprint)) kg CO2")
                    .font(.subheadline)
                    .foregroundColor(Theme.text)
                
                Spacer()
                
                Image(systemName: "flame.fill")
                    .foregroundColor(Theme.accent)
                Text("\(recipe.calories) calories")
                    .font(.subheadline)
                    .foregroundColor(Theme.text)
            }
            
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(Theme.accent)
                Text("30 min")
                    .font(.subheadline)
                    .foregroundColor(Theme.text)
            }
        }
        .cardStyle()
        .padding(.horizontal)
    }
}

struct RecipeDetailView: View {
    let recipe: Recipe
    @ObservedObject var viewModel: FridgeViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showingShareSheet = false
    @State private var showingGeminiHelp = false
    
    var body: some View {
        NavigationView {
            RecipeDetailContent(
                recipe: recipe,
                viewModel: viewModel,
                showingShareSheet: $showingShareSheet,
                showingGeminiHelp: $showingGeminiHelp
            )
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .modifier(RecipeDetailModifier(
                recipe: recipe,
                viewModel: viewModel,
                showingShareSheet: $showingShareSheet,
                showingGeminiHelp: $showingGeminiHelp
            ))
        }
    }
}

struct RecipeDetailModifier: ViewModifier {
    let recipe: Recipe
    @ObservedObject var viewModel: FridgeViewModel
    @Binding var showingShareSheet: Bool
    @Binding var showingGeminiHelp: Bool
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [recipe.name, recipe.instructions.joined(separator: "\n")])
            }
            .sheet(isPresented: $showingGeminiHelp) {
                GeminiHelpView(recipe: recipe)
            }
    }
}

struct RecipeDetailContent: View {
    let recipe: Recipe
    @ObservedObject var viewModel: FridgeViewModel
    @Binding var showingShareSheet: Bool
    @Binding var showingGeminiHelp: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RecipeHeaderView(recipe: recipe)
                QuickActionsView(
                    recipe: recipe,
                    viewModel: viewModel,
                    showingShareSheet: $showingShareSheet,
                    showingGeminiHelp: $showingGeminiHelp
                )
                IngredientsView(recipe: recipe)
                InstructionsView(recipe: recipe)
                NutritionalInfoView(recipe: recipe)
            }
            .padding()
        }
        .background(Theme.background)
    }
}

struct RecipeHeaderView: View {
    let recipe: Recipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(recipe.name)
                .font(.title)
                .bold()
                .foregroundColor(Theme.text)
            
            HStack {
                Label("\(recipe.calories) calories", systemImage: "flame.fill")
                Spacer()
                Label("\(String(format: "%.1f", recipe.carbonFootprint)) kg CO2", systemImage: "leaf.fill")
            }
            .foregroundColor(Theme.text)
        }
        .padding(.bottom)
    }
}

struct QuickActionsView: View {
    let recipe: Recipe
    @ObservedObject var viewModel: FridgeViewModel
    @Binding var showingShareSheet: Bool
    @Binding var showingGeminiHelp: Bool
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: { viewModel.toggleFavorite(recipe) }) {
                Label(viewModel.isFavorite(recipe) ? "Favorited" : "Favorite", 
                      systemImage: viewModel.isFavorite(recipe) ? "heart.fill" : "heart")
            }
            .foregroundColor(viewModel.isFavorite(recipe) ? .red : Theme.primary)
            
            Button(action: { showingShareSheet = true }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .foregroundColor(Theme.primary)
            
            Button(action: { showingGeminiHelp = true }) {
                Label("AI Help", systemImage: "sparkles")
            }
            .foregroundColor(Theme.primary)
            
            Spacer()
            
            Button(action: {
                if viewModel.isSpeaking {
                    viewModel.stopSpeaking()
                } else {
                    viewModel.speakRecipe(recipe)
                }
            }) {
                Label(viewModel.isSpeaking ? "Stop" : "Listen", 
                      systemImage: viewModel.isSpeaking ? "stop.fill" : "play.fill")
            }
            .foregroundColor(Theme.primary)
        }
        .padding(.bottom)
    }
}

struct IngredientsView: View {
    let recipe: Recipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ingredients")
                .font(.headline)
                .foregroundColor(Theme.text)
            ForEach(recipe.ingredients, id: \.self) { ingredient in
                HStack {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Theme.primary)
                    Text(ingredient)
                        .foregroundColor(Theme.text)
                }
            }
        }
    }
}

struct InstructionsView: View {
    let recipe: Recipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Instructions")
                .font(.headline)
                .foregroundColor(Theme.text)
            ForEach(Array(recipe.instructions.enumerated()), id: \.element) { index, instruction in
                HStack(alignment: .top) {
                    Text("\(index + 1)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Theme.primary)
                        .clipShape(Circle())
                    Text(instruction)
                        .foregroundColor(Theme.text)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct NutritionalInfoView: View {
    let recipe: Recipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nutritional Information")
                .font(.headline)
                .foregroundColor(Theme.text)
            
            HStack {
                NutrientCard(title: "Protein", value: recipe.nutritionalInfo.protein, unit: "g")
                NutrientCard(title: "Carbs", value: recipe.nutritionalInfo.carbs, unit: "g")
                NutrientCard(title: "Fat", value: recipe.nutritionalInfo.fat, unit: "g")
                NutrientCard(title: "Fiber", value: recipe.nutritionalInfo.fiber, unit: "g")
            }
        }
    }
}

struct NutrientCard: View {
    let title: String
    let value: Double
    let unit: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.text)
            Text("\(Int(value))\(unit)")
                .font(.headline)
                .foregroundColor(Theme.primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.primary.opacity(0.1))
        .cornerRadius(10)
    }
}

struct GeminiHelpView: View {
    let recipe: Recipe
    @Environment(\.presentationMode) var presentationMode
    @State private var aiResponse: String = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Getting AI help...")
                        .padding()
                } else {
                    ScrollView {
                        Text(aiResponse)
                            .padding()
                            .foregroundColor(Theme.text)
                    }
                }
            }
            .navigationTitle("AI Cooking Assistant")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                // Here you would integrate with Gemini API
                // For now, we'll show a placeholder response
                isLoading = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    aiResponse = "Here are some tips for making \(recipe.name):\n\n1. Make sure all ingredients are fresh and properly prepared\n2. Follow the instructions carefully\n3. Adjust seasoning to your taste\n4. Consider adding garnishes for presentation\n5. Let the dish rest before serving"
                    isLoading = false
                }
            }
        }
    }
}

struct FavoritesView: View {
    @ObservedObject var viewModel: FridgeViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        List {
            ForEach(viewModel.favoriteRecipes) { recipe in
                RecipeCard(recipe: recipe, viewModel: viewModel)
                    .onTapGesture {
                        viewModel.selectedRecipe = recipe
                    }
            }
        }
        .navigationTitle("Favorites")
        .navigationBarItems(trailing: Button("Done") {
            presentationMode.wrappedValue.dismiss()
        })
    }
}

struct ProfileView: View {
    var body: some View {
        Text("Profile View")
            .navigationTitle("Profile")
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Preview provider for SwiftUI canvas
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 
