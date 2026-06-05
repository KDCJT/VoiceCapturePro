// RecordingListView.swift
// File management library: list, search, filter, delete, export.

import SwiftUI
import AVFoundation

// MARK: - RecordingListView

struct RecordingListView: View {
    @EnvironmentObject var manager: RecordingManager

    @State private var searchText      = ""
    @State private var selectedFilter: FilterMode = .all
    @State private var selectedItem:   Recording?
    @State private var deleteTarget:   Recording?
    @State private var showDeleteAlert = false
    @State private var sortOrder:      SortOrder = .newest

    enum FilterMode: String, CaseIterable {
        case all      = "全部"
        case dualTrack = "双轨"
        case micOnly  = "纯麦克风"
    }

    enum SortOrder: String, CaseIterable {
        case newest = "最新"
        case oldest = "最旧"
        case longest = "最长"
    }

    var filteredRecordings: [Recording] {
        var list = manager.recordings

        // Filter by mode
        switch selectedFilter {
        case .dualTrack: list = list.filter { !$0.isMicOnly }
        case .micOnly:   list = list.filter { $0.isMicOnly }
        case .all: break
        }

        // Search
        if !searchText.isEmpty {
            list = list.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.locationName ?? "").localizedCaseInsensitiveContains(searchText) ||
                $0.notes.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort
        switch sortOrder {
        case .newest:  list.sort { $0.startDate > $1.startDate }
        case .oldest:  list.sort { $0.startDate < $1.startDate }
        case .longest: list.sort { $0.duration   > $1.duration  }
        }

        return list
    }

    var body: some View {
        ZStack {
            Color.vcBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // ─── Search Bar ──────────────────────────────────────────
                searchBar.padding(.horizontal, 16).padding(.top, 8)

                // ─── Filter Chips ────────────────────────────────────────
                filterRow.padding(.vertical, 10)

                // ─── List ────────────────────────────────────────────────
                if filteredRecordings.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredRecordings) { rec in
                                RecordingCardView(recording: rec)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedItem = rec }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            deleteTarget   = rec
                                            showDeleteAlert = true
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                        Button {
                                            shareRecording(rec)
                                        } label: {
                                            Label("导出 / 分享", systemImage: "square.and.arrow.up")
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationTitle("录音库")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button {
                            sortOrder = order
                        } label: {
                            Label(order.rawValue, systemImage: sortOrder == order ? "checkmark" : "")
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .foregroundColor(.vcAccent)
                }
            }
        }
        .sheet(item: $selectedItem) { rec in
            RecordingDetailView(recording: rec)
                .environmentObject(manager)
                .preferredColorScheme(.dark)
        }
        .alert("确认删除", isPresented: $showDeleteAlert, presenting: deleteTarget) { rec in
            Button("删除", role: .destructive) { manager.delete(rec) }
            Button("取消", role: .cancel) {}
        } message: { rec in
            Text("将永久删除「\(rec.title)」及其音频文件，无法恢复。")
        }
        .onAppear { manager.loadRecordings() }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sub-views

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.vcSubtext)
            TextField("搜索录音、位置、备注…", text: $searchText)
                .foregroundColor(.vcText)
                .font(.system(size: 15))
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.vcSubtext)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.vcSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilterMode.allCases, id: \.self) { f in
                    Button {
                        withAnimation(.spring(response: 0.25)) { selectedFilter = f }
                    } label: {
                        Text(f.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selectedFilter == f ? Color.vcAccent.opacity(0.25) : Color.vcSurface)
                            .foregroundColor(selectedFilter == f ? .vcAccent : .vcSubtext)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "waveform.slash")
                .font(.system(size: 48))
                .foregroundColor(.vcSubtext.opacity(0.4))
            Text(searchText.isEmpty ? "暂无录音" : "未找到匹配的录音")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.vcSubtext)
            Spacer()
        }
    }

    // MARK: - Actions

    private func shareRecording(_ recording: Recording) {
        var urls: [URL] = [recording.micFileURL]
        if let sysURL = recording.sysFileURL { urls.append(sysURL) }

        let vc = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController?
            .present(vc, animated: true)
    }
}
