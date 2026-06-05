// WaveformView.swift
// Animated bar waveform that reflects live audio level.
// Premium design: electric cyan gradient bars with glow on dark background.

import SwiftUI

// MARK: - WaveformView

struct WaveformView: View {
    let level:        Float        // 0.0 – 1.0
    let isActive:     Bool
    var barCount:     Int   = 40
    var accentColor:  Color = .vcAccent

    // Each bar gets a random phase offset so they don't all move in sync
    @State private var phases: [Double] = []
    @State private var tick:   Double   = 0

    private let timer = Timer.publish(every: 0.04, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: geo.size.width / CGFloat(barCount * 2)) {
                ForEach(0..<barCount, id: \.self) { i in
                    barView(index: i, totalWidth: geo.size.width, height: geo.size.height)
                }
            }
        }
        .onAppear { phases = (0..<barCount).map { _ in Double.random(in: 0...(2 * .pi)) } }
        .onReceive(timer) { _ in
            if isActive { tick += 0.08 }
        }
    }

    @ViewBuilder
    private func barView(index: Int, totalWidth: CGFloat, height: CGFloat) -> some View {
        let phase   = phases.isEmpty ? 0.0 : phases[index]
        let base    = CGFloat(level)
        let wave    = isActive ? CGFloat(sin(tick + phase)) * 0.15 : 0
        let barH    = max(4, (base + wave) * height * 0.9)
        let opacity = isActive ? Double(0.6 + base * 0.4) : 0.2

        Capsule()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [accentColor.opacity(opacity), accentColor.opacity(opacity * 0.4)]),
                    startPoint: .top,
                    endPoint:   .bottom
                )
            )
            .frame(width: max(2, totalWidth / CGFloat(barCount * 2)), height: barH)
            .shadow(color: isActive ? accentColor.opacity(0.4) : .clear, radius: 4)
            .animation(.easeInOut(duration: 0.04), value: barH)
    }
}

// MARK: - CircularWaveform (used on record button)

struct CircularPulseView: View {
    let level:    Float
    let isActive: Bool
    var color:    Color = .vcRed

    @State private var pulse = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(color.opacity(isActive ? Double(0.4 - Double(i) * 0.12) : 0), lineWidth: 2)
                    .scaleEffect(isActive ? 1 + CGFloat(i + 1) * 0.18 + CGFloat(level) * 0.3 : 1)
                    .animation(
                        .easeInOut(duration: 0.6 + Double(i) * 0.2).repeatForever(autoreverses: true),
                        value: isActive
                    )
            }
        }
    }
}

// MARK: - Color palette

extension Color {
    static let vcBackground = Color(red: 0.04, green: 0.04, blue: 0.08)
    static let vcSurface    = Color(red: 0.09, green: 0.09, blue: 0.16)
    static let vcCard       = Color(red: 0.11, green: 0.11, blue: 0.20)
    static let vcAccent     = Color(red: 0.00, green: 0.84, blue: 1.00)   // Electric cyan
    static let vcPurple     = Color(red: 0.48, green: 0.37, blue: 0.85)   // Purple
    static let vcRed        = Color(red: 1.00, green: 0.23, blue: 0.36)   // Vivid red
    static let vcText       = Color(red: 0.92, green: 0.92, blue: 0.98)
    static let vcSubtext    = Color(red: 0.55, green: 0.55, blue: 0.70)
}
