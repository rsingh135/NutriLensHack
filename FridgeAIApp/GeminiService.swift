import Foundation
import Network

enum GeminiError: Error, LocalizedError {
    case invalidAPIKey
    case invalidResponse
    case networkError(Error)
    case serverError(Int, String)
    case noInternetConnection
    
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
        case .noInternetConnection:
            return "No internet connection. Please check your network settings."
        }
    }
}

class GeminiService {
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    private let model = "gemini-1.5-flash"
    private let monitor = NWPathMonitor()
    private var isConnected = false
    private let queue = DispatchQueue(label: "com.fridgeai.networkmonitor")
    
    init(apiKey: String) {
        self.apiKey = apiKey
        print("GeminiService initialized with API key: \(apiKey.prefix(5))...")
        
        // Start monitoring network connectivity
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                print("🌐 Network Status Update:")
                print("   - Status: \(path.status)")
                print("   - Is Expensive: \(path.isExpensive)")
                print("   - Is Constrained: \(path.isConstrained)")
                print("   - Available Interfaces: \(path.availableInterfaces)")
            }
        }
        monitor.start(queue: queue)
        
        // Initial network check
        checkInitialConnection()
    }
    
    deinit {
        monitor.cancel()
    }
    
    private func checkInitialConnection() {
        let endpoint = "\(baseURL)/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else { return }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Initial connection test failed: \(error.localizedDescription)")
                    self?.isConnected = false
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("✅ Initial connection test successful (Status: \(httpResponse.statusCode))")
                    self?.isConnected = true
                }
            }
        }
        task.resume()
    }
    
    private func checkConnection() throws {
        guard isConnected else {
            print("❌ No internet connection available")
            // Try one more time with a direct check
            let endpoint = "\(baseURL)/\(model):generateContent?key=\(apiKey)"
            guard let url = URL(string: endpoint) else {
                throw GeminiError.noInternetConnection
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var isReachable = false
            
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                isReachable = error == nil
                semaphore.signal()
            }
            task.resume()
            
            _ = semaphore.wait(timeout: .now() + 5.0)
            
            if !isReachable {
                throw GeminiError.noInternetConnection
            }
            
            self.isConnected = true
            print("✅ Connection restored")
            return
        }
    }
    
    private func testAPIKey() async throws {
        print("Testing API key...")
        try checkConnection()
        
        let endpoint = "\(baseURL)/\(model):generateContent?key=\(apiKey)"
        let url = URL(string: endpoint)!
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": "Hello, this is a test request."
                        ]
                    ]
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response during API key test")
                throw GeminiError.invalidResponse
            }
            
            print("🔑 API Key Test Response Code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    print("❌ API Key Test Failed: \(message)")
                    throw GeminiError.serverError(httpResponse.statusCode, message)
                } else {
                    print("❌ API Key Test Failed with status code: \(httpResponse.statusCode)")
                    throw GeminiError.serverError(httpResponse.statusCode, "Unknown error")
                }
            } else {
                print("✅ API Key Test Successful!")
            }
        } catch let error as GeminiError {
            throw error
        } catch {
            print("❌ Network error during API key test: \(error)")
            throw GeminiError.networkError(error)
        }
    }
    
    func analyzeImage(_ imageData: Data) async throws -> [String] {
        print("Starting image analysis...")
        try checkConnection()
        
        let endpoint = "\(baseURL)/\(model):generateContent?key=\(apiKey)"
        let url = URL(string: endpoint)!
        
        // Convert image data to base64
        let base64Image = imageData.base64EncodedString()
        print("Image converted to base64 (length: \(base64Image.count))")
        
        // Updated request format for gemini-1.5-flash
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
        
        do {
            print("Sending request to Gemini API...")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid HTTP response")
                throw GeminiError.invalidResponse
            }
            
            print("Received response with status code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    print("Server error: \(message)")
                    throw GeminiError.serverError(httpResponse.statusCode, message)
                } else {
                    print("Server error with status code: \(httpResponse.statusCode)")
                    throw GeminiError.serverError(httpResponse.statusCode, "Unknown error")
                }
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            print("Response JSON: \(String(describing: json))")
            
            guard let candidates = json?["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String else {
                print("Failed to parse response structure")
                throw GeminiError.invalidResponse
            }
            
            print("Successfully parsed response text: \(text)")
            let ingredients = text.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            print("Extracted ingredients: \(ingredients)")
            return ingredients
            
        } catch let error as GeminiError {
            throw error
        } catch {
            print("Error during image analysis: \(error)")
            throw GeminiError.networkError(error)
        }
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
        
        print("Received response text: \(text)")
        
        // Clean up the response text to ensure it's valid JSON
        let cleanedText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract only the JSON object (everything between the first { and the matching })
        if let jsonStart = cleanedText.firstIndex(of: "{"),
           let jsonEnd = cleanedText.lastIndex(of: "}") {
            let jsonString = String(cleanedText[jsonStart...jsonEnd])
            print("Cleaned JSON text: \(jsonString)")
            
            guard let jsonData = jsonString.data(using: .utf8) else {
                print("Failed to convert response text to data")
                throw GeminiError.invalidResponse
            }
            
            do {
                // First try to parse as a dictionary to validate JSON structure
                if let jsonDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    print("JSON structure is valid")
                } else {
                    print("Invalid JSON structure")
                    throw GeminiError.invalidResponse
                }
                
                let recipesResponse = try JSONDecoder().decode(RecipesResponse.self, from: jsonData)
                print("Successfully decoded \(recipesResponse.recipes.count) recipes")
                return recipesResponse.recipes
            } catch {
                print("Failed to decode recipes: \(error)")
                print("JSON data: \(String(data: jsonData, encoding: .utf8) ?? "invalid data")")
                throw GeminiError.invalidResponse
            }
        } else {
            print("Could not find valid JSON object in response")
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
}

// Helper struct for decoding recipe responses
private struct RecipesResponse: Codable {
    let recipes: [Recipe]
} 
