import SwiftUI
import MapboxMaps
import CoreLocation
import UIKit

// MARK: - Map Annotation Pin

private struct MapHazardPin: View {
    let type: String
    let source: String
    let severity: Int
    let confidence: Double

    private var hazardType: HazardType { HazardType.from(type) }

    /// Tint colour based on how the detection was created.
    private var tint: Color {
        let s = source.lowercased()
        if s.contains("camera") || s.contains("dashcam") || s.contains("segmentation") {
            return .blue               // ML / camera detection
        }
        return .orange                 // Manual user report
    }

    /// Ring colour around the pin for high-severity hazards.
    private var severityRing: Color {
        switch severity {
        case 5:  return .red
        case 4:  return .orange
        case 3:  return .yellow
        default: return .clear
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if severity >= 3 {
                    Circle()
                        .stroke(severityRing, lineWidth: 2)
                        .frame(width: 40, height: 40)
                }

                Image(systemName: hazardType.symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(tint)
                    .clipShape(Circle())
            }

            Text(type.replacingOccurrences(of: "_", with: " "))
                .font(.caption2)
                .foregroundStyle(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.thinMaterial)
                .clipShape(Capsule())

            // Show confidence % for camera detections
            if confidence > 0 {
                let s = source.lowercased()
                if s.contains("camera") || s.contains("dashcam") || s.contains("segmentation") {
                    Text("\(Int(confidence * 100))%")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Cluster Pin

private struct MapHazardClusterPin: View {
    let count: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.85))
                .frame(width: 34, height: 34)

            Text("\(count)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(
            Circle()
                .stroke(.white.opacity(0.9), lineWidth: 2)
                .frame(width: 34, height: 34)
        )
    }
}

// MARK: - MapboxMapView (UIViewRepresentable)

struct MapboxMapView: UIViewRepresentable {
    let hazards: [HazardDTO]
    let center: CLLocationCoordinate2D
    var onClusterTap: (([HazardDTO]) -> Void)? = nil
    var onCenterChanged: ((CLLocationCoordinate2D) -> Void)? = nil

    func makeUIView(context: Context) -> MapView {
        let cameraOptions = CameraOptions(center: center, zoom: 12)
        let mapInitOptions = MapInitOptions(cameraOptions: cameraOptions)
        let mapView = MapView(frame: .zero, mapInitOptions: mapInitOptions)

        mapView.ornaments.options.compass.visibility = .hidden
        mapView.ornaments.options.scaleBar.visibility = .hidden

        let puck = Puck2DConfiguration.makeDefault(showBearing: true)
        mapView.location.options.puckType = .puck2D(puck)
        mapView.location.options.puckBearingEnabled = true
        mapView.location.options.puckBearing = .heading

        context.coordinator.mapView = mapView
        context.coordinator.cachedHazards = hazards
        context.coordinator.onCenterChanged = onCenterChanged
        context.coordinator.installMapLoadedHandler()
        context.coordinator.installCameraChangedHandler()

        return mapView
    }

    func updateUIView(_ mapView: MapView, context: Context) {
        context.coordinator.cachedHazards = hazards
        context.coordinator.onClusterTap = onClusterTap
        context.coordinator.onCenterChanged = onCenterChanged
        context.coordinator.updateAnnotations(hazards)
        //let camera = CameraOptions(center: center, zoom: 14) auto refresh ...
        //mapView.camera.ease(to: camera, duration: 0.6)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var mapView: MapView?
        var cachedHazards: [HazardDTO] = []
        private var isStyleLoaded = false
        private var cancelables: [Cancelable] = []
        var onClusterTap: (([HazardDTO]) -> Void)?
        var onCenterChanged: ((CLLocationCoordinate2D) -> Void)?
        private var annotationViews: [UIView: [HazardDTO]] = [:]

        func installMapLoadedHandler() {
            guard let mapView else { return }
            cancelables.forEach { $0.cancel() }
            cancelables.removeAll()
            let cancelable = mapView.mapboxMap.onMapLoaded.observeNext { [weak self] _ in
                guard let self else { return }
                self.isStyleLoaded = true
                self.updateAnnotations(self.cachedHazards)
            }
            cancelables.append(cancelable)
        }

        func installCameraChangedHandler() {
            guard let mapView else { return }
            let cancelable = mapView.mapboxMap.onCameraChanged.observeNext { [weak self] (_: CameraChanged) in
                guard let self, let mapView = self.mapView else { return }
                let center = mapView.cameraState.center
                self.onCenterChanged?(center)
            }
            cancelables.append(cancelable)
        }

        func updateAnnotations(_ hazards: [HazardDTO]) {
            guard let mapView, isStyleLoaded else { return }
            mapView.viewAnnotations.removeAll()
            annotationViews.removeAll()

            let grouped = groupByCoordinate(hazards)
            for group in grouped {
                let view: AnyView
                if group.count > 1 {
                    view = AnyView(MapHazardClusterPin(count: group.count))
                } else if let hazard = group.first {
                    view = AnyView(MapHazardPin(
                        type: hazard.type,
                        source: hazard.source,
                        severity: hazard.severity,
                        confidence: hazard.confidence
                    ))
                } else {
                    continue
                }

                let host = UIHostingController(rootView: view)
                host.view.backgroundColor = UIColor.clear
                host.view.isUserInteractionEnabled = true
                host.view.setNeedsLayout()
                host.view.layoutIfNeeded()
                let size = host.sizeThatFits(in: CGSize(width: 140, height: 140))
                host.view.frame = CGRect(origin: .zero, size: size)

                let tap = UITapGestureRecognizer(target: self, action: #selector(handleAnnotationTap(_:)))
                host.view.addGestureRecognizer(tap)
                annotationViews[host.view] = group

                let point = Point(CLLocationCoordinate2D(
                    latitude: group[0].latitude,
                    longitude: group[0].longitude
                ))
                let options = ViewAnnotationOptions(
                    geometry: point,
                    allowOverlap: true,
                    anchor: .center
                )

                do {
                    try mapView.viewAnnotations.add(host.view, options: options)
                } catch {
                    // Silently skip failed annotations
                }
            }
        }

        private func groupByCoordinate(_ hazards: [HazardDTO]) -> [[HazardDTO]] {
            var buckets: [String: [HazardDTO]] = [:]
            buckets.reserveCapacity(hazards.count)
            for h in hazards {
                let key = String(format: "%.6f,%.6f", h.latitude, h.longitude)
                buckets[key, default: []].append(h)
            }
            return Array(buckets.values)
        }

        @objc private func handleAnnotationTap(_ sender: UITapGestureRecognizer) {
            guard let view = sender.view, let hazards = annotationViews[view] else { return }
            onClusterTap?(hazards)
        }
    }
}
