// RecordingManager.swift
// Orchestrates the full recording lifecycle:
//   - Mic-only mode  → AudioRecordingEngine
//   - Full capture   → BroadcastManager (extension) + optional local mic monitor
// After a recording finishes it saves a Recording to RecordingsStore.

import SwiftUI
import Combine
import AVFoundation

// MARK: - Recording Mode

enum RecordingMode: String, CaseIterable, Identifiable {
    case micOnly     = "纯麦克风"
    case fullCapture = "双轨全捕获"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .micOnly:     return "mic.fill"
        case .fullCapture: return "waveform.and.mic"
        }
    }
    var description: String {
        switch self {
        case .micOnly:
            return "仅录制麦克风\n立即开始，无需授权"
        case .fullCapture:
            return "同时录制系统声音和麦克风\n支持微信通话双轨分离\n需点击系统授权"
        }
    }
}

// MARK: - RecordingManager

final class RecordingManager: ObservableObject {

    // MARK: Dependencies (injected via environment)
    let micEngine       = AudioRecordingEngine()
    let broadcastMgr    = BroadcastManager()
    let locationMgr     = LocationManager()

    // MARK: Published state
    @Published var recordings:       [Recording] = []
    @Published var isRecording       = false
    @Published var currentMode:      RecordingMode  = .fullCapture
    @Published var selectedQuality:  AudioQuality   = .high
    @Published var currentNotes:     String         = ""
    @Published var currentTags:      [String]       = []

    // Combined audio level (0-1) for waveform display
    @Published var displayLevel:     Float = 0

    // MARK: Private
    private var cancellables = Set<AnyCancellable>()
    private var sessionStartDate: Date?

    // MARK: Init

    init() {
        loadRecordings()
        setupObservers()
        locationMgr.requestPermission()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Mic-only engine level → displayLevel
        micEngine.$audioLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] lvl in
                guard let self = self, self.currentMode == .micOnly else { return }
                self.displayLevel = lvl
            }
            .store(in: &cancellables)

        // Broadcast combined level → displayLevel
        broadcastMgr.$micLevel
            .combineLatest(broadcastMgr.$sysLevel)
            .receive(on: RunLoop.main)
            .map { m, s in max(m, s) }
            .sink { [weak self] lvl in
                guard let self = self, self.currentMode == .fullCapture else { return }
                self.displayLevel = lvl
            }
            .store(in: &cancellables)

        // Broadcast finished/started -> update state and save recording
        broadcastMgr.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                if self.currentMode == .fullCapture {
                    switch status {
                    case .recording, .paused:
                        self.isRecording = true
                    case .finished:
                        self.onBroadcastFinished()
                        self.isRecording = false
                    case .idle:
                        self.isRecording = false
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Start Recording

    func startRecording(in viewController: UIViewController? = nil) {
        sessionStartDate = Date()
        currentNotes = ""
        locationMgr.fetchCurrentLocation()

        switch currentMode {

        case .micOnly:
            guard let url = makeFileURL(suffix: "_mic.\(selectedQuality.fileExtension)") else { return }
            do {
                try micEngine.start(outputURL: url, quality: selectedQuality)
                isRecording = true
            } catch {
                print("❌ Mic engine start failed:", error.localizedDescription)
            }

        case .fullCapture:
            // Save quality preference so extension can read it
            UserDefaults(suiteName: AppGroupConstants.appGroupID)?
                .set(selectedQuality.rawValue, forKey: AppGroupConstants.selectedQualityKey)

            // Show the system broadcast picker
            guard let vc = viewController else {
                showBroadcastPickerFallback()
                return
            }
            broadcastMgr.showBroadcastPicker(in: vc)
        }
    }

    func stopRecording() {
        switch currentMode {

        case .micOnly:
            guard let fileURL = micEngine.stop() else { return }
            isRecording  = false
            displayLevel = 0

            let duration = Date().timeIntervalSince(sessionStartDate ?? Date())
            let size     = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0

            let recording = Recording(
                title:        autoTitle(),
                startDate:    sessionStartDate ?? Date(),
                endDate:      Date(),
                duration:     duration,
                micFilePath:  fileURL.path,
                sysFilePath:  nil,
                latitude:     locationMgr.currentLocation?.coordinate.latitude,
                longitude:    locationMgr.currentLocation?.coordinate.longitude,
                locationName: locationMgr.currentLocationName,
                notes:        currentNotes,
                quality:      selectedQuality.rawValue,
                fileSize:     size,
                tags:         currentTags,
                isMicOnly:    true
            )
            save(recording)

        case .fullCapture:
            // Request the broadcast extension to stop via Darwin notification
            broadcastMgr.stopBroadcast()
        }
    }

    // MARK: - Broadcast Finished Handler

    private func onBroadcastFinished() {
        isRecording  = false
        displayLevel = 0

        guard let micPath = broadcastMgr.currentMicFilePath else { return }

        let start    = broadcastMgr.recordingStartTime ?? sessionStartDate ?? Date()
        let end      = broadcastMgr.recordingEndTime   ?? Date()
        let duration = end.timeIntervalSince(start)
        let micSize  = (try? URL(fileURLWithPath: micPath).resourceValues(
            forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
        let sysSize  = broadcastMgr.currentSysFilePath.flatMap { p in
            try? URL(fileURLWithPath: p).resourceValues(forKeys: [.fileSizeKey]).fileSize
        }.map { Int64($0) } ?? 0

        let recording = Recording(
            title:        autoTitle(),
            startDate:    start,
            endDate:      end,
            duration:     duration,
            micFilePath:  micPath,
            sysFilePath:  broadcastMgr.currentSysFilePath,
            latitude:     locationMgr.currentLocation?.coordinate.latitude,
            longitude:    locationMgr.currentLocation?.coordinate.longitude,
            locationName: locationMgr.currentLocationName,
            notes:        currentNotes,
            quality:      selectedQuality.rawValue,
            fileSize:     micSize + sysSize,
            tags:         currentTags,
            isMicOnly:    false
        )
        save(recording)
    }

    // MARK: - Library Operations

    func loadRecordings() {
        recordings = RecordingsStore.shared.load()
    }

    func delete(_ recording: Recording) {
        RecordingsStore.shared.delete(ids: [recording.id])
        recordings.removeAll { $0.id == recording.id }
    }

    func update(_ recording: Recording) {
        RecordingsStore.shared.update(recording)
        if let idx = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[idx] = recording
        }
    }

    // MARK: - Helpers

    private func save(_ recording: Recording) {
        RecordingsStore.shared.append(recording)
        recordings.insert(recording, at: 0)
        sessionStartDate = nil
        currentNotes     = ""
        currentTags      = []
    }

    private func autoTitle() -> String {
        let f = DateFormatter()
        f.dateFormat = "MM月dd日 HH:mm"
        let base = f.string(from: Date())
        let loc  = locationMgr.currentLocationName
        return loc.isEmpty ? base : "\(base) · \(loc)"
    }

    private func makeFileURL(suffix: String) -> URL? {
        AppGroupConstants.containerURL?
            .appendingPathComponent(UUID().uuidString + suffix)
    }

    private func showBroadcastPickerFallback() {
        // When no UIViewController is available, post a notification for the root VC to handle
        NotificationCenter.default.post(name: .showBroadcastPicker, object: nil)
    }
}

extension Notification.Name {
    static let showBroadcastPicker = Notification.Name("com.vcpro.showBroadcastPicker")
}
