import UIKit
import MapKit
import CoreLocation

class MapViewController: UIViewController {
    
    private let mapView = MKMapView()
    private let locationManager = CLLocationManager()
    private let searchBar = UISearchBar()
    private let filterButton = UIButton(type: .system)
    private let listToggleButton = UIButton(type: .system)
    private let currentLocationButton = UIButton(type: .system)
    
    private var properties: [Property] = []
    private var selectedProperty: Property?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupLocationManager()
        loadProperties()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Property Map"
        
        // Configure map view
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)
        
        // Configure search bar
        searchBar.placeholder = "Search area or address"
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)
        
        // Configure filter button
        filterButton.setTitle("Filters", for: .normal)
        filterButton.setImage(UIImage(systemName: "slider.horizontal.3"), for: .normal)
        filterButton.backgroundColor = .systemBackground
        filterButton.layer.cornerRadius = 20
        filterButton.layer.shadowColor = UIColor.black.cgColor
        filterButton.layer.shadowOpacity = 0.1
        filterButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        filterButton.layer.shadowRadius = 4
        filterButton.addTarget(self, action: #selector(filterTapped), for: .touchUpInside)
        filterButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterButton)
        
        // Configure list toggle button
        listToggleButton.setTitle("List", for: .normal)
        listToggleButton.setImage(UIImage(systemName: "list.bullet"), for: .normal)
        listToggleButton.backgroundColor = .systemBackground
        listToggleButton.layer.cornerRadius = 20
        listToggleButton.layer.shadowColor = UIColor.black.cgColor
        listToggleButton.layer.shadowOpacity = 0.1
        listToggleButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        listToggleButton.layer.shadowRadius = 4
        listToggleButton.addTarget(self, action: #selector(listToggleTapped), for: .touchUpInside)
        listToggleButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(listToggleButton)
        
        // Configure current location button
        currentLocationButton.setImage(UIImage(systemName: "location.fill"), for: .normal)
        currentLocationButton.backgroundColor = .systemBackground
        currentLocationButton.tintColor = Theme.Colors.primary
        currentLocationButton.layer.cornerRadius = 25
        currentLocationButton.layer.shadowColor = UIColor.black.cgColor
        currentLocationButton.layer.shadowOpacity = 0.1
        currentLocationButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        currentLocationButton.layer.shadowRadius = 4
        currentLocationButton.addTarget(self, action: #selector(currentLocationTapped), for: .touchUpInside)
        currentLocationButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(currentLocationButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            mapView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            filterButton.topAnchor.constraint(equalTo: mapView.topAnchor, constant: 16),
            filterButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            filterButton.widthAnchor.constraint(equalToConstant: 80),
            filterButton.heightAnchor.constraint(equalToConstant: 40),
            
            listToggleButton.topAnchor.constraint(equalTo: mapView.topAnchor, constant: 16),
            listToggleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            listToggleButton.widthAnchor.constraint(equalToConstant: 70),
            listToggleButton.heightAnchor.constraint(equalToConstant: 40),
            
            currentLocationButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            currentLocationButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            currentLocationButton.widthAnchor.constraint(equalToConstant: 50),
            currentLocationButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func loadProperties() {
        APIService.shared.fetchProperties { [weak self] result in
            switch result {
            case .success(let properties):
                self?.properties = properties
                self?.addPropertyAnnotations()
            case .failure(let error):
                print("Error loading properties: \(error)")
                self?.loadSampleProperties()
            }
        }
    }
    
    private func loadSampleProperties() {
        let sampleProperty1 = Property(
            id: "1",
            title: "Downtown Apartment",
            description: "Modern apartment in the city center",
            address: "123 Main Street",
            city: "New York",
            state: "NY",
            zipCode: "10001",
            price: 2500.0,
            bedrooms: 2,
            bathrooms: 2,
            sqft: 1200,
            propertyType: "Apartment",
            images: ["https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=400&h=250&fit=crop"],
            amenities: ["Parking", "Gym"],
            latitude: 40.7128,
            longitude: -74.0060,
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z",
            isFavorite: false
        )
        
        let sampleProperty2 = Property(
            id: "2",
            title: "Brooklyn Loft",
            description: "Spacious loft in trendy Brooklyn",
            address: "456 Brooklyn Ave",
            city: "Brooklyn",
            state: "NY",
            zipCode: "11201",
            price: 3000.0,
            bedrooms: 3,
            bathrooms: 2,
            sqft: 1500,
            propertyType: "Loft",
            images: ["https://images.unsplash.com/photo-1560449752-c40dfffbdab9?w=400&h=250&fit=crop"],
            amenities: ["Parking", "Rooftop"],
            latitude: 40.6892,
            longitude: -73.9442,
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z",
            isFavorite: false
        )
        
        properties = [sampleProperty1, sampleProperty2]
        addPropertyAnnotations()
    }
    
    private func addPropertyAnnotations() {
        // Remove existing annotations
        mapView.removeAnnotations(mapView.annotations)
        
        // Add property annotations
        for property in properties {
            if let latitude = property.latitude, let longitude = property.longitude {
                let annotation = PropertyAnnotation(property: property)
                mapView.addAnnotation(annotation)
            }
        }
        
        // Set initial region if we have properties
        if let firstProperty = properties.first,
           let latitude = firstProperty.latitude,
           let longitude = firstProperty.longitude {
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            mapView.setRegion(region, animated: true)
        }
    }
    
    @objc private func filterTapped() {
        let filterVC = FilterViewController()
        filterVC.delegate = self
        let navController = UINavigationController(rootViewController: filterVC)
        present(navController, animated: true)
    }
    
    @objc private func listToggleTapped() {
        let searchVC = SearchViewController()
        navigationController?.pushViewController(searchVC, animated: true)
    }
    
    @objc private func currentLocationTapped() {
        if let userLocation = locationManager.location {
            let region = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            mapView.setRegion(region, animated: true)
        } else {
            locationManager.requestLocation()
        }
    }
}

// MARK: - MKMapViewDelegate
extension MapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let propertyAnnotation = annotation as? PropertyAnnotation else {
            return nil
        }
        
        let identifier = "PropertyAnnotation"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        
        if annotationView == nil {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
            annotationView?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        } else {
            annotationView?.annotation = annotation
        }
        
        // Create custom pin view
        let pinView = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 50))
        pinView.backgroundColor = .clear
        
        let priceLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 40, height: 30))
        priceLabel.text = "$\(Int(propertyAnnotation.property.price))"
        priceLabel.font = .systemFont(ofSize: 12, weight: .bold)
        priceLabel.textColor = .white
        priceLabel.backgroundColor = Theme.Colors.primary
        priceLabel.textAlignment = .center
        priceLabel.layer.cornerRadius = 15
        priceLabel.clipsToBounds = true
        pinView.addSubview(priceLabel)
        
        let pinImageView = UIImageView(frame: CGRect(x: 15, y: 25, width: 10, height: 15))
        pinImageView.image = UIImage(systemName: "arrowtriangle.down.fill")
        pinImageView.tintColor = Theme.Colors.primary
        pinView.addSubview(pinImageView)
        
        annotationView?.addSubview(pinView)
        annotationView?.frame = pinView.frame
        
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        guard let propertyAnnotation = view.annotation as? PropertyAnnotation else { return }
        
        let detailVC = PropertyDetailViewController()
        detailVC.property = propertyAnnotation.property
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - CLLocationManagerDelegate
extension MapViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            let region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            mapView.setRegion(region, animated: true)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            // Show alert about location access
            break
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
}

// MARK: - UISearchBarDelegate
extension MapViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Implement search functionality
        guard !searchText.isEmpty else { return }
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(searchText) { [weak self] placemarks, error in
            if let placemark = placemarks?.first,
               let location = placemark.location {
                let region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                self?.mapView.setRegion(region, animated: true)
            }
        }
    }
}

// MARK: - FilterViewControllerDelegate
extension MapViewController: FilterViewControllerDelegate {
    func didApplyFilters(_ filters: [String: Any]) {
        // Apply filters to map properties
        print("Applied filters to map: \(filters)")
        // Reload properties with filters
        loadProperties()
    }
}

// MARK: - Property Annotation
class PropertyAnnotation: NSObject, MKAnnotation {
    let property: Property
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(
            latitude: property.latitude ?? 0,
            longitude: property.longitude ?? 0
        )
    }
    
    var title: String? {
        return property.title
    }
    
    var subtitle: String? {
        return "$\(Int(property.price))/month"
    }
    
    init(property: Property) {
        self.property = property
    }
}