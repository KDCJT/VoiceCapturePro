// AudioQualityConfig.swift
// Defines recording quality presets used by both mic-only and broadcast modes.

import AVFoundation

// MARK: - Audio Quality

enum AudioQuality: String, CaseIterable, Identifiable, Codable {
    case normal       = "普通"
    case standard     = "标准"
    case high         = "高质量"
    case professional = "专业"
    case lossless     = "无损"

    var id: String { rawValue }

    var sampleRate: Double {
        switch self {
        case .normal:       return 22050
        case .standard:     return 44100
        case .high:         return 44100
        case .professional: return 48000
        case .lossless:     return 48000
        }
    }

    var bitRate: Int {
        switch self {
        case .normal:       return 64_000
        case .standard:     return 128_000
        case .high:         return 256_000
        case .professional: return 320_000
        case .lossless:     return 0 // PCM, no compression
        }
    }

    var formatID: AudioFormatID {
        switch self {
        case .lossless: return kAudioFormatLinearPCM
        default:        return kAudioFormatMPEG4AAC
        }
    }

    var bitDepth: Int { self == .lossless ? 24 : 16 }

    var fileExtension: String { self == .lossless ? "caf" : "m4a" }

    var fileType: AVFileType { self == .lossless ? .caf : .m4a }

    var subtitle: String {
        switch self {
        case .normal:       return "AAC 64kbps · 22kHz · 省空间"
        case .standard:     return "AAC 128kbps · 44.1kHz"
        case .high:         return "AAC 256kbps · 44.1kHz · 推荐"
        case .professional: return "AAC 320kbps · 48kHz"
        case .lossless:     return "PCM 24bit · 48kHz · 无损"
        }
    }

    // Settings used by AVAudioRecorder (mic-only mode)
    var recorderSettings: [String: Any] {
        if formatID == kAudioFormatLinearPCM {
            return [
                AVFormatIDKey:             kAudioFormatLinearPCM,
                AVSampleRateKey:           sampleRate,
                AVNumberOfChannelsKey:     1,
                AVLinearPCMBitDepthKey:    bitDepth,
                AVLinearPCMIsFloatKey:     false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
        }
        return [
            AVFormatIDKey:          kAudioFormatMPEG4AAC,
            AVSampleRateKey:        sampleRate,
            AVNumberOfChannelsKey:  1,
            AVEncoderBitRateKey:    bitRate,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
    }

    // High-quality stereo CAF settings used by the broadcast extension (CMSampleBuffer path)
    static var broadcastAudioSettings: [String: Any] {
        [
            AVFormatIDKey:             kAudioFormatLinearPCM,
            AVSampleRateKey:           48000.0,
            AVNumberOfChannelsKey:     2,
            AVLinearPCMBitDepthKey:    16,
            AVLinearPCMIsFloatKey:     false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
    }
}
