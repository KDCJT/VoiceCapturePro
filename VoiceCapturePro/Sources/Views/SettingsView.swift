// SettingsView.swift
// App-wide settings: quality, location permission, about, storage info.

import SwiftUI
import AVFoundation
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject var manager: RecordingManager
    @AppStorage("autoLocation") private var autoLocation  = true
    @AppStorage("keepBothTracks") private var keepBothTracks = true
    @AppStorage("showWaveform")  private var showWaveform  = true

    @State private var storageUsed: String = "计算中…"
    @State private var showClearConfirm = false
    @State private var showDiagnostics  = false

    var body: some View {
        ZStack {
            Color.vcBackground.ignoresSafeArea()
            List {
                // ─── 录音质量 ────────────────────────────────────────────
                Section {
                    ForEach(AudioQuality.allCases) { q in
                        Button {
                            manager.selectedQuality = q
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(q.rawValue)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.vcText)
                                    Text(q.subtitle)
                                        .font(.system(size: 11))
                                        .foregroundColor(.vcSubtext)
                                }
                                Spacer()
                                if manager.selectedQuality == q {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.vcAccent)
                                }
                            }
                        }
                        .listRowBackground(Color.vcCard)
                    }
                } header: {
                    sectionHeader("录音质量")
                }

                // ─── 功能选项 ────────────────────────────────────────────
                Section {
                    Toggle(isOn: $autoLocation) {
                        Label("自动记录位置", systemImage: "location.fill")
                    }
                    .tint(.vcAccent)
                    .foregroundColor(.vcText)
                    .listRowBackground(Color.vcCard)

                    Toggle(isOn: $keepBothTracks) {
                        Label("双轨道分开保存", systemImage: "waveform.badge.plus")
                    }
                    .tint(.vcAccent)
                    .foregroundColor(.vcText)
                    .listRowBackground(Color.vcCard)

                    Toggle(isOn: $showWaveform) {
                        Label("显示波形动画", systemImage: "waveform")
                    }
                    .tint(.vcAccent)
                    .foregroundColor(.vcText)
                    .listRowBackground(Color.vcCard)
                } header: {
                    sectionHeader("功能选项")
                }

                // ─── 权限状态 ────────────────────────────────────────────
                Section {
                    permRow("麦克风",
                            status: micStatus,
                            icon:  "mic.fill",
                            action: { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) })
                    permRow("位置服务",
                            status: locStatus,
                            icon:  "location.fill",
                            action: { manager.locationMgr.requestPermission() })
                } header: {
                    sectionHeader("权限状态")
                }

                // ─── 存储 ────────────────────────────────────────────────
                Section {
                    HStack {
                        Label("已用存储空间", systemImage: "internaldrive")
                            .foregroundColor(.vcText)
                        Spacer()
                        Text(storageUsed).foregroundColor(.vcSubtext)
                    }
                    .listRowBackground(Color.vcCard)

                    Button(role: .destructive) { showClearConfirm = true } label: {
                        Label("清除全部录音", systemImage: "trash")
                    }
                    .listRowBackground(Color.vcCard)
                } header: {
                    sectionHeader("存储")
                }

                // ─── 关于 ────────────────────────────────────────────────
                Section {
                    infoRow("版本", "1.1.0")
                    infoRow("双轨道捕获", "ReplayKit Broadcast Extension")
                    infoRow("支持格式", "AAC (.m4a) / PCM (.caf)")
                    infoRow("最高音质", "48kHz · 24bit · PCM 无损")
                    Link(destination: URL(string: "https://developer.apple.com/documentation/replaykit")!) {
                        Label("了解 ReplayKit 录制原理", systemImage: "arrow.up.right")
                            .font(.system(size: 13))
                            .foregroundColor(.vcAccent)
                    }
                    .listRowBackground(Color.vcCard)

                    Button {
                        showDiagnostics = true
                    } label: {
                        Label("查看系统广播诊断日志", systemImage: "terminal.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.vcAccent)
                    }
                    .listRowBackground(Color.vcCard)
                } header: {
                    sectionHeader("关于")
                }
            }
            .listStyle(.insetGrouped)
            .onAppear {
                UITableView.appearance().backgroundColor = .clear
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(.dark)
        .onAppear { calcStorage() }
        .alert("确认清除", isPresented: $showClearConfirm) {
            Button("清除", role: .destructive) {
                let all = manager.recordings
                for r in all { manager.delete(r) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除全部录音及音频文件，此操作无法撤销。")
        }
        .sheet(isPresented: $showDiagnostics) {
            DiagnosticLogsView()
        }
    }

    // MARK: - Sub-views

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.vcSubtext)
            .textCase(nil)
    }

    private func permRow(_ name: String, status: String, icon: String, action: @escaping () -> Void) -> some View {
        HStack {
            Label(name, systemImage: icon).foregroundColor(.vcText)
            Spacer()
            Text(status)
                .font(.system(size: 13))
                .foregroundColor(status == "已授权" ? .vcAccent : .vcRed)
            Button("前往", action: action)
                .font(.system(size: 12))
                .foregroundColor(.vcAccent)
                .padding(.leading, 6)
        }
        .listRowBackground(Color.vcCard)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.vcSubtext)
            Spacer()
            Text(value).foregroundColor(.vcText).font(.system(size: 13))
        }
        .listRowBackground(Color.vcCard)
    }

    // MARK: - Helpers

    private var micStatus: String {
        // AVAudioApplication is iOS 17+; use AVAudioSession for iOS 16 compatibility
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:   return "已授权"
        case .denied:    return "已拒绝"
        default:         return "待授权"
        }
    }

    private var locStatus: String {
        switch manager.locationMgr.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return "已授权"
        case .denied, .restricted:                    return "已拒绝"
        default:                                      return "待授权"
        }
    }

    private func calcStorage() {
        DispatchQueue.global().async {
            var total: Int64 = 0
            if let container = AppGroupConstants.containerURL,
               let items = try? FileManager.default.contentsOfDirectory(at: container,
                                                                         includingPropertiesForKeys: [.fileSizeKey]) {
                for item in items {
                    total += (try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
                }
            }
            let fmt = ByteCountFormatter()
            fmt.allowedUnits = [.useKB, .useMB, .useGB]; fmt.countStyle = .file
            DispatchQueue.main.async { storageUsed = fmt.string(fromByteCount: total) }
        }
    }
}

// MARK: - DiagnosticLogsView

struct DiagnosticLogsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var logs = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    Text(logs)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.vcText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(Color.vcSurface)
                .cornerRadius(12)
                .padding()

                HStack(spacing: 16) {
                    Button(action: {
                        UIPasteboard.general.string = logs
                    }) {
                        Label("复制日志", systemImage: "doc.on.doc.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.vcAccent)
                            .cornerRadius(12)
                    }

                    Button(action: {
                        AppGroupConstants.clearLogs()
                        refreshLogs()
                    }) {
                        Label("清空日志", systemImage: "trash.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.vcRed)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color.vcBackground.ignoresSafeArea())
            .navigationTitle("系统广播诊断日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(.vcAccent)
                }
            }
        }
        .onAppear { refreshLogs() }
        .preferredColorScheme(.dark)
    }

    private func refreshLogs() {
        let appGroupID = AppGroupConstants.appGroupID
        let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        let statusText = groupURL != nil 
            ? "✅ App Group 共享容器有效!\n路径: \(groupURL!.path)" 
            : "❌ App Group 共享容器失效!\n正在使用本地沙盒路径，扩展进程与 App 进程将无法同步录音文件与数据！请检查 TrollStore / 证书签名 entitlements 配置。"
        
        let fileLogs = AppGroupConstants.readLogs()
        logs = "【沙盒环境检测】\n\(statusText)\n\n【后台扩展日志】\n\(fileLogs)"
    }
}
