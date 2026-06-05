// RecordingCardView.swift
// Card displayed in the recording list.

import SwiftUI

struct RecordingCardView: View {
    let recording: Recording
    var onDelete:  (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ─── Header ─────────────────────────────────────────────
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.vcText)
                        .lineLimit(2)

                    Text(recording.formattedDate)
                        .font(.system(size: 12))
                        .foregroundColor(.vcSubtext)
                }
                Spacer()

                // Mode badge
                Label(recording.modeLabel, systemImage: recording.isMicOnly ? "mic" : "waveform.and.mic")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(recording.isMicOnly ? .vcPurple : .vcAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill((recording.isMicOnly ? Color.vcPurple : Color.vcAccent).opacity(0.15))
                    )
            }

            Divider().background(Color.vcSubtext.opacity(0.2))

            // ─── Metadata row ────────────────────────────────────────
            HStack(spacing: 16) {
                InfoChip(icon: "clock", text: recording.formattedDuration)
                if let name = recording.locationName, !name.isEmpty {
                    InfoChip(icon: "location", text: name)
                }
                InfoChip(icon: "doc.richtext", text: recording.formattedFileSize)
                Spacer()
            }

            // ─── Tags ────────────────────────────────────────────────
            if !recording.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(recording.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.vcAccent.opacity(0.8))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().stroke(Color.vcAccent.opacity(0.3), lineWidth: 1))
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.vcCard)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        )
    }
}

// MARK: - InfoChip

struct InfoChip: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11))
            .foregroundColor(.vcSubtext)
            .lineLimit(1)
    }
}
