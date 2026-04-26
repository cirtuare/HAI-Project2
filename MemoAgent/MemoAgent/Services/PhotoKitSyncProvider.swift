// PhotoKitSyncProvider.swift
// MemoAgent V2 — Photos integration via PhotoKit
//
// Privacy architecture:
// - Only PHAsset.localIdentifier + metadata stored in NodeRecord.
// - Full image bytes are NEVER written to disk or SwiftData.
// - Thumbnails are generated on-demand and held in NSCache only.

import Foundation
import Photos
import AppKit
import CoreGraphics

// MARK: - PhotoKitSyncProvider

final class PhotoKitSyncProvider {
    static let shared = PhotoKitSyncProvider()

    // Thumbnail cache: keyed by PHAsset.localIdentifier
    private let thumbnailCache = NSCache<NSString, NSImage>()

    private init() {
        thumbnailCache.countLimit = 200
    }

    // MARK: - Authorization

    var authorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    // MARK: - Fetch metadata (no image data)

    /// Fetch recent photo metadata and return GraphNode drafts.
    /// For the `.hobby` persona: higher limit, location/time metadata emphasised.
    func fetchRecentPhotoNodes(for persona: PersonaRecord, limit: Int = 40) -> [GraphNode] {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else { return [] }

        let isHobby = persona.personaType == .hobby
        let effectiveLimit = isHobby ? max(limit, 60) : limit

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = effectiveLimit
        // Hobby persona: include all media, not just recent photos
        if !isHobby {
            // Non-hobby: skip screenshots to reduce noise
            options.predicate = NSPredicate(
                format: "NOT (mediaSubtype & %d != 0)",
                PHAssetMediaSubtype.photoScreenshot.rawValue
            )
        }

        let assets = PHAsset.fetchAssets(with: .image, options: options)
        let formatter = ISO8601DateFormatter()
        var nodes: [GraphNode] = []

        assets.enumerateObjects { [self] asset, _, _ in
            let dateStr = asset.creationDate.map { formatter.string(from: $0).prefix(10).description }
                ?? formatter.string(from: Date()).prefix(10).description
            let location = asset.location.map {
                "\(String(format: "%.4f", $0.coordinate.latitude)), \(String(format: "%.4f", $0.coordinate.longitude))"
            }

            // Hobby: richer summary with location + time of day
            let summary: String
            if isHobby {
                var parts: [String] = []
                if let loc = location { parts.append("📍 \(loc)") }
                if let created = asset.creationDate {
                    let hour = Calendar.current.component(.hour, from: created)
                    parts.append(timeOfDayLabel(hour: hour))
                }
                if asset.isFavorite { parts.append("⭐ 즐겨찾기") }
                summary = parts.joined(separator: " · ").nilIfEmpty ?? "사진 기록"
            } else {
                summary = [location.map { "📍 \($0)" }, asset.isFavorite ? "⭐ 즐겨찾기" : nil]
                    .compactMap { $0 }.joined(separator: " · ").nilIfEmpty ?? "사진 기록"
            }

            let isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)
            var tags = ["사진"]
            if isScreenshot { tags.append("스크린샷") }
            if location != nil && isHobby { tags.append("위치기록") }
            if asset.isFavorite { tags.append("즐겨찾기") }

            let node = GraphNode(
                id: UUID().uuidString,
                title: isHobby ? "사진 \(dateStr)\(location != nil ? " (위치 있음)" : "")" : "사진 \(dateStr)",
                summary: summary,
                type: .photo,
                date: dateStr,
                originalText: "Photo: \(asset.localIdentifier) | \(dateStr) | location: \(location ?? "none") | favorite: \(asset.isFavorite)",
                isImportant: asset.isFavorite,
                tags: tags,
                position: CGPoint(x: Double.random(in: -600...600), y: Double.random(in: -400...400)),
                sourceSystem: .photos,
                externalID: asset.localIdentifier,
                personaIDs: [persona.id]
            )
            nodes.append(node)
        }
        return nodes
    }

    private func timeOfDayLabel(hour: Int) -> String {
        switch hour {
        case 5..<9:   return "🌅 아침"
        case 9..<12:  return "☀️ 오전"
        case 12..<14: return "🌞 점심"
        case 14..<18: return "🌤 오후"
        case 18..<21: return "🌇 저녁"
        default:       return "🌙 밤"
        }
    }

    // MARK: - Thumbnail (on-demand, cached, never persisted)

    func thumbnail(for assetID: String, size: CGSize = CGSize(width: 120, height: 120)) async -> NSImage? {
        let key = assetID as NSString

        // Return from cache if available
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }

        // Fetch from Photos
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = fetchResult.firstObject else { return nil }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = false
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { [weak self] image, _ in
                if let image {
                    self?.thumbnailCache.setObject(image, forKey: key)
                }
                continuation.resume(returning: image)
            }
        }
    }

    func clearCache() {
        thumbnailCache.removeAllObjects()
    }
}

// MARK: - String helper

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? { self?.nilIfEmpty }
}
