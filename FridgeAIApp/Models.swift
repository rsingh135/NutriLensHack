//
//  Models.swift
//  FridgeAIApp
//
//  Created by Ranveer Singh on 3/28/25.
//

import Foundation

struct Recipe: Identifiable, Codable {
    let id: UUID
    let name: String
    let ingredients: [String]
    let instructions: [String]
    let carbonFootprint: Double
    let calories: Int
    let nutritionalInfo: NutritionalInfo
    let expirationInfo: ExpirationInfo
    
    init(id: UUID = UUID(), name: String, ingredients: [String], instructions: [String], carbonFootprint: Double, calories: Int, nutritionalInfo: NutritionalInfo, expirationInfo: ExpirationInfo) {
        self.id = id
        self.name = name
        self.ingredients = ingredients
        self.instructions = instructions
        self.carbonFootprint = carbonFootprint
        self.calories = calories
        self.nutritionalInfo = nutritionalInfo
        self.expirationInfo = expirationInfo
    }
    
    // Add custom decoding to handle missing id field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID() // Generate a new UUID during decoding
        self.name = try container.decode(String.self, forKey: .name)
        self.ingredients = try container.decode([String].self, forKey: .ingredients)
        self.instructions = try container.decode([String].self, forKey: .instructions)
        self.carbonFootprint = try container.decode(Double.self, forKey: .carbonFootprint)
        self.calories = try container.decode(Int.self, forKey: .calories)
        self.nutritionalInfo = try container.decode(NutritionalInfo.self, forKey: .nutritionalInfo)
        self.expirationInfo = try container.decode(ExpirationInfo.self, forKey: .expirationInfo)
    }
    
    private enum CodingKeys: String, CodingKey {
        case name
        case ingredients
        case instructions
        case carbonFootprint
        case calories
        case nutritionalInfo
        case expirationInfo
    }
}

struct NutritionalInfo: Codable {
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
}

struct ExpirationInfo: Codable {
    let daysUntilExpiration: Int
    let freshnessScore: Double // 0.0 to 1.0, where 1.0 is freshest
    let priorityIngredients: [String] // List of ingredients that are close to expiring
}

struct WorkoutRecommendation: Codable {
    let recipeName: String
    let caloriesToBurn: Int
    let workouts: [WorkoutOption]
}

struct WorkoutOption: Codable, Identifiable {
    let id: UUID
    let type: WorkoutType
    let duration: Int // in minutes
    let caloriesBurned: Int
    let description: String
    var isCompleted: Bool
    var completedDate: Date?
    
    init(id: UUID = UUID(), type: WorkoutType, duration: Int, caloriesBurned: Int, description: String, isCompleted: Bool = false, completedDate: Date? = nil) {
        self.id = id
        self.type = type
        self.duration = duration
        self.caloriesBurned = caloriesBurned
        self.description = description
        self.isCompleted = isCompleted
        self.completedDate = completedDate
    }
    
    // Add custom decoding to handle missing id field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID() // Generate a new UUID during decoding
        self.type = try container.decode(WorkoutType.self, forKey: .type)
        self.duration = try container.decode(Int.self, forKey: .duration)
        self.caloriesBurned = try container.decode(Int.self, forKey: .caloriesBurned)
        self.description = try container.decode(String.self, forKey: .description)
        self.isCompleted = false
        self.completedDate = nil
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case duration
        case caloriesBurned
        case description
    }
}

enum WorkoutType: String, Codable {
    case walking
    case running
    case cycling
    
    var icon: String {
        switch self {
        case .walking: return "figure.walk"
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        }
    }
} 
