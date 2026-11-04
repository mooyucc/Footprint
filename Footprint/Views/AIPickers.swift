//
//  AIPickers.swift
//  Footprint
//
//  从 AIAssistantView.swift 提取（编译拆分）
//

import SwiftUI
import SwiftData
import StoreKit

struct DestinationPickerView: View {
    let destinations: [TravelDestination]
    let onSelect: (TravelDestination) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(destinations.sorted(by: { $0.visitDate > $1.visitDate })) { destination in
                    Button {
                        onSelect(destination)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(destination.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("\(destination.country) · \(formatDate(destination.visitDate))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer(minLength: 8)
                            
                            HStack(spacing: 8) {
                                if hasNotes(destination) {
                                    Text("ai_picker_has_notes".localized)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                
                                if !destination.photoDatas.isEmpty {
                                    Image(systemName: "photo.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .appPageBackgroundGradient(for: colorScheme)
            .navigationTitle("ai_select_destination".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func hasNotes(_ destination: TravelDestination) -> Bool {
        !destination.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func formatDate(_ date: Date) -> String {
        date.localizedFormatted(dateStyle: .medium, timeStyle: .none)
    }
}

// MARK: - Trip Picker View


struct TripPickerView: View {
    let trips: [TravelTrip]
    let onSelect: (TravelTrip) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(trips.sorted(by: { $0.startDate > $1.startDate })) { trip in
                    Button {
                        onSelect(trip)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(trip.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("\(formatDateRange(trip.startDate, trip.endDate)) · \("journey_cards_destinations_count".localized(with: trip.destinationCount))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer(minLength: 8)
                            
                            if hasDescription(trip) {
                                Text("ai_picker_has_description".localized)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .appPageBackgroundGradient(for: colorScheme)
            .navigationTitle("ai_select_trip".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func hasDescription(_ trip: TravelTrip) -> Bool {
        !trip.desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let startText = start.localizedFormatted(dateStyle: .medium, timeStyle: .none)
        let endText = end.localizedFormatted(dateStyle: .medium, timeStyle: .none)
        return "\(startText) - \(endText)"
    }
}

// MARK: - AI Note Preview Sheet

/// AI笔记预览和编辑Sheet - 用于地点预览卡片
