//
//  LanguageSelectionView.swift
//  Footprint
//
//  Created on 2025/01/27.
//

import SwiftUI

struct LanguageSelectionView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            FootprintFormScaffold(accent: Color.footprintRed) {
                List {
                    ForEach(LanguageManager.Language.allCases, id: \.self) { language in
                        Button(action: {
                            languageManager.setLanguage(language)
                            dismiss()
                        }) {
                            HStack {
                                Text(language.flag)
                                    .font(.title2)
                                
                                Text(language.displayName)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                if languageManager.currentLanguage == language {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.footprintRed)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .navigationTitle("language_selection".localized)
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
}

#Preview {
    LanguageSelectionView()
        .environmentObject(LanguageManager.shared)
}
