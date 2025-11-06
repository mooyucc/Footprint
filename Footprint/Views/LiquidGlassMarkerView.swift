import SwiftUI

struct LiquidGlassMarkerView: View {
    let size: CGFloat
    let startColor: Color
    let endColor: Color
    let borderWidth: CGFloat

    init(size: CGFloat, startColor: Color, endColor: Color, borderWidth: CGFloat = 2) {
        self.size = size
        self.startColor = startColor
        self.endColor = endColor
        self.borderWidth = borderWidth
    }

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [startColor, endColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: borderWidth)
            )
            .shadow(color: startColor.opacity(0.6), radius: 8)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .opacity(0.92)
    }
}


