// BroadcastManager.swift
// Monitors the broadcast extension's state from the main app.
// Listens to Darwin notifications + polls shared UserDefaults.

import ReplayKit
import SwiftUI
import Combine

// MARK: - BroadcastManager

final class BroadcastManager: NSObject, ObservableObject {

    // MARK: Published state

    @Published var status:       BroadcastStatus = .idle
    @Published var micLevel:     Float = 0
    @Published var sysLevel:     Float = 0
    @Published var elapsedTime:  TimeInterval = 0
    @Published var recordingID:  String = ""

    // MARK: Private

    private var defaults:    UserDefaults? { UserDefaults(suiteName: AppGroupConstants.appGroupID) }
    private var pollTimer:   Timer?
    private var clockTimer:  Timer?
    private var startTime:   Date?

    // MARK: - Init / Deinit

    override init() {
        super.init()
        registerDarwinNotifications()
        // Reset status to idle on fresh launch to clear any crash-induced stuck states.
        defaults?.set(BroadcastStatus.idle.rawValue, forKey: AppGroupConstants.broadcastStatusKey)
        defaults?.set(0.0, forKey: AppGroupConstants.micAudioLevelKey)
        defaults?.set(0.0, forKey: AppGroupConstants.sysAudioLevelKey)
        syncStatusFromDefaults()
    }

    deinit {
        unregisterDarwinNotifications()
        stopTimers()
    }

    // MARK: - Public: Trigger Broadcast

    /// Presents the system broadcast picker sheet inside the given view hierarchy.
    func showBroadcastPicker(in parent: UIViewController) {
        DispatchQueue.main.async {
            let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
            picker.preferredExtension = AppGroupConstants.broadcastBundleID
            picker.showsMicrophoneButton = false
            picker.alpha = 0.01 // Hidden to user but active to system
            parent.view.addSubview(picker)

            func findButton(in view: UIView) -> UIButton? {
                if let button = view as? UIButton { return button }
                for sub in view.subviews {
                    if let btn = findButton(in: sub) { return btn }
                }
                return nil
            }

            if let btn = findButton(in: picker) {
                btn.sendActions(for: .touchUpInside)
            }

            // Cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                picker.removeFromSuperview()
            }
        }
    }

    /// Requests the broadcast extension to stop recording via Darwin notification.
    func stopBroadcast() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(AppGroupConstants.broadcastRequestStopNotif as CFString),
            nil, nil, true
        )
    }

    // MARK: - Darwin Notification Handling

    private func registerDarwinNotifications() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let names = [
            AppGroupConstants.broadcastStartedNotif,
            AppGroupConstants.broadcastPausedNotif,
            AppGroupConstants.broadcastResumedNotif,
            AppGroupConstants.broadcastFinishedNotif
        ]
        // Use passUnretained: BroadcastManager lives for the app lifetime (@StateObject)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        for name in names {
            CFNotificationCenterAddObserver(
                center,
                selfPtr,
                { _, observer, name, _, _ in
                    guard let obs = observer else { return }
                    let mgr = Unmanaged<BroadcastManager>.fromOpaque(obs).takeUnretainedValue()
                    let n = (name?.rawValue as String?) ?? ""
                    DispatchQueue.main.async { mgr.handleNotification(n) }
                },
                name as CFString,
                nil,
                .deliverImmediately
            )
        }
    }

    private func unregisterDarwinNotifications() {
        // Use passUnretained to match the same pointer value used in registerDarwinNotifications
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    private func handleNotification(_ name: String) {
        syncStatusFromDefaults()
        switch name {
        case AppGroupConstants.broadcastStartedNotif:
            status = .recording
            startPolling()
            startClock()
        case AppGroupConstants.broadcastPausedNotif:
            status = .paused
            stopPolling()
        case AppGroupConstants.broadcastResumedNotif:
            status = .recording
            startPolling()
        case AppGroupConstants.broadcastFinishedNotif:
            status = .finished
            stopTimers()
            micLevel = 0
            sysLevel = 0
        default:
            break
        }
    }

    private func syncStatusFromDefaults() {
        let raw = defaults?.string(forKey: AppGroupConstants.broadcastStatusKey) ?? "idle"
        let newStatus = BroadcastStatus(rawValue: raw) ?? .idle
        DispatchQueue.main.async {
            self.status = newStatus
            self.recordingID = self.defaults?.string(forKey: AppGroupConstants.currentRecordingIDKey) ?? ""
            if let ts = self.defaults?.double(forKey: AppGroupConstants.recordingStartTimeKey), ts > 0 {
                self.startTime = Date(timeIntervalSince1970: ts)
            }
        }
    }

    // MARK: - Timers

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self = self, let d = self.defaults else { return }
            let mic = Float(d.double(forKey: AppGroupConstants.micAudioLevelKey))
            let sys = Float(d.double(forKey: AppGroupConstants.sysAudioLevelKey))
            DispatchQueue.main.async {
                self.micLevel = min(1, mic * 8)   // scale RMS → displayable 0-1
                self.sysLevel = min(1, sys * 8)
            }
        }
    }

    private func startClock() {
        startTime = startTime ?? Date()
        let capturedStart = startTime!
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.elapsedTime = Date().timeIntervalSince(capturedStart)
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func stopTimers() {
        pollTimer?.invalidate();  pollTimer = nil
        clockTimer?.invalidate(); clockTimer = nil
        elapsedTime = 0
    }

    // MARK: - Computed helpers

    var currentMicFilePath: String? { defaults?.string(forKey: AppGroupConstants.currentMicFilePathKey) }
    var currentSysFilePath: String? { defaults?.string(forKey: AppGroupConstants.currentSysFilePathKey) }
    var recordingStartTime: Date? {
        guard let ts = defaults?.double(forKey: AppGroupConstants.recordingStartTimeKey), ts > 0
        else { return nil }
        return Date(timeIntervalSince1970: ts)
    }
    var recordingEndTime: Date? {
        guard let ts = defaults?.double(forKey: AppGroupConstants.recordingEndTimeKey), ts > 0
        else { return nil }
        return Date(timeIntervalSince1970: ts)
    }
}
