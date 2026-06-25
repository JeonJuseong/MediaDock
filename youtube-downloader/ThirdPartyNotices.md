# Third-Party Notices

MediaDock is licensed under GNU GPL version 3 or later and bundles the following
third-party command-line tools.

## yt-dlp 2026.03.17

- Project: https://github.com/yt-dlp/yt-dlp
- Release: https://github.com/yt-dlp/yt-dlp/releases/tag/2026.03.17
- Source: https://github.com/yt-dlp/yt-dlp/releases/download/2026.03.17/yt-dlp.tar.gz

yt-dlp itself is released under the Unlicense. The official PyInstaller executable
contains components under additional licenses and the combined work is distributed
under GPL version 3 or later. Its complete third-party license manifest must be
included with every MediaDock binary release.

## FFmpeg 8.1.2

- Project: https://ffmpeg.org/
- Source: https://ffmpeg.org/releases/ffmpeg-8.1.2.tar.xz
- SHA-256: `464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c`
- License: LGPL version 2.1 or later

MediaDock uses a purpose-built arm64 FFmpeg and FFprobe without `--enable-gpl`,
`--enable-nonfree`, x264, x265, OpenSSL, or other optional codec libraries. Exact
configure arguments are included in `Resources/ffmpeg-exec/BUILD-INFO.txt`.

## LAME 3.100

- Project: https://lame.sourceforge.io/
- Source: https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
- SHA-256: `ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e`
- License: LGPL version 2.0 or later

LAME is statically linked into the minimal FFmpeg executables to support MP3 output.
The FFmpeg and LAME license texts are included under
`Resources/ffmpeg-exec/licenses`.

## Source availability

Every binary release must provide the exact corresponding source code and build
instructions alongside the DMG. Upstream links in this notice are informational and
do not replace the distributor's source-code obligations.
