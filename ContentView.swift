//
//  ContentView.swift
//  CurbyiOS
//
//  Created by Isaiah Hinds on 1/5/26.
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation
import Combine

// MARK: - Auth

final class AuthManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var username: String = "demo_user"

    func login(username: String) {
        self.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        isLoggedIn = true
    }

    func logout() {
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
    @State private var username: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Spacer()

                Image(systemName: "car.fill")
                    .font(.system(size: 56))
                    .padding(.bottom, 6)

                Text("Curby")
                    .font(.largeTitle.bold())

                //THIS IS FOR THE SUBTITLE ON LOGIN SCREEN
                //Text("Smart road hazard map")
                    //.foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    TextField("username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(12)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 18)
                .padding(.horizontal)

                Button {
                    auth.login(username: username.isEmpty ? "demo_user" : username)
                } label: {
                    Text("Log In")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Map Home (works with iOS 16 +)

struct MapHomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Hazard.createdAt, order: .reverse)
    private var hazards: [Hazard]

    @StateObject private var location = LocationManager()

    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 32.5299, longitude: -92.6379),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )

    @State private var region: MKCoordinateRegion = Self.defaultRegion

    @State private var showingAddHazard = false
    @State private var showingProfile = false

    var body: some View {
        ZStack(alignment: .bottom) {

            Map(
                coordinateRegion: $region,
                showsUserLocation: true,
                annotationItems: hazards
            ) { h in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: h.latitude, longitude: h.longitude)) {
                    HazardPin(type: h.type, source: h.source)
                }
            }
            .onAppear { location.request() }
            .onReceive(location.$lastCoordinate) { newCoord in
                guard let c = newCoord else { return }
                region = MKCoordinateRegion(
                    center: c,
                    span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
                )
            }
            .ignoresSafeArea()

            bottomBar
        }
        .sheet(isPresented: $showingAddHazard) {
            AddHazardView(suggestedCoordinate: region.center)
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
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
                showingAddHazard = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Circle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .shadow(radius: 10)
    }
}

// MARK: - Pin UI

struct HazardPin: View {
    let type: String
    let source: String

    private var symbol: String {
        switch type.lowercased() {
        case "pothole": return "exclamationmark.triangle.fill"
        case "stop sign": return "stop.fill"
        case "road closure": return "road.lanes"
        case "debris": return "trash.fill"
        default: return "mappin.circle.fill"
        }
    }

    private var tint: Color {
        switch source.lowercased() {
        case "camera": return .blue
        case "user": return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .padding(8)
                .background(tint)
                .clipShape(Circle())

            Text(type)
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

struct AddHazardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let suggestedCoordinate: CLLocationCoordinate2D

    @State private var type: String = "pothole"
    @State private var latitudeText: String = ""
    @State private var longitudeText: String = ""

    private let hazardTypes = ["pothole", "stop sign", "road closure", "debris", "other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Hazard Type") {
                    Picker("Type", selection: $type) {
                        ForEach(hazardTypes, id: \.self) { t in
                            Text(t.capitalized).tag(t)
                        }
                    }
                }

                Section("Location") {
                    TextField("Latitude", text: $latitudeText)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Longitude", text: $longitudeText)
                        .keyboardType(.numbersAndPunctuation)

                    Button("Use current map center") {
                        latitudeText = String(format: "%.6f", suggestedCoordinate.latitude)
                        longitudeText = String(format: "%.6f", suggestedCoordinate.longitude)
                    }
                }

                Section {
                    Button("Add Hazard") {
                        addHazard()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Add Hazard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                latitudeText = String(format: "%.6f", suggestedCoordinate.latitude)
                longitudeText = String(format: "%.6f", suggestedCoordinate.longitude)
            }
        }
    }

    private func addHazard() {
        guard
            let lat = Double(latitudeText.trimmingCharacters(in: .whitespacesAndNewlines)),
            let lon = Double(longitudeText.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return }

        let hazard = Hazard(type: type, latitude: lat, longitude: lon, source: "user")
        modelContext.insert(hazard)
    }
}

// MARK: - Profile

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Hazard.createdAt, order: .reverse)
    private var hazards: [Hazard]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    Divider()

                    Text("Recent hazards")
                        .font(.headline)
                        .padding(.horizontal)

                    LazyVStack(spacing: 10) {
                        ForEach(hazards.prefix(20)) { h in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(h.type.capitalized)
                                        .font(.headline)
                                    Text("\(h.source.uppercased()) • \(h.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
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
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
        .modelContainer(for: Hazard.self, inMemory: true)
}

