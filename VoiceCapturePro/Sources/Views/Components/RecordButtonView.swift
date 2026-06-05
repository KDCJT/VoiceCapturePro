// RecordButtonView.swift
// The large central record/stop button with animated ring and glow.

import SwiftUI
import ReplayKit

// MARK: - RecordButtonView

struct RecordButtonView: View {
    let isRecording:   Bool
    let level:         Float
    let mode:          RecordingMode
    let onTap:         () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: { withAnimation(.spring(response: 0.3)) { onTap() } }) {
            ZStack {
                // Outer pulse rings
                CircularPulseView(level: level, isActive: isRecording, color: buttonColor)

                // Button background
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [buttonColor.opacity(0.9), buttonColor.opacity(0.5)]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: buttonColor.opacity(isRecording ? 0.6 : 0.3), radius: isRecording ? 20 : 8)
                    .scaleEffect(isPressed ? 0.94 : 1.0)

                // Inner icon
                ZStack {
                    if isRecording {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white)
                            .frame(width: 34, height: 34)
                    } else {
                        Image(systemName: mode == .micOnly ? "mic.fill" : "waveform.and.mic")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isRecording)
    }

    private var buttonColor: Color {
        isRecording ? .vcRed : (mode == .fullCapture ? .vcAccent : .vcPurple)
    }
}

// MARK: - BroadcastPickerButton
// A thin SwiftUI wrapper around RPSystemBroadcastPickerView.

struct BroadcastPickerButton: UIViewRepresentable {
    let extensionBundleID: String

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView()
        picker.preferredExtension  = extensionBundleID
        picker.showsMicrophoneButton = false
        picker.tintColor = UIColor(Color.vcAccent)
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

// MARK: - Helpers

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
