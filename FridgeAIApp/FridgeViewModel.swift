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
    
    override init() {
        // Initialize with API key from Secrets.swift
        self.geminiService = GeminiService(apiKey: Secrets.geminiAPIKey)
        super.init()
        speechSynthesizer.delegate = self
        loadFavorites()
    }
    
    func analyzeFridgeImage() {
        guard let image = fridgeImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Failed to process image"
            return
        }
        
        isAnalyzing = true
        errorMessage = nil
        
        Task {
            do {
                detectedIngredients = try await geminiService.analyzeImage(imageData)
                recipes = try await geminiService.generateRecipes(ingredients: detectedIngredients)
                
                if isSustainableMode {
                    // Sort recipes based on both carbon footprint and expiration
                    recipes.sort { recipe1, recipe2 in
                        // First, prioritize recipes with ingredients close to expiring
                        if recipe1.expirationInfo.daysUntilExpiration <= 3 && recipe2.expirationInfo.daysUntilExpiration > 3 {
                            return true
                        } else if recipe2.expirationInfo.daysUntilExpiration <= 3 && recipe1.expirationInfo.daysUntilExpiration > 3 {
                            return false
                        }
                        
                        // Then, consider carbon footprint
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
        if let index = favoriteRecipes.firstIndex(where: { $0.id == recipe.id }) {
            favoriteRecipes.remove(at: index)
        } else {
            favoriteRecipes.append(recipe)
        }
        saveFavorites()
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
