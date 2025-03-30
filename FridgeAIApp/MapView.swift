import SwiftUI
import MapKit
import CoreLocation

struct IdentifiableMapMarker: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String?
    
    init(coordinate: CLLocationCoordinate2D, title: String? = nil) {
        self.coordinate = coordinate
        self.title = title
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var locationError: String?
    @Published var isRequestingLocation = false
    
    override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.pausesLocationUpdatesAutomatically = true
    }
    
    func requestLocation() {
        // Reset any previous errors
        locationError = nil
        
        // Check if location services are enabled
        if !CLLocationManager.locationServicesEnabled() {
            DispatchQueue.main.async {
                self.locationError = "Location services are disabled. Please enable them in Settings."
            }
            return
        }
        
        // Check current authorization status
        let currentStatus = locationManager.authorizationStatus
        
        switch currentStatus {
        case .notDetermined:
            // Request authorization and wait for callback
            isRequestingLocation = true
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            // Already authorized, start updating location
            isRequestingLocation = true
            locationManager.startUpdatingLocation()
        case .denied:
            DispatchQueue.main.async {
                self.locationError = "Location access denied. Please enable it in Settings."
            }
        case .restricted:
            DispatchQueue.main.async {
                self.locationError = "Location access is restricted."
            }
        @unknown default:
            DispatchQueue.main.async {
                self.locationError = "Unknown location authorization status."
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse:
                // Start updating location when we get "When in Use" authorization
                self.locationManager.startUpdatingLocation()
            case .denied:
                self.locationError = "Location access denied. Please enable it in Settings."
                self.isRequestingLocation = false
            case .restricted:
                self.locationError = "Location access is restricted."
                self.isRequestingLocation = false
            case .notDetermined:
                // Authorization status is still being determined
                break
            @unknown default:
                self.locationError = "Unknown location authorization status."
                self.isRequestingLocation = false
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.location = location
            self.locationError = nil
            self.isRequestingLocation = false
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.locationError = "Location access denied. Please enable it in Settings."
                case .locationUnknown:
                    // Try to get location again after a short delay
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                        self.locationManager.startUpdatingLocation()
                    }
                    self.locationError = "Unable to determine location. Please try again."
                default:
                    self.locationError = "Location error: \(error.localizedDescription)"
                }
            } else {
                self.locationError = "Location error: \(error.localizedDescription)"
            }
            self.isRequestingLocation = false
        }
    }
}

struct MapView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedItem: MKMapItem?
    @State private var showingDetail = false
    @State private var showingLocationPermissionAlert = false
    @State private var mapAnnotations: [IdentifiableMapMarker] = []
    @State private var searchedLocation: CLLocationCoordinate2D?
    
    var body: some View {
        ZStack(alignment: .top) {
            Map(coordinateRegion: $region,
                showsUserLocation: true,
                annotationItems: mapAnnotations) { marker in
                MapAnnotation(coordinate: marker.coordinate) {
                    VStack {
                        Image(systemName: "leaf.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                        if let title = marker.title {
                            Text(title)
                                .font(.caption)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            .task {
                locationManager.requestLocation()
            }
            .onChange(of: locationManager.location) { _, newLocation in
                if let location = newLocation, searchedLocation == nil {
                    withAnimation {
                        region = MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    }
                }
            }
            
            VStack(spacing: 0) {
                HStack {
                    TextField("Search location", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            searchLocation()
                        }
                    
                    Button(action: {
                        searchLocation()
                    }) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        searchSustainableFoodSources()
                    }) {
                        Image(systemName: "leaf.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                    
                    Button(action: centerOnUserLocation) {
                        Image(systemName: "location.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                if !searchResults.isEmpty {
                    List(searchResults, id: \.self) { item in
                        Button(action: {
                            selectedItem = item
                            showingDetail = true
                            withAnimation {
                                region.center = item.placemark.coordinate
                                searchedLocation = item.placemark.coordinate
                            }
                        }) {
                            VStack(alignment: .leading) {
                                Text(item.name ?? "Unknown Location")
                                    .font(.headline)
                                Text(item.placemark.title ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                    .background(Color(.systemBackground))
                }
            }
        }
        .alert("Location Error", isPresented: .constant(locationManager.locationError != nil)) {
            Button("OK") {
                locationManager.locationError = nil
            }
        } message: {
            if let error = locationManager.locationError {
                Text(error)
            }
        }
        .alert("Location Access Required", isPresented: $showingLocationPermissionAlert) {
            Button("Settings", role: .none) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable location access in Settings to find sustainable places near you.")
        }
        .sheet(isPresented: $showingDetail) {
            if let item = selectedItem {
                LocationDetailView(mapItem: item)
            }
        }
    }
    
    private func searchLocation() {
        guard !searchText.isEmpty else { return }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.resultTypes = [.address, .pointOfInterest]
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response, error == nil else {
                print("Error searching for location: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                searchResults = response.mapItems
                if let firstResult = response.mapItems.first {
                    withAnimation {
                        region = response.boundingRegion
                        searchedLocation = firstResult.placemark.coordinate
                    }
                }
            }
        }
    }
    
    private func centerOnUserLocation() {
        searchedLocation = nil
        locationManager.requestLocation()
        if let location = locationManager.location {
            withAnimation {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        } else {
            showingLocationPermissionAlert = true
        }
    }
    
    private func searchSustainableFoodSources() {
        let searchTerms = [
            "restaurant sustainable",
            "restaurant organic",
            "restaurant farm to table",
            "restaurant eco friendly",
            "restaurant vegetarian",
            "restaurant vegan",
            "farmers market",
            "organic market",
            "health food store"
        ]
        
        // Clear existing annotations
        mapAnnotations = []
        
        // Ensure valid search region
        let searchRegion: MKCoordinateRegion
        if let searchedLocation = searchedLocation {
            searchRegion = MKCoordinateRegion(
                center: searchedLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        } else if let userLocation = locationManager.location {
            searchRegion = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        } else {
            searchRegion = region
        }
        
        // Perform separate searches
        var allResults: [MKMapItem] = []
        let group = DispatchGroup()
        
        for term in searchTerms {
            group.enter()
            
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = term
            request.region = searchRegion
            request.resultTypes = .pointOfInterest
            
            let search = MKLocalSearch(request: request)
            search.start { response, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Search error for term '\(term)': \(error.localizedDescription)")
                    return
                }
                
                if let response = response {
                    allResults.append(contentsOf: response.mapItems)
                }
            }
        }
        
        group.notify(queue: .main) {
            // Remove duplicates
            let uniqueResults = Array(Set(allResults.map { item in
                return (item.placemark.coordinate.latitude, item.placemark.coordinate.longitude, item)
            }.map { $0.2 }))
            
            // Sort by distance
            let centerLocation = CLLocation(
                latitude: searchRegion.center.latitude,
                longitude: searchRegion.center.longitude
            )
            
            let sortedResults = uniqueResults.sorted { item1, item2 in
                let location1 = CLLocation(
                    latitude: item1.placemark.coordinate.latitude,
                    longitude: item1.placemark.coordinate.longitude
                )
                let location2 = CLLocation(
                    latitude: item2.placemark.coordinate.latitude,
                    longitude: item2.placemark.coordinate.longitude
                )
                return location1.distance(from: centerLocation) < location2.distance(from: centerLocation)
            }
            
            searchResults = sortedResults
            
            // Create annotations for the results
            mapAnnotations = sortedResults.map { item in
                let distance = calculateDistance(from: centerLocation.coordinate, to: item.placemark.coordinate)
                let distanceString = formatDistance(distance)
                return IdentifiableMapMarker(
                    coordinate: item.placemark.coordinate,
                    title: "\(item.name ?? "Unknown") (\(distanceString))"
                )
            }
            
            // Show results in region
            if !sortedResults.isEmpty {
                var boundingBox = MKMapRect.null
                for item in sortedResults {
                    let point = MKMapPoint(item.placemark.coordinate)
                    let rect = MKMapRect(x: point.x - 1000, y: point.y - 1000, width: 2000, height: 2000)
                    boundingBox = boundingBox.union(rect)
                }
                
                let region = MKCoordinateRegion(boundingBox)
                withAnimation {
                    self.region = region
                }
            }
        }
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D?, to: CLLocationCoordinate2D) -> CLLocationDistance {
        guard let from = from else { return 0 }
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = LengthFormatter()
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter.string(fromValue: distance / 1000, unit: .kilometer)
    }
}

struct LocationDetailView: View {
    let mapItem: MKMapItem
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text(mapItem.name ?? "Unknown Location")
                        .font(.headline)
                    
                    if let address = mapItem.placemark.title {
                        Text(address)
                            .font(.subheadline)
                    }
                    
                    if let phone = mapItem.phoneNumber {
                        Button(action: {
                            guard let url = URL(string: "tel:\(phone)") else { return }
                            UIApplication.shared.open(url)
                        }) {
                            Label(phone, systemImage: "phone")
                        }
                    }
                    
                    if let url = mapItem.url {
                        Link(destination: url) {
                            Label("Visit Website", systemImage: "safari")
                        }
                    }
                    
                    Button(action: {
                        mapItem.openInMaps()
                    }) {
                        Label("Open in Maps", systemImage: "map")
                    }
                }
            }
            .navigationTitle("Location Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MapView()
} 

