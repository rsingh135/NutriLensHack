//
//  FridgeViewModel.swift
//  FridgeAIApp
//
//  Created by Ranveer Singh on 3/28/25.
//

import SwiftUI
import Vision
import CoreML
import AVFoundation

@MainActor
class FridgeViewModel: NSObject, ObservableObject {
    private let geminiService: GeminiService
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    @Published var fridgeImage: UIImage?
    @Published var detectedIngredients: [String] = []
    @Published var recipes: [Recipe] = []
    @Published var favoriteRecipes: [Recipe] = []
    @Published var selectedRecipe: Recipe?
    @Published var isAnalyzing = false
    @Published var errorMessage: String?
    @Published var isSustainableMode = false
    @Published var isSpeaking = false
    @Published var workoutRecommendation: WorkoutRecommendation?
    @Published var showingRecipeSelection = false
    @Published var isGeneratingWorkout = false
    @Published var savedWorkouts: [WorkoutOption] = []
    @Published var selectedWorkoutType: WorkoutType?
    @Published var userHealthProfile: UserHealthProfile?
    @Published var showingHealthProfile = false
    
    private let userDefaults = UserDefaults.standard
    private let healthProfileKey = "userHealthProfile"
    
    override init() {
        // Initialize with API key from Secrets.swift
        self.geminiService = GeminiService(apiKey: Secrets.geminiAPIKey)
        super.init()
        speechSynthesizer.delegate = self
        loadFavorites()
        loadSavedWorkouts()
        loadHealthProfile()
    }
    
    func analyzeFridgeImage() {
        guard let image = fridgeImage else { return }
        isAnalyzing = true
        
        // Gives context with health profile information
        var contextString = "Analyze this image of fridge contents"
        if let profile = userHealthProfile {
            contextString += " considering the following dietary preferences: \(profile.dietaryPreferences.joined(separator: ", "))"
            if !profile.allergies.isEmpty {
                contextString += " and avoiding these allergens: \(profile.allergies.joined(separator: ", "))"
            }
            contextString += ". The user's fitness goal is \(profile.fitnessGoal)."
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Failed to process image"
            isAnalyzing = false
            return
        }
        
        errorMessage = nil
        
        Task {
            do {
                detectedIngredients = try await geminiService.analyzeImage(imageData)
                recipes = try await geminiService.generateRecipes(ingredients: detectedIngredients)
                
                if isSustainableMode {
                    // Sort recipes based on both carbon footprint and expiration
                    recipes.sort { recipe1, recipe2 in
                        // sort by expiration
                        if recipe1.expirationInfo.daysUntilExpiration <= 3 && recipe2.expirationInfo.daysUntilExpiration > 3 {
                            return true
                        } else if recipe2.expirationInfo.daysUntilExpiration <= 3 && recipe1.expirationInfo.daysUntilExpiration > 3 {
                            return false
                        }
                        
                        // sort by carbon footprint
                        return recipe1.carbonFootprint < recipe2.carbonFootprint
                    }
                }
                
                isAnalyzing = false
            } catch {
                errorMessage = "Error analyzing image: \(error.localizedDescription)"
                isAnalyzing = false
            }
        }
    }
    
    func toggleFavorite(_ recipe: Recipe) {
        Task { @MainActor in
            if let index = favoriteRecipes.firstIndex(where: { $0.id == recipe.id }) {
                favoriteRecipes.remove(at: index)
            } else {
                favoriteRecipes.append(recipe)
            }
            saveFavorites()
        }
    }
    
    func isFavorite(_ recipe: Recipe) -> Bool {
        favoriteRecipes.contains(where: { $0.id == recipe.id })
    }
    
    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favoriteRecipes) {
            UserDefaults.standard.set(encoded, forKey: "FavoriteRecipes")
        }
    }
    
    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: "FavoriteRecipes"),
           let decoded = try? JSONDecoder().decode([Recipe].self, from: data) {
            favoriteRecipes = decoded
        }
    }
    
    func speakRecipe(_ recipe: Recipe) {
        let text = """
        Recipe for \(recipe.name).
        Ingredients: \(recipe.ingredients.joined(separator: ", ")).
        Instructions: \(recipe.instructions.joined(separator: ". "))
        """
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        
        isSpeaking = true
        speechSynthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    func generateWorkoutRecommendation(for recipe: Recipe) {
        isGeneratingWorkout = true
        errorMessage = nil
        
        Task {
            do {
                workoutRecommendation = try await geminiService.generateWorkoutRecommendation(for: recipe)
                isGeneratingWorkout = false
            } catch {
                errorMessage = "Error generating workout recommendation: \(error.localizedDescription)"
                isGeneratingWorkout = false
            }
        }
    }
    
    func saveWorkout(_ workout: WorkoutOption) {
        Task { @MainActor in
            var updatedWorkout = workout
            updatedWorkout.isCompleted = true
            updatedWorkout.completedDate = Date()
            savedWorkouts.append(updatedWorkout)
            saveSavedWorkouts()
            updateWeeklyProgress()
            // Resets recommendations
            workoutRecommendation = nil
        }
    }
    
    func deleteWorkout(_ workout: WorkoutOption) {
        Task { @MainActor in
            if let index = savedWorkouts.firstIndex(where: { $0.id == workout.id }) {
                savedWorkouts.remove(at: index)
                saveSavedWorkouts()
                updateWeeklyProgress()
            }
        }
    }
    
    func getWorkoutsForType(_ type: WorkoutType) -> [WorkoutOption] {
        savedWorkouts.filter { $0.type == type }
    }
    
    func getWeeklyProgress() -> [Bool] {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        return (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
            return savedWorkouts.contains { workout in
                guard let completedDate = workout.completedDate else { return false }
                return calendar.isDate(completedDate, inSameDayAs: date)
            }
        }
    }
    
    func getMonthlyStats() -> (distance: Double, time: String, calories: Int) {
        let totalCalories = savedWorkouts.reduce(0) { $0 + $1.caloriesBurned }
        let totalMinutes = savedWorkouts.reduce(0) { $0 + $1.duration }
        
        // Keep total distance tracked at bottom
        let totalDistance = savedWorkouts.reduce(0.0) { total, workout in
            let speed: Double
            switch workout.type {
            case .walking: speed = 4.0 // 4 mph
            case .running: speed = 6.0 // 6 mph
            case .cycling: speed = 14.0 // 14 mph
            }
            return total + (speed * Double(workout.duration) / 60.0) // Convert to miles
        }
        
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let timeString = "\(hours)h \(minutes)m"
        
        return (totalDistance, timeString, totalCalories)
    }
    
    private func saveSavedWorkouts() {
        if let encoded = try? JSONEncoder().encode(savedWorkouts) {
            UserDefaults.standard.set(encoded, forKey: "SavedWorkouts")
        }
    }
    
    private func loadSavedWorkouts() {
        if let data = UserDefaults.standard.data(forKey: "SavedWorkouts"),
           let decoded = try? JSONDecoder().decode([WorkoutOption].self, from: data) {
            savedWorkouts = decoded
        }
    }
    
    private func updateWeeklyProgress() {
    }
    
    func updateHealthProfile(_ profile: UserHealthProfile) {
        Task { @MainActor in
            userHealthProfile = profile
            saveHealthProfile()
        }
    }
    
    private func loadHealthProfile() {
        if let data = userDefaults.data(forKey: healthProfileKey),
           let profile = try? JSONDecoder().decode(UserHealthProfile.self, from: data) {
            userHealthProfile = profile
        }
    }
    
    private func saveHealthProfile() {
        if let profile = userHealthProfile,
           let data = try? JSONEncoder().encode(profile) {
            userDefaults.set(data, forKey: healthProfileKey)
        }
    }
    
    // Update recipe suggestions based on user's stats
    func suggestRecipes(for ingredients: [String]) {
        var prompt = "Suggest recipes using these ingredients: \(ingredients.joined(separator: ", "))"
        
        if let profile = userHealthProfile {
            prompt += "\nConsider these dietary preferences: \(profile.dietaryPreferences.joined(separator: ", "))"
            if !profile.allergies.isEmpty {
                prompt += "\nAvoid these allergens: \(profile.allergies.joined(separator: ", "))"
            }
            prompt += "\nFitness goal: \(profile.fitnessGoal)"
            prompt += "\nActivity level: \(profile.activityLevel)"
        }
        
        if isSustainableMode {
            prompt += "\nFocus on sustainable and eco-friendly cooking methods."
        }
        
      
    }
}

extension FridgeViewModel: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
} 
