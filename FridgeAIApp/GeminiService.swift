import Foundation

enum GeminiError: Error, LocalizedError {
    case invalidAPIKey
    case invalidResponse
    case networkError(Error)
    case serverError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key. Please check your configuration."
        case .invalidResponse:
            return "Invalid response from Gemini API. Please try again."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        }
    }
}

class GeminiService {
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    private let model = "gemini-1.5-flash"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func analyzeImage(_ imageData: Data) async throws -> [String] {
        let endpoint = "\(baseURL)/\(model):generateContent?key=\(apiKey)"
        let url = URL(string: endpoint)!
        
        let base64Image = imageData.base64EncodedString()
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": "Analyze this image of a fridge and list all visible food items and ingredients. Return only a list of ingredients, separated by commas."
                        ],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.4,
                "topK": 32,
                "topP": 1
            ],
            "safetySettings": [
                [
                    "category": "HARM_CATEGORY_HARASSMENT",
                    "threshold": "BLOCK_NONE"
                ],
                [
                    "category": "HARM_CATEGORY_HATE_SPEECH",
                    "threshold": "BLOCK_NONE"
                ],
                [
                    "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                    "threshold": "BLOCK_NONE"
                ],
                [
                    "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                    "threshold": "BLOCK_NONE"
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GeminiError.invalidResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw GeminiError.invalidResponse
        }
        
        let ingredients = text.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return ingredients
    }
    
    func generateRecipes(ingredients: [String]) async throws -> [Recipe] {
        let endpoint = "\(baseURL)/\(model):generateContent?key=\(apiKey)"
        let url = URL(string: endpoint)!
        
        let prompt = """
        Generate 3 recipes using some or all of these ingredients: \(ingredients.joined(separator: ", ")).
        For each recipe, provide:
        1. Name
        2. List of ingredients (including quantities)
        3. Step by step instructions
        4. Estimated calories
        5. Carbon footprint (in kg CO2)
        6. Nutritional info (protein, carbs, fat, fiber in grams)
        7. Expiration info:
           - daysUntilExpiration: Number of days until the most perishable ingredient expires
           - freshnessScore: A score from 0.0 to 1.0 indicating overall freshness (1.0 being freshest)
           - priorityIngredients: List of ingredients that are close to expiring
        
        Format as JSON array with this structure:
        {
          "recipes": [
            {
              "name": "Recipe Name",
              "ingredients": ["ingredient 1", "ingredient 2"],
              "instructions": ["step 1", "step 2"],
              "calories": 500,
              "carbonFootprint": 2.5,
              "nutritionalInfo": {
                "protein": 20,
                "carbs": 30,
                "fat": 15,
                "fiber": 5
              },
              "expirationInfo": {
                "daysUntilExpiration": 3,
                "freshnessScore": 0.8,
                "priorityIngredients": ["ingredient 1"]
              }
            }
          ]
        }
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "topK": 32,
                "topP": 1
            ],
            "safetySettings": [
                [
                    "category": "HARM_CATEGORY_HARASSMENT",
                    "threshold": "BLOCK_NONE"
                ],
                [
                    "category": "HARM_CATEGORY_HATE_SPEECH",
                    "threshold": "BLOCK_NONE"
                ],
                [
                    "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                    "threshold": "BLOCK_NONE"
                ],
                [
                    "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                    "threshold": "BLOCK_NONE"
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GeminiError.invalidResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw GeminiError.invalidResponse
        }
        
        let cleanedText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let jsonStart = cleanedText.firstIndex(of: "{"),
           let jsonEnd = cleanedText.lastIndex(of: "}") {
            let jsonString = String(cleanedText[jsonStart...jsonEnd])
            
            guard let jsonData = jsonString.data(using: .utf8) else {
                throw GeminiError.invalidResponse
            }
            
            let recipesResponse = try JSONDecoder().decode(RecipesResponse.self, from: jsonData)
            return recipesResponse.recipes
        } else {
            throw GeminiError.invalidResponse
        }
    }
    
    func getRecipeHelp(recipe: Recipe) async throws -> String {
        let endpoint = "\(baseURL)/\(model):generateContent?key=\(apiKey)"
        let url = URL(string: endpoint)!
        
        let prompt = """
        Provide cooking tips and advice for making \(recipe.name).
        Consider:
        1. Ingredient preparation
        2. Cooking techniques
        3. Common mistakes to avoid
        4. Timing and temperature
        5. Plating and presentation
        Keep the response concise and practical.
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "topK": 32,
                "topP": 1
            ],
            "safetySettings": [
                [
                    "category": "HARM_CATEGORY_HARASSMENT",
                    "threshold": "BLOCK_NONE"
                ],
                [
                    "category": "HARM_CATEGORY_HATE_SPEECH",
                    "threshold": "BLOCK_NONE"
                ],
                [
                    "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                    "threshold": "BLOCK_NONE"
                ],
                [
                    "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                    "threshold": "BLOCK_NONE"
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GeminiError.invalidResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw GeminiError.invalidResponse
        }
        
        return text
    }
    
    func generateWorkoutRecommendation(for recipe: Recipe) async throws -> WorkoutRecommendation {
        let endpoint = "\(baseURL)/\(model):generateContent?key=\(apiKey)"
        let url = URL(string: endpoint)!
        
        let prompt = """
        Generate workout recommendations to burn off the calories from this recipe: \(recipe.name) (\(recipe.calories) calories).
        
        Provide three different workout options (walking, running, and cycling) with appropriate durations to burn these calories.
        For each workout, include:
        1. Type of workout (must be one of: walking, running, cycling)
        2. Duration in minutes
        3. Estimated calories burned
        4. A brief description of the workout
        
        Format as JSON with this structure:
        {
          "recipeName": "\(recipe.name)",
          "caloriesToBurn": \(recipe.calories),
          "workouts": [
            {
              "type": "walking",
              "duration": 60,
              "caloriesBurned": 250,
              "description": "Brisk walk at 4 mph"
            },
            {
              "type": "running",
              "duration": 30,
              "caloriesBurned": 400,
              "description": "Jog at 6 mph"
            },
            {
              "type": "cycling",
              "duration": 45,
              "caloriesBurned": 500,
              "description": "Moderate cycling at 14 mph"
            }
          ]
        }
        
        Make sure to:
        1. Use the exact recipe name provided
        2. Use the exact calories provided
        3. Include all three workout types
        4. Ensure the total calories burned matches the recipe calories
        5. Use valid workout types (walking, running, cycling)
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "topK": 32,
                "topP": 1
            ],
            "safetySettings": [
                [
                    "category": "HARM_CATEGORY_HARASSMENT",
                    "threshold": "BLOCK_NONE"
                ],
                [
                    "category": "HARM_CATEGORY_HATE_SPEECH",
                    "threshold": "BLOCK_NONE"
                ],
                [
                    "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                    "threshold": "BLOCK_NONE"
                ],
                [
                    "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                    "threshold": "BLOCK_NONE"
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GeminiError.invalidResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw GeminiError.invalidResponse
        }
        
        let cleanedText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let jsonStart = cleanedText.firstIndex(of: "{"),
           let jsonEnd = cleanedText.lastIndex(of: "}") {
            let jsonString = String(cleanedText[jsonStart...jsonEnd])
            
            guard let jsonData = jsonString.data(using: .utf8) else {
                throw GeminiError.invalidResponse
            }
            
            let recommendation = try JSONDecoder().decode(WorkoutRecommendation.self, from: jsonData)
            return recommendation
        } else {
            throw GeminiError.invalidResponse
        }
    }
}

// Helper struct for decoding recipe responses
private struct RecipesResponse: Codable {
    let recipes: [Recipe]
} 
