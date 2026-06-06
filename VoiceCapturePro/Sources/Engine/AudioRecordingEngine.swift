// AudioRecordingEngine.swift
// Handles mic-only recording within the main app process (no broadcast required).
// Used for the "快速录音" mode where system audio is not needed.

import AVFoundation
import Combine

// MARK: - AudioRecordingEngine

final class AudioRecordingEngine: NSObject, ObservableObject, AVAudioRecorderDelegate {

    // MARK: Published state

    @Published var isRecording  = false
    @Published var isPaused     = false
    @Published var audioLevel:  Float = 0        // 0.0 – 1.0 normalised
    @Published var elapsedTime: TimeInterval = 0

    // MARK: Private

    private var recorder:    AVAudioRecorder?
    private var levelTimer:  Timer?
    private var clockTimer:  Timer?
    private var startTime:   Date?
    private var outputURL:   URL?
    private(set) var quality: AudioQuality = .high

    // MARK: - Public API

    /// Start mic-only recording to the given URL.
    func start(outputURL: URL, quality: AudioQuality) throws {
        self.outputURL = outputURL
        self.quality   = quality

        // Configure AVAudioSession for recording while allowing other apps to play
        let session = AVAudioSession.sharedInstance()
        var categoryOptions: AVAudioSession.CategoryOptions = [
            .defaultToSpeaker,
            .allowBluetooth,          // Bluetooth headset mic
            .allowBluetoothA2DP,      // A2DP (AirPods, etc.)
            .mixWithOthers            // Let other apps (WeChat) keep playing
        ]
        #if compiler(>=5.9)
        if #available(iOS 17.0, *) {
            categoryOptions.insert(.interruptSpokenAudioAndMixWithOthers)
        }
        #endif
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: categoryOptions
        )
        try session.setPreferredSampleRate(quality.sampleRate)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        recorder = try AVAudioRecorder(url: outputURL, settings: quality.recorderSettings)
        recorder?.delegate         = self
        recorder?.isMeteringEnabled = true
        recorder?.record()

        startTime   = Date()
        elapsedTime = 0
        isRecording = true
        isPaused    = false

        startTimers()
    }

    func pause() {
        guard isRecording, !isPaused else { return }
        recorder?.pause()
        isPaused = true
        stopTimers()
    }

    func resume() {
        guard isRecording, isPaused else { return }
        recorder?.record()
        isPaused = false
        startTimers()
    }

    /// Stops recording and returns the final URL.
    @discardableResult
    func stop() -> URL? {
        guard isRecording else { return nil }
        stopTimers()
        recorder?.stop()
        recorder = nil
        isRecording  = false
        isPaused     = false
        audioLevel   = 0

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return outputURL
    }

    // MARK: - AVAudioRecorderDelegate

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            isRecording = false
        }
    }

    // MARK: - Timers

    private func startTimers() {
        // Level polling (20 Hz)
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let rec = self.recorder else { return }
            rec.updateMeters()
            // averagePower is in dBFS (-160 ... 0); map to 0...1
            let db = rec.averagePower(forChannel: 0)
            let normalized = max(0, min(1, (db + 60) / 60))
            DispatchQueue.main.async { self.audioLevel = normalized }
        }

        // Elapsed-time clock (1 Hz)
        let capturedStart = startTime ?? Date()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.elapsedTime = Date().timeIntervalSince(capturedStart)
            }
        }
    }

    private func stopTimers() {
        levelTimer?.invalidate(); levelTimer = nil
        clockTimer?.invalidate(); clockTimer = nil
    }
}
