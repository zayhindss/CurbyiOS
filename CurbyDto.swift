import Foundation

// MARK: - UI Hazard DTO (mapped from DetectionData)

struct HazardDTO: Identifiable {
    let id: String
    let type: String          // Exact class_name from the Python script, e.g. "Pothole"
    let latitude: Double
    let longitude: Double
    let createdAt: Date
    let source: String        // sourceDeviceId: "camera_segmentation", "dashcam", username, …
    let severity: Int         // 1–5, from Python _estimate_severity()
    let confidence: Double    // 0.0–1.0
    let note: String?
}

struct CreateHazardRequest {
    let type: String
    let latitude: Double
    let longitude: Double
    let roadSegmentId: String
    let sourceDeviceId: String
    let severity: Int
    let confidence: Double
    let note: String?
}

// MARK: - HazardType — maps every Python class_name to an SF Symbol + tint

/// The Python script uploads `type` as the literal class name from its
/// `load_class_names()` list.  This enum provides icon + colour mapping for
/// every class that isn't in the ignored set, plus a fallback for unknowns.
enum HazardType: String, CaseIterable, Identifiable {
    // Road surface
    case pothole          = "Pothole"
    case speedBump        = "Speed Bump"
    case speedHump        = "Speed Hump"
    case oilStain         = "Oil Stain"
    case roadDivider      = "Road Divider"
    case roadEdge         = "Road Edge"
    case construction     = "Construction"

    // Infrastructure
    case curb             = "Curb"
    case curbCut          = "Curb Cut"
    case manhole          = "Manhole"
    case manholeCover     = "Manhole Cover"
    case catchBasin       = "Catch Basin"
    case sewer            = "Sewer"
    case fireHydrant      = "Fire Hydrant"
    case junctionBox      = "Junction Box"
    case utilityPole      = "Utility Pole"
    case pole             = "Pole"

    // Traffic control
    case trafficLight     = "Traffic Light"
    case trafficSignFront = "Traffic Sign (Front)"
    case trafficSignBack  = "Traffic Sign (Back)"
    case trafficSignFrame = "Traffic Sign Frame"
    case trafficCone      = "Traffic Cone"
    case stopLine         = "Stop Line"

    // Street furniture
    case bench            = "Bench"
    case trashCan         = "Trash Can"
    case bikeRack         = "Bike Rack"
    case billboard        = "Billboard"
    case banner           = "Banner"
    case streetLight      = "Street Light"
    case cctvCamera       = "CCTV Camera"
    case mailbox          = "Mailbox"
    case phoneBooth       = "Phone Booth"
    case parkingMeter     = "Parking Meter"

    // Markings
    case laneMarkCrosswalk = "Lane Marking - Crosswalk"
    case laneMarkGeneral   = "Lane Marking - General"
    case crosswalkPlain    = "Crosswalk - Plain"
    case crosswalkLines    = "Crosswalk Lines"
    case arrowMarking      = "Arrow Marking"
    case pedestrianCross   = "Pedestrian Crossing"
    case turnLane          = "Turn Lane"
    case bikeSymbol        = "Bike Symbol"
    case textMarking       = "Text Marking"
    case hatchedMarking    = "Hatched Marking"

    // Vehicles (may appear as hazard-adjacent detections)
    case bicycle           = "Bicycle"
    case bus               = "Bus"
    case car               = "Car"
    case truck             = "Truck"
    case motorcycle        = "Motorcycle"

    // People / riders
    case person            = "Person"
    case bicyclist         = "Bicyclist"
    case motorcyclist      = "Motorcyclist"

    // Barriers
    case fence             = "Fence"
    case guardRail         = "Guard Rail"
    case barrier           = "Barrier"

    // Points of interest
    case busStop           = "Bus Stop"
    case tollBooth         = "Toll Booth"
    case gasStation        = "Gas Station"
    case loadingZone       = "Loading Zone"

    // Catch-all
    case other             = "Other"

    var id: String { rawValue }

    // MARK: SF Symbol per type

    var symbol: String {
        switch self {
        case .pothole:                            return "exclamationmark.triangle.fill"
        case .speedBump, .speedHump:              return "speedometer"
        case .oilStain:                           return "drop.triangle"
        case .roadDivider, .roadEdge:             return "road.lanes"
        case .construction:                       return "hammer.fill"
        case .curb, .curbCut:                     return "road.lanes"
        case .manhole, .manholeCover:             return "circle.circle"
        case .catchBasin, .sewer:                 return "drop.circle"
        case .fireHydrant:                        return "flame.circle"
        case .junctionBox:                        return "square.grid.2x2"
        case .utilityPole, .pole:                 return "line.3.horizontal"
        case .trafficLight:                       return "light.beacon.max"
        case .trafficSignFront, .trafficSignBack: return "stop.circle"
        case .trafficSignFrame:                   return "rectangle.portrait"
        case .trafficCone:                        return "cone.fill"
        case .stopLine:                           return "hand.raised.fill"
        case .bench:                              return "chair.fill"
        case .trashCan:                           return "trash.fill"
        case .bikeRack:                           return "bicycle"
        case .billboard, .banner:                 return "rectangle.3.group"
        case .streetLight:                        return "lamp.desk"
        case .cctvCamera:                         return "video.fill"
        case .mailbox:                            return "envelope.fill"
        case .phoneBooth:                         return "phone.fill"
        case .parkingMeter:                       return "parkingsign"
        case .laneMarkCrosswalk, .crosswalkPlain,
             .crosswalkLines, .pedestrianCross:   return "figure.walk"
        case .laneMarkGeneral, .hatchedMarking:   return "lines.measurement.horizontal"
        case .arrowMarking, .turnLane:            return "arrow.up.forward"
        case .bikeSymbol:                         return "bicycle"
        case .textMarking:                        return "textformat"
        case .bicycle, .bicyclist:                return "bicycle"
        case .bus:                                return "bus.fill"
        case .car:                                return "car.fill"
        case .truck:                              return "box.truck.fill"
        case .motorcycle, .motorcyclist:          return "figure.outdoor.cycle"
        case .person:                             return "person.fill"
        case .fence:                              return "rectangle.split.3x1"
        case .guardRail, .barrier:                return "road.lanes"
        case .busStop:                            return "bus.fill"
        case .tollBooth:                          return "creditcard.fill"
        case .gasStation:                         return "fuelpump.fill"
        case .loadingZone:                        return "shippingbox.fill"
        case .other:                              return "mappin.circle.fill"
        }
    }

    // MARK: Resolve raw type string → HazardType


    static func from(_ raw: String) -> HazardType {
        // 1. Exact rawValue match
        if let exact = HazardType(rawValue: raw) { return exact }

        // 2. Case-insensitive / separator-normalised match
        let normalised = raw
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespaces)

        for t in HazardType.allCases where t.rawValue.lowercased() == normalised {
            return t
        }

        // 3. Keyword fallback (order matters – most-specific first)
        let kw: [(String, HazardType)] = [
            ("pothole",        .pothole),
            ("speed bump",     .speedBump),
            ("speed hump",     .speedHump),
            ("oil stain",      .oilStain),
            ("road divider",   .roadDivider),
            ("road edge",      .roadEdge),
            ("construction",   .construction),
            ("curb cut",       .curbCut),
            ("curb",           .curb),
            ("manhole cover",  .manholeCover),
            ("manhole",        .manhole),
            ("catch basin",    .catchBasin),
            ("sewer",          .sewer),
            ("fire hydrant",   .fireHydrant),
            ("junction box",   .junctionBox),
            ("utility pole",   .utilityPole),
            ("pole",           .pole),
            ("traffic light",  .trafficLight),
            ("traffic sign",   .trafficSignFront),
            ("traffic cone",   .trafficCone),
            ("stop line",      .stopLine),
            ("bench",          .bench),
            ("trash",          .trashCan),
            ("bike rack",      .bikeRack),
            ("billboard",      .billboard),
            ("banner",         .banner),
            ("street light",   .streetLight),
            ("cctv",           .cctvCamera),
            ("mailbox",        .mailbox),
            ("phone booth",    .phoneBooth),
            ("parking meter",  .parkingMeter),
            ("crosswalk",      .crosswalkPlain),
            ("arrow",          .arrowMarking),
            ("pedestrian cross", .pedestrianCross),
            ("turn lane",      .turnLane),
            ("bike symbol",    .bikeSymbol),
            ("hatched",        .hatchedMarking),
            ("bus stop",       .busStop),
            ("toll",           .tollBooth),
            ("gas station",    .gasStation),
            ("loading zone",   .loadingZone),
            ("bicycle",        .bicycle),
            ("bus",            .bus),
            ("car",            .car),
            ("truck",          .truck),
            ("motorcycle",     .motorcycle),
            ("person",         .person),
            ("bicyclist",      .bicyclist),
            ("fence",          .fence),
            ("guard rail",     .guardRail),
            ("barrier",        .barrier),
        ]
        for (keyword, type) in kw {
            if normalised.contains(keyword) { return type }
        }

        return .other
    }
}
