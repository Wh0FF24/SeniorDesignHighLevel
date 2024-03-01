import SwiftUI
import MapKit
import CoreLocation
import CoreMotion

// MARK: - Utility Extensions

extension CLLocationCoordinate2D {
    // Calculate bearing to another point (in radians)
    func bearing(to point: CLLocationCoordinate2D) -> Double {
        let lat1 = self.latitude.toRadians()
        let lon1 = self.longitude.toRadians()
        
        let lat2 = point.latitude.toRadians()
        let lon2 = point.longitude.toRadians()
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        return atan2(y, x)
    }
    
    // Calculate coordinate offset by distance in meters at a bearing (in radians)
    func coordinate(at distance: Double, bearing: Double) -> CLLocationCoordinate2D {
        let earthRadius = 6371000.0  // Earth's radius in meters
        let lat1 = self.latitude.toRadians()
        let lon1 = self.longitude.toRadians()
        
        let dLat = distance * cos(bearing) / earthRadius
        let dLon = distance * sin(bearing) / (earthRadius * cos(lat1 + dLat))
        
        let lat2 = lat1 + dLat
        let lon2 = lon1 + dLon
        
        return CLLocationCoordinate2D(latitude: lat2.toDegrees(), longitude: lon2.toDegrees())
    }
    
    // Shift function for cross slope line
    func shift(by distance: Double, bearing: Double) -> CLLocationCoordinate2D {
        return self.coordinate(at: distance, bearing: bearing)
    }
}

extension Double {
    // Convert degree to radian
    func toRadians() -> Double {
        return self * .pi / 180.0
    }
    
    // Convert radian to degree
    func toDegrees() -> Double {
        return self * 180.0 / .pi
    }
}
// MARK: - Gradient Polylines









// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    var shouldForceCenterUpdate = true
    private var locationManager = CLLocationManager()
    var polylineDataTypes = [MKPolyline: SlopeDataType]()
    var polylineSlopeValues = [MKPolyline: Double]()
    var polylineCrossSlopeValues = [MKPolyline: Double]()

    
    
    struct SlopeLocation {
        let id = UUID()
        var location: CLLocation
        var slope: Double  // % Grade
        var crossSlope: Double  // % Grade
    }
    
    
    @Published var locations: [SlopeLocation] = []
    var motionManager = MotionManager()
    @Published var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    // New properties for filtering
    private let maxWalkingSpeed: Double = 2.5 // Maximum walking speed in m/s
    private let filterSize: Int = 5 // Number of locations to consider for moving average
    private var locationBuffer: [CLLocation] = [] // Buffer to hold last N locations for moving average
    
    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        //self.locationManager.startUpdatingLocation()
    }
    
    @Published var isTracking: Bool = false
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations newLocations: [CLLocation]) {
        guard let newLocation = newLocations.last else { return }
        region.center = newLocation.coordinate
        if isTracking {
            let slopeData = SlopeLocation(location: newLocation,
                                          slope: motionManager.pitchGrade,
                                          crossSlope: motionManager.rollGrade)
            self.locations.append(slopeData)
        }
    }
    
    func addPin(for location: CLLocation) {
        let slopeData = SlopeLocation(location: location,
                                      slope: motionManager.pitchGrade,
                                      crossSlope: motionManager.rollGrade) // Corrected this line
        self.locations.append(slopeData)
    }
    
    func addPolyline(for coordinates: [CLLocationCoordinate2D], withType type: SlopeDataType) {
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        polylineDataTypes[polyline] = type
        // Further processing, like adding the polyline to the map view
    }
}

extension LocationManager.SlopeLocation {
    var color: UIColor {
        switch abs(slope) {
        case 0...5:
            return .green
        case 6...15:
            return .yellow
        default:
            return .red
        }
    }
}

// Map Representation

enum SlopeDataType {
    case slope 
    case crossSlope }


struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var locations: [LocationManager.SlopeLocation]
    var locationManager: LocationManager
    
    
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.showsUserLocation = true
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        updateOverlays(from: uiView)
        uiView.setRegion(region, animated: true)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func shouldAddAnnotation(for currentLocation: CLLocation, from lastLocation: CLLocation) -> Bool {
        let intervalDistance = 7.62
        return currentLocation.distance(from: lastLocation) > intervalDistance
    }
    
    private func updateOverlays(from mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        guard locations.count > 1 else { return }
        
    //    let offsetDistance = 5.0
        var lastPinLocation = locations.first!.location
        
        for i in 1..<locations.count {
            let previousLocation = locations[i-1]
            let currentLocation = locations[i]
            
            if shouldAddAnnotation(for: currentLocation.location, from: lastPinLocation) {
                mapView.addAnnotation(MKPointAnnotation(__coordinate: currentLocation.location.coordinate))
                lastPinLocation = currentLocation.location
                
                let bearing = previousLocation.location.coordinate.bearing(to: currentLocation.location.coordinate)
                let leftBearing = bearing - .pi / 2
                let rightBearing = bearing + .pi / 2
                
                let coordinates = [previousLocation.location.coordinate, currentLocation.location.coordinate]
                addGradientPolyline(to: mapView, coordinates: coordinates, leftBearing: leftBearing, rightBearing: rightBearing, slope: currentLocation.slope, crossSlope: currentLocation.crossSlope)
            }
        }
    }
    
    private func addGradientPolyline(to mapView: MKMapView, coordinates: [CLLocationCoordinate2D], leftBearing: Double, rightBearing: Double, slope: Double, crossSlope: Double) {
        let leftCoordinates = coordinates.map { $0.shift(by: 5.0, bearing: leftBearing) }
        let rightCoordinates = coordinates.map { $0.shift(by: 5.0, bearing: rightBearing) }
        
        let leftPolyline = MKPolyline(coordinates: leftCoordinates, count: leftCoordinates.count)
        let rightPolyline = MKPolyline(coordinates: rightCoordinates, count: rightCoordinates.count)
        
        self.locationManager.polylineDataTypes[leftPolyline] = .slope
        self.locationManager.polylineDataTypes[rightPolyline] = .crossSlope
        
        mapView.addOverlay(leftPolyline)
        mapView.addOverlay(rightPolyline)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "location"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline, let dataType = parent.polylineDataTypes[polyline] {
                let gradientColors: [UIColor] = dataType == .slope ? GradientPolylineRenderer.gradientColorsForSlope(slope: polyline.slopeValue) : GradientPolylineRenderer.gradientColorsForCrossSlope(crossSlope: polyline.crossSlopeValue)
                
                let renderer = GradientPolylineRenderer(polyline: polyline, gradientColors: gradientColors)
                renderer.lineWidth = 5
                return renderer
            }
            
            return MKOverlayRenderer()
        }
    }
}
    
    // Move MapTrailView out of MapViewRepresentable
    struct MapTrailView: View {
        @ObservedObject var locationData: LocationManager = LocationManager()
        
        var body: some View {
            VStack {
                
                MapViewRepresentable(region: $locationData.region, locations: locationData.locations, locationManager: locationData)
                Button(action: {
                    locationData.isTracking.toggle()
                    
                    if locationData.isTracking {  // Just started tracking
                        // We only start updates when tracking starts
                        locationData.startLocationUpdates()
                        if let currentLocation = locationData.locations.last?.location {
                            locationData.addPin(for: currentLocation)
                        }
                    } else {  // Just stopped tracking
                        // We stop updates when tracking stops
                        locationData.stopLocationUpdates()
                        if let currentLocation = locationData.locations.last?.location {
                            locationData.addPin(for: currentLocation)
                        }
                        locationData.stopLocationUpdates()
                        locationData.saveTrailDataAsCSV()  // Save the trail data as CSV here
                        
                    }
                }) {
                    Text(locationData.isTracking ? "Stop Tracking" : "Start Tracking")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.bottom, 8)
                
                Button(action: {
                    locationData.addCurrentLocationPin()
                }) {
                    Text("Drop Pin")
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.bottom, 16)
            }
        }
    }
    
extension LocationManager {
    func addCurrentLocationPin() {
        if let currentLocation = self.locations.last?.location {
            self.addPin(for: currentLocation)
        }
    }
}
    
    
    // MARK: - Additional Classes
    
    class ColoredPolyline: MKPolyline {
        var color: UIColor?
        
        convenience init(coordinates: UnsafePointer<CLLocationCoordinate2D>, count: Int, color: UIColor) {
            self.init(coordinates: coordinates, count: count)
            self.color = color
        }
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        // This function is for providing a view for a given annotation
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "location"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            return annotationView
        }
        
        // This function is for rendering overlays (like your polyline)
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? ColoredPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = polyline.color
                renderer.lineWidth = 5
                return renderer
            }
            return MKOverlayRenderer()
        }
        
       
        
    }
    
    // MARK: - LocationManager Control Functions
    
    extension LocationManager {
        func saveTrailDataAsCSV() {
            // Define the header for the CSV file
            var csvString = "Timestamp, Latitude, Longitude, Slope, Cross Slope\n"
            
            // Loop through locations and append each one as a line in the CSV string
            for location in locations {
                let timestamp = location.location.timestamp
                let latitude = location.location.coordinate.latitude
                let longitude = location.location.coordinate.longitude
                let slope = location.slope
                let crossSlope = location.crossSlope
                
                // Create a line for the current location
                let line = "\(timestamp), \(latitude), \(longitude), \(slope), \(crossSlope)\n"
                
                // Append the line to the CSV string
                csvString.append(contentsOf: line)
            }
            
            // Get the path to the documents directory and define the file name
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let savePath = documentsDirectory.appendingPathComponent("trailData.csv")
            
            // Write the CSV string to a file at the save path
            do {
                try csvString.write(to: savePath, atomically: true, encoding: .utf8)
                print("Trail data saved as CSV to: \(savePath)")
            } catch {
                print("Failed to save trail data as CSV: \(error.localizedDescription)")
            }
        }
        func startLocationUpdates() {
            locationManager.startUpdatingLocation()
        }
        
        func stopLocationUpdates() {
            locationManager.stopUpdatingLocation()
        }
        
    }

