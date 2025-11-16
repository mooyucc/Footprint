//
//  DestinationRow.swift
//  Footprint
//
//  Created by GPT-5 Codex on 2025/11/08.
//

import SwiftUI

struct DestinationRow: View {
    let destination: TravelDestination
    let showsDisclosureIndicator: Bool
    
    init(destination: TravelDestination, showsDisclosureIndicator: Bool = false) {
        self.destination = destination
        self.showsDisclosureIndicator = showsDisclosureIndicator
    }
    
    @StateObject private var countryManager = CountryManager.shared
    
    private var visitDateText: String {
        DestinationRow.dateFormatter.string(from: destination.visitDate)
    }

    private var regionTag: (icon: String, color: Color)? {
        if countryManager.isDomestic(country: destination.country) {
            return ("house.fill", .red)
        } else if !destination.country.isEmpty {
            return ("airplane", .blue)
        }
        return nil
    }
    
    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(destination.name.isEmpty ? "-" : destination.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if destination.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.pink)
                            .font(.caption)
                    }
                }
                
                Text(destination.country.isEmpty ? "-" : destination.country)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(visitDateText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let tag = regionTag {
                Image(systemName: tag.icon)
                    .foregroundColor(tag.color)
                    .font(.subheadline)
                    .padding(8)
                    .background(tag.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            
            if showsDisclosureIndicator {
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(.tertiaryLabel))
                    .font(.footnote)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
    
    private var thumbnail: some View {
        Group {
            if let data = destination.photoThumbnailData ?? destination.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image("ImageMooyu")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFill()
            }
        }
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

