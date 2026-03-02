//
//  ContentView.swift
//  CurbyiOS
//
//  Created by Isaiah Hinds on 1/5/26.
//

import SwiftUI
import SwiftData
import CoreLocation
import Combine
import MapboxMaps
import MapKit

// MARK: - Auth

@MainActor
final class AuthManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var username: String = "demo_user"
    @Published var email: String = ""
    @Published var displayName: String = ""
    @Published var deviceId: String = ""
    @Published var isAuthenticating: Bool = false
    @Published var authError: String?

    func login(usernameOrEmail: String, password: String) async {
        let credential = usernameOrEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !credential.isEmpty, !password.isEmpty else {
            authError = "Enter username/email and password."
            return
        }

        isAuthenticating = true
        authError = nil

        do {
            let response = try await APIClient.shared.login(
                usernameOrEmail: credential,
                password: password
            )

            username = response.username.isEmpty ? credential : response.username
            email = response.email
            displayName = response.displayName
            deviceId = response.deviceId
            isLoggedIn = true
        } catch {
            isLoggedIn = false
            authError = error.localizedDescription
        }

        isAuthenticating = false
    }

    func register(
        email: String,
        password: String,
        username: String? = nil,
        displayName: String? = nil,
        deviceId: String? = nil
    ) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty, !password.isEmpty else {
            authError = "Enter email and password."
            return
        }

        isAuthenticating = true
        authError = nil

        do {
            let response = try await APIClient.shared.register(
                email: normalizedEmail,
                password: password,
                username: username?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                displayName: displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                deviceId: deviceId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )

            self.username = response.username
            self.email = response.email
            self.displayName = response.displayName
            self.deviceId = response.deviceId
            isLoggedIn = true
        } catch {
            isLoggedIn = false
            authError = error.localizedDescription
        }

        isAuthenticating = false
    }

    func logout() {
        isAuthenticating = false
        authError = nil
        isLoggedIn = false
    }
}

// MARK: - Location

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var lastCoordinate: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func request() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastCoordinate = locations.last?.coordinate
    }
}

// MARK: - Root

struct ContentView: View {
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        Group {
            if auth.isLoggedIn {
                MapHomeView()
            } else {
                LoginView()
            }
        }
    }
}

// MARK: - Login

struct LoginView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var usernameOrEmail: String = ""
    @State private var password: String = ""
    @State private var showingCreateAccount = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Spacer()

                Image(systemName: "car.fill")
                    .font(.system(size: 56))
                    .padding(.bottom, 6)

                Text("Curby")
                    .font(.largeTitle.bold())

                VStack(alignment: .leading, spacing: 8) {
                    Text("Username or Email")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    TextField("username or email", text: $usernameOrEmail)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(12)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    SecureField("password", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(12)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 18)
                .padding(.horizontal)

                Button {
                    Task {
                        await auth.login(
                            usernameOrEmail: usernameOrEmail,
                            password: password
                        )
                    }
                } label: {
                    if auth.isAuthenticating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Text("Log In")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .disabled(
                    auth.isAuthenticating ||
                    usernameOrEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    password.isEmpty
                )
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                Button("Create Account") {
                    showingCreateAccount = true
                }
                .disabled(auth.isAuthenticating)
                .padding(.top, 2)

                if let authError = auth.authError, !authError.isEmpty {
                    Text(authError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
            .sheet(isPresented: $showingCreateAccount) {
                CreateAccountView()
            }
        }
    }
}

private struct CreateAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var displayName = ""
    @State private var deviceId = ""
    @State private var localError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Credentials") {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.emailAddress)
                    SecureField("Password", text: $password)
                    SecureField("Confirm Password", text: $confirmPassword)
                }

                Section("Profile (optional)") {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    TextField("Display Name", text: $displayName)
                    TextField("Device ID", text: $deviceId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }

                if let localError {
                    Section {
                        Text(localError)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                Section {
                    Button {
                        createAccount()
                    } label: {
                        if auth.isAuthenticating {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Create Account")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(auth.isAuthenticating)
                }
            }
            .navigationTitle("Create Account")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func createAccount() {
        localError = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else {
            localError = "Email is required."
            return
        }
        guard !password.isEmpty else {
            localError = "Password is required."
            return
        }
        guard password == confirmPassword else {
            localError = "Passwords do not match."
            return
        }

        Task {
            await auth.register(
                email: trimmedEmail,
                password: password,
                username: username,
                displayName: displayName,
                deviceId: deviceId
            )
            if auth.isLoggedIn {
                await MainActor.run { dismiss() }
            } else if localError == nil {
                await MainActor.run {
                    localError = auth.authError
                }
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

// MARK: - Map Home

struct MapHomeView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var hazards: [HazardDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedCluster: [HazardDTO] = []
    @State private var hasUserMovedMap = false

    @StateObject private var location = LocationManager()

    private static let defaultCenter = CLLocationCoordinate2D(latitude: 32.5299, longitude: -92.6379)
    @State private var suggestedCoordinate: CLLocationCoordinate2D = MapHomeView.defaultCenter

    @State private var showingAddHazard = false
    @State private var showingProfile = false
    @State private var showingTripPlanner = false
    @State private var addHazardInitialCoordinate: CLLocationCoordinate2D?

    /// Auto-refresh every 15 seconds to pick up new camera detections.
    private let refreshTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .bottom) {

            MapboxMapView(
                hazards: hazards,
                center: suggestedCoordinate,
                onClusterTap: { hazards in
                    selectedCluster = hazards
                },
                onCenterChanged: { center in
                    suggestedCoordinate = center
                    hasUserMovedMap = true
                }
            )
                .onAppear { location.request() }
                .onReceive(location.$lastCoordinate) { newCoord in
                    guard let c = newCoord else { return }
                    if !hasUserMovedMap {
                        suggestedCoordinate = c
                    }
                }
                .ignoresSafeArea()

            if !selectedCluster.isEmpty {
                clusterDropdown
            }

            bottomBar
        }
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hazards: \(hazards.count)")
                    .font(.caption)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(8)
        }
        .task {
            await loadHazards()
        }
        .onReceive(refreshTimer) { _ in
            Task { await loadHazards() }
        }
        .sheet(isPresented: $showingAddHazard, onDismiss: {
            addHazardInitialCoordinate = nil
            Task { await loadHazards() }
        }) {
            if let addHazardInitialCoordinate {
                AddHazardView(
                    suggestedCoordinate: addHazardInitialCoordinate,
                    onCreated: { hazard in
                        upsertHazard(hazard)
                        suggestedCoordinate = CLLocationCoordinate2D(
                            latitude: hazard.latitude,
                            longitude: hazard.longitude
                        )
                        hasUserMovedMap = true
                        selectedCluster = clusterFor(hazard)
                    }
                )
            } else {
                ProgressView("Getting current location…")
                    .padding()
            }
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView(
                onHazardDeleted: { deletedId in
                    removeHazard(withId: deletedId)
                }
            )
        }
        .sheet(isPresented: $showingTripPlanner) {
            TripPlannerView(
                hazards: hazards,
                startCoordinate: location.lastCoordinate ?? suggestedCoordinate
            )
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 16) {
            Button {
                showingProfile = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle")
                    Text("Profile")
                        .font(.headline)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.bordered)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Spacer()

            Button {
                showingTripPlanner = true
            } label: {
                Image(systemName: "location.north.line.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .clipShape(Circle())

            Button {
                guard let current = location.lastCoordinate else {
                    errorMessage = "Current location unavailable. Check location permission and try again."
                    return
                }
                addHazardInitialCoordinate = current
                showingAddHazard = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Circle())
            .disabled(location.lastCoordinate == nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .shadow(radius: 10)
    }

    private var clusterDropdown: some View {
        let coordText = selectedCluster.first.map {
            String(format: "%.6f, %.6f", $0.latitude, $0.longitude)
        } ?? ""

        return VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hazards at this spot (\(selectedCluster.count))")
                        .font(.headline)
                    if !coordText.isEmpty {
                        Text(coordText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                    .font(.headline)
                Spacer()
                Button {
                    selectedCluster = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(selectedCluster) { h in
                        ClusterHazardRow(hazard: h)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 14)
        .padding(.bottom, 90)
        .shadow(radius: 10)
    }

    @MainActor
    private func loadHazards() async {
        let isInitial = hazards.isEmpty
        if isInitial { isLoading = true }
        defer { if isInitial { isLoading = false } }

        do {
            hazards = try await APIClient.shared.getHazards()
            errorMessage = nil
        } catch {
            if hazards.isEmpty {
                errorMessage = "Failed to load: \(error.localizedDescription)"
            }
            print("Failed to load hazards:", error)
        }
    }

    private func upsertHazard(_ hazard: HazardDTO) {
        if let idx = hazards.firstIndex(where: { $0.id == hazard.id }) {
            hazards[idx] = hazard
        } else {
            hazards.append(hazard)
        }
    }

    private func removeHazard(withId id: String) {
        hazards.removeAll { $0.id == id }
        selectedCluster.removeAll { $0.id == id }
    }

    private func clusterFor(_ hazard: HazardDTO) -> [HazardDTO] {
        let key = String(format: "%.6f,%.6f", hazard.latitude, hazard.longitude)
        return hazards.filter {
            String(format: "%.6f,%.6f", $0.latitude, $0.longitude) == key
        }
    }
}

// MARK: - Trip Planner

private struct TripPlannerView: View {
    @Environment(\.dismiss) private var dismiss

    let hazards: [HazardDTO]
    let startCoordinate: CLLocationCoordinate2D

    @StateObject private var searchCompleter = TripSearchCompleter()
    @State private var destinationQuery = ""
    @State private var planningError: String?
    @State private var isComputingRoute = false
    @State private var routePlan: SaferRoutePlan?
    @State private var selectedCompletion: MKLocalSearchCompletion?

    var body: some View {
        NavigationStack {
            Form {
                Section("Destination") {
                    TextField("Where are you going?", text: $destinationQuery)
                        .textInputAutocapitalization(.words)
                    Button("Find Safer Route") {
                        Task { await buildSaferRoute(using: selectedCompletion) }
                    }
                    .disabled(destinationQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isComputingRoute)
                }

                if !searchCompleter.completions.isEmpty {
                    Section("Suggestions") {
                        ForEach(Array(searchCompleter.completions.enumerated()), id: \.offset) { _, completion in
                            Button {
                                selectedCompletion = completion
                                destinationQuery = completion.subtitle.isEmpty
                                    ? completion.title
                                    : "\(completion.title), \(completion.subtitle)"
                                Task { await buildSaferRoute(using: completion) }
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(completion.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    if !completion.subtitle.isEmpty {
                                        Text(completion.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if isComputingRoute {
                    Section {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Evaluating route options...")
                                .font(.subheadline)
                        }
                    }
                }

                if let planningError {
                    Section {
                        Text(planningError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if let routePlan {
                    Section("Safer Route") {
                        Text(routePlan.destinationName)
                            .font(.headline)
                        Text("Compared \(routePlan.alternativesEvaluated) route option(s) and chose the safest.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        SaferRouteMapView(route: routePlan.route)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        HStack {
                            Label(distanceText(for: routePlan.route.distance), systemImage: "ruler")
                            Spacer()
                            Label(durationText(for: routePlan.route.expectedTravelTime), systemImage: "clock")
                        }
                        .font(.subheadline)

                        let hits = routePlan.hazardScore.hazardHits
                        Text(hits == 0 ? "No known hazards detected near this route." : "\(hits) known hazard(s) are near this route.")
                            .font(.footnote)
                            .foregroundStyle(hits == 0 ? .green : .orange)

                        Button("Start Trip in Apple Maps") {
                            openInMaps(routePlan)
                        }
                    }
                }
            }
            .navigationTitle("Plan Trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                searchCompleter.update(query: destinationQuery, near: startCoordinate)
            }
            .onChange(of: destinationQuery) { newValue in
                selectedCompletion = nil
                searchCompleter.update(query: newValue, near: startCoordinate)
            }
        }
    }

    @MainActor
    private func buildSaferRoute(using completion: MKLocalSearchCompletion?) async {
        planningError = nil
        routePlan = nil
        isComputingRoute = true
        defer { isComputingRoute = false }

        let trimmed = destinationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            let destination: MKMapItem
            if let completion {
                let completionRequest = MKLocalSearch.Request(completion: completion)
                completionRequest.resultTypes = [.address, .pointOfInterest]
                let completionResponse = try await MKLocalSearch(request: completionRequest).start()
                guard let match = completionResponse.mapItems.first else {
                    planningError = "No destination match found."
                    return
                }
                destination = match
            } else {
                let searchRequest = MKLocalSearch.Request()
                searchRequest.naturalLanguageQuery = trimmed
                searchRequest.resultTypes = [.address, .pointOfInterest]
                searchRequest.region = MKCoordinateRegion(
                    center: startCoordinate,
                    latitudinalMeters: 45_000,
                    longitudinalMeters: 45_000
                )

                let searchResponse = try await MKLocalSearch(request: searchRequest).start()
                guard let match = searchResponse.mapItems.first else {
                    planningError = "No destination match found."
                    return
                }
                destination = match
            }

            let source = MKMapItem(placemark: MKPlacemark(coordinate: startCoordinate))
            let request = MKDirections.Request()
            request.source = source
            request.destination = destination
            request.transportType = .automobile
            request.requestsAlternateRoutes = true

            let directionsResponse = try await MKDirections(request: request).calculate()
            guard !directionsResponse.routes.isEmpty else {
                planningError = "No drivable route found."
                return
            }

            let ranked = directionsResponse.routes
                .map { route in
                    (route: route, score: score(route: route))
                }
                .sorted {
                    if $0.score.riskScore == $1.score.riskScore {
                        return $0.route.expectedTravelTime < $1.route.expectedTravelTime
                    }
                    return $0.score.riskScore < $1.score.riskScore
                }

            guard let best = ranked.first else {
                planningError = "Could not evaluate routes."
                return
            }

            routePlan = SaferRoutePlan(
                destinationMapItem: destination,
                destinationName: destination.name ?? trimmed,
                route: best.route,
                hazardScore: best.score,
                alternativesEvaluated: ranked.count
            )
        } catch {
            planningError = "Trip planning failed: \(error.localizedDescription)"
        }
    }

    private func score(route: MKRoute) -> RouteHazardScore {
        let thresholdMeters: CLLocationDistance = 80
        var riskScore = 0.0
        var hits = 0
        var closestHazard: CLLocationDistance?

        for hazard in hazards {
            let coord = CLLocationCoordinate2D(latitude: hazard.latitude, longitude: hazard.longitude)
            let distance = route.polyline.minimumDistance(to: coord)
            guard distance <= thresholdMeters else { continue }

            hits += 1
            let severityWeight = Double(max(1, hazard.severity))
            let proximityWeight = max(0.2, 1 - (distance / thresholdMeters))
            riskScore += severityWeight * proximityWeight
            if closestHazard == nil || distance < closestHazard! {
                closestHazard = distance
            }
        }

        return RouteHazardScore(
            riskScore: riskScore,
            hazardHits: hits,
            closestHazardMeters: closestHazard
        )
    }

    private func openInMaps(_ routePlan: SaferRoutePlan) {
        let source = MKMapItem(placemark: MKPlacemark(coordinate: startCoordinate))
        MKMapItem.openMaps(
            with: [source, routePlan.destinationMapItem],
            launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ]
        )
    }

    private func distanceText(for meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters.rounded())) m"
    }

    private func durationText(for seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: seconds) ?? "--"
    }
}

private struct SaferRoutePlan {
    let destinationMapItem: MKMapItem
    let destinationName: String
    let route: MKRoute
    let hazardScore: RouteHazardScore
    let alternativesEvaluated: Int
}

@MainActor
private final class TripSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var completions: [MKLocalSearchCompletion] = []

    private let completer: MKLocalSearchCompleter = {
        let value = MKLocalSearchCompleter()
        value.resultTypes = [.address, .pointOfInterest]
        return value
    }()

    override init() {
        super.init()
        completer.delegate = self
    }

    func update(query: String, near coordinate: CLLocationCoordinate2D) {
        completer.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 60_000,
            longitudinalMeters: 60_000
        )
        completer.queryFragment = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            completions = []
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        completions = []
    }
}

private struct RouteHazardScore {
    let riskScore: Double
    let hazardHits: Int
    let closestHazardMeters: CLLocationDistance?
}

private struct SaferRouteMapView: UIViewRepresentable {
    let route: MKRoute

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.showsScale = false
        mapView.pointOfInterestFilter = .excludingAll
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        mapView.addOverlay(route.polyline)
        let startAnnotation = MKPointAnnotation()
        startAnnotation.coordinate = route.polyline.firstCoordinate
        startAnnotation.title = "Start"

        let endAnnotation = MKPointAnnotation()
        endAnnotation.coordinate = route.polyline.lastCoordinate
        endAnnotation.title = "Destination"

        mapView.addAnnotations([startAnnotation, endAnnotation])
        mapView.setVisibleMapRect(
            route.polyline.boundingMapRect,
            edgePadding: UIEdgeInsets(top: 28, left: 20, bottom: 28, right: 20),
            animated: false
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.systemBlue
            renderer.lineWidth = 6
            renderer.alpha = 0.9
            return renderer
        }
    }
}

private extension MKPolyline {
    var firstCoordinate: CLLocationCoordinate2D {
        points()[0].coordinate
    }

    var lastCoordinate: CLLocationCoordinate2D {
        points()[pointCount - 1].coordinate
    }

    func minimumDistance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        guard pointCount > 0 else { return .greatestFiniteMagnitude }
        let target = MKMapPoint(coordinate)
        let metersPerMapPoint = MKMetersPerMapPointAtLatitude(coordinate.latitude)
        let pts = points()

        if pointCount == 1 {
            let dx = target.x - pts[0].x
            let dy = target.y - pts[0].y
            return hypot(dx, dy) * metersPerMapPoint
        }

        var minDistance = CLLocationDistance.greatestFiniteMagnitude
        for i in 0..<(pointCount - 1) {
            let segmentDistance = distanceFromMapPoint(
                target,
                segmentStart: pts[i],
                segmentEnd: pts[i + 1],
                metersPerMapPoint: metersPerMapPoint
            )
            if segmentDistance < minDistance {
                minDistance = segmentDistance
            }
        }
        return minDistance
    }

    private func distanceFromMapPoint(
        _ point: MKMapPoint,
        segmentStart: MKMapPoint,
        segmentEnd: MKMapPoint,
        metersPerMapPoint: Double
    ) -> CLLocationDistance {
        let dx = segmentEnd.x - segmentStart.x
        let dy = segmentEnd.y - segmentStart.y

        if dx == 0 && dy == 0 {
            return hypot(point.x - segmentStart.x, point.y - segmentStart.y) * metersPerMapPoint
        }

        let projection = ((point.x - segmentStart.x) * dx + (point.y - segmentStart.y) * dy) / (dx * dx + dy * dy)
        let t = max(0.0, min(1.0, projection))
        let nearestX = segmentStart.x + (t * dx)
        let nearestY = segmentStart.y + (t * dy)
        return hypot(point.x - nearestX, point.y - nearestY) * metersPerMapPoint
    }
}

// MARK: - Pin UI (used outside the map, e.g. list cells)

private struct ClusterHazardRow: View {
    let hazard: HazardDTO

    private var hazardType: HazardType { HazardType.from(hazard.type) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: hazardType.symbol)
                .font(.system(size: 18))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(hazard.type)
                    .font(.subheadline.bold())
                HStack(spacing: 6) {
                    Text("Sev \(hazard.severity)")
                    Text("•")
                    Text(hazard.source)
                    if hazard.confidence > 0 {
                        Text("•")
                        Text("\(Int(hazard.confidence * 100))%")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(hazardType.rawValue)
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(severityColor(hazard.severity).opacity(0.2))
                .foregroundStyle(severityColor(hazard.severity))
                .clipShape(Capsule())
        }
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func severityColor(_ severity: Int) -> Color {
        switch severity {
        case 5: return .red
        case 4: return .orange
        case 3: return .yellow
        default: return .gray
        }
    }
}

struct HazardPin: View {
    let type: String
    let source: String

    private var hazardType: HazardType { HazardType.from(type) }

    private var tint: Color {
        let s = source.lowercased()
        if s.contains("camera") || s.contains("dashcam") || s.contains("segmentation") {
            return .blue
        }
        return .orange
    }

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: hazardType.symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .padding(8)
                .background(tint)
                .clipShape(Circle())

            Text(type.replacingOccurrences(of: "_", with: " "))
                .font(.caption2)
                .foregroundStyle(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.thinMaterial)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Add Hazard

private struct HazardPlacementMapView: UIViewRepresentable {
    @Binding var coordinate: CLLocationCoordinate2D
    let hazardType: HazardType

    func makeUIView(context: Context) -> MapView {
        let camera = CameraOptions(center: coordinate, zoom: 15)
        let mapView = MapView(frame: .zero, mapInitOptions: MapInitOptions(cameraOptions: camera))
        mapView.ornaments.options.compass.visibility = .hidden
        mapView.ornaments.options.scaleBar.visibility = .hidden

        context.coordinator.parent = self
        context.coordinator.mapView = mapView
        context.coordinator.installMapLoadedHandler()
        context.coordinator.placeOrMovePin(to: coordinate)
        return mapView
    }

    func updateUIView(_ mapView: MapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updatePinAppearance()
        if !context.coordinator.isDraggingPin {
            context.coordinator.placeOrMovePin(to: coordinate)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject {
        var parent: HazardPlacementMapView
        weak var mapView: MapView?
        private var pinContainer: UIView?
        private var pinSymbolView: UIImageView?
        private var pinPanStartCenter = CGPoint.zero
        private var mapIsLoaded = false
        var isDraggingPin = false
        private var cancelables: [Cancelable] = []

        init(parent: HazardPlacementMapView) {
            self.parent = parent
        }

        func installMapLoadedHandler() {
            guard let mapView else { return }
            let cancelable = mapView.mapboxMap.onMapLoaded.observeNext { [weak self] _ in
                guard let self else { return }
                self.mapIsLoaded = true
                self.placeOrMovePin(to: self.parent.coordinate)
            }
            cancelables.append(cancelable)
        }

        func placeOrMovePin(to coordinate: CLLocationCoordinate2D) {
            guard let mapView else { return }
            if pinContainer == nil {
                let container = buildPinView()
                pinContainer = container

                let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePinPan(_:)))
                container.addGestureRecognizer(pan)
                container.isUserInteractionEnabled = true

                let options = ViewAnnotationOptions(
                    geometry: Point(coordinate),
                    allowOverlap: true,
                    anchor: .center
                )
                try? mapView.viewAnnotations.add(container, options: options)
                return
            }

            guard mapIsLoaded, let pinContainer else { return }
            let options = ViewAnnotationOptions(
                geometry: Point(coordinate),
                allowOverlap: true,
                anchor: .center
            )
            try? mapView.viewAnnotations.update(pinContainer, options: options)
        }

        func updatePinAppearance() {
            pinSymbolView?.image = UIImage(systemName: parent.hazardType.symbol)
        }

        private func buildPinView() -> UIView {
            let container = UIView(frame: CGRect(x: 0, y: 0, width: 46, height: 46))
            container.backgroundColor = .clear

            let circle = UIView(frame: container.bounds)
            circle.backgroundColor = .systemOrange
            circle.layer.cornerRadius = 23
            circle.layer.borderWidth = 2
            circle.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
            circle.isUserInteractionEnabled = false
            container.addSubview(circle)

            let imageView = UIImageView(frame: container.bounds.insetBy(dx: 10, dy: 10))
            imageView.contentMode = .scaleAspectFit
            imageView.tintColor = .white
            imageView.image = UIImage(systemName: parent.hazardType.symbol)
            imageView.isUserInteractionEnabled = false
            container.addSubview(imageView)

            pinSymbolView = imageView
            return container
        }

        @objc private func handlePinPan(_ gesture: UIPanGestureRecognizer) {
            guard let mapView, let pinContainer else { return }

            switch gesture.state {
            case .began:
                isDraggingPin = true
                pinPanStartCenter = pinContainer.center
            case .changed:
                let translation = gesture.translation(in: mapView)
                let targetPoint = CGPoint(
                    x: pinPanStartCenter.x + translation.x,
                    y: pinPanStartCenter.y + translation.y
                )
                let coordinate = mapView.mapboxMap.coordinate(for: targetPoint)
                parent.coordinate = coordinate
                placeOrMovePin(to: coordinate)
            case .ended, .cancelled, .failed:
                isDraggingPin = false
            default:
                break
            }
        }
    }
}

private struct HazardPinPlacementView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var coordinate: CLLocationCoordinate2D
    let hazardType: HazardType
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HazardPlacementMapView(coordinate: $coordinate, hazardType: hazardType)
                    .ignoresSafeArea(edges: .top)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Drag the pin to place the hazard")
                        .font(.headline)
                    Text(String(format: "Lat: %.6f  Lon: %.6f", coordinate.latitude, coordinate.longitude))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Use This Location") {
                        onConfirm()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Place Hazard Pin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct AddHazardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var auth: AuthManager

    let suggestedCoordinate: CLLocationCoordinate2D
    let onCreated: ((HazardDTO) -> Void)?

    /// Allow manual posting for every known hazard type.
    private let reportableTypes: [HazardType] = HazardType.allCases

    @State private var selectedType: HazardType = .pothole
    @State private var selectedCoordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    @State private var hasInitializedCoordinate = false
    @State private var hasConfirmedLocation = false
    @State private var showingLocationPicker = false
    @State private var roadSegmentId: String = ""
    @State private var severityValue: Double = 3
    @State private var noteText: String = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Hazard Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(reportableTypes) { t in
                            Label(t.rawValue, systemImage: t.symbol).tag(t)
                        }
                    }
                }

                Section("Location") {
                    Button(hasConfirmedLocation ? "Adjust hazard pin" : "Place hazard pin") {
                        showingLocationPicker = true
                    }

                    if !hasConfirmedLocation {
                        Text("Pick a location by dragging the pin before submitting.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Severity (1–5)") {
                    HStack {
                        Text("\(Int(severityValue))")
                            .font(.headline)
                            .frame(width: 30)
                        Slider(value: $severityValue, in: 1...5, step: 1)
                    }
                }

                Section("Note (optional)") {
                    TextField("Additional details", text: $noteText)
                }

                Section {
                    Button("Add Hazard") { addHazard() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!hasConfirmedLocation)
                }
            }
            .navigationTitle("Add Hazard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                guard !hasInitializedCoordinate else { return }
                selectedCoordinate = suggestedCoordinate
                roadSegmentId = makeRoadSegmentId(
                    suggestedCoordinate.latitude,
                    suggestedCoordinate.longitude
                )
                hasInitializedCoordinate = true
            }
            .fullScreenCover(isPresented: $showingLocationPicker) {
                HazardPinPlacementView(
                    coordinate: $selectedCoordinate,
                    hazardType: selectedType,
                    onConfirm: {
                        hasConfirmedLocation = true
                        let trimmed = roadSegmentId.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty || trimmed.hasPrefix("seg_") {
                            roadSegmentId = makeRoadSegmentId(
                                selectedCoordinate.latitude,
                                selectedCoordinate.longitude
                            )
                        }
                    }
                )
            }
            .alert(
                "Couldn’t Add Hazard",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { isPresented in
                        if !isPresented { errorMessage = nil }
                    }
                )
            ) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    /// Same format as Python `_make_road_segment_id()`: "seg_{lat:.3f}_{lon:.3f}"
    private func makeRoadSegmentId(_ lat: Double, _ lon: Double) -> String {
        String(format: "seg_%.3f_%.3f", lat, lon)
    }

    /// Normalize UI labels into backend-friendly identifiers.
    private func apiType(for type: HazardType) -> String {
        let lower = type.rawValue.lowercased()
        let replaced = lower.replacingOccurrences(
            of: "[^a-z0-9]+",
            with: "_",
            options: .regularExpression
        )
        return replaced.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    private func addHazard() {
        let lat = selectedCoordinate.latitude
        let lon = selectedCoordinate.longitude

        let seg = roadSegmentId.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSeg = seg.isEmpty ? makeRoadSegmentId(lat, lon) : seg

        Task {
            do {
                let created = try await APIClient.shared.createHazard(
                    CreateHazardRequest(
                        type: apiType(for: selectedType),
                        latitude: lat,
                        longitude: lon,
                        roadSegmentId: finalSeg,
                        sourceDeviceId: auth.username,
                        severity: Int(severityValue),
                        confidence: 1.0,              // Manual = 100% sure
                        note: noteText.isEmpty ? nil : noteText
                    )
                )
                if let hazard = try await APIClient.shared.getHazardById(created.id) {
                    await MainActor.run {
                        onCreated?(hazard)
                    }
                }
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Profile

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    let onHazardDeleted: ((String) -> Void)?

    @State private var hazards: [HazardDTO] = []
    @State private var isLoading = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var pendingDeleteHazard: HazardDTO?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    Divider()

                    Text("Recent hazards")
                        .font(.headline)
                        .padding(.horizontal)

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }

                    LazyVStack(spacing: 10) {
                        ForEach(hazards.prefix(20)) { h in
                            let ht = HazardType.from(h.type)
                            HStack {
                                Image(systemName: ht.symbol)
                                    .font(.system(size: 22))
                                    .foregroundStyle(sourceColour(h.source))
                                    .frame(width: 36)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(h.type)
                                        .font(.headline)
                                    HStack(spacing: 4) {
                                        Text(h.source.uppercased())
                                        Text("•")
                                        Text(h.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        if h.confidence > 0 {
                                            Text("•")
                                            Text("\(Int(h.confidence * 100))%")
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()

                                // Severity badge
                                Text("Sev \(h.severity)")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(severityColor(h.severity).opacity(0.2))
                                    .foregroundStyle(severityColor(h.severity))
                                    .clipShape(Capsule())

                                Button {
                                    pendingDeleteHazard = h
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                        .padding(.leading, 4)
                                }
                                .buttonStyle(.plain)
                                .disabled(isDeleting)
                            }
                            .padding()
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 24)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Log out") { auth.logout() }
                        .foregroundStyle(.red)
                }
            }
            .task {
                await loadUserHazards()
            }
            .alert(
                "Delete Hazard?",
                isPresented: Binding(
                    get: { pendingDeleteHazard != nil },
                    set: { isPresented in
                        if !isPresented { pendingDeleteHazard = nil }
                    }
                ),
                presenting: pendingDeleteHazard
            ) { hazard in
                Button("Delete", role: .destructive) {
                    Task { await deleteHazard(hazard) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { hazard in
                Text("Remove \(hazard.type) from the map for everyone?")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(auth.username)
                        .font(.title2.bold())
                    Text("Hazards posted: \(hazards.count)")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                Spacer()
            }
            .padding(.horizontal)
        }
        .padding(.top, 10)
    }

    @MainActor
    private func loadUserHazards() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let allHazards = try await APIClient.shared.getHazards()
            let identities = Set(
                [auth.username, auth.deviceId, auth.email]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
            )
            hazards = allHazards.filter { hazard in
                identities.contains(hazard.source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load user hazards:", error)
        }
    }

    @MainActor
    private func deleteHazard(_ hazard: HazardDTO) async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            _ = try await APIClient.shared.deleteDetection(id: hazard.id)
            hazards.removeAll { $0.id == hazard.id }
            onHazardDeleted?(hazard.id)
            pendingDeleteHazard = nil
            errorMessage = nil
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
            print("Failed to delete hazard:", error)
        }
    }

    private func sourceColour(_ source: String) -> Color {
        let s = source.lowercased()
        if s.contains("camera") || s.contains("dashcam") || s.contains("segmentation") {
            return .blue
        }
        return .orange
    }

    private func severityColor(_ severity: Int) -> Color {
        switch severity {
        case 5: return .red
        case 4: return .orange
        case 3: return .yellow
        case 2: return .blue
        default: return .gray
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
        .modelContainer(for: Hazard.self, inMemory: true)
}
