import Foundation

enum AudioFormat: String, CaseIterable, Identifiable {
    case mp3_320
    case mp3_192
    case mp3_128
    case m4aBest
    case aacBest

    var id: Self { self }

    var displayName: String {
        switch self {
        case .mp3_320: "MP3 320Kbps"
        case .mp3_192: "MP3 192Kbps"
        case .mp3_128: "MP3 128Kbps"
        case .m4aBest: "M4A Best"
        case .aacBest: "AAC Best"
        }
    }

    var arguments: [String] {
        switch self {
        case .mp3_320:
            ["-x", "--audio-format", "mp3", "--audio-quality", "320K"]
        case .mp3_192:
            ["-x", "--audio-format", "mp3", "--audio-quality", "192K"]
        case .mp3_128:
            ["-x", "--audio-format", "mp3", "--audio-quality", "128K"]
        case .m4aBest:
            ["-f", "ba", "-x", "--audio-format", "m4a", "--audio-quality", "0"]
        case .aacBest:
            ["-f", "ba", "-x", "--audio-format", "aac", "--audio-quality", "0"]
        }
    }
}

enum VideoFormat: String, CaseIterable, Identifiable {
    case best
    case upTo4K
    case upTo1440p
    case upTo1080p
    case upTo720p
    case upTo480p
    case mkvBest

    var id: Self { self }

    var displayName: String {
        switch self {
        case .best: "Best (Auto)"
        case .upTo4K: "Up to 4K"
        case .upTo1440p: "Up to 1440p"
        case .upTo1080p: "Up to 1080p"
        case .upTo720p: "Up to 720p"
        case .upTo480p: "Up to 480p"
        case .mkvBest: "MKV Best"
        }
    }

    var arguments: [String] {
        switch self {
        case .best:
            ["-f", "bv*+ba/b", "--merge-output-format", "mp4"]
        case .upTo4K:
            ["-f", "bv*+ba/b", "-S", "res:2160", "--merge-output-format", "mp4"]
        case .upTo1440p:
            ["-f", "bv*+ba/b", "-S", "res:1440", "--merge-output-format", "mp4"]
        case .upTo1080p:
            ["-f", "bv*+ba/b", "-S", "res:1080", "--merge-output-format", "mp4"]
        case .upTo720p:
            ["-f", "bv*+ba/b", "-S", "res:720", "--merge-output-format", "mp4"]
        case .upTo480p:
            ["-f", "bv*+ba/b", "-S", "res:480", "--merge-output-format", "mp4"]
        case .mkvBest:
            ["-t", "mkv"]
        }
    }
}
