//
//  PlaceTypeImageClassifier.swift
//  Footprint
//
//  通过 Apple Vision 对照片进行场景分类，自动建议地点类型。
//

import Foundation
import Vision
import UIKit

/// 使用 Vision 框架对照片进行场景分类，映射到 App 的地点类型（type key）
enum PlaceTypeImageClassifier {

    /// Vision 分类标识符 -> 地点类型 key 的映射（与 TravelDestination.placeTypeFilterOptions 一致）
    private static let identifierToPlaceType: [String: String] = {
        var map: [String: String] = [:]
        for id in ["beach", "canyon", "waterfall", "mountain", "forest", "lake", "river", "sky", "aurora", "volcano", "desert", "ocean", "cliff", "valley", "island", "coral_reef", "glacier", "iceberg", "cave", "blossom", "tree", "nature", "grass", "rock", "sunset", "sunrise", "blue_sky", "snow", "wave", "coast", "meadow", "wildflower", "bamboo", "palm_tree", "rainforest"] {
            map[id] = "natural_wonder"
        }
        for id in ["building", "city", "street", "downtown", "architecture", "bridge", "tower", "apartment", "alley", "airport", "skyscraper", "billboards", "subway", "highway", "road", "parking_lot", "factory", "chimney"] {
            map[id] = "urban_landscape"
        }
        for id in ["temple", "church", "castle", "monument", "museum", "arch", "palace", "belltower", "pyramid", "fort", "cathedral", "pagoda", "mosque", "synagogue", "statue", "ruins", "historical_site", "lighthouse"] {
            map[id] = "historical_culture"
        }
        for id in ["food", "restaurant", "dish", "cake", "bakery", "pizza", "sushi", "breakfast", "lunch", "dinner", "dessert", "cuisine", "barbecue", "buffet", "cafe", "coffee", "bread", "pastry", "salad", "soup", "pasta", "seafood", "steak", "burger", "sandwich", "ice_cream", "chocolate", "fruit_plate", "antipasti", "bruschetta", "caprese", "biryani"] {
            map[id] = "food_feast"
        }
        for id in ["amusement_park", "park", "bar", "aquarium", "carnival", "casino", "theater", "cinema", "playground", "bowling", "gym", "spa", "resort", "pool", "zoo", "concert", "stadium", "shopping_mall", "market", "ferris_wheel", "carousel"] {
            map[id] = "leisure_entertainment"
        }
        for id in ["camping", "hiking", "mountain", "skiing", "surfing", "climbing", "rafting", "canoe", "kayak", "cycling", "running", "trekking", "scuba_diving", "snorkeling", "fishing", "horseback_riding", "paragliding", "bungee", "zip_line", "cableway", "snowboarding"] {
            map[id] = "outdoor_adventure"
        }
        for id in ["art", "sculpture", "museum", "graffiti", "mural", "gallery", "street_art", "installation_art", "photography", "exhibition"] {
            map[id] = "artistic_checkin"
        }
        return map
    }()

    /// 根据图片数据推测地点类型（主线程外调用）
    static func suggestPlaceType(from imageData: Data) -> String? {
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else { return nil }

        let request = VNClassifyImageRequest()
        request.revision = VNClassifyImageRequestRevision1

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observations = request.results as? [VNClassificationObservation] else { return nil }

        for obs in observations {
            if obs.confidence < 0.15 { break }
            if let placeType = identifierToPlaceType[obs.identifier] {
                return placeType
            }
        }
        return nil
    }

    /// 异步版本：在后台执行分类，完成后回调主线程
    static func suggestPlaceType(from imageData: Data, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = suggestPlaceType(from: imageData)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
