#!/bin/sh

set -eu

ffmpeg_directory="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/ffmpeg-exec"
yt_dlp="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/yt-exec/yt-dlp"
tool_entitlements="${SRCROOT}/scripts/yt-dlp.entitlements"

for executable in "$ffmpeg_directory/ffmpeg" "$ffmpeg_directory/ffprobe" "$yt_dlp"; do
    if [ ! -x "$executable" ]; then
        echo "error: Bundled executable is missing or not executable: $executable" >&2
        exit 1
    fi
done

if otool -L "$ffmpeg_directory/ffmpeg" "$ffmpeg_directory/ffprobe" \
    | grep -E '/opt/homebrew|/usr/local' >/dev/null; then
    echo "error: Bundled minimal FFmpeg contains a Homebrew dependency." >&2
    exit 1
fi

signing_identity="${EXPANDED_CODE_SIGN_IDENTITY:--}"
[ -n "$signing_identity" ] || signing_identity="-"

for executable in "$ffmpeg_directory/ffmpeg" "$ffmpeg_directory/ffprobe" "$yt_dlp"; do
    codesign \
        --force \
        --sign "$signing_identity" \
        --options runtime \
        --timestamp=none \
        --entitlements "$tool_entitlements" \
        "$executable"
done

"$ffmpeg_directory/ffmpeg" -version >/dev/null
"$ffmpeg_directory/ffprobe" -version >/dev/null

echo "Verified and signed bundled yt-dlp, minimal FFmpeg, and FFprobe"
