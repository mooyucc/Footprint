//
//  TabListSnapshotStore.swift
//  Footprint
//
//  旅程 / 时光胶囊 / 我的：用手动 fetch + 磁盘轻量快照替代全量 @Query 订阅。
//  各 Tab 按需加载；仅刷新「已经打开过」的切片，避免地图首启拖全家桶。
//

import Foundation
import SwiftData
import Combine

@MainActor
final class TabListSnapshotStore: ObservableObject {
    static let shared = TabListSnapshotStore()
    static let journeyStackLimit = 24

    @Published private(set) var journeyTrips: [TravelTrip] = []
    @Published private(set) var journeyTripCount: Int = 0
    @Published private(set) var yearDestinations: [TravelDestination] = []
    @Published private(set) var loadedYear: Int?
    @Published private(set) var favoriteDestinations: [TravelDestination] = []

    private var modelContext: ModelContext?
    private var debounceTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var handledRevision: Int = -1
    private var lastLightSignature: String = ""
    private var didLoadProfileSnapshots = false
    private var didLoadJourneyTrips = false
    private var didLoadFavorites = false
    private let persistQueue = DispatchQueue(label: "com.footprint.tabListSnapshot.persist", qos: .utility)

    private init() {
        DestinationDataRevision.shared.$revision
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleRefreshLoaded(force: true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .tripUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleRefreshLoaded(force: true)
            }
            .store(in: &cancellables)

        loadJourneyFingerprintFromDisk()
    }

    /// 仅绑定主上下文，不主动全表刷新（地图首帧优先）。
    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// 旅程 Tab：拉限量旅程列表
    func ensureJourneyTrips(force: Bool = false) {
        guard modelContext != nil else { return }
        if !force, didLoadJourneyTrips, handledRevision == DestinationDataRevision.shared.revision {
            return
        }
        refreshJourneyTrips()
    }

    /// 我的 / 时光胶囊时间线：轻量快照 + 收藏（有磁盘时可跳过全表，直到 force / revision 变化）
    func ensureProfileData(force: Bool = false) {
        guard modelContext != nil else { return }
        let revision = DestinationDataRevision.shared.revision
        let hasDisk =
            ProfileCacheStore.shared.statistics != nil
            || !ProfileCacheStore.shared.destinationSnapshots.isEmpty
            || ProfileCacheStore.shared.handledDestinationCount >= 0

        if !force, didLoadProfileSnapshots, handledRevision == revision {
            if didLoadFavorites { return }
            refreshFavorites()
            return
        }

        if !force, !didLoadProfileSnapshots, hasDisk, handledRevision < 0 {
            // 磁盘已有统计/快照：首帧直接用，后台延后校验全表
            didLoadProfileSnapshots = true
            scheduleRefreshLoaded(force: true, delayNanoseconds: 1_200_000_000)
            refreshFavorites()
            return
        }

        refreshProfileSnapshots(force: force)
        refreshFavorites()
    }

    func scheduleRefreshLoaded(force: Bool = false, delayNanoseconds: UInt64 = 120_000_000) {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            refreshLoadedSlices(force: force)
        }
    }

    /// 回前台：仅当轻量签名变化且已有加载切片时刷新。
    func refreshIfStaleOnForeground() {
        guard let context = modelContext else { return }
        let signature = currentLightSignature(in: context)
        guard signature != lastLightSignature else { return }
        scheduleRefreshLoaded(force: true)
    }

    func loadYear(_ year: Int, force: Bool = false) {
        guard let context = modelContext else { return }
        guard year > 0 else {
            yearDestinations = []
            loadedYear = nil
            return
        }
        if !force, loadedYear == year, !yearDestinations.isEmpty { return }
        yearDestinations = Self.fetchDestinations(year: year, in: context)
        loadedYear = year
    }

    func destinations(matchingCountry country: CountryManager.Country) -> [TravelDestination] {
        guard let context = modelContext else { return [] }
        let keys = [country.rawValue, country.displayName, country.englishName]
        let ids = ProfileCacheStore.shared.destinationSnapshots
            .filter { keys.contains($0.country) }
            .map(\.id)
        return Self.fetchDestinations(ids: ids, in: context)
    }

    func destinations(matchingProvince provinceName: String) -> [TravelDestination] {
        guard let context = modelContext else { return [] }
        let badgeManager = BadgeManager.shared
        let normalized = badgeManager.normalizeProvinceName(provinceName)
        let ids = ProfileCacheStore.shared.destinationSnapshots
            .filter { snapshot in
                let isChina = snapshot.country == "中国"
                    || snapshot.country == "CN"
                    || snapshot.country == "China"
                guard isChina, !snapshot.province.isEmpty else { return false }
                return badgeManager.normalizeProvinceName(snapshot.province) == normalized
            }
            .map(\.id)
        return Self.fetchDestinations(ids: ids, in: context)
    }

    func trip(id: UUID) -> TravelTrip? {
        if let hit = journeyTrips.first(where: { $0.id == id }) { return hit }
        guard let context = modelContext else { return nil }
        var descriptor = FetchDescriptor<TravelTrip>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    // MARK: - Slice refresh

    private func refreshLoadedSlices(force: Bool) {
        guard modelContext != nil else { return }
        let revision = DestinationDataRevision.shared.revision
        if !force, revision == handledRevision { return }

        // 只刷新已经按需加载过的切片，避免地图场景拖全家桶
        if didLoadProfileSnapshots {
            refreshProfileSnapshots(force: force)
        }
        if didLoadJourneyTrips {
            refreshJourneyTrips()
        }
        if didLoadFavorites {
            refreshFavorites()
        }
        if let year = loadedYear, year > 0 {
            loadYear(year, force: true)
        }

        if let context = modelContext {
            lastLightSignature = currentLightSignature(in: context)
        }
        if didLoadProfileSnapshots || didLoadJourneyTrips || didLoadFavorites || loadedYear != nil {
            handledRevision = revision
        }
    }

    private func refreshProfileSnapshots(force: Bool) {
        guard let context = modelContext else { return }
        let revision = DestinationDataRevision.shared.revision
        let snapshots = Self.fetchLightSnapshots(in: context)
        ProfileCacheStore.shared.applySnapshots(
            snapshots,
            revision: revision,
            userCountry: CountryManager.shared.currentCountry,
            force: force
        )
        didLoadProfileSnapshots = true
        handledRevision = revision
        lastLightSignature = currentLightSignature(in: context)
    }

    private func refreshJourneyTrips() {
        guard let context = modelContext else { return }
        journeyTripCount = (try? context.fetchCount(FetchDescriptor<TravelTrip>())) ?? 0
        journeyTrips = Self.fetchJourneyTrips(in: context, limit: Self.journeyStackLimit)
        persistJourneyFingerprint(trips: journeyTrips, totalCount: journeyTripCount)
        didLoadJourneyTrips = true
        handledRevision = DestinationDataRevision.shared.revision
        lastLightSignature = currentLightSignature(in: context)
    }

    private func refreshFavorites() {
        guard let context = modelContext else { return }
        let favoriteIDs = Array(ProfileCacheStore.shared.favoriteIDs.prefix(5))
        favoriteDestinations = Self.fetchDestinations(ids: favoriteIDs, in: context)
        didLoadFavorites = true
    }

    private func currentLightSignature(in context: ModelContext) -> String {
        let destinations = MapDestinationFetcher.fetchLightSignature(in: context)
        let trips = (try? context.fetchCount(FetchDescriptor<TravelTrip>())) ?? 0
        return "\(destinations)|t\(trips)"
    }

    // MARK: - Fetch helpers

    static func fetchLightSnapshots(in context: ModelContext) -> [ProfileDestinationSnapshot] {
        let descriptor = FetchDescriptor<TravelDestination>(
            sortBy: [SortDescriptor(\.visitDate, order: .reverse)]
        )
        let destinations = (try? context.fetch(descriptor)) ?? []
        return destinations.map {
            ProfileDestinationSnapshot(
                id: $0.id,
                name: $0.name,
                country: $0.country,
                province: $0.province,
                category: $0.category,
                isFavorite: $0.isFavorite,
                visitDate: $0.visitDate
            )
        }
    }

    static func fetchJourneyTrips(in context: ModelContext, limit: Int) -> [TravelTrip] {
        var descriptor = FetchDescriptor<TravelTrip>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.relationshipKeyPathsForPrefetching = [\.destinations]
        return (try? context.fetch(descriptor)) ?? []
    }

    static func fetchDestinations(year: Int, in context: ModelContext) -> [TravelDestination] {
        let calendar = Calendar.current
        guard
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
            let end = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        else { return [] }

        let descriptor = FetchDescriptor<TravelDestination>(
            predicate: #Predicate<TravelDestination> { destination in
                destination.visitDate >= start && destination.visitDate < end
            },
            sortBy: [SortDescriptor(\.visitDate, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func fetchDestinations(ids: [UUID], in context: ModelContext) -> [TravelDestination] {
        guard !ids.isEmpty else { return [] }
        var byID: [UUID: TravelDestination] = [:]
        byID.reserveCapacity(ids.count)
        for id in ids {
            var descriptor = FetchDescriptor<TravelDestination>(
                predicate: #Predicate<TravelDestination> { destination in
                    destination.id == id
                }
            )
            descriptor.fetchLimit = 1
            if let item = try? context.fetch(descriptor).first {
                byID[id] = item
            }
        }
        return ids.compactMap { byID[$0] }
    }

    // MARK: - Journey disk fingerprint

    private struct PersistedJourneyPayload: Codable {
        var totalCount: Int
        var trips: [PersistedJourneyItem]
    }

    private struct PersistedJourneyItem: Codable {
        var id: UUID
        var name: String
        var startDate: Date
        var endDate: Date
        var destinationCount: Int
    }

    private static var journeyFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Footprint", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("journey_list_snapshot.json")
    }

    private func loadJourneyFingerprintFromDisk() {
        let url = Self.journeyFileURL
        guard
            FileManager.default.fileExists(atPath: url.path),
            let data = try? Data(contentsOf: url),
            let payload = try? JSONDecoder().decode(PersistedJourneyPayload.self, from: data)
        else { return }
        journeyTripCount = payload.totalCount
    }

    private func persistJourneyFingerprint(trips: [TravelTrip], totalCount: Int) {
        let items = trips.map {
            PersistedJourneyItem(
                id: $0.id,
                name: $0.name,
                startDate: $0.startDate,
                endDate: $0.endDate,
                destinationCount: $0.destinationCount
            )
        }
        let payload = PersistedJourneyPayload(totalCount: totalCount, trips: items)
        let url = Self.journeyFileURL
        guard let data = try? JSONEncoder().encode(payload) else { return }
        persistQueue.async {
            try? data.write(to: url, options: [.atomic])
        }
    }
}
