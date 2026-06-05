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

    // ─── Shared container URL ───────────────────────────────
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }
}

// MARK: - Broadcast Status

enum BroadcastStatus: String, Codable {
    case idle      = "idle"
    case recording = "recording"
    case paused    = "paused"
    case finished  = "finished"
}
