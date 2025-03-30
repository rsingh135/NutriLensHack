# FridgeAI App

An iOS app that helps you manage your fridge contents, generate recipes, and track workouts.

## Setup Instructions

### API Key Configuration

1. Get your Gemini API key:
   - Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
   - Create a new API key or copy your existing one

2. Set up the Secrets file:
   - Locate `Secrets.swift.template` in the project
   - Create a copy of it and name it `Secrets.swift`
   - Replace `YOUR_API_KEY_HERE` with your actual Gemini API key

```swift
enum Secrets {
    static let geminiAPIKey = "your-actual-api-key-here"
}
```

** Security **:
 - Don't commit your Secrets.swift file and don't leak your API please 
