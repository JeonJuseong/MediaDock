#!/bin/sh

set -eu

ffmpeg_version="8.1.2"
ffmpeg_sha256="464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c"
lame_version="3.100"
lame_sha256="ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e"
deployment_target="11.0"

script_directory="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
project_directory="$(dirname "$script_directory")"
output_directory="${1:-$project_directory/youtube-downloader/ffmpeg-exec}"
cache_directory="${MEDIASAVER_SOURCE_CACHE:-$project_directory/.build/third-party-sources}"
work_directory="$(mktemp -d "${TMPDIR:-/tmp}/mediadock-minimal-ffmpeg.XXXXXX")"
trap 'rm -rf "$work_directory"' EXIT

mkdir -p "$cache_directory" "$output_directory/licenses"

download_and_verify() {
    url="$1"
    archive="$2"
    expected_sha256="$3"

    if [ ! -f "$archive" ]; then
        curl --fail --location --retry 3 "$url" --output "$archive"
    fi

    actual_sha256="$(shasum -a 256 "$archive" | awk '{ print $1 }')"
    if [ "$actual_sha256" != "$expected_sha256" ]; then
        echo "error: SHA-256 mismatch for $archive" >&2
        exit 1
    fi
}

ffmpeg_archive="$cache_directory/ffmpeg-$ffmpeg_version.tar.xz"
lame_archive="$cache_directory/lame-$lame_version.tar.gz"

download_and_verify \
    "https://ffmpeg.org/releases/ffmpeg-$ffmpeg_version.tar.xz" \
    "$ffmpeg_archive" \
    "$ffmpeg_sha256"
download_and_verify \
    "https://downloads.sourceforge.net/project/lame/lame/$lame_version/lame-$lame_version.tar.gz" \
    "$lame_archive" \
    "$lame_sha256"

tar -xf "$ffmpeg_archive" -C "$work_directory"
tar -xf "$lame_archive" -C "$work_directory"

parallel_jobs="$(sysctl -n hw.ncpu 2>/dev/null || printf '4')"
lame_prefix="$work_directory/lame-install"

(
    cd "$work_directory/lame-$lame_version"
    ./configure \
        --prefix="$lame_prefix" \
        --host=arm-apple-darwin \
        --disable-shared \
        --enable-static \
        --disable-frontend \
        CFLAGS="-arch arm64 -mmacosx-version-min=$deployment_target -O2" \
        LDFLAGS="-arch arm64 -mmacosx-version-min=$deployment_target"
    make -j"$parallel_jobs"
    make install
)

ffmpeg_prefix="$work_directory/ffmpeg-install"
configure_arguments="--prefix=$ffmpeg_prefix --arch=arm64 --target-os=darwin --cc=clang --disable-autodetect --disable-shared --enable-static --disable-doc --disable-debug --disable-ffplay --enable-libmp3lame --enable-audiotoolbox --enable-videotoolbox --extra-cflags=-arch arm64 -mmacosx-version-min=$deployment_target -I$lame_prefix/include --extra-ldflags=-arch arm64 -mmacosx-version-min=$deployment_target -L$lame_prefix/lib --extra-libs=-lmp3lame"

(
    cd "$work_directory/ffmpeg-$ffmpeg_version"
    PKG_CONFIG_PATH="$lame_prefix/lib/pkgconfig" ./configure \
        --prefix="$ffmpeg_prefix" \
        --arch=arm64 \
        --target-os=darwin \
        --cc=clang \
        --disable-autodetect \
        --disable-shared \
        --enable-static \
        --disable-doc \
        --disable-debug \
        --disable-ffplay \
        --enable-libmp3lame \
        --enable-audiotoolbox \
        --enable-videotoolbox \
        --extra-cflags="-arch arm64 -mmacosx-version-min=$deployment_target -I$lame_prefix/include" \
        --extra-ldflags="-arch arm64 -mmacosx-version-min=$deployment_target -L$lame_prefix/lib" \
        --extra-libs=-lmp3lame
    make -j"$parallel_jobs" ffmpeg ffprobe
)

cp "$work_directory/ffmpeg-$ffmpeg_version/ffmpeg" "$output_directory/ffmpeg"
cp "$work_directory/ffmpeg-$ffmpeg_version/ffprobe" "$output_directory/ffprobe"
chmod 755 "$output_directory/ffmpeg" "$output_directory/ffprobe"

cp "$work_directory/ffmpeg-$ffmpeg_version/COPYING.LGPLv2.1" \
    "$output_directory/licenses/FFmpeg-LGPL-2.1.txt"
cp "$work_directory/lame-$lame_version/COPYING" \
    "$output_directory/licenses/LAME-LGPL-2.0.txt"

cat > "$output_directory/BUILD-INFO.txt" <<EOF
FFmpeg version: $ffmpeg_version
FFmpeg source: https://ffmpeg.org/releases/ffmpeg-$ffmpeg_version.tar.xz
FFmpeg SHA-256: $ffmpeg_sha256
LAME version: $lame_version
LAME source: https://downloads.sourceforge.net/project/lame/lame/$lame_version/lame-$lame_version.tar.gz
LAME SHA-256: $lame_sha256
Architecture: arm64
Minimum macOS: $deployment_target
FFmpeg configure arguments:
$configure_arguments
EOF

if otool -L "$output_directory/ffmpeg" "$output_directory/ffprobe" \
    | grep -E '/opt/homebrew|/usr/local' >/dev/null; then
    echo "error: Minimal FFmpeg still references Homebrew libraries." >&2
    exit 1
fi

if ! "$output_directory/ffmpeg" -hide_banner -encoders 2>/dev/null \
    | grep 'libmp3lame' >/dev/null; then
    echo "error: Minimal FFmpeg does not contain the libmp3lame encoder." >&2
    exit 1
fi

"$output_directory/ffprobe" -version >/dev/null
echo "Built minimal LGPL FFmpeg in $output_directory"
