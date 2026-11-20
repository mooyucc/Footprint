//
//  ProvinceTicketDiskCache.swift
//  Footprint
//
//  省份票根的选定照片和底色。地点快照未变时直接读取，不再逐省重算。
//

import SwiftUI
import UIKit

@MainActor
enum ProvinceTicketDiskCache {
    /// 本会话写入或命中缓存时的地点版本。版本变了就不用旧文件。
    private static var appliedRevision: Int?
    /// 本进程是否已算过票面。冷启动不读盘，以便封面随机换一批。
    private static var hasComputedThisLaunch = false

    static func fingerprint(of snapshots: [ProfileDestinationSnapshot]) -> String {
        let lines = snapshots
            .filter { snapshot in
                snapshot.country == "中国" || snapshot.country == "CN" || snapshot.country == "China"
            }
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { "\($0.id.uuidString)|\($0.province)|\($0.visitDate.timeIntervalSince1970)" }
        return String(BadgeTicketBarcodeSeed.make(lines.joined(separator: "\n")))
    }

    static func load(fingerprint: String) -> [String: ProvinceTicketReady]? {
        // 冷启动跳过磁盘，走 ProvinceTicketPicker 随机；同进程内首次算完后才读盘复用。
        guard hasComputedThisLaunch else { return nil }
        let revision = DestinationDataRevision.shared.revision
        if let appliedRevision, appliedRevision != revision {
            return nil
        }
        guard let payload = read(), payload.fingerprint == fingerprint, !payload.items.isEmpty else {
            return nil
        }
        appliedRevision = revision
        var ready: [String: ProvinceTicketReady] = [:]
        ready.reserveCapacity(payload.items.count)
        for item in payload.items {
            ready[item.id] = item.makeReady()
        }
        return ready
    }

    static func save(fingerprint: String, items: [String: ProvinceTicketReady]) {
        guard !items.isEmpty else { return }
        hasComputedThisLaunch = true
        appliedRevision = DestinationDataRevision.shared.revision
        let payload = Payload(
            fingerprint: fingerprint,
            items: items.map { id, ready in StoredTicket(id: id, ready: ready) }
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let url = fileURL
        DispatchQueue.global(qos: .utility).async {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Footprint", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("province_tickets.json")
    }

    private static func read() -> Payload? {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }
}

private struct Payload: Codable {
    var fingerprint: String
    var items: [StoredTicket]
}

private struct StoredColor: Codable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(_ color: Color) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        self.r = Double(r)
        self.g = Double(g)
        self.b = Double(b)
        self.a = Double(a == 0 ? 1 : a)
    }

    var color: Color {
        Color(red: r, green: g, blue: b, opacity: a)
    }
}

private struct StoredTicket: Codable {
    var id: String
    var placeName: String
    var latinLines: String
    var dateText: String
    var serialText: String
    var sideCode: String
    var barcodeSeed: UInt64
    var destinationId: UUID?
    var paletteIndex: Int
    var ground: StoredColor
    var paper: StoredColor
    var thumbnail: Data?

    init(id: String, ready: ProvinceTicketReady) {
        self.id = id
        self.placeName = ready.face.placeName
        self.latinLines = ready.face.latinLines
        self.dateText = ready.face.dateText
        self.serialText = ready.face.serialText
        self.sideCode = ready.face.sideCode
        self.barcodeSeed = ready.face.barcodeSeed
        self.destinationId = ready.face.destinationId
        self.paletteIndex = ready.face.paletteIndex
        self.ground = StoredColor(ready.palette.ground)
        self.paper = StoredColor(ready.palette.paper)
        self.thumbnail = ready.face.thumbnailData
    }

    func makeReady() -> ProvinceTicketReady {
        let face = ProvinceTicketFace(
            provinceName: placeName,
            placeName: placeName,
            latinLines: latinLines,
            dateText: dateText,
            serialText: serialText,
            sideCode: sideCode,
            barcodeSeed: barcodeSeed,
            destinationId: destinationId,
            thumbnailData: thumbnail,
            fullData: nil,
            paletteIndex: paletteIndex
        )
        let image = thumbnail.flatMap { UIImage(data: $0) }
        return ProvinceTicketReady(
            face: face,
            image: image,
            palette: ProvinceTicketPalette(ground: ground.color, paper: paper.color)
        )
    }
}
