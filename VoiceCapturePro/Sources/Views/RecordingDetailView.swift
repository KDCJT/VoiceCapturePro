// RecordingDetailView.swift
// Full detail view with playback, metadata display and edit.

import SwiftUI
import AVFoundation

// MARK: - RecordingDetailView

struct RecordingDetailView: View {
    @EnvironmentObject var manager: RecordingManager
    @Environment(\.dismiss) private var dismiss

    @State var recording: Recording

    // Playback
    @State private var player:        AVAudioPlayer?
    @State private var isPlaying      = false
    @State private var playProgress:  Double = 0
    @State private var duration:      Double = 0
    @State private var playTimer:     Timer?

    // Edit
    @State private var editingNotes   = false
    @State private var editingTitle   = false
    @State private var draftNotes     = ""
    @State private var draftTitle     = ""
    @State private var tagInput       = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color.vcBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        titleSection
                        playbackSection
                        metadataSection
                        trackSection
                        notesSection
                        tagsSection
                        Spacer(minLength: 40)
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { stopPlayback(); dismiss() }
                        .foregroundColor(.vcAccent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { shareRecording() } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.vcAccent)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        Group {
            if editingTitle {
                HStack {
                    TextField("录音标题", text: $draftTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.vcText)
                    Button("完成") {
                        recording.title = draftTitle
                        manager.update(recording)
                        editingTitle = false
                    }
                    .foregroundColor(.vcAccent)
                }
                .padding(12)
                .background(Color.vcSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                HStack {
                    Text(recording.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.vcText)
                    Spacer()
                    Button { draftTitle = recording.title; editingTitle = true } label: {
                        Image(systemName: "pencil.circle")
                            .foregroundColor(.vcSubtext)
                    }
                }
            }
        }
    }

    // MARK: - Playback

    private var playbackSection: some View {
        VStack(spacing: 12) {
            // Progress bar
            Slider(value: $playProgress, in: 0...(duration > 0 ? duration : 1)) { editing in
                if editing { pausePlayback() }
                else       { seek(to: playProgress) }
            }
            .tint(.vcAccent)

            HStack {
                Text(formatTime(playProgress))
                Spacer()
                Text(formatTime(duration))
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.vcSubtext)

            // Controls
            HStack(spacing: 36) {
                Button { seek(to: max(0, playProgress - 15)) } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 22))
                        .foregroundColor(.vcSubtext)
                }

                Button {
                    isPlaying ? pausePlayback() : startPlayback()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.vcAccent.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.vcAccent)
                    }
                }

                Button { seek(to: min(duration, playProgress + 15)) } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 22))
                        .foregroundColor(.vcSubtext)
                }
            }
        }
        .padding(16)
        .background(Color.vcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear { setupPlayer() }
        .onDisappear { stopPlayback() }
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(spacing: 0) {
            metaRow(icon: "calendar",         label: "开始时间", value: recording.formattedDate)
            Divider().background(Color.vcSubtext.opacity(0.15))
            metaRow(icon: "clock",            label: "时长",     value: recording.formattedDuration)
            Divider().background(Color.vcSubtext.opacity(0.15))
            metaRow(icon: "doc",              label: "文件大小", value: recording.formattedFileSize)
            Divider().background(Color.vcSubtext.opacity(0.15))
            metaRow(icon: "waveform",         label: "录制质量", value: recording.quality)
            if let loc = recording.locationName, !loc.isEmpty {
                Divider().background(Color.vcSubtext.opacity(0.15))
                metaRow(icon: "location.fill", label: "位置",    value: loc)
            }
        }
        .background(Color.vcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func metaRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.vcAccent)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.vcSubtext)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.vcText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Track info

    private var trackSection: some View {
        HStack(spacing: 10) {
            trackBadge(title: "麦克风轨道",   subtitle: recording.micFilePath.components(separatedBy: "/").last ?? "", color: .vcPurple)
            if let sys = recording.sysFilePath {
                trackBadge(title: "系统声音轨道", subtitle: sys.components(separatedBy: "/").last ?? "", color: .vcAccent)
            }
        }
    }

    private func trackBadge(title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: "music.note.list")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(.vcSubtext)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("备注", systemImage: "text.alignleft")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.vcSubtext)

            if editingNotes {
                TextEditor(text: $draftNotes)
                    .frame(minHeight: 80)
                    .foregroundColor(.vcText)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(Color.vcSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onAppear {
                        // iOS 15 workaround for TextEditor background
                        UITextView.appearance().backgroundColor = .clear
                    }

                HStack {
                    Spacer()
                    Button("取消") { editingNotes = false }
                        .foregroundColor(.vcSubtext)
                    Button("保存") {
                        recording.notes = draftNotes
                        manager.update(recording)
                        editingNotes = false
                    }
                    .foregroundColor(.vcAccent)
                    .fontWeight(.semibold)
                }
                .font(.system(size: 14))
            } else {
                Text(recording.notes.isEmpty ? "暂无备注，点击添加…" : recording.notes)
                    .font(.system(size: 14))
                    .foregroundColor(recording.notes.isEmpty ? .vcSubtext : .vcText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.vcSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onTapGesture { draftNotes = recording.notes; editingNotes = true }
            }
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("标签", systemImage: "tag")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.vcSubtext)

            // Use a simple wrapping HStack approach (iOS 15 compatible)
            WrappingHStack(spacing: 8) {
                ForEach(recording.tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text("#\(tag)")
                            .font(.system(size: 12))
                            .foregroundColor(.vcAccent)
                        Button {
                            recording.tags.removeAll { $0 == tag }
                            manager.update(recording)
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 9))
                                .foregroundColor(.vcSubtext)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.vcAccent.opacity(0.12))
                    .clipShape(Capsule())
                }

                // Tag input
                HStack(spacing: 4) {
                    TextField("添加标签", text: $tagInput)
                        .font(.system(size: 12))
                        .foregroundColor(.vcText)
                        .frame(width: 70)
                        .onSubmit { addTag() }
                    Button(action: addTag) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.vcAccent)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.vcSurface)
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Playback logic

    private func setupPlayer() {
        let url = recording.micFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        duration = player?.duration ?? 0
    }

    private func startPlayback() {
        player?.play()
        isPlaying = true
        playTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            playProgress = player?.currentTime ?? 0
            if !(player?.isPlaying ?? false) {
                isPlaying    = false
                playProgress = 0
                playTimer?.invalidate()
            }
        }
    }

    private func pausePlayback() {
        player?.pause()
        isPlaying = false
        playTimer?.invalidate()
    }

    private func stopPlayback() {
        player?.stop()
        isPlaying    = false
        playProgress = 0
        playTimer?.invalidate()
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func seek(to time: Double) {
        player?.currentTime = time
        playProgress = time
        if isPlaying { player?.play() }
    }

    private func addTag() {
        let tag = tagInput.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !recording.tags.contains(tag) else { tagInput = ""; return }
        recording.tags.append(tag)
        manager.update(recording)
        tagInput = ""
    }

    private func shareRecording() {
        var urls: [URL] = [recording.micFileURL]
        if let sysURL = recording.sysFileURL { urls.append(sysURL) }
        let vc = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController?
            .present(vc, animated: true)
    }

    private func formatTime(_ t: Double) -> String {
        let m = Int(t) / 60; let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - WrappingHStack (iOS 15 compatible flow layout)

/// A simple wrapping layout that works on iOS 15+ (no Layout protocol needed).
struct WrappingHStack<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        // For iOS 15, use a simple VStack + HStack wrapping approach
        // by leveraging the _VariadicView internal, or just use a ScrollView with horizontal wrapping.
        // Simplest reliable approach: let the tags wrap using a LazyVGrid with flexible columns.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: spacing)], alignment: .leading, spacing: spacing) {
            content()
        }
    }
}
