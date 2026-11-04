//
//  ProfileCacheStore.swift
//  Footprint
//
//  Profile tab stats cache: survives Tab recreation + cold start via disk snapshot.
//  Refresh when DestinationDataRevision / destination count changes; never overwrite
//  a non-empty cache with a transient empty @Query.
//

import Foundation
import Combine

struct ProfileDestinationSnapshot: Sendable {
    let id: UUID
    let country: String
    let category: String
    let isFavorite: Bool
    let visitDate: Date
}

struct ProfileStatistics: Sendable, Equatable, Codable {
    var total: Int
    var domestic: Int
    var international: Int
    var countries: Int
    var continents: Int

    static let zero = ProfileStatistics(total: 0, domestic: 0, international: 0, countries: 0, continents: 0)
}

@MainActor
final class ProfileCacheStore: ObservableObject {
    static let shared = ProfileCacheStore()

    @Published private(set) var statistics: ProfileStatistics?
    @Published private(set) var favoriteIDs: [UUID] = []
    @Published private(set) var timelineYearItems: [(year: Int, count: Int)] = []

    /// 上次成功应用的会话 revision；磁盘恢复后为 -1，迫使首次非空 @Query 重算校验
    private(set) var handledRevision: Int = -1
    /// 上次成功应用的地点数量（用于冷启动指纹与空结果保护）
    private(set) var handledDestinationCount: Int = -1

    private var refreshTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private let persistQueue = DispatchQueue(label: "com.footprint.profileCache.persist", qos: .utility)

    private init() {
        loadFromDisk()
    }

    var displayStatistics: ProfileStatistics {
        statistics ?? .zero
    }

    /// 仅在尚无缓存或 revision 变化时重算；`force` 用于 @Query count 变化（含确认清空）
    func refreshIfNeeded(
        revision: Int,
        snapshots: [ProfileDestinationSnapshot],
        userCountry: CountryManager.Country,
        force: Bool = false
    ) {
        if !force {
            guard statistics == nil || revision != handledRevision else { return }
        }
        let domesticKeys = (
            userCountry.rawValue,
            userCountry.displayName,
            userCountry.englishName
        )
        // force + 空 snapshots = @Query 已确认 0 条，允许清空；否则空结果不覆盖非空缓存
        refresh(
            revision: revision,
            snapshots: snapshots,
            domesticKeys: domesticKeys,
            allowEmptyOverwrite: force
        )
    }

    /// debounce：等待 SwiftData @Query 同步后再重算
    func scheduleRefresh(
        revision: Int,
        snapshots: @escaping @MainActor () -> [ProfileDestinationSnapshot],
        userCountry: @escaping @MainActor () -> CountryManager.Country,
        force: Bool = false
    ) {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            refreshIfNeeded(
                revision: revision,
                snapshots: snapshots(),
                userCountry: userCountry(),
                force: force
            )
        }
    }

    private func refresh(
        revision: Int,
        snapshots: [ProfileDestinationSnapshot],
        domesticKeys: (String, String, String),
        allowEmptyOverwrite: Bool
    ) {
        // 冷启动竞态：@Query 尚未就绪时 snapshots 为空，绝不能覆盖磁盘/内存里的非空结果
        if snapshots.isEmpty, !allowEmptyOverwrite, let existing = statistics, existing.total > 0 {
            return
        }

        refreshTask?.cancel()
        refreshTask = Task {
            let computed = await Task.detached(priority: .userInitiated) {
                Self.compute(from: snapshots, domesticKeys: domesticKeys)
            }.value

            guard !Task.isCancelled else { return }

            if snapshots.isEmpty, !allowEmptyOverwrite, let existing = self.statistics, existing.total > 0 {
                return
            }

            self.statistics = computed.statistics
            self.favoriteIDs = computed.favoriteIDs
            self.timelineYearItems = computed.timelineYearItems
            self.handledRevision = revision
            self.handledDestinationCount = snapshots.count
            self.saveToDisk(
                statistics: computed.statistics,
                favoriteIDs: computed.favoriteIDs,
                timelineYearItems: computed.timelineYearItems,
                destinationCount: snapshots.count
            )
        }
    }

    // MARK: - Disk

    private struct PersistedPayload: Codable {
        var destinationCount: Int
        var statistics: ProfileStatistics
        var favoriteIDs: [UUID]
        var timelineYearItems: [PersistedYearItem]
    }

    private struct PersistedYearItem: Codable {
        var year: Int
        var count: Int
    }

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Footprint", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("profile_cache.json")
    }

    private func loadFromDisk() {
        let url = Self.fileURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(PersistedPayload.self, from: data) else {
            return
        }
        statistics = payload.statistics
        favoriteIDs = payload.favoriteIDs
        timelineYearItems = payload.timelineYearItems.map { (year: $0.year, count: $0.count) }
        handledDestinationCount = payload.destinationCount
        // handledRevision 保持 -1，等本会话 @Query 校验后再对齐
    }

    private func saveToDisk(
        statistics: ProfileStatistics,
        favoriteIDs: [UUID],
        timelineYearItems: [(year: Int, count: Int)],
        destinationCount: Int
    ) {
        let payload = PersistedPayload(
            destinationCount: destinationCount,
            statistics: statistics,
            favoriteIDs: favoriteIDs,
            timelineYearItems: timelineYearItems.map { PersistedYearItem(year: $0.year, count: $0.count) }
        )
        let url = Self.fileURL
        persistQueue.async {
            guard let data = try? JSONEncoder().encode(payload) else { return }
            try? data.write(to: url, options: [.atomic])
        }
    }

    nonisolated private static func compute(
        from snapshots: [ProfileDestinationSnapshot],
        domesticKeys: (String, String, String)
    ) -> (
        statistics: ProfileStatistics,
        favoriteIDs: [UUID],
        timelineYearItems: [(year: Int, count: Int)]
    ) {
        let total = snapshots.count
        let domestic = snapshots.filter { isDomestic(country: $0.country, keys: domesticKeys) }.count
        let international = total - domestic
        let countries = Set(snapshots.map(\.country)).count
        let continents = estimateContinents(from: snapshots)

        let favoriteIDs = snapshots
            .filter(\.isFavorite)
            .sorted { $0.visitDate > $1.visitDate }
            .map(\.id)

        let calendar = Calendar.current
        let groups = Dictionary(grouping: snapshots) { snapshot in
            calendar.component(.year, from: snapshot.visitDate)
        }
        let timelineYearItems = groups
            .map { (year: $0.key, count: $0.value.count) }
            .sorted { $0.year > $1.year }

        return (
            ProfileStatistics(
                total: total,
                domestic: domestic,
                international: international,
                countries: countries,
                continents: continents
            ),
            favoriteIDs,
            timelineYearItems
        )
    }

    nonisolated private static func isDomestic(country: String, keys: (String, String, String)) -> Bool {
        country == keys.0 || country == keys.1 || country == keys.2
    }

    nonisolated private static func estimateContinents(from snapshots: [ProfileDestinationSnapshot]) -> Int {
        let asianCountries = ["中国", "日本", "韩国", "泰国", "新加坡", "马来西亚", "印度", "越南"]
        let europeanCountries = ["法国", "德国", "英国", "意大利", "西班牙", "瑞士", "荷兰", "冰岛"]
        let americanCountries = ["美国", "加拿大", "墨西哥", "巴西", "阿根廷"]
        let oceaniaCountries = ["澳大利亚", "新西兰"]
        let africanCountries = ["南非", "埃及", "摩洛哥", "肯尼亚"]

        var continents = Set<String>()

        for snapshot in snapshots {
            if asianCountries.contains(snapshot.country) || snapshot.category == "domestic" {
                continents.insert("Asia")
            } else if europeanCountries.contains(snapshot.country) {
                continents.insert("Europe")
            } else if americanCountries.contains(snapshot.country) {
                continents.insert("America")
            } else if oceaniaCountries.contains(snapshot.country) {
                continents.insert("Oceania")
            } else if africanCountries.contains(snapshot.country) {
                continents.insert("Africa")
            }
        }

        return continents.count
    }
}
