// Recording.swift
// Data model for a completed recording session.

import Foundation

// MARK: - Recording Model

struct Recording: Codable, Identifiable, Hashable {
    var id:           UUID
    var title:        String
    var startDate:    Date
    var endDate:      Date?
    var duration:     TimeInterval      // seconds
    var micFilePath:  String            // path in App Group container
    var sysFilePath:  String?           // nil for mic-only recordings
    var latitude:     Double?
    var longitude:    Double?
    var locationName: String?
    var notes:        String
    var quality:      String            // AudioQuality.rawValue
    var fileSize:     Int64             // bytes
    var tags:         [String]
    var isMicOnly:    Bool              // true = no system audio track

    // MARK: Init

    init(
        id:           UUID         = UUID(),
        title:        String,
        startDate:    Date         = Date(),
        endDate:      Date?        = nil,
        duration:     TimeInterval = 0,
        micFilePath:  String,
        sysFilePath:  String?      = nil,
        latitude:     Double?      = nil,
        longitude:    Double?      = nil,
        locationName: String?      = nil,
        notes:        String       = "",
        quality:      String       = AudioQuality.high.rawValue,
        fileSize:     Int64        = 0,
        tags:         [String]     = [],
        isMicOnly:    Bool         = false
    ) {
        self.id           = id
        self.title        = title
        self.startDate    = startDate
        self.endDate      = endDate
        self.duration     = duration
        self.micFilePath  = micFilePath
        self.sysFilePath  = sysFilePath
        self.latitude     = latitude
        self.longitude    = longitude
        self.locationName = locationName
        self.notes        = notes
        self.quality      = quality
        self.fileSize     = fileSize
        self.tags         = tags
        self.isMicOnly    = isMicOnly
    }

    // MARK: Computed helpers

    var micFileURL: URL { URL(fileURLWithPath: micFilePath) }
    var sysFileURL: URL? { sysFilePath.map { URL(fileURLWithPath: $0) } }

    var formattedDuration: String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        let s = Int(duration) % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy年MM月dd日 HH:mm"
        return f.string(from: startDate)
    }

    var formattedFileSize: String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle   = .file
        return f.string(fromByteCount: fileSize)
    }

    var modeLabel: String { isMicOnly ? "纯麦克风" : "双轨道" }
}

// MARK: - Recordings Store

/// Persists recordings list as JSON in the App Group shared container.
final class RecordingsStore {
    static let shared = RecordingsStore()
    private init() {}

    private let fileName = "recordings.json"
    private var storeURL: URL? {
        AppGroupConstants.containerURL?.appendingPathComponent(fileName)
    }

    func load() -> [Recording] {
        guard let url = storeURL, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Recording].self, from: data)) ?? []
    }

    func save(_ recordings: [Recording]) {
        guard let url = storeURL,
              let data = try? JSONEncoder().encode(recordings) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func append(_ recording: Recording) {
        var list = load()
        list.insert(recording, at: 0)
        save(list)
    }

    func delete(ids: Set<UUID>) {
        var list = load()
        let removed = list.filter { ids.contains($0.id) }
        list.removeAll { ids.contains($0.id) }
        save(list)
        // Also remove audio files
        for r in removed {
            try? FileManager.default.removeItem(at: r.micFileURL)
            r.sysFileURL.map { try? FileManager.default.removeItem(at: $0) }
        }
    }

    func update(_ recording: Recording) {
        var list = load()
        if let idx = list.firstIndex(where: { $0.id == recording.id }) {
            list[idx] = recording
        }
        save(list)
    }
}
