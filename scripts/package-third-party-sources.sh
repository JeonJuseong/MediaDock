#!/bin/sh

set -eu

ffmpeg_version="8.1.2"
ffmpeg_sha256="464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c"
lame_version="3.100"
lame_sha256="ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e"
yt_dlp_version="2026.03.17"
yt_dlp_commit="7fd74d10097833ebce0cb162e0ccf7825de9b768"

script_directory="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
project_directory="$(dirname "$script_directory")"
output_directory="${1:-$project_directory/dist}"
cache_directory="${MEDIASAVER_SOURCE_CACHE:-$project_directory/.build/third-party-sources}"
work_directory="$(mktemp -d "${TMPDIR:-/tmp}/mediadock-source-package.XXXXXX")"
package_directory="$work_directory/MediaDock-third-party-sources-$yt_dlp_version"
trap 'rm -rf "$work_directory"' EXIT

mkdir -p "$output_directory" "$cache_directory" "$package_directory/licenses"

download_and_verify() {
    url="$1"
    archive="$2"
    expected_sha256="$3"

    if [ ! -f "$archive" ]; then
        curl --fail --location --retry 3 "$url" --output "$archive"
    fi

    actual_sha256="$(shasum -a 256 "$archive" | awk '{ print $1 }')"
    [ "$actual_sha256" = "$expected_sha256" ] || {
        echo "error: SHA-256 mismatch for $archive" >&2
        exit 1
    }
}

ffmpeg_archive="$cache_directory/ffmpeg-$ffmpeg_version.tar.xz"
lame_archive="$cache_directory/lame-$lame_version.tar.gz"
yt_dlp_archive="$cache_directory/yt-dlp-$yt_dlp_version.tar.gz"

download_and_verify \
    "https://ffmpeg.org/releases/ffmpeg-$ffmpeg_version.tar.xz" \
    "$ffmpeg_archive" \
    "$ffmpeg_sha256"
download_and_verify \
    "https://downloads.sourceforge.net/project/lame/lame/$lame_version/lame-$lame_version.tar.gz" \
    "$lame_archive" \
    "$lame_sha256"

curl --fail --location --retry 3 \
    "https://github.com/yt-dlp/yt-dlp/releases/download/$yt_dlp_version/SHA2-256SUMS" \
    --output "$work_directory/SHA2-256SUMS"
if [ ! -f "$yt_dlp_archive" ]; then
    curl --fail --location --retry 3 \
        "https://github.com/yt-dlp/yt-dlp/releases/download/$yt_dlp_version/yt-dlp.tar.gz" \
        --output "$yt_dlp_archive"
fi
(
    cd "$cache_directory"
    expected_line="$(grep ' yt-dlp.tar.gz$' "$work_directory/SHA2-256SUMS")"
    expected_hash="$(printf '%s\n' "$expected_line" | awk '{ print $1 }')"
    actual_hash="$(shasum -a 256 "$yt_dlp_archive" | awk '{ print $1 }')"
    [ "$actual_hash" = "$expected_hash" ] || {
        echo "error: SHA-256 mismatch for yt-dlp source" >&2
        exit 1
    }
)

cp "$ffmpeg_archive" "$package_directory/"
cp "$lame_archive" "$package_directory/"
cp "$yt_dlp_archive" "$package_directory/yt-dlp-$yt_dlp_version.tar.gz"
cp "$script_directory/build-minimal-ffmpeg.sh" "$package_directory/"
cp "$project_directory/LICENSE" "$package_directory/MediaDock-GPL-3.0-or-later.txt"
cp "$project_directory/youtube-downloader/ThirdPartyNotices.md" "$package_directory/"

curl --fail --location --retry 3 \
    "https://raw.githubusercontent.com/yt-dlp/yt-dlp/$yt_dlp_commit/LICENSE" \
    --output "$package_directory/licenses/yt-dlp-Unlicense.txt"
curl --fail --location --retry 3 \
    "https://raw.githubusercontent.com/yt-dlp/yt-dlp/$yt_dlp_commit/THIRD_PARTY_LICENSES.txt" \
    --output "$package_directory/licenses/yt-dlp-THIRD_PARTY_LICENSES.txt"

cat > "$package_directory/README.txt" <<EOF
This archive accompanies the MediaDock binary release.

It contains the exact upstream source archives used by the bundled tools and the
reproducible minimal FFmpeg build script. yt-dlp release: $yt_dlp_version
($yt_dlp_commit). FFmpeg: $ffmpeg_version. LAME: $lame_version.
EOF

archive="$output_directory/MediaDock-third-party-sources-$yt_dlp_version.tar.gz"
tar -czf "$archive" -C "$work_directory" "$(basename "$package_directory")"
echo "Created $archive"
