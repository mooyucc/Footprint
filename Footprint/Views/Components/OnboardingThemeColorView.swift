//
//  OnboardingThemeColorView.swift
//  Footprint
//
//  引导主题色页：按身份推荐强调色，星座作为第二枚可选色。
//

import SwiftUI

struct OnboardingThemeColorView: View {
    @EnvironmentObject private var brandColorManager: BrandColorManager
    @EnvironmentObject private var userProfileManager: UserProfileManager

    @State private var selectedID: String?
    @State private var applyCount = 0

    let onNext: () -> Void

    private var suggestions: [ProfileThemeSuggestion] {
        ProfileThemePalette.suggestions(
            personaKey: userProfileManager.personaTag,
            constellationKey: userProfileManager.constellation
        )
    }

    private var selectedSuggestion: ProfileThemeSuggestion? {
        suggestions.first { $0.id == selectedID } ?? suggestions.first
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                    .frame(width: 80)
                Spacer()
                Text("onboarding_theme_color_title".localized)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Spacer()
                    .frame(width: 80)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(suggestions.isEmpty
                         ? "onboarding_theme_color_empty".localized
                         : "onboarding_theme_color_description".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("theme_color_reset_hint".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(suggestions) { suggestion in
                        suggestionButton(suggestion)
                    }

                    ColorPicker(selection: Binding(
                        get: { brandColorManager.currentBrandColor },
                        set: { brandColorManager.setCustomBrandColor($0) }
                    ), supportsOpacity: false) {
                        Label("onboarding_theme_color_pick".localized, systemImage: "paintpalette")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                }
                .padding(20)
                .footprintGlassCard(cornerRadius: 18, glow: brandColorManager.currentBrandColor)
                .padding(.horizontal, 20)
            }

            VStack(spacing: 12) {
                if selectedSuggestion != nil {
                    Button {
                        if let suggestion = selectedSuggestion {
                            brandColorManager.setCustomBrandColor(suggestion.color)
                            applyCount += 1
                        }
                        onNext()
                    } label: {
                        Text("onboarding_theme_color_use".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(selectedSuggestion?.color ?? brandColorManager.currentBrandColor)
                            )
                    }
                    .sensoryFeedback(.impact(weight: .medium, intensity: 0.8), trigger: applyCount)
                }

                Button(action: onNext) {
                    Text("onboarding_next".localized)
                        .font(.headline)
                        .foregroundColor(brandColorManager.currentBrandColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(brandColorManager.currentBrandColor, lineWidth: 1.5)
                        )
                }

                OnboardingStepDots(
                    count: 5,
                    activeIndex: 4,
                    activeColor: brandColorManager.currentBrandColor
                )
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background {
            FootprintAtmosphereBackground(
                accent: brandColorManager.currentBrandColor,
                secondaryAccent: FootprintTheme.Accent.secondary
            )
        }
        .onAppear {
            if selectedID == nil {
                selectedID = suggestions.first?.id
            }
        }
    }

    private func suggestionButton(_ suggestion: ProfileThemeSuggestion) -> some View {
        let isSelected = suggestion.id == (selectedID ?? suggestions.first?.id)
        return Button {
            selectedID = suggestion.id
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(suggestion.color)
                    .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.sourceTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(suggestion.attributeName)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(suggestion.color)
                }
            }
            .padding(12)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(isSelected ? 0.08 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? suggestion.color : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(suggestion.sourceTitle) \(suggestion.attributeName)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
