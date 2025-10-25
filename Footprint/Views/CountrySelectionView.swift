//
//  CountrySelectionView.swift
//  Footprint
//
//  Created on 2025/01/27.
//

import SwiftUI

struct CountrySelectionView: View {
    @EnvironmentObject var countryManager: CountryManager
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    var filteredCountries: [CountryManager.Country] {
        if searchText.isEmpty {
            return CountryManager.Country.allCases
        } else {
            return CountryManager.Country.allCases.filter { country in
                country.displayName.localizedCaseInsensitiveContains(searchText) ||
                country.englishName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCountries, id: \.rawValue) { country in
                    Button(action: {
                        countryManager.setCountry(country)
                        dismiss()
                    }) {
                        HStack {
                            Text(country.flag)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(country.displayName)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Text(country.englishName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if country == countryManager.currentCountry {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .font(.body)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .searchable(text: $searchText, prompt: "search_countries".localized)
            .navigationTitle("country_selection".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CountrySelectionView()
        .environmentObject(CountryManager.shared)
}
