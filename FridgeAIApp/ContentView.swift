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
    @State private var showingPhotoLibrary = false
    @State private var selectedTab = 0
    @State private var isAuthenticated = false
    
    var body: some View {
        Group {
            if isAuthenticated {
                TabView(selection: $selectedTab) {
                    HomeTabView(viewModel: viewModel, showingCamera: $showingCamera, showingPhotoLibrary: $showingPhotoLibrary)
                        .tabItem {
                            Label("Home", systemImage: "house.fill")
                        }
                        .tag(0)
                    
                    RecipesTabView(viewModel: viewModel)
                        .tabItem {
                            Label("Recipes", systemImage: "fork.knife")
                        }
                        .tag(1)
                    
                    WorkoutsView(viewModel: viewModel)
                        .tabItem {
                            Label("Workouts", systemImage: "figure.run")
                        }
                        .tag(2)
                    
                    UserHealthProfileView(viewModel: viewModel)
                        .tabItem {
                            Label("Profile", systemImage: "person.crop.circle")
                        }
                        .tag(3)
                    
                    MapView()
                        .tabItem {
                            Label("Map", systemImage: "map")
                        }
                        .tag(4)
                }
                .sheet(isPresented: $showingCamera) {
                    CameraView(image: $viewModel.fridgeImage, sourceType: .camera)
                }
                .sheet(isPresented: $showingPhotoLibrary) {
                    CameraView(image: $viewModel.fridgeImage, sourceType: .photoLibrary)
                }
                .sheet(item: $viewModel.selectedRecipe) { recipe in
                    RecipeDetailView(recipe: recipe, viewModel: viewModel)
                }
                .sheet(isPresented: $viewModel.showingHealthProfile) {
                    UserHealthProfileView(viewModel: viewModel)
                }
                .onChange(of: viewModel.fridgeImage) { oldImage, newImage in
                    if newImage != nil {
                        viewModel.analyzeFridgeImage()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            viewModel.showingHealthProfile = true
                        }) {
                            Image(systemName: "person.crop.circle")
                        }
                    }
                }
            } else {
                LoginView(isAuthenticated: $isAuthenticated)
            }
        }
        .onChange(of: isAuthenticated) { _, newValue in
            if newValue && viewModel.userHealthProfile == nil {
                // Health profile should display here
                viewModel.showingHealthProfile = true
            }
        }
    }
}

struct HomeTabView: View {
    @ObservedObject var viewModel: FridgeViewModel
    @Binding var showingCamera: Bool
    @Binding var showingPhotoLibrary: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    CameraSectionView(viewModel: viewModel, showingCamera: $showingCamera, showingPhotoLibrary: $showingPhotoLibrary)
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
            .navigationTitle("NutriLens")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

struct CameraSectionView: View {
    @ObservedObject var viewModel: FridgeViewModel
    @Binding var showingCamera: Bool
    @Binding var showingPhotoLibrary: Bool
    
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
            
            HStack(spacing: 15) {
                Button(action: {
                    showingCamera = true
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Take Photo")
                    }
                    .primaryButton()
                }
                
                Button(action: {
                    showingPhotoLibrary = true
                }) {
                    HStack {
                        Image(systemName: "photo.fill")
                        Text("Upload Photo")
                    }
                    .primaryButton()
                }
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
            ZStack {
                Theme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        Section(header: Text("All Recipes").font(.headline).foregroundColor(Theme.text)) {
                            ForEach(viewModel.recipes) { recipe in
                                RecipeCard(recipe: recipe, viewModel: viewModel)
                                    .onTapGesture {
                                        viewModel.selectedRecipe = recipe
                                    }
                            }
                        }
                        
                        Section(header: Text("Favorites").font(.headline).foregroundColor(Theme.text).fixedSize()) {
                            ForEach(viewModel.favoriteRecipes) { recipe in
                                RecipeCard(recipe: recipe, viewModel: viewModel)
                                    .onTapGesture {
                                        viewModel.selectedRecipe = recipe
                                    }
                            }
                        }
                    }
                    .padding()
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

struct WorkoutsView: View {
    @ObservedObject var viewModel: FridgeViewModel
    @State private var selectedWorkoutType = "All"
    let workoutTypes = ["All", "Running", "Cycling", "Walking"]
    
    var filteredWorkouts: [WorkoutOption] {
        guard selectedWorkoutType != "All" else {
            return viewModel.savedWorkouts
        }
        return viewModel.savedWorkouts.filter { workout in
            workout.type.rawValue.capitalized == selectedWorkoutType
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Workout Type Picker
                    Picker("Workout Type", selection: $selectedWorkoutType) {
                        ForEach(workoutTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    // Weekly Progress Card
                    WeeklyProgressCard(progress: viewModel.getWeeklyProgress())
                        .padding(.horizontal)
                    
                    // Recipe-based Workout Recommendation
                    if let recommendation = viewModel.workoutRecommendation {
                        WorkoutRecommendationView(recommendation: recommendation, viewModel: viewModel)
                            .padding(.horizontal)
                    }
                    
                    // Add Workout Button
                    Button(action: {
                        viewModel.showingRecipeSelection = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Generate Workout from Recipe")
                        }
                        .primaryButton()
                    }
                    .padding()
                    
                    // Saved Workouts List
                    if filteredWorkouts.isEmpty {
                        if viewModel.savedWorkouts.isEmpty {
                            PlaceholderWorkoutsSection()
                                .padding()
                        } else {
                            Text("No \(selectedWorkoutType) workouts found")
                                .foregroundColor(Theme.text.opacity(0.6))
                                .padding()
                        }
                    } else {
                        VStack(spacing: 15) {
                            ForEach(filteredWorkouts) { workout in
                                WorkoutCard(workout: workout, viewModel: viewModel)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.bottom)
                    }
                }
            }
            .background(Theme.background)
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $viewModel.showingRecipeSelection) {
                RecipeSelectionView(viewModel: viewModel)
            }
        }
    }
}

struct PlaceholderWorkoutsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Workouts")
                .font(.headline)
                .foregroundColor(Theme.text)
                .padding(.horizontal)
            
            ForEach(0..<3) { _ in
                PlaceholderWorkoutCard()
            }
        }
    }
}

struct PlaceholderWorkoutCard: View {
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

struct WeeklyProgressCard: View {
    let progress: [Bool]
    
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
                            .fill(progress[day] ? Theme.primary : Theme.primary.opacity(0.3))
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

struct WorkoutRecommendationView: View {
    let recommendation: WorkoutRecommendation
    @ObservedObject var viewModel: FridgeViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Workout Recommendation")
                .font(.title2)
                .bold()
                .foregroundColor(Theme.text)
            
            Text("To burn off \(recommendation.caloriesToBurn) calories from \(recommendation.recipeName)")
                .foregroundColor(Theme.text)
            
            ForEach(recommendation.workouts) { workout in
                WorkoutOptionCard(workout: workout, viewModel: viewModel)
            }
        }
        .padding()
        .background(Theme.background)
        .cornerRadius(15)
        .padding(.horizontal)
    }
}

struct WorkoutOptionCard: View {
    let workout: WorkoutOption
    @ObservedObject var viewModel: FridgeViewModel
    
    var body: some View {
        HStack {
            Image(systemName: workout.type.icon)
                .font(.title2)
                .foregroundColor(Theme.primary)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.type.rawValue.capitalized)
                    .font(.headline)
                    .foregroundColor(Theme.text)
                
                Text(workout.description)
                    .font(.subheadline)
                    .foregroundColor(Theme.text)
                
                HStack {
                    Image(systemName: "clock.fill")
                    Text("\(workout.duration) min")
                    Spacer()
                    Image(systemName: "flame.fill")
                    Text("\(workout.caloriesBurned) cal")
                }
                .font(.caption)
                .foregroundColor(Theme.accent)
            }
            
            Spacer()
            
            if !workout.isCompleted {
                Button(action: {
                    viewModel.saveWorkout(workout)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Theme.primary)
                }
            }
        }
        .padding()
        .background(Theme.primary.opacity(0.1))
        .cornerRadius(10)
    }
}

struct WorkoutCard: View {
    let workout: WorkoutOption
    @ObservedObject var viewModel: FridgeViewModel
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: workout.type.icon)
                .font(.title)
                .foregroundColor(Theme.primary)
                .frame(width: 50, height: 50)
                .background(Theme.primary.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.type.rawValue.capitalized)
                    .font(.headline)
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                Text(workout.description)
                    .font(.subheadline)
                    .foregroundColor(Theme.text.opacity(0.8))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(workout.caloriesBurned)")
                    .font(.title2)
                    .bold()
                    .foregroundColor(Theme.primary)
                Text("cal")
                    .font(.caption)
                    .foregroundColor(Theme.text.opacity(0.8))
            }
            .frame(width: 70)
        }
        .padding()
        .background(Theme.primary.opacity(0.1))
        .cornerRadius(15)
    }
}

struct RecipeSelectionView: View {
    @ObservedObject var viewModel: FridgeViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Recent Recipes")) {
                    ForEach(viewModel.recipes) { recipe in
                        Button(action: {
                            viewModel.generateWorkoutRecommendation(for: recipe)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(recipe.name)
                                        .foregroundColor(Theme.text)
                                    Text("\(recipe.calories) calories")
                                        .font(.caption)
                                        .foregroundColor(Theme.accent)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Theme.primary)
                            }
                        }
                    }
                }
                
                Section(header: Text("Favorite Recipes")) {
                    ForEach(viewModel.favoriteRecipes) { recipe in
                        Button(action: {
                            viewModel.generateWorkoutRecommendation(for: recipe)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(recipe.name)
                                        .foregroundColor(Theme.text)
                                    Text("\(recipe.calories) calories")
                                        .font(.caption)
                                        .foregroundColor(Theme.accent)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Theme.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Recipe")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

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
        HStack(spacing: 15) {
            Button(action: { viewModel.toggleFavorite(recipe) }) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isFavorite(recipe) ? "heart.fill" : "heart")
                    Text(viewModel.isFavorite(recipe) ? "Favorited" : "Favorite")
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundColor(viewModel.isFavorite(recipe) ? .red : Theme.primary)
            
            Button(action: { showingShareSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
            }
            .foregroundColor(Theme.primary)
            
            Button(action: { showingGeminiHelp = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text("AI Help")
                }
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
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isSpeaking ? "stop.fill" : "play.fill")
                    Text(viewModel.isSpeaking ? "Stop" : "Listen")
                }
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
                isLoading = true
                // placeholder AI helper response (expand in future)
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
