//
//  Item.swift
//  CurbyiOS
//
//  Created by Isaiah Hinds on 1/5/26.
//

import Foundation
import SwiftData

@Model
final class Hazard: Identifiable {
    var id: UUID
    var type: String
    var latitude: Double
    var longitude: Double
    var createdAt: Date
    var source: String
    var note: String?

    init(
        id: UUID = UUID(),
        type: String,
        latitude: Double,
        longitude: Double,
        createdAt: Date = Date(),
        source: String,
        note: String? = nil
    ) {
        self.id = id
        self.type = type
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
        self.source = source
        self.note = note
    }
}
