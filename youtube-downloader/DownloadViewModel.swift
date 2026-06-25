import AppKit
import Combine
import Foundation

@MainActor
final class DownloadViewModel: ObservableObject {
    @Published var urlText = ""
    @Published var isVideoMode = false {
        didSet {
            if isVideoMode {
                selectedVideoFormat = .best
            } else {
                selectedAudioFormat = .mp3_320
            }
        }
    }
    @Published var selectedAudioFormat: AudioFormat = .mp3_320
    @Published var selectedVideoFormat: VideoFormat = .best
    @Published private(set) var selectedDownloadDirectory: URL
    @Published private(set) var progress = 0.0
    @Published private(set) var statusText = "Ready"
    @Published private(set) var isRunning = false

    private var process: Process?
    private var stdoutBuffer = ""
    private var stderrBuffer = ""
    private var recentErrors: [String] = []
    private var selectedDirectoryIsSecurityScoped = false

    var hasValidURL: Bool {
        let value = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.hasPrefix("https://") || value.hasPrefix("http://")
    }

    var canExtract: Bool {
        hasValidURL && !isRunning
    }

    init(fileManager: FileManager = .default) {
        let downloads = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
        let defaultDirectory = downloads.appendingPathComponent("MediaDock", isDirectory: true)
        selectedDownloadDirectory = defaultDirectory

        do {
            try fileManager.createDirectory(
                at: defaultDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            statusText = "Failed: Could not create the default download folder (\(error.localizedDescription))"
        }
    }

    func chooseDownloadDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose Download Folder"
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = selectedDownloadDirectory

        guard panel.runModal() == .OK, let directory = panel.url else { return }

        selectedDownloadDirectory = directory
        selectedDirectoryIsSecurityScoped = true
        statusText = "Ready"
    }

    func startDownload() {
        guard !isRunning else { return }

        let trimmedURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedURL.hasPrefix("https://") || trimmedURL.hasPrefix("http://") else {
            statusText = "Failed: Enter a URL beginning with http:// or https://"
            return
        }

        guard let executableURL = locateYTDLPExecutable() else {
            statusText = "Failed: yt-exec/yt-dlp was not found in the app bundle or project directory."
            return
        }

        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            statusText = "Failed: yt-dlp is not executable. Run chmod +x yt-exec/yt-dlp and rebuild."
            return
        }

        guard let ffmpegDirectory = locateFFmpegDirectory() else {
            statusText = "Failed: Bundled ffmpeg and ffprobe were not found. Regenerate the minimal FFmpeg tools and rebuild MediaDock."
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: selectedDownloadDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            statusText = "Failed: The download folder is unavailable (\(error.localizedDescription))"
            return
        }

        let securityScopeWasStarted = selectedDirectoryIsSecurityScoped
            && selectedDownloadDirectory.startAccessingSecurityScopedResource()

        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = executableURL
        process.arguments = makeArguments(url: trimmedURL, ffmpegDirectory: ffmpegDirectory)
        process.standardOutput = standardOutput
        process.standardError = standardError

        stdoutBuffer = ""
        stderrBuffer = ""
        recentErrors = []
        progress = 0
        statusText = "Extracting..."
        isRunning = true
        self.process = process

        standardOutput.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                self?.consumeOutput(chunk, isErrorStream: false)
            }
        }

        standardError.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                self?.consumeOutput(chunk, isErrorStream: true)
            }
        }

        process.terminationHandler = { [weak self] finishedProcess in
            standardOutput.fileHandleForReading.readabilityHandler = nil
            standardError.fileHandleForReading.readabilityHandler = nil

            let remainingOutput = standardOutput.fileHandleForReading.readDataToEndOfFile()
            let remainingError = standardError.fileHandleForReading.readDataToEndOfFile()

            Task { @MainActor [weak self] in
                guard let self else { return }

                if let chunk = String(data: remainingOutput, encoding: .utf8), !chunk.isEmpty {
                    self.consumeOutput(chunk, isErrorStream: false, flush: true)
                } else {
                    self.flushOutputBuffer(isErrorStream: false)
                }

                if let chunk = String(data: remainingError, encoding: .utf8), !chunk.isEmpty {
                    self.consumeOutput(chunk, isErrorStream: true, flush: true)
                } else {
                    self.flushOutputBuffer(isErrorStream: true)
                }

                if securityScopeWasStarted {
                    self.selectedDownloadDirectory.stopAccessingSecurityScopedResource()
                }

                self.finish(exitCode: finishedProcess.terminationStatus)
            }
        }

        do {
            try process.run()
        } catch {
            standardOutput.fileHandleForReading.readabilityHandler = nil
            standardError.fileHandleForReading.readabilityHandler = nil
            if securityScopeWasStarted {
                selectedDownloadDirectory.stopAccessingSecurityScopedResource()
            }
            self.process = nil
            isRunning = false
            statusText = "Failed: Could not launch yt-dlp (\(error.localizedDescription))"
        }
    }

    func makeArguments(url: String, ffmpegDirectory: URL? = nil) -> [String] {
        var arguments = [
            "--newline",
            "--progress-template",
            "download:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
            "-P",
            selectedDownloadDirectory.path,
            "-o",
            "%(title).200B [%(id)s].%(ext)s"
        ]

        if let ffmpegDirectory {
            arguments += ["--ffmpeg-location", ffmpegDirectory.path]
        }

        arguments += isVideoMode ? selectedVideoFormat.arguments : selectedAudioFormat.arguments
        arguments.append(url)
        return arguments
    }

    private func locateYTDLPExecutable() -> URL? {
        let fileManager = FileManager.default
        var candidates: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent("yt-exec/yt-dlp"))
            candidates.append(resourceURL.appendingPathComponent("yt-dlp"))
        }

        let currentDirectory = URL(
            fileURLWithPath: fileManager.currentDirectoryPath,
            isDirectory: true
        )
        candidates.append(currentDirectory.appendingPathComponent("yt-exec/yt-dlp"))
        candidates.append(currentDirectory.appendingPathComponent("youtube-downloader/yt-exec/yt-dlp"))

        let sourceDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        candidates.append(sourceDirectory.appendingPathComponent("yt-exec/yt-dlp"))

        return candidates.first { fileManager.fileExists(atPath: $0.path) }
    }

    private func locateFFmpegDirectory() -> URL? {
        let fileManager = FileManager.default
        var candidates: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent("ffmpeg-exec", isDirectory: true))
            candidates.append(resourceURL.appendingPathComponent("ffmpeg", isDirectory: true))
        }

        if let configuredPath = ProcessInfo.processInfo.environment["FFMPEG_LOCATION"] {
            candidates.append(URL(fileURLWithPath: configuredPath, isDirectory: true))
        }

        candidates += [
            URL(fileURLWithPath: "/opt/homebrew/bin", isDirectory: true),
            URL(fileURLWithPath: "/usr/local/bin", isDirectory: true)
        ]

        return candidates.first { directory in
            fileManager.isExecutableFile(atPath: directory.appendingPathComponent("ffmpeg").path)
                && fileManager.isExecutableFile(atPath: directory.appendingPathComponent("ffprobe").path)
        }
    }

    private func consumeOutput(_ chunk: String, isErrorStream: Bool, flush: Bool = false) {
        if isErrorStream {
            stderrBuffer += chunk
            drainLines(from: &stderrBuffer, isErrorStream: true)
            if flush { flushOutputBuffer(isErrorStream: true) }
        } else {
            stdoutBuffer += chunk
            drainLines(from: &stdoutBuffer, isErrorStream: false)
            if flush { flushOutputBuffer(isErrorStream: false) }
        }
    }

    private func drainLines(from buffer: inout String, isErrorStream: Bool) {
        while let newline = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<newline])
            buffer.removeSubrange(...newline)
            handleLine(line, isErrorStream: isErrorStream)
        }
    }

    private func flushOutputBuffer(isErrorStream: Bool) {
        if isErrorStream {
            guard !stderrBuffer.isEmpty else { return }
            let line = stderrBuffer
            stderrBuffer = ""
            handleLine(line, isErrorStream: true)
        } else {
            guard !stdoutBuffer.isEmpty else { return }
            let line = stdoutBuffer
            stdoutBuffer = ""
            handleLine(line, isErrorStream: false)
        }
    }

    private func handleLine(_ rawLine: String, isErrorStream: Bool) {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return }

        if let percent = parseProgressPercent(from: line), isRunning {
            let clampedPercent = min(max(percent, 0), 100)
            progress = clampedPercent / 100
        } else if isErrorStream {
            recentErrors.append(line)
            if recentErrors.count > 8 {
                recentErrors.removeFirst(recentErrors.count - 8)
            }
        }
    }

    private func parseProgressPercent(from line: String) -> Double? {
        // In yt-dlp, "download:" can act as the progress-template type prefix and
        // may therefore be omitted from the rendered output. Accept both forms.
        let payload = line.hasPrefix("download:")
            ? String(line.dropFirst("download:".count))
            : line
        let fields = payload.split(separator: "|", omittingEmptySubsequences: false)
        guard fields.count == 3 else { return nil }

        let percentText = fields[0].trimmingCharacters(in: .whitespaces)
        guard percentText.hasSuffix("%") else { return nil }

        return Double(percentText.dropLast().trimmingCharacters(in: .whitespaces))
    }

    private func finish(exitCode: Int32) {
        process = nil
        isRunning = false

        if exitCode == 0 {
            progress = 1
            statusText = "Completed"
        } else {
            let detail = recentErrors.last ?? "yt-dlp exited with code \(exitCode)."
            statusText = "Failed: \(detail)"
        }
    }
}
