import SwiftUI
import MapKit
import CoreLocation

struct IdentifiableMapMarker: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct MapView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    )
    
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedItem: MKMapItem?
    @State private var showingDetail = false
    @State private var showingLocationPermissionAlert = false
    @State private var showingSustainableFoodSources = false
    @State private var mapAnnotations: [IdentifiableMapMarker] = []
    @State private var scrollOffset: CGFloat = 0
    @State private var shouldUpdateMapCenter = true
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: mapAnnotations) { annotation in
                MapMarker(coordinate: annotation.coordinate, tint: .green)
            }
            .edgesIgnoringSafeArea(.top)
            .onAppear {
                checkLocationPermission()
            }
            .onChange(of: locationManager.location) { oldLocation, newLocation in
                if let location = newLocation, shouldUpdateMapCenter {
                    region.center = location.coordinate
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { _ in
                        shouldUpdateMapCenter = false
                    }
            )
            
            VStack {
                HStack {
                    TextField("Search for a location", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: searchText) { newValue in
                            searchLocations(query: newValue)
                        }
                    
                    Button(action: {
                        showingSustainableFoodSources = true
                        searchSustainableFoodSources()
                    }) {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                if !searchResults.isEmpty {
                    ScrollView {
                        GeometryReader { geometry in
                            Color.clear.preference(key: ScrollOffsetPreferenceKey.self,
                                value: geometry.frame(in: .named("scroll")).minY)
                        }
                        .frame(height: 0)
                        
                        LazyVStack(spacing: 0) {
                            ForEach(searchResults, id: \.self) { item in
                                Button(action: {
                                    selectedItem = item
                                    showingDetail = true
                                    shouldUpdateMapCenter = false
                                    region.center = item.placemark.coordinate
                                }) {
                                    VStack(alignment: .leading) {
                                        Text(item.name ?? "Unknown Location")
                                            .font(.headline)
                                        Text(item.placemark.title ?? "")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color(.systemBackground))
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if item != searchResults.last {
                                    Divider()
                                }
                            }
                        }
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        scrollOffset = value
                    }
                    .frame(maxHeight: 300)
                    .background(Color(.systemBackground))
                    .offset(y: -scrollOffset)
                }
            }
            .background(Color(.systemBackground))
        }
        .alert("Location Access Required", isPresented: $showingLocationPermissionAlert) {
            Button("Settings", role: .none) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable location access in Settings to use this feature.")
        }
        .sheet(isPresented: $showingDetail) {
            if let item = selectedItem {
                LocationDetailView(mapItem: item)
            }
        }
    }
    
    private func checkLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestLocation()
        case .restricted, .denied:
            showingLocationPermissionAlert = true
        case .authorizedWhenInUse, .authorizedAlways:
            if let location = locationManager.location {
                region.center = location.coordinate
            }
        @unknown default:
            break
        }
    }
    
    private func searchLocations(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            mapAnnotations = []
            return
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response else {
                print("Error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                searchResults = response.mapItems
                updateMapAnnotations(with: response.mapItems)
            }
        }
    }
    
    private func searchSustainableFoodSources() {
        guard let location = locationManager.location else { return }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "sustainable food market organic grocery"
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response else {
                print("Error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                searchResults = response.mapItems
                updateMapAnnotations(with: response.mapItems)
            }
        }
    }
    
    private func updateMapAnnotations(with items: [MKMapItem]) {
        mapAnnotations = items.map { item in
            IdentifiableMapMarker(coordinate: item.placemark.coordinate)
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    
    override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
        locationManager.startUpdatingLocation()
    }
    
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.location = location
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}

struct LocationDetailView: View {
    let mapItem: MKMapItem
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text(mapItem.name ?? "Unknown Location")
                    .font(.title)
                    .bold()
                
                Text(mapItem.placemark.title ?? "")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                if let phone = mapItem.phoneNumber {
                    Text("Phone: \(phone)")
                        .font(.subheadline)
                }
                
                if let url = mapItem.url {
                    Link("Website", destination: url)
                        .font(.subheadline)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

#Preview {
    MapView()
} 