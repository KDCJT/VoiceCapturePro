// AppGroupConstants.swift
// Shared between main app and broadcast extension targets.
// IMPORTANT: Replace "group.com.vcpro.recorder" with YOUR App Group ID,
//            which must match what's registered in your Apple Developer account.

import Foundation

// MARK: - App Group & Bundle IDs

enum AppGroupConstants {
    // ⚠️ Change these to match your Apple ID / developer team
    static let appGroupID            = "group.com.vcpro.recorder"
    static let broadcastBundleID     = "com.vcpro.recorder.broadcast"

    // ─── UserDefaults keys ──────────────────────────────────
    static let currentRecordingIDKey   = "currentRecordingID"
    static let recordingStartTimeKey   = "recordingStartTime"
    static let recordingEndTimeKey     = "recordingEndTime"
    static let broadcastStatusKey      = "broadcastStatus"
    static let currentMicFilePathKey   = "currentMicFilePath"
    static let currentSysFilePathKey   = "currentSysFilePath"
    static let selectedQualityKey      = "selectedQuality"
    static let micAudioLevelKey        = "micAudioLevel"
    static let sysAudioLevelKey        = "sysAudioLevel"

    // ─── Darwin notification names ──────────────────────────
    static let broadcastStartedNotif   = "com.vcpro.recorder.broadcastStarted"
    static let broadcastPausedNotif    = "com.vcpro.recorder.broadcastPaused"
    static let broadcastResumedNotif   = "com.vcpro.recorder.broadcastResumed"
    static let broadcastFinishedNotif  = "com.vcpro.recorder.broadcastFinished"
    static let broadcastRequestStopNotif = "com.vcpro.recorder.broadcastRequestStop"

    // ─── Shared container URL ───────────────────────────────
    /// Returns the App Group shared container if available.
    /// Falls back to the app's Documents directory when the
    /// App Group entitlement isn't provisioned (e.g. TrollStore).
    static var containerURL: URL? {
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID) {
            return groupURL
        }
        // Fallback: use the app's own Documents directory
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    // ─── Logging Utility ──────────────────────────────────────
    static func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logLine = "[\(timestamp)] \(message)\n"
        print(logLine)
        
        guard let container = containerURL else { return }
        let logURL = container.appendingPathComponent("extension_debug.log")
        
        if let data = logLine.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logURL)
            }
        }
    }

    static func clearLogs() {
        guard let container = containerURL else { return }
        let logURL = container.appendingPathComponent("extension_debug.log")
        try? FileManager.default.removeItem(at: logURL)
    }

    static func readLogs() -> String {
        guard let container = containerURL else { return "No container" }
        let logURL = container.appendingPathComponent("extension_debug.log")
        guard FileManager.default.fileExists(atPath: logURL.path) else { return "No logs recorded yet" }
        if let content = try? String(contentsOf: logURL, encoding: .utf8) {
            return content
        }
        return "Failed to read log file"
    }
}

// MARK: - Broadcast Status

enum BroadcastStatus: String, Codable {
    case idle      = "idle"
    case recording = "recording"
    case paused    = "paused"
    case finished  = "finished"
}
