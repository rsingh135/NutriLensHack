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
    
    init(id: UUID = UUID(), name: String, ingredients: [String], instructions: [String], carbonFootprint: Double, calories: Int, nutritionalInfo: NutritionalInfo) {
        self.id = id
        self.name = name
        self.ingredients = ingredients
        self.instructions = instructions
        self.carbonFootprint = carbonFootprint
        self.calories = calories
        self.nutritionalInfo = nutritionalInfo
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
    }
    
    private enum CodingKeys: String, CodingKey {
        case name
        case ingredients
        case instructions
        case carbonFootprint
        case calories
        case nutritionalInfo
    }
}

struct NutritionalInfo: Codable {
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
} 
