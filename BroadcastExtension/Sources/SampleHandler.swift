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
        AppGroupConstants.log("=== Broadcast starting... ID: \(recordingID) ===")

        // Persist state so the main app can track progress
        defaults?.set(recordingID,              forKey: AppGroupConstants.currentRecordingIDKey)
        defaults?.set(Date().timeIntervalSince1970, forKey: AppGroupConstants.recordingStartTimeKey)
        defaults?.set(BroadcastStatus.recording.rawValue, forKey: AppGroupConstants.broadcastStatusKey)

        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupID
        ) else {
            let errorMsg = "无法访问 App Group 容器，请确认已配置 App Group。"
            AppGroupConstants.log("Error: \(errorMsg)")
            finishBroadcastWithError(makeError(errorMsg))
            return
        }

        // Read quality from UserDefaults and set file extension / format
        let qualityRaw = defaults?.string(forKey: AppGroupConstants.selectedQualityKey) ?? "高质量"
        let quality = AudioQuality(rawValue: qualityRaw) ?? .high
        let fileExt = quality.fileExtension
        let fileType = quality.fileType
        AppGroupConstants.log("Selected quality setting: \(quality.rawValue), file extension: .\(fileExt)")

        let micURL = container.appendingPathComponent("\(recordingID)_mic.\(fileExt)")
        let sysURL = container.appendingPathComponent("\(recordingID)_sys.\(fileExt)")

        AppGroupConstants.log("Writing mic file to: \(micURL.path)")
        AppGroupConstants.log("Writing sys file to: \(sysURL.path)")

        defaults?.set(micURL.path, forKey: AppGroupConstants.currentMicFilePathKey)
        defaults?.set(sysURL.path, forKey: AppGroupConstants.currentSysFilePathKey)

        // Configure dynamic settings based on AAC or Lossless PCM
        let micSettings: [String: Any]
        let sysSettings: [String: Any]

        if quality == .lossless {
            micSettings = [
                AVFormatIDKey:             kAudioFormatLinearPCM,
                AVSampleRateKey:           48000.0,
                AVNumberOfChannelsKey:     1,
                AVLinearPCMBitDepthKey:    24,
                AVLinearPCMIsFloatKey:     false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
            sysSettings = [
                AVFormatIDKey:             kAudioFormatLinearPCM,
                AVSampleRateKey:           48000.0,
                AVNumberOfChannelsKey:     2,
                AVLinearPCMBitDepthKey:    24,
                AVLinearPCMIsFloatKey:     false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
        } else {
            micSettings = [
                AVFormatIDKey:             kAudioFormatMPEG4AAC,
                AVSampleRateKey:           quality.sampleRate,
                AVNumberOfChannelsKey:     1,
                AVEncoderBitRateKey:       quality.bitRate / 2
            ]
            sysSettings = [
                AVFormatIDKey:             kAudioFormatMPEG4AAC,
                AVSampleRateKey:           quality.sampleRate,
                AVNumberOfChannelsKey:     2,
                AVEncoderBitRateKey:       quality.bitRate
            ]
        }

        do {
            // ─── Microphone writer ───────────────────────────────────
            micWriter = try AVAssetWriter(outputURL: micURL, fileType: fileType)
            let mi = AVAssetWriterInput(mediaType: .audio, outputSettings: micSettings)
            mi.expectsMediaDataInRealTime = true
            if micWriter!.canAdd(mi) { micWriter!.add(mi) }
            micInput = mi
            micWriter?.startWriting()
            if micWriter?.status == .failed {
                throw micWriter?.error ?? makeError("Microphone writer failed to start writing")
            }

            // ─── System audio writer ───────────────────────────────
            sysWriter = try AVAssetWriter(outputURL: sysURL, fileType: fileType)
            let si = AVAssetWriterInput(mediaType: .audio, outputSettings: sysSettings)
            si.expectsMediaDataInRealTime = true
            if sysWriter!.canAdd(si) { sysWriter!.add(si) }
            sysInput = si
            sysWriter?.startWriting()
            if sysWriter?.status == .failed {
                throw sysWriter?.error ?? makeError("System writer failed to start writing")
            }

            AppGroupConstants.log("AVAssetWriters initialized dynamically and startWriting() succeeded.")
        } catch {
            AppGroupConstants.log("Error initializing AVAssetWriter: \(error.localizedDescription)")
            finishBroadcastWithError(error)
            return
        }

        notify(AppGroupConstants.broadcastStartedNotif)
        registerStopNotification()
        AppGroupConstants.log("broadcastStarted completed successfully. Stop notification observer registered.")
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
            AppGroupConstants.log("Extension received first audio buffer. Starting sessions at PTS: \(pts.value)/\(pts.timescale). Type: \(sampleBufferType == .audioMic ? "Mic" : "App")")
            
            if let micW = micWriter, micW.status == .writing {
                micW.startSession(atSourceTime: pts)
            } else {
                AppGroupConstants.log("Mic writer cannot start session. Status: \(micWriter?.status.rawValue ?? -1), Error: \(micWriter?.error?.localizedDescription ?? "none")")
            }
            
            if let sysW = sysWriter, sysW.status == .writing {
                sysW.startSession(atSourceTime: pts)
            } else {
                AppGroupConstants.log("Sys writer cannot start session. Status: \(sysWriter?.status.rawValue ?? -1), Error: \(sysWriter?.error?.localizedDescription ?? "none")")
            }
            
            sessionBegan = true
            sessionStartTime = pts
        }

        switch sampleBufferType {

        case .audioMic:
            guard let writer = micWriter, let input = micInput, sessionBegan else { return }
            if writer.status == .failed {
                AppGroupConstants.log("Mic writer is in failed state: \(writer.error?.localizedDescription ?? "unknown")")
                return
            }
            guard writer.status == .writing else { return }
            
            if input.isReadyForMoreMediaData {
                if !input.append(sampleBuffer) {
                    AppGroupConstants.log("Mic writer failed to append sample buffer: \(writer.error?.localizedDescription ?? "unknown")")
                }
            }
            // Report level so HomeView waveform can animate
            defaults?.set(rmsLevel(sampleBuffer), forKey: AppGroupConstants.micAudioLevelKey)

        case .audioApp:
            guard let writer = sysWriter, let input = sysInput, sessionBegan else { return }
            if writer.status == .failed {
                AppGroupConstants.log("Sys writer is in failed state: \(writer.error?.localizedDescription ?? "unknown")")
                return
            }
            guard writer.status == .writing else { return }
            
            if input.isReadyForMoreMediaData {
                if !input.append(sampleBuffer) {
                    AppGroupConstants.log("Sys writer failed to append sample buffer: \(writer.error?.localizedDescription ?? "unknown")")
                }
            }
            defaults?.set(rmsLevel(sampleBuffer), forKey: AppGroupConstants.sysAudioLevelKey)

        case .video:
            break // Screen video not needed

        @unknown default:
            break
        }
    }

    // MARK: - Finalization

    private func finalizeRecording() {
        AppGroupConstants.log("finalizeRecording called. Finalizing audio writers...")
        unregisterStopNotification()
        let group = DispatchGroup()

        group.enter()
        micInput?.markAsFinished()
        micWriter?.finishWriting {
            AppGroupConstants.log("Mic writer finishWriting complete. Status: \(self.micWriter?.status.rawValue ?? -1)")
            group.leave()
        }

        group.enter()
        sysInput?.markAsFinished()
        sysWriter?.finishWriting {
            AppGroupConstants.log("Sys writer finishWriting complete. Status: \(self.sysWriter?.status.rawValue ?? -1)")
            group.leave()
        }

        group.notify(queue: .global()) {
            AppGroupConstants.log("All audio writers finalized. Notifying parent app...")
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
                AppGroupConstants.log("Darwin stop notification observer callback invoked!")
                handler.finishBroadcastNormally()
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

// MARK: - RPBroadcastSampleHandler Extension for Graceful Stop
extension RPBroadcastSampleHandler {
    func finishBroadcastNormally() {
        let selector = NSSelectorFromString("finishBroadcastWithError:")
        if self.responds(to: selector) {
            AppGroupConstants.log("Performing Selector finishBroadcastWithError: nil synchronously...")
            self.perform(selector, with: nil)
        } else {
            AppGroupConstants.log("Error: Target does not respond to finishBroadcastWithError:")
        }
    }
}
