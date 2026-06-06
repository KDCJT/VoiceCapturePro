// SampleHandler.swift
// Broadcast Upload Extension – captures BOTH system audio and microphone audio
// via ReplayKit and writes them to TWO separate .caf files in the App Group container.
//
// ─── Why this works with earphones ──────────────────────────────────────────────
// ReplayKit captures audio at the software mixing layer, BEFORE the system routes
// it to any physical output device (speakers, wired earphones, AirPods, Bluetooth).
// So connecting earphones does NOT prevent us from capturing the app's audio output.
// ────────────────────────────────────────────────────────────────────────────────

import ReplayKit
import AVFoundation

class SampleHandler: RPBroadcastSampleHandler {

    // MARK: - Properties

    private let groupID = AppGroupConstants.appGroupID
    private var recordingID = ""

    // Microphone writer (mono, 48 kHz, 16-bit PCM)
    private var micWriter:      AVAssetWriter?
    private var micInput:       AVAssetWriterInput?

    // System audio writer (stereo, 48 kHz, 16-bit PCM)
    private var sysWriter:      AVAssetWriter?
    private var sysInput:       AVAssetWriterInput?

    // Shared session state
    private var sessionBegan     = false
    private var sessionStartTime: CMTime?

    // Shared state
    private var defaults: UserDefaults? { UserDefaults(suiteName: groupID) }

    // MARK: - Broadcast Lifecycle

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        recordingID = UUID().uuidString

        // Persist state so the main app can track progress
        defaults?.set(recordingID,              forKey: AppGroupConstants.currentRecordingIDKey)
        defaults?.set(Date().timeIntervalSince1970, forKey: AppGroupConstants.recordingStartTimeKey)
        defaults?.set(BroadcastStatus.recording.rawValue, forKey: AppGroupConstants.broadcastStatusKey)

        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupID
        ) else {
            finishBroadcastWithError(makeError("无法访问 App Group 容器，请确认已配置 App Group。"))
            return
        }

        let micURL = container.appendingPathComponent("\(recordingID)_mic.caf")
        let sysURL = container.appendingPathComponent("\(recordingID)_sys.caf")

        defaults?.set(micURL.path, forKey: AppGroupConstants.currentMicFilePathKey)
        defaults?.set(sysURL.path, forKey: AppGroupConstants.currentSysFilePathKey)

        do {
            // ─── Microphone writer (mono) ───────────────────────────────────
            micWriter = try AVAssetWriter(outputURL: micURL, fileType: .caf)
            let micSettings: [String: Any] = [
                AVFormatIDKey:             kAudioFormatLinearPCM,
                AVSampleRateKey:           48000.0,
                AVNumberOfChannelsKey:     1,
                AVLinearPCMBitDepthKey:    16,
                AVLinearPCMIsFloatKey:     false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
            let mi = AVAssetWriterInput(mediaType: .audio, outputSettings: micSettings)
            mi.expectsMediaDataInRealTime = true
            if micWriter!.canAdd(mi) { micWriter!.add(mi) }
            micInput = mi
            micWriter?.startWriting()

            // ─── System audio writer (stereo) ───────────────────────────────
            sysWriter = try AVAssetWriter(outputURL: sysURL, fileType: .caf)
            let sysSettings: [String: Any] = [
                AVFormatIDKey:             kAudioFormatLinearPCM,
                AVSampleRateKey:           48000.0,
                AVNumberOfChannelsKey:     2,
                AVLinearPCMBitDepthKey:    16,
                AVLinearPCMIsFloatKey:     false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
            let si = AVAssetWriterInput(mediaType: .audio, outputSettings: sysSettings)
            si.expectsMediaDataInRealTime = true
            if sysWriter!.canAdd(si) { sysWriter!.add(si) }
            sysInput = si
            sysWriter?.startWriting()

        } catch {
            finishBroadcastWithError(error)
            return
        }

        notify(AppGroupConstants.broadcastStartedNotif)
        registerStopNotification()
    }

    override func broadcastPaused() {
        defaults?.set(BroadcastStatus.paused.rawValue, forKey: AppGroupConstants.broadcastStatusKey)
        notify(AppGroupConstants.broadcastPausedNotif)
    }

    override func broadcastResumed() {
        defaults?.set(BroadcastStatus.recording.rawValue, forKey: AppGroupConstants.broadcastStatusKey)
        notify(AppGroupConstants.broadcastResumedNotif)
    }

    override func broadcastFinished() {
        defaults?.set(Date().timeIntervalSince1970, forKey: AppGroupConstants.recordingEndTimeKey)
        defaults?.set(BroadcastStatus.finished.rawValue, forKey: AppGroupConstants.broadcastStatusKey)
        finalizeRecording()
    }

    // MARK: - Sample Processing

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                      with sampleBufferType: RPSampleBufferType) {
        // Start session on first buffer of any audio type
        if !sessionBegan && (sampleBufferType == .audioMic || sampleBufferType == .audioApp) {
            let pts = sampleBuffer.presentationTimeStamp
            micWriter?.startSession(atSourceTime: pts)
            sysWriter?.startSession(atSourceTime: pts)
            sessionBegan = true
            sessionStartTime = pts
        }

        switch sampleBufferType {

        case .audioMic:
            guard let writer = micWriter, writer.status == .writing,
                  let input  = micInput, sessionBegan else { return }
            if input.isReadyForMoreMediaData { input.append(sampleBuffer) }
            // Report level so HomeView waveform can animate
            defaults?.set(rmsLevel(sampleBuffer), forKey: AppGroupConstants.micAudioLevelKey)

        case .audioApp:
            guard let writer = sysWriter, writer.status == .writing,
                  let input  = sysInput, sessionBegan else { return }
            if input.isReadyForMoreMediaData { input.append(sampleBuffer) }
            defaults?.set(rmsLevel(sampleBuffer), forKey: AppGroupConstants.sysAudioLevelKey)

        case .video:
            break // Screen video not needed

        @unknown default:
            break
        }
    }

    // MARK: - Finalization

    private func finalizeRecording() {
        unregisterStopNotification()
        let group = DispatchGroup()

        group.enter()
        micInput?.markAsFinished()
        micWriter?.finishWriting { group.leave() }

        group.enter()
        sysInput?.markAsFinished()
        sysWriter?.finishWriting { group.leave() }

        group.notify(queue: .global()) {
            self.notify(AppGroupConstants.broadcastFinishedNotif)
        }
    }

    // MARK: - Helpers

    /// Calculates the RMS (root-mean-square) audio level from a 16-bit PCM CMSampleBuffer.
    private func rmsLevel(_ sampleBuffer: CMSampleBuffer) -> Float {
        guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { return 0 }

        let offset = 0
        var lengthAtOffset = 0
        var totalLength    = 0
        var ptr: UnsafeMutablePointer<Int8>?

        guard CMBlockBufferGetDataPointer(block,
                                          atOffset: offset,
                                          lengthAtOffsetOut: &lengthAtOffset,
                                          totalLengthOut: &totalLength,
                                          dataPointerOut: &ptr) == noErr,
              let rawPtr = ptr, totalLength > 0 else { return 0 }

        let count = totalLength / MemoryLayout<Int16>.size
        guard count > 0 else { return 0 }

        var sumSq: Float = 0
        rawPtr.withMemoryRebound(to: Int16.self, capacity: count) { p in
            for i in 0..<count {
                let s = Float(p[i]) / Float(Int16.max)
                sumSq += s * s
            }
        }
        return sqrt(sumSq / Float(count))
    }

    private func makeError(_ msg: String) -> Error {
        NSError(domain: "VoiceCapturePro.Broadcast",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: msg])
    }

    private func notify(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString),
            nil, nil, true
        )
    }

    private func registerStopNotification() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            center,
            selfPtr,
            { _, observer, _, _, _ in
                guard let obs = observer else { return }
                let handler = Unmanaged<SampleHandler>.fromOpaque(obs).takeUnretainedValue()
                DispatchQueue.main.async {
                    handler.perform(#selector(RPBroadcastSampleHandler.finishBroadcastWithError(_:)), with: nil)
                }
            },
            AppGroupConstants.broadcastRequestStopNotif as CFString,
            nil,
            .deliverImmediately
        )
    }

    private func unregisterStopNotification() {
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
    }
}
