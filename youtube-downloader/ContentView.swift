import AppKit
import Combine
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DownloadViewModel()
    @State private var isShowingAbout = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MediaDock")
                    .font(.title2.weight(.semibold))

                Text("Not affiliated with YouTube. Download only content you own or have permission to use.")
                    .font(.caption2)
                    .foregroundColor(Color.secondary.opacity(0.7))
            }

            settingsCard
            statusCard

            HStack {
                Button("About") {
                    isShowingAbout = true
                }

                Spacer()

                Button("Extract") {
                    viewModel.startDownload()
                }
                .buttonStyle(ExtractButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.canExtract)
            }
        }
        .padding(24)
        .frame(minWidth: 632, minHeight: 372)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $isShowingAbout) {
            AboutView()
        }
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text("YouTube URL")
                    .font(.headline)

                TextField(
                    "https://www.youtube.com/watch?v=...",
                    text: $viewModel.urlText,
                    onCommit: {
                        if viewModel.canExtract {
                            viewModel.startDownload()
                        }
                    }
                )
                .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Save To")
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(viewModel.selectedDownloadDirectory.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color(NSColor.textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                        .help(viewModel.selectedDownloadDirectory.path)

                    Button {
                        viewModel.chooseDownloadDirectory()
                    } label: {
                        Image(systemName: "folder.fill")
                            .frame(width: 24, height: 18)
                    }
                    .help("Choose download folder")
                    .disabled(viewModel.isRunning)
                }
            }

            Divider()

            HStack(spacing: 18) {
                Picker("Media Type", selection: $viewModel.isVideoMode) {
                    Text("Audio").tag(false)
                    Text("Video").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 120)
                .disabled(viewModel.isRunning)

                Spacer()

                Text("Format")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if viewModel.isVideoMode {
                    Picker("Format", selection: $viewModel.selectedVideoFormat) {
                        ForEach(VideoFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                    .disabled(viewModel.isRunning)
                } else {
                    Picker("Format", selection: $viewModel.selectedAudioFormat) {
                        ForEach(AudioFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                    .disabled(viewModel.isRunning)
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var statusCard: some View {
        HStack(spacing: 10) {
            if viewModel.isRunning {
                ProgressView()
                    .controlSize(.small)

                ExtractingStatusText()
            } else {
                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundColor(viewModel.statusText.hasPrefix("Failed") ? Color.red : Color.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(14)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(NSColor.controlBackgroundColor))
            .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
    }
}

private struct AboutView: View {
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("About MediaDock")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    informationSection(
                        title: "MediaDock",
                        detail: "Copyright © 2026. Licensed under GNU GPL version 3 or later."
                    )

                    informationSection(
                        title: "yt-dlp 2026.03.17",
                        detail: "The PyInstaller distribution is licensed as a combined work under GPLv3+ and includes components under additional licenses."
                    )
                    Link("yt-dlp source and licenses", destination: URL(string: "https://github.com/yt-dlp/yt-dlp/releases/tag/2026.03.17")!)

                    informationSection(
                        title: "FFmpeg 8.1.2 + LAME 3.100",
                        detail: "MediaDock includes a minimal arm64 build without GPL or nonfree FFmpeg components. FFmpeg is LGPL-2.1-or-later; LAME is LGPL-2.0-or-later."
                    )
                    Link("FFmpeg source", destination: URL(string: "https://ffmpeg.org/releases/ffmpeg-8.1.2.tar.xz")!)
                    Link("LAME source", destination: URL(string: "https://sourceforge.net/projects/lame/files/lame/3.100/")!)

                    Divider()

                    Text("MediaDock is not affiliated with or endorsed by YouTube. Use it only for content you own, content in the public domain, or content you are authorized to download. You are responsible for complying with applicable law and service terms.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(22)
        .frame(width: 520, height: 440)
    }

    private func informationSection(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

private struct ExtractingStatusText: View {
    @State private var dotCount = 1
    private let timer = Timer.publish(every: 0.45, on: .main, in: .common).autoconnect()

    var body: some View {
        Text("Extracting" + String(repeating: ".", count: dotCount))
            .font(.caption)
            .foregroundColor(.secondary)
            .onReceive(timer) { _ in
                dotCount = dotCount % 3 + 1
            }
    }
}

private struct ExtractButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundColor(Color.black.opacity(configuration.isPressed ? 0.65 : 0.9))
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.82 : 0.96))
                    .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.88 : 1) : 0.45)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 680, height: 420)
    }
}
