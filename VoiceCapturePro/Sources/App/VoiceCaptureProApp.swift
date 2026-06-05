// VoiceCaptureProApp.swift
// App entry point + TabView shell.

import SwiftUI
import AVFoundation

@main
struct VoiceCaptureProApp: App {
    @StateObject private var recordingManager = RecordingManager()

    init() {
        // Request microphone permission at launch
        AVAudioApplication.requestRecordPermission { _ in }
        // Dark appearance
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor(Color.vcText)
        ]
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recordingManager)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - ContentView (TabView)

struct ContentView: View {
    @EnvironmentObject var manager: RecordingManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // ── Tab 1: Record ──────────────────────────────────────
            NavigationStack {
                HomeView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Label("录音", systemImage: selectedTab == 0 ? "mic.fill" : "mic")
            }
            .tag(0)

            // ── Tab 2: Library ─────────────────────────────────────
            NavigationStack {
                RecordingListView()
            }
            .tabItem {
                Label("录音库", systemImage: selectedTab == 1 ? "waveform" : "waveform")
            }
            .tag(1)
        }
        .accentColor(.vcAccent)
        .onAppear {
            let tabBar = UITabBar.appearance()
            tabBar.unselectedItemTintColor = UIColor(Color.vcSubtext)
            tabBar.backgroundColor       = UIColor(Color.vcSurface.opacity(0.95))
        }
    }
}
