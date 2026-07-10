//
//  DestinationCollectionSignature.swift
//  Footprint
//
//  Lightweight change detection for destination collections (avoids O(n) string building).
//

import Foundation

enum DestinationCollectionSignature {
    /// Map tab: detect coordinate, trip, and visit date changes.
    static func makeForMap(from destinations: [TravelDestination]) -> String {
        fingerprint(destinations) { dest in
            var h = Hasher()
            h.combine(dest.id)
            h.combine(dest.latitude)
            h.combine(dest.longitude)
            h.combine(dest.trip?.id)
            h.combine(dest.visitDate.timeIntervalSince1970)
            return h.finalize()
        }
    }

    /// Badge tab: detect country / province changes.
    static func makeForBadges(from destinations: [TravelDestination]) -> String {
        fingerprint(destinations) { dest in
            var h = Hasher()
            h.combine(dest.id)
            h.combine(dest.country)
            h.combine(dest.province)
            return h.finalize()
        }
    }

    /// Profile tab: detect fields used in statistics / favorites / timeline.
    static func makeForProfile(from destinations: [TravelDestination]) -> String {
        fingerprint(destinations) { dest in
            var h = Hasher()
            h.combine(dest.id)
            h.combine(dest.country)
            h.combine(dest.category)
            h.combine(dest.isFavorite)
            h.combine(dest.visitDate.timeIntervalSince1970)
            return h.finalize()
        }
    }

    private static func fingerprint(
        _ destinations: [TravelDestination],
        perItem: (TravelDestination) -> Int
    ) -> String {
        var aggregate = Hasher()
        aggregate.combine(destinations.count)
        for destination in destinations {
            aggregate.combine(perItem(destination))
        }
        return String(aggregate.finalize())
    }
}
