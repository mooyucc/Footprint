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
    let onSelect: (TravelDestination) -> Void

    @Query(sort: \TravelDestination.visitDate, order: .reverse) private var destinations: [TravelDestination]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(destinations) { destination in
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
                                
                                if destination.hasPhotos {
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
        .task {
            await DestinationPhotoFlagBackfill.backfillIfNeeded(in: modelContext)
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
    let onSelect: (TravelTrip) -> Void

    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(trips) { trip in
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

// MARK: - Photo flag backfill

/// 旧数据没有 hasPhotos。第一次打开地点选择器时补一次，之后列表不再读图片二进制。
private enum DestinationPhotoFlagBackfill {
    private static let completionKey = "destinationHasPhotosBackfill.v1"

    static func backfillIfNeeded(in context: ModelContext) async {
        guard !UserDefaults.standard.bool(forKey: completionKey) else { return }

        do {
            let count = try context.fetchCount(FetchDescriptor<TravelDestination>())
            var offset = 0
            var pendingSaves = 0
            while offset < count {
                var descriptor = FetchDescriptor<TravelDestination>(
                    sortBy: [SortDescriptor(\.visitDate, order: .reverse)]
                )
                descriptor.fetchOffset = offset
                descriptor.fetchLimit = 1
                if let destination = try context.fetch(descriptor).first {
                    destination.updateHasPhotosFlag()
                    if context.hasChanges {
                        pendingSaves += 1
                    }
                }
                if pendingSaves >= 10 {
                    try context.save()
                    pendingSaves = 0
                }
                offset += 1
                await Task.yield()
            }
            if context.hasChanges {
                try context.save()
            }
            UserDefaults.standard.set(true, forKey: completionKey)
        } catch {
            print("⚠️ 地点照片标记补齐失败，将在下次打开选择器时重试: \(error.localizedDescription)")
        }
    }
}

// MARK: - AI Note Preview Sheet

/// AI笔记预览和编辑Sheet - 用于地点预览卡片
