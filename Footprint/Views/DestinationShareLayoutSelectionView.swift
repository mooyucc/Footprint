import SwiftUI
import SwiftData

struct DestinationShareLayoutSelectionView: View {
    let destination: TravelDestination
    @Binding var selectedLayout: DestinationShareLayout
    @Environment(\.dismiss) private var dismiss
    @State private var shareItem: TripShareItem?
    @State private var isGenerating = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(DestinationShareLayout.allCases) { layout in
                            DestinationLayoutOptionCard(
                                layout: layout,
                                isSelected: selectedLayout == layout
                            ) {
                                selectedLayout = layout
                            }
                        }
                    }
                    .padding()
                }
                
                VStack(spacing: 12) {
                    Button {
                        guard !isGenerating else { return }
                        generateAndShare()
                    } label: {
                        HStack {
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                            Text(isGenerating ? "share_generating".localized : "share".localized)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isGenerating ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isGenerating)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("cancel".localized)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("select_layout".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $shareItem) { item in
            if let image = item.image {
                SystemShareSheet(items: [image])
            }
        }
    }
    
    private func generateAndShare() {
        guard !isGenerating else { return }
        
        isGenerating = true
        DispatchQueue.global(qos: .userInitiated).async {
            let image = TripImageGenerator.generateDestinationImage(from: destination, layout: selectedLayout)
            
            DispatchQueue.main.async {
                self.isGenerating = false
                self.shareItem = TripShareItem(text: "", image: image)
            }
        }
    }
}

struct DestinationLayoutOptionCard: View {
    let layout: DestinationShareLayout
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: layout.iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(layout.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(layout.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.05) : Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

