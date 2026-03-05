//
//  MapCalloutComponents.swift
//  Footprint
//
//  Created by K.X on 2026/01/26.
//  从 MapView.swift 提取的地图标注弹窗组件（主要用于发现地图）
//

import SwiftUI
import MapKit
import SwiftData

// MARK: - 简化头像圆圈标注视图
/// 用于发现地图模式下的简化头像圆圈标注（当卡片可能重叠时使用）
struct SimplifiedAvatarAnnotationView: View {
    let destination: TravelDestination
    let appleSignInManager: AppleSignInManager
    let accentColor: Color  // 品牌色，用于默认头像
    
    // 头像圆圈尺寸
    private let avatarSize: CGFloat = 44
    
    var body: some View {
        Button {
            // 点击事件（如果需要）
        } label: {
            avatarView
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 头像视图
    private var avatarView: some View {
        Group {
            if let photoData = destination.photoData,
               let uiImage = UIImage(data: photoData) {
                // 地点照片作为头像
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(.white, lineWidth: 2.5)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
            } else {
                // 默认头像（使用品牌色）
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.85),
                                accentColor.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay(
                        Circle()
                            .stroke(.white, lineWidth: 2.5)
                    )
                    .overlay(
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
            }
        }
    }
}

// MARK: - 地图地点标注卡片视图（直接显示在地图上）
/// 用于发现地图模式下的地点标注卡片
struct MapDestinationCalloutAnnotationView: View {
    let destination: TravelDestination
    let appleSignInManager: AppleSignInManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                mainContent
            }
            .frame(width: 200, height: 70) // 固定宽度200，固定高度70
            .background(cardBackground)
            .overlay(bottomTail, alignment: .bottom)
            
            userAvatar
        }
    }
    
    // MARK: - 主内容区域
    private var mainContent: some View {
        HStack(alignment: .top, spacing: 10) {
            leftContent
            rightPhoto
        }
        .padding(10) // 内容与卡片四边的padding为10（上下左右都是10）
    }
    
    // MARK: - 左侧内容
    private var leftContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            // spacing: 4，使得 15 + 4 + 30 = 49，加上padding 20 = 69，接近70
            nameAndCategoryRow
                .frame(height: 15) // 固定高度15
            notesContent
                .frame(height: 30) // 固定高度30（2行，11pt字体 + 行间距需要约28-30pt）
        }
        .frame(maxWidth: 120, alignment: .leading) // 进一步缩小宽度：从180改为120
    }
    
    // MARK: - 名称和类型行
    private var nameAndCategoryRow: some View {
        HStack(spacing: 5) {
            // 显示地点类型（如果有），否则显示地点名称
            Text(destination.localizedType.isEmpty ? destination.name : destination.localizedType)
                .font(.system(size: 13, weight: .semibold, design: .rounded)) // 进一步缩小字体：从16改为13
                .foregroundColor(.primary)
                .lineLimit(1)
            
            // 显示时间日期（替代原来的"国内"）
            Text(formatVisitDate(destination.visitDate))
                .font(.system(size: 10, weight: .medium, design: .rounded)) // 进一步缩小字体：从12改为10
                .foregroundColor(.secondary)
                .padding(.horizontal, 5) // 进一步缩小内边距
                .padding(.vertical, 2) // 进一步缩小内边距
                .background(Color(.tertiarySystemFill))
                .cornerRadius(5) // 进一步缩小圆角：从8改为5
        }
    }
    
    // MARK: - 格式化访问日期
    private func formatVisitDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    // MARK: - 笔记内容
    private var notesContent: some View {
        Group {
            if !destination.notes.isEmpty {
                Text(destination.notes)
                    .font(.system(size: 11, weight: .regular, design: .rounded)) // 进一步缩小字体：从13改为11
                    .foregroundColor(.secondary)
                    .lineLimit(2) // 固定显示两行
                    .truncationMode(.tail) // 超出部分用"..."省略
                    .multilineTextAlignment(.leading)
            } else {
                Text("暂无笔记")
                    .font(.system(size: 11, weight: .regular, design: .rounded)) // 缩小字体
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
    }
    
    // MARK: - 右侧照片
    @ViewBuilder
    private var rightPhoto: some View {
        if let photoData = destination.photoData,
           let uiImage = UIImage(data: photoData) {
            photoImageView(uiImage: uiImage)
        } else if let firstPhotoData = destination.photoDatas.first,
                  let uiImage = UIImage(data: firstPhotoData) {
            photoImageView(uiImage: uiImage)
        } else {
            photoPlaceholder
        }
    }
    
    // MARK: - 照片视图
    private func photoImageView(uiImage: UIImage) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(width: 50, height: 50) // 进一步缩小照片：从80改为50
            .clipShape(RoundedRectangle(cornerRadius: 8)) // 进一步缩小圆角：从12改为8
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
    }
    
    // MARK: - 照片占位符
    private var photoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.tertiarySystemFill))
            .frame(width: 50, height: 50) // 进一步缩小照片：从80改为50
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 18)) // 进一步缩小图标：从24改为18
                    .foregroundStyle(.tertiary)
            )
    }
    
    // MARK: - 卡片背景
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous) // 进一步缩小圆角：从18改为12
            .fill(Color.white) // 改为白色背景
            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2) // 进一步缩小阴影
    }
    
    // MARK: - 用户头像
    @ViewBuilder
    private var userAvatar: some View {
        Group {
            // 优先显示用户头像（创建地点的用户）
            if let avatarImage = appleSignInManager.userAvatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
            } else {
                // 如果没有用户头像，显示默认头像
                Image("ImageMooyu")
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFill()
            }
        }
        .frame(width: 40, height: 40) // 缩小头像：从50改为40
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white, lineWidth: 2.5) // 缩小边框：从3改为2.5
        )
        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2) // 缩小阴影
        .offset(x: -20, y: -20) // 调整偏移量：使用ZStack topLeading对齐后，偏移-20让头像中心在左上角（头像半径20）
    }
    
    // MARK: - 底部尖角
    private var bottomTail: some View {
        CalloutTailShape()
            .fill(Color.white) // 尖角也改为白色，与卡片背景一致
            .frame(width: 14, height: 8) // 进一步缩小尖角：从16x10改为14x8
            .offset(y: 8) // 调整偏移
    }
}

// MARK: - 地图地点标注弹窗视图
/// 用于地图上点击地点时显示的弹窗（已废弃，保留用于兼容）
struct MapDestinationCalloutView: View {
    let destination: TravelDestination
    let onTap: () -> Void
    let appleSignInManager: AppleSignInManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                mainContent
            }
            .background(cardBackground)
            .overlay(bottomTail, alignment: .bottom)
            
            userAvatar
        }
        .onTapGesture {
            onTap()
        }
    }
    
    // MARK: - 主内容区域
    private var mainContent: some View {
        HStack(alignment: .top, spacing: 8) {
            leftContent
            rightPhoto
        }
        .padding(.all, 10) // 内容与卡片四边的padding为10
    }
    
    // MARK: - 左侧内容
    private var leftContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            nameAndCategoryRow
            notesContent
        }
        .frame(maxWidth: 120, alignment: .leading) // 进一步缩小宽度：从140改为120
    }
    
    // MARK: - 名称和类型行
    private var nameAndCategoryRow: some View {
        HStack(spacing: 5) {
            // 显示地点类型（如果有），否则显示地点名称
            Text(destination.localizedType.isEmpty ? destination.name : destination.localizedType)
                .font(.system(size: 13, weight: .semibold, design: .rounded)) // 进一步缩小字体：从14改为13
                .foregroundColor(.primary)
                .lineLimit(1)
            
            // 显示时间日期（替代原来的"国内"）
            Text(formatVisitDate(destination.visitDate))
                .font(.system(size: 10, weight: .medium, design: .rounded)) // 进一步缩小字体：从11改为10
                .foregroundColor(.secondary)
                .padding(.horizontal, 5) // 进一步缩小内边距
                .padding(.vertical, 2) // 进一步缩小内边距
                .background(Color(.tertiarySystemFill))
                .cornerRadius(5) // 进一步缩小圆角：从6改为5
        }
    }
    
    // MARK: - 格式化访问日期
    private func formatVisitDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    // MARK: - 笔记内容
    private var notesContent: some View {
        Group {
            if !destination.notes.isEmpty {
                Text(destination.notes)
                    .font(.system(size: 11, weight: .regular, design: .rounded)) // 进一步缩小字体：从12改为11
                    .foregroundColor(.secondary)
                    .lineLimit(2, reservesSpace: false) // 只显示两行，不保留额外空间
                    .truncationMode(.tail) // 超出部分用"..."省略
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true) // 允许垂直扩展，但限制水平宽度
            } else {
                Text("暂无笔记")
                    .font(.system(size: 11, weight: .regular, design: .rounded)) // 进一步缩小字体
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
    }
    
    // MARK: - 右侧照片
    @ViewBuilder
    private var rightPhoto: some View {
        if let photoData = destination.photoData,
           let uiImage = UIImage(data: photoData) {
            photoImageView(uiImage: uiImage)
        } else if let firstPhotoData = destination.photoDatas.first,
                  let uiImage = UIImage(data: firstPhotoData) {
            photoImageView(uiImage: uiImage)
        } else {
            photoPlaceholder
        }
    }
    
    // MARK: - 照片视图
    private func photoImageView(uiImage: UIImage) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(width: 50, height: 50) // 进一步缩小照片：从60改为50
            .clipShape(RoundedRectangle(cornerRadius: 8)) // 进一步缩小圆角：从10改为8
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
    }
    
    // MARK: - 照片占位符
    private var photoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.tertiarySystemFill))
            .frame(width: 50, height: 50) // 进一步缩小照片：从60改为50
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 18)) // 进一步缩小图标：从20改为18
                    .foregroundStyle(.tertiary)
            )
    }
    
    // MARK: - 卡片背景
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous) // 进一步缩小圆角：从14改为12
            .fill(Color.white) // 改为白色背景
            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2) // 进一步缩小阴影
    }
    
    // MARK: - 底部尖角
    private var bottomTail: some View {
        CalloutTailShape()
            .fill(Color.white) // 尖角也改为白色，与卡片背景一致
            .frame(width: 14, height: 8) // 进一步缩小尖角：从16x10改为14x8
            .offset(y: 8) // 调整偏移
    }
    
    // MARK: - 用户头像
    @ViewBuilder
    private var userAvatar: some View {
        Group {
            // 优先显示用户头像（创建地点的用户）
            if let avatarImage = appleSignInManager.userAvatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
            } else {
                // 如果没有用户头像，显示默认头像
                Image("ImageMooyu")
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFill()
            }
        }
        .frame(width: 40, height: 40) // 缩小头像：从50改为40
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white, lineWidth: 2.5) // 缩小边框：从3改为2.5
        )
        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2) // 缩小阴影
        .offset(x: -20, y: -20) // 调整偏移量：使用ZStack topLeading对齐后，偏移-20让头像中心在左上角（头像半径20）
    }
}

// MARK: - 聚合地点标注卡片视图
/// 用于发现地图模式下聚合地点的标注卡片，显示层叠头像
struct ClusterCalloutAnnotationView: View {
    let destinations: [TravelDestination]
    @Environment(\.colorScheme) private var colorScheme
    let appleSignInManager: AppleSignInManager
    
    // 最多显示的头像数量（根据卡片大小计算）
    private let maxVisibleAvatars = 3
    
    // 单个头像的大小
    private var avatarSize: CGFloat {
        30 // 头像尺寸30x30
    }
    
    // 头像之间的水平间距（轻微重叠）
    private var horizontalSpacing: CGFloat {
        avatarSize * 0.5 // 水平间距50%的尺寸，形成轻微重叠效果
    }
    
    // 实际显示的头像（最多 maxVisibleAvatars 个）
    private var visibleDestinations: [TravelDestination] {
        Array(destinations.prefix(maxVisibleAvatars))
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                mainContent
            }
            .frame(width: 200, height: 55) // 固定宽度200，固定高度55
            .background(cardBackground)
            .overlay(bottomTail, alignment: .bottom)
        }
    }
    
    // 随机选择一个地点的笔记用于显示
    private var randomNoteDestination: TravelDestination? {
        // 优先选择有笔记的地点
        let destinationsWithNotes = destinations.filter { !$0.notes.isEmpty }
        if let randomDestination = destinationsWithNotes.randomElement() {
            return randomDestination
        }
        // 如果没有有笔记的地点，随机选择一个
        return destinations.randomElement()
    }
    
    // MARK: - 主内容区域
    private var mainContent: some View {
        HStack(alignment: .top, spacing: 10) {
            // 左侧 1/3：层叠头像区域
            VStack(alignment: .leading, spacing: 0) {
                // 水平排列的头像区域（无垂直偏移，完全水平）
                HStack(spacing: -horizontalSpacing) {
                    ForEach(Array(visibleDestinations.enumerated()), id: \.element.id) { index, destination in
                        avatarView(for: destination)
                            .zIndex(Double(visibleDestinations.count - index)) // 右侧的头像在上层
                    }
                }
                .frame(height: avatarSize) // 头像高度30
            }
            .frame(width: 60, height: 35) // 左侧固定宽度60，高度35（卡片总高度55，减去padding 20，内容区域高度35）
            
            // 右侧 2/3：随机显示某个地点的笔记
            VStack(alignment: .leading, spacing: 0) {
                if let noteDestination = randomNoteDestination {
                    if !noteDestination.notes.isEmpty {
                        // 显示笔记内容
                        Text(noteDestination.notes)
                            .font(.system(size: 13, weight: .regular, design: .rounded)) // 字体13pt
                            .foregroundColor(.primary) // 黑色
                            .lineLimit(2) // 固定显示两行
                            .truncationMode(.tail)
                            .multilineTextAlignment(.leading)
                            .frame(width: 120, alignment: .leading) // 固定宽度120，确保文字能够换行
                    } else {
                        // 如果没有笔记，显示"暂无笔记"
                        Text("暂无笔记")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.primary) // 黑色
                            .lineLimit(2)
                    }
                } else {
                    Text("暂无笔记")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.primary) // 黑色
                        .lineLimit(2)
                }
            }
            .frame(width: 120, alignment: .leading) // 右侧固定宽度 120，约占总内容宽度的 2/3 (120/180 ≈ 67%)
            .frame(height: 35, alignment: .top) // 固定高度35，显示两行文字（13pt字体两行需要约32-34pt，35pt足够）
        }
        .padding(.all, 10) // 内容与卡片四边的padding为10，与单个地点卡片一致
        // 总宽度：60 (左侧) + 10 (spacing) + 120 (右侧) + 20 (padding) = 210
        // 单个地点卡片：120 (leftContent) + 10 (spacing) + 50 (rightPhoto) + 20 (padding) = 200
        // 为了更接近，可以稍微调整，但考虑到笔记内容需要更多空间，210 的宽度是合理的
    }
    
    // MARK: - 单个头像视图
    @ViewBuilder
    private func avatarView(for destination: TravelDestination) -> some View {
        Group {
            if let photoData = destination.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image("ImageMooyu")
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFill()
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(.white, lineWidth: 2.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
    }
    
    // MARK: - 卡片背景
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous) // 圆角改为30
            .fill(Color.white)
            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - 底部尖角
    private var bottomTail: some View {
        CalloutTailShape()
            .fill(Color.white)
            .frame(width: 14, height: 8)
            .offset(y: 8)
    }
}

// MARK: - 标注弹窗底部尖角形状
struct CalloutTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerX = rect.midX
        
        // 绘制向下的三角形
        path.move(to: CGPoint(x: centerX, y: rect.maxY))
        path.addLine(to: CGPoint(x: centerX - 10, y: rect.minY))
        path.addLine(to: CGPoint(x: centerX + 10, y: rect.minY))
        path.closeSubpath()
        
        return path
    }
}
