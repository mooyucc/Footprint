import SwiftUI

struct DragCheckInButton: View {
    @Binding var isCheckingIn: Bool
    let onCheckIn: () -> Void
    
    // 可选的PNG图片名称
    let normalImageName: String?
    let successImageName: String?
    
    // 地图样式（用于自适应背景）
    let mapStyle: MapStyle
    
    @State private var dragOffset: CGFloat = -15  // 初始位置向上偏移15像素
    @State private var isDragging = false
    @State private var hasTriggered = false
    
    // 拖动阈值 - 需要拖动多少距离才能触发打卡
    private let triggerThreshold: CGFloat = 60
    
    // 初始化方法
    init(
        isCheckingIn: Binding<Bool>,
        onCheckIn: @escaping () -> Void,
        normalImageName: String? = nil,
        successImageName: String? = nil,
        mapStyle: MapStyle = .standard
    ) {
        self._isCheckingIn = isCheckingIn
        self.onCheckIn = onCheckIn
        self.normalImageName = normalImageName
        self.successImageName = successImageName
        self.mapStyle = mapStyle
    }
    
    // 判断是否是深色地图样式
    private var isDarkMapStyle: Bool {
        switch mapStyle {
        case .standard:
            return false
        case .hybrid, .imagery:
            return true
        }
    }
    
    var body: some View {
        ZStack {
            // 背景轨道 - 根据地图样式调整
            if isDarkMapStyle {
                // 深色地图：半透明浅色背景（类似其他按钮的玻璃质感）
                ZStack {
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.black.opacity(0.65))
                    
                    RoundedRectangle(cornerRadius: 25)
                        .fill(.thinMaterial.opacity(0.8))
                    
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                }
                .frame(width: 44, height: 80)
                .overlay(
                    // 轨道内的渐变指示
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [.green.opacity(0.3), .green.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: max(0, min(60, dragOffset + 35)))
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
                    }
                    .padding(4)
                )
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
                .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
            } else {
                // 标准地图：使用浅灰色背景
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color(.systemGray5))
                    .frame(width: 44, height: 80)
                    .overlay(
                        // 轨道内的渐变指示
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [.green.opacity(0.3), .green.opacity(0.1)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: max(0, min(60, dragOffset + 35)))
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
                        }
                        .padding(4)
                    )
            }
            
            // 可拖动的按钮
            Circle()
                .fill(
                    LinearGradient(
                        colors: isDragging ? [.green, .green.opacity(0.8)] : [.blue, .blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
                .overlay(
                    Group {
                        // 如果提供了PNG图片名称，使用PNG图片
                        if let imageName = hasTriggered ? successImageName : normalImageName {
                            Image(imageName)
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(.white)
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                        } else {
                            // 否则使用SF Symbols
                            Image(systemName: hasTriggered ? "checkmark" : "location.circle.fill")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                )
                .shadow(color: .black.opacity(0.2), radius: isDragging ? 8 : 4, x: 0, y: isDragging ? 4 : 2)
                .offset(y: dragOffset)
                .scaleEffect(isDragging ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isCheckingIn && !hasTriggered {
                                isDragging = true
                                // 只允许向下拖动，考虑初始偏移
                                dragOffset = max(-15, min(value.translation.height - 15, triggerThreshold - 15))
                                
                                // 当拖动超过阈值时提供触觉反馈
                                if dragOffset >= (triggerThreshold - 15) && !hasTriggered {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    hasTriggered = true
                                }
                            }
                        }
                        .onEnded { value in
                            if hasTriggered {
                                // 触发打卡
                                let successFeedback = UINotificationFeedbackGenerator()
                                successFeedback.notificationOccurred(.success)
                                
                                onCheckIn()
                                
                                // 重置状态
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    resetButton()
                                }
                            } else {
                                // 没有达到阈值，回弹
                                let lightFeedback = UIImpactFeedbackGenerator(style: .light)
                                lightFeedback.impactOccurred()
                                resetButton()
                            }
                        }
                )
        }
        .disabled(isCheckingIn)
        .opacity(isCheckingIn ? 0.6 : 1.0)
    }
    
    private func resetButton() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            dragOffset = -15  // 确保回弹到初始位置（向上偏移15像素）
            isDragging = false
            hasTriggered = false
        }
    }
}

// 预览
struct DragCheckInButton_Previews: PreviewProvider {
    @State static var isCheckingIn = false
    
    static var previews: some View {
        VStack(spacing: 50) {
            DragCheckInButton(isCheckingIn: $isCheckingIn) {
                print("打卡触发!")
            }
            
            // 测试状态
            Button("测试打卡状态") {
                isCheckingIn.toggle()
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}