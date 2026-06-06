// HomeView.swift
// The main recording screen. Deep-dark, electric-cyan premium design.

import SwiftUI
import ReplayKit

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject var manager: RecordingManager

    // Local UI state
    @State private var showModePicker   = false
    @State private var showQualityPicker = false
    @State private var noteText         = ""
    @State private var showBroadcastHelper = false
    @State private var elapsedDisplay: String = "00:00"

    // For reading VC to pass into showBroadcastPicker
    @State private var hostVC: UIViewController?

    private let elapsedTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // ─── Background ──────────────────────────────────────────
            Color.vcBackground.ignoresSafeArea()

            // Subtle radial glow behind record button
            if manager.isRecording {
                RadialGradient(
                    colors: [Color.vcAccent.opacity(0.07), Color.clear],
                    center: .center, startRadius: 60, endRadius: 320
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: manager.displayLevel)
            }

            ScrollView {
                VStack(spacing: 24) {
                    headerBar
                    modeSelector
                    waveformSection
                    timerSection
                    recordButton
                    if manager.isRecording { notesSection }
                    qualitySection
                    if manager.currentMode == .fullCapture && !manager.isRecording {
                        broadcastHint
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showQualityPicker) { qualitySheet }
        .onReceive(elapsedTimer) { _ in updateElapsed() }
        .background(ViewControllerFinder(vc: $hostVC))
    }

    // MARK: - Sub-views

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("VoiceCapture")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.vcText)
                if let loc = manager.locationMgr.currentLocationName as String?,
                   !loc.isEmpty {
                    Label(loc, systemImage: "location.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.vcSubtext)
                }
            }
            Spacer()
            NavigationLink(destination: SettingsView().environmentObject(manager)) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.vcSubtext)
            }
        }
        .padding(.top, 8)
    }

    private var modeSelector: some View {
        HStack(spacing: 0) {
            ForEach(RecordingMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        manager.currentMode = mode
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.icon)
                        Text(mode.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        manager.currentMode == mode
                            ? (mode == .micOnly ? Color.vcPurple : Color.vcAccent).opacity(0.2)
                            : Color.clear
                    )
                    .foregroundColor(
                        manager.currentMode == mode
                            ? (mode == .micOnly ? .vcPurple : .vcAccent)
                            : .vcSubtext
                    )
                }
            }
        }
        .background(Color.vcSurface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.vcSubtext.opacity(0.15), lineWidth: 1))
        .disabled(manager.isRecording)
    }

    private var waveformSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.vcSurface)
                .frame(height: 100)

            if manager.isRecording {
                VStack(spacing: 6) {
                    WaveformView(
                        level:       manager.displayLevel,
                        isActive:    manager.isRecording,
                        accentColor: manager.currentMode == .micOnly ? .vcPurple : .vcAccent
                    )
                    .frame(height: 70)
                    .padding(.horizontal, 12)

                    // Dual-track indicator
                    if manager.currentMode == .fullCapture {
                        HStack(spacing: 16) {
                            LevelPill(label: "MIC", level: manager.broadcastMgr.micLevel, color: .vcPurple)
                            LevelPill(label: "SYS", level: manager.broadcastMgr.sysLevel, color: .vcAccent)
                        }
                    }
                }
            } else {
                Text("待机中")
                    .font(.system(size: 13))
                    .foregroundColor(.vcSubtext)
            }
        }
    }

    private var timerSection: some View {
        VStack(spacing: 4) {
            Text(elapsedDisplay)
                .font(.system(size: 52, weight: .thin, design: .monospaced))
                .foregroundColor(manager.isRecording ? .vcText : .vcSubtext)

            if manager.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.vcRed)
                        .frame(width: 8, height: 8)
                        .opacity(Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0)
                    Text("录制中")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.vcRed)
                }
            }
        }
    }

    private var recordButton: some View {
        RecordButtonView(
            isRecording: manager.isRecording,
            level:       manager.displayLevel,
            mode:        manager.currentMode,
            onTap: {
                if manager.isRecording {
                    manager.stopRecording()
                } else {
                    manager.startRecording(in: hostVC)
                }
            }
        )
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("录音备注", systemImage: "pencil")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.vcSubtext)

            TextField("添加备注…", text: $manager.currentNotes)
                .font(.system(size: 14))
                .foregroundColor(.vcText)
                .padding(12)
                .background(Color.vcSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var qualitySection: some View {
        Button { showQualityPicker = true } label: {
            HStack {
                Label(manager.selectedQuality.rawValue, systemImage: "waveform")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.vcAccent)
                Spacer()
                Text(manager.selectedQuality.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.vcSubtext)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.vcSubtext)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.vcSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(manager.isRecording)
    }

    private var broadcastHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.vcAccent)
            Text("双轨模式：点击录音按钮后，在系统弹窗中选择「开始直播」即可同时录制系统音频（微信通话等）和麦克风。停止时请点击控制中心的红色状态条。")
                .font(.system(size: 12))
                .foregroundColor(.vcSubtext)
        }
        .padding(12)
        .background(Color.vcAccent.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var qualitySheet: some View {
        NavigationView {
            List {
                ForEach(AudioQuality.allCases) { q in
                    Button {
                        manager.selectedQuality = q
                        showQualityPicker = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(q.rawValue)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.vcText)
                                Text(q.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundColor(.vcSubtext)
                            }
                            Spacer()
                            if manager.selectedQuality == q {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.vcAccent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.vcCard)
                }
            }
            .listStyle(.insetGrouped)
            .background(Color.vcBackground)
            .navigationTitle("录音质量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { showQualityPicker = false }
                        .foregroundColor(.vcAccent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Helpers

    private func updateElapsed() {
        let t: TimeInterval
        if manager.currentMode == .micOnly {
            t = manager.micEngine.elapsedTime
        } else {
            t = manager.broadcastMgr.elapsedTime
        }
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        let s = Int(t) % 60
        elapsedDisplay = h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}

// MARK: - LevelPill

private struct LevelPill: View {
    let label: String
    let level: Float
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule()
                        .fill(color.opacity(0.6))
                        .frame(width: geo.size.width * CGFloat(level))
                }
            }
            .frame(width: 50, height: 6)
        }
    }
}

// MARK: - ViewControllerFinder
// Helper to extract the host UIViewController for the broadcast picker.

private struct ViewControllerFinder: UIViewRepresentable {
    @Binding var vc: UIViewController?

    func makeUIView(context: Context) -> UIView {
        let view = PassthroughView()
        view.vcBinding = $vc
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    class PassthroughView: UIView {
        var vcBinding: Binding<UIViewController?>?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            vcBinding?.wrappedValue = self.parentViewController
        }
    }
}

private extension UIView {
    var parentViewController: UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let vc = next as? UIViewController { return vc }
            responder = next
        }
        return nil
    }
}
