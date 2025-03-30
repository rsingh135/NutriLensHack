import SwiftUI

struct UserHealthProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: FridgeViewModel
    @State private var healthProfile: UserHealthProfile
    @State private var selectedDietaryPreferences: Set<String>
    @State private var newAllergy: String = ""
    @State private var showingSaveConfirmation = false
    @State private var heightInInches: Double
    @State private var weightInPounds: Double
    @State private var selectedAllergies: Set<String>
    @State private var isEditing = false
    
    let commonAllergies = [
        "Milk", "Eggs", "Fish", "Shellfish", "Tree Nuts",
        "Peanuts", "Wheat", "Soy", "Sesame"
    ]
    
    init(viewModel: FridgeViewModel) {
        // Initialize the viewModel
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        
        // Get the profile or create a new one
        let profile = viewModel.userHealthProfile ?? UserHealthProfile()
        
        // Initialize state variables one by one
        let initialHealthProfile = profile
        let initialDietaryPreferences = Set(profile.dietaryPreferences)
        let initialHeightInInches = profile.height / 2.54
        let initialWeightInPounds = profile.weight * 2.20462
        let initialAllergies = Set(profile.allergies)
        
        // Set the state variables
        self._healthProfile = State(initialValue: initialHealthProfile)
        self._selectedDietaryPreferences = State(initialValue: initialDietaryPreferences)
        self._heightInInches = State(initialValue: initialHeightInInches)
        self._weightInPounds = State(initialValue: initialWeightInPounds)
        self._selectedAllergies = State(initialValue: initialAllergies)
    }
    
    var body: some View {
        NavigationView {
            mainScrollView
        }
    }
    
    private var mainScrollView: some View {
        ScrollView {
            VStack(spacing: 20) {
                basicInformationSection
                healthMetricsSection
                dietaryPreferencesSection
                allergiesSection
            }
            .padding(.vertical)
        }
        .background(Theme.background)
        .navigationTitle("Health Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                cancelButton
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                editSaveButton
            }
        }
        .alert("Profile Saved", isPresented: $showingSaveConfirmation) {
            Button("OK") {
                isEditing = false
            }
        } message: {
            Text("Your health profile has been updated successfully.")
        }
    }
    
    private var basicInformationSection: some View {
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
                ) { newValue in
                    healthProfile.age = Int(newValue)
                }
                
                GenderSelector(
                    selection: Binding(
                        get: { healthProfile.gender.rawValue },
                        set: { newValue in
                            if let gender = Gender(rawValue: newValue) {
                                healthProfile.gender = gender
                            }
                        }
                    ),
                    isDisabled: !isEditing
                )
            }
            .padding()
            .background(Theme.primary.opacity(0.1))
            .cornerRadius(15)
            .padding(.horizontal)
        }
    }
    
    private var healthMetricsSection: some View {
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
    }
    
    private var dietaryPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dietary Preferences")
                .font(.headline)
                .foregroundColor(Theme.text)
                .padding(.horizontal)
            
            VStack(spacing: 15) {
                ForEach(DietaryPreference.allCases, id: \.self) { preference in
                    dietaryPreferenceToggle(for: preference)
                }
            }
            .padding()
            .background(Theme.primary.opacity(0.1))
            .cornerRadius(15)
            .padding(.horizontal)
        }
    }
    
    private func dietaryPreferenceToggle(for preference: DietaryPreference) -> some View {
        Toggle(isOn: Binding(
            get: { selectedDietaryPreferences.contains(preference.rawValue) },
            set: { isSelected in
                if isSelected {
                    selectedDietaryPreferences.insert(preference.rawValue)
                } else {
                    selectedDietaryPreferences.remove(preference.rawValue)
                }
                healthProfile.dietaryPreferences = Array(selectedDietaryPreferences)
            }
        )) {
            HStack {
                Text(preference.rawValue)
                    .foregroundColor(Theme.text)
            }
        }
        .disabled(!isEditing)
    }
    
    private var allergiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Allergies")
                .font(.headline)
                .foregroundColor(Theme.text)
                .padding(.horizontal)
            
            VStack(spacing: 15) {
                ForEach(commonAllergies, id: \.self) { allergy in
                    allergyToggle(for: allergy)
                }
                
                if isEditing {
                    addAllergyField
                }
            }
            .padding()
            .background(Theme.primary.opacity(0.1))
            .cornerRadius(15)
            .padding(.horizontal)
        }
    }
    
    private func allergyToggle(for allergy: String) -> some View {
        Toggle(isOn: Binding(
            get: { selectedAllergies.contains(allergy) },
            set: { isSelected in
                if isSelected {
                    selectedAllergies.insert(allergy)
                } else {
                    selectedAllergies.remove(allergy)
                }
                healthProfile.allergies = Array(selectedAllergies)
            }
        )) {
            Text(allergy)
                .foregroundColor(Theme.text)
        }
        .disabled(!isEditing)
    }
    
    private var addAllergyField: some View {
        HStack {
            TextField("Add custom allergy", text: $newAllergy)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .foregroundColor(Theme.text)
            
            Button(action: {
                if !newAllergy.isEmpty {
                    selectedAllergies.insert(newAllergy)
                    healthProfile.allergies = Array(selectedAllergies)
                    newAllergy = ""
                }
            }) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(Theme.primary)
            }
        }
        .padding(.horizontal)
    }
    
    private var cancelButton: some View {
        Button("Cancel") {
            presentationMode.wrappedValue.dismiss()
        }
        .foregroundColor(Theme.primary)
    }
    
    private var editSaveButton: some View {
        if isEditing {
            return Button("Save") {
                viewModel.updateHealthProfile(healthProfile)
                showingSaveConfirmation = true
            }
            .foregroundColor(Theme.primary)
        } else {
            return Button("Edit") {
                isEditing = true
            }
            .foregroundColor(Theme.primary)
        }
    }
}

struct MetricInputField: View {
    let icon: String
    let title: String
    let unit: String
    @Binding var value: Double
    let isDisabled: Bool
    let onValueChange: (Double) -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Theme.primary)
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(Theme.text)
            
            Spacer()
            
            TextField("0", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .disabled(isDisabled)
                .onChange(of: value) { newValue in
                    onValueChange(newValue)
                }
            
            Text(unit)
                .foregroundColor(Theme.text.opacity(0.8))
        }
    }
}

struct GenderSelector: View {
    @Binding var selection: String
    let isDisabled: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "person")
                .foregroundColor(Theme.primary)
                .frame(width: 30)
            
            Text("Gender")
                .foregroundColor(Theme.text)
            
            Spacer()
            
            Picker("Gender", selection: $selection) {
                ForEach(Gender.allCases, id: \.self) { gender in
                    Text(gender.rawValue.capitalized)
                        .tag(gender.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isDisabled)
        }
    }
}

struct BMICard: View {
    let bmi: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("BMI")
                .font(.subheadline)
                .foregroundColor(Theme.text.opacity(0.8))
            
            Text(String(format: "%.1f", bmi))
                .font(.title)
                .bold()
                .foregroundColor(Theme.primary)
            
            Text(bmiCategory)
                .font(.caption)
                .foregroundColor(Theme.text.opacity(0.8))
        }
        .padding()
        .frame(width: 120)
        .background(Theme.primary.opacity(0.1))
        .cornerRadius(15)
    }
    
    private var bmiCategory: String {
        switch bmi {
        case ..<18.5:
            return "Underweight"
        case 18.5..<25:
            return "Normal"
        case 25..<30:
            return "Overweight"
        default:
            return "Obese"
        }
    }
}
