import SwiftUI

struct UserHealthProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: FridgeViewModel
    @State private var healthProfile: UserHealthProfile
    @State private var selectedDietaryPreferences: Set<String> = []
    @State private var newAllergy: String = ""
    @State private var showingSaveConfirmation = false
    @State private var heightInInches: Double = 0
    @State private var weightInPounds: Double = 0
    @State private var selectedAllergies: Set<String> = []
    @State private var isEditing = false
    
    let commonAllergies = [
        "Milk", "Eggs", "Fish", "Shellfish", "Tree Nuts",
        "Peanuts", "Wheat", "Soy", "Sesame"
    ]
    
    init(viewModel: FridgeViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self._healthProfile = State(initialValue: viewModel.userHealthProfile ?? UserHealthProfile())
        if let preferences = viewModel.userHealthProfile?.dietaryPreferences {
            self._selectedDietaryPreferences = State(initialValue: Set(preferences))
        }
        if let profile = viewModel.userHealthProfile {
            self._heightInInches = State(initialValue: profile.height / 2.54)
            self._weightInPounds = State(initialValue: profile.weight * 2.20462)
            self._selectedAllergies = State(initialValue: Set(profile.allergies))
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Basic Information Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Basic Information")
                            .font(.headline)
                            .foregroundColor(Theme.text)
                            .padding(.horizontal)
                        
                        VStack(spacing: 15) {
                            MetricInputField(
                                icon: "ruler",
                                title: "Height",
                                unit: "inches",
                                value: $heightInInches,
                                isDisabled: !isEditing
                            ) { newValue in
                                healthProfile.height = newValue * 2.54
                            }
                            
                            MetricInputField(
                                icon: "scalemass",
                                title: "Weight",
                                unit: "lbs",
                                value: $weightInPounds,
                                isDisabled: !isEditing
                            ) { newValue in
                                healthProfile.weight = newValue / 2.20462
                            }
                            
                            MetricInputField(
                                icon: "calendar",
                                title: "Age",
                                unit: "years",
                                value: Binding(
                                    get: { Double(healthProfile.age) },
                                    set: { healthProfile.age = Int($0) }
                                ),
                                isDisabled: !isEditing
                            )
                            
                            GenderSelector(selection: $healthProfile.gender, isDisabled: !isEditing)
                        }
                        .padding()
                        .background(Theme.primary.opacity(0.1))
                        .cornerRadius(15)
                        .padding(.horizontal)
                    }
                    
                    // BMI Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Health Metrics")
                            .font(.headline)
                            .foregroundColor(Theme.text)
                            .padding(.horizontal)
                        
                        HStack {
                            BMICard(bmi: healthProfile.bmi)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    
                    // Dietary Preferences Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Dietary Preferences")
                            .font(.headline)
                            .foregroundColor(Theme.text)
                            .padding(.horizontal)
                        
                        VStack {
                            ForEach(DietaryPreference.allCases, id: \.rawValue) { preference in
                                Toggle(preference.rawValue, isOn: Binding(
                                    get: { selectedDietaryPreferences.contains(preference.rawValue) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedDietaryPreferences.insert(preference.rawValue)
                                        } else {
                                            selectedDietaryPreferences.remove(preference.rawValue)
                                        }
                                        healthProfile.dietaryPreferences = Array(selectedDietaryPreferences)
                                    }
                                ))
                                .toggleStyle(SwitchToggleStyle(tint: Theme.primary))
                                .disabled(!isEditing)
                                if preference != DietaryPreference.allCases.last {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                        .background(Theme.primary.opacity(0.1))
                        .cornerRadius(15)
                        .padding(.horizontal)
                    }
                    
                    // Allergies Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Allergies")
                            .font(.headline)
                            .foregroundColor(Theme.text)
                            .padding(.horizontal)
                        
                        VStack(spacing: 2) {
                            ForEach(commonAllergies, id: \.self) { allergy in
                                Toggle(allergy, isOn: Binding(
                                    get: { selectedAllergies.contains(allergy) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedAllergies.insert(allergy)
                                        } else {
                                            selectedAllergies.remove(allergy)
                                        }
                                        healthProfile.allergies = Array(selectedAllergies)
                                    }
                                ))
                                .toggleStyle(SwitchToggleStyle(tint: Theme.primary))
                                .disabled(!isEditing)
                                if allergy != commonAllergies.last {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                        .background(Theme.primary.opacity(0.1))
                        .cornerRadius(15)
                        .padding(.horizontal)
                    }
                    
                    // Fitness Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Fitness")
                            .font(.headline)
                            .foregroundColor(Theme.text)
                            .padding(.horizontal)
                        
                        VStack(spacing: 15) {
                            FitnessSelector(
                                title: "Fitness Goal",
                                selection: $healthProfile.fitnessGoal,
                                options: FitnessGoal.allCases.map { $0.rawValue },
                                isDisabled: !isEditing
                            )
                            
                            FitnessSelector(
                                title: "Activity Level",
                                selection: $healthProfile.activityLevel,
                                options: ActivityLevel.allCases.map { $0.rawValue },
                                isDisabled: !isEditing
                            )
                        }
                        .padding()
                        .background(Theme.primary.opacity(0.1))
                        .cornerRadius(15)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Theme.background)
            .navigationTitle("Health Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            saveProfile()
                        }
                        isEditing.toggle()
                    }
                }
            }
            .alert(isPresented: $showingSaveConfirmation) {
                Alert(
                    title: Text("Profile Saved"),
                    message: Text("Your health profile has been updated."),
                    dismissButton: .default(Text("OK")) {
                        isEditing = false
                    }
                )
            }
        }
    }
    
    private func addAllergy() {
        let trimmedAllergy = newAllergy.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAllergy.isEmpty && !healthProfile.allergies.contains(trimmedAllergy) {
            healthProfile.allergies.append(trimmedAllergy)
            newAllergy = ""
        }
    }
    
    private func saveProfile() {
        healthProfile.dietaryPreferences = Array(selectedDietaryPreferences)
        healthProfile.allergies = Array(selectedAllergies)
        viewModel.updateHealthProfile(healthProfile)
        showingSaveConfirmation = true
    }
}

// Supporting Views
struct MetricInputField: View {
    let icon: String
    let title: String
    let unit: String
    @Binding var value: Double
    let isDisabled: Bool
    var onValueChanged: ((Double) -> Void)? = nil
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Theme.primary)
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(Theme.text)
            
            Spacer()
            
            TextField("Value", value: $value, formatter: NumberFormatter())
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .disabled(isDisabled)
                .onChange(of: value) { newValue in
                    onValueChanged?(newValue)
                }
            
            Text(unit)
                .foregroundColor(Theme.text.opacity(0.8))
                .frame(width: 50, alignment: .leading)
        }
    }
}

struct GenderSelector: View {
    @Binding var selection: String
    let isDisabled: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "person.fill")
                .foregroundColor(Theme.primary)
                .frame(width: 30)
            
            Text("Gender")
                .foregroundColor(Theme.text)
            
            Spacer()
            
            Picker("Gender", selection: $selection) {
                Text("Male").tag("male")
                Text("Female").tag("female")
                Text("Other").tag("other")
                Text("Prefer not to say").tag("prefer not to say")
            }
            .disabled(isDisabled)
            .tint(Theme.primary)
        }
    }
}

struct BMICard: View {
    let bmi: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BMI")
                .font(.headline)
                .foregroundColor(Theme.text)
            
            HStack(alignment: .bottom, spacing: 4) {
                Text(String(format: "%.1f", bmi))
                    .font(.title)
                    .bold()
                    .foregroundColor(getBMIColor(bmi: bmi))
                
                Text(getBMICategory(bmi: bmi))
                    .font(.caption)
                    .foregroundColor(Theme.text.opacity(0.8))
                    .padding(.bottom, 4)
            }
        }
        .padding()
        .background(Theme.primary.opacity(0.1))
        .cornerRadius(15)
    }
    
    private func getBMIColor(bmi: Double) -> Color {
        switch bmi {
        case ..<18.5: return .blue
        case 18.5..<25: return Theme.primary
        case 25..<30: return .orange
        default: return .red
        }
    }
    
    private func getBMICategory(bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal weight"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }
}

struct FitnessSelector: View {
    let title: String
    @Binding var selection: String
    let options: [String]
    let isDisabled: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundColor(Theme.text)
            
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option.capitalized)
                        .tag(option)
                }
            }
            .disabled(isDisabled)
            .pickerStyle(SegmentedPickerStyle())
            .tint(Theme.primary)
        }
    }
} 