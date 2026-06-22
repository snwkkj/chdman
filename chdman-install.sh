#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${CHDMAN_DIR:-}"
BUILD_DIR="${CHDMAN_BUILD_DIR:-}"
MAME_REPO="${MAME_REPO:-https://github.com/mamedev/mame.git}"
MAME_REF="${MAME_REF:-master}"
MAME_LDOPTS="${MAME_LDOPTS:--llog}"
LOG_FILE="${CHDMAN_LOG:-}"
CLEAN_BUILD="${CHDMAN_CLEAN_BUILD:-1}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}"

info() {
  printf '\033[1;34m==>\033[0m %s\n' "$*"
}

die() {
  printf '\033[1;31mError:\033[0m %s\n' "$*" >&2
  exit 1
}

on_exit() {
  local status="$?"

  if [[ "$status" -ne 0 && -n "${LOG_FILE:-}" ]]; then
    printf '\nInstall failed. Full log: %s\n' "$LOG_FILE" >&2
  fi
}

trap on_exit EXIT

require_termux() {
  if [[ -z "${PREFIX:-}" || "$PREFIX" != *"/com.termux/"* ]]; then
    die "this installer is designed to run inside Termux."
  fi
}

set_install_dir() {
  if [[ -n "$APP_DIR" ]]; then
    return 0
  fi

  if [[ -d "$HOME/storage/shared" && ( "$PWD" == "$HOME" || "$PWD" == "$HOME/storage" ) ]]; then
    APP_DIR="$HOME/storage/shared/CHDMan"
    return 0
  fi

  if [[ "$PWD" != "$HOME" ]]; then
    APP_DIR="$PWD/CHDMan"
    return 0
  fi

  die "Termux storage is not available. Run termux-setup-storage or cd into the folder where you want chdman installed."
}

set_build_dir() {
  if [[ -z "$BUILD_DIR" ]]; then
    BUILD_DIR="$PREFIX/tmp/chdman-build"
  fi
}

setup_logging() {
  mkdir -p "$APP_DIR"

  if [[ -z "$LOG_FILE" ]]; then
    LOG_FILE="$APP_DIR/chdman-install.log"
  fi

  : > "$LOG_FILE"
  exec > >(tee -a "$LOG_FILE") 2>&1
  info "Writing install log to $LOG_FILE"
}

patch_android_log_link() {
  local makefile="$1/chdman.make"

  [[ -f "$makefile" ]] || die "could not find generated chdman makefile: $makefile"

  if ! grep -q -- "-llog" "$makefile"; then
    info "Patching chdman link flags for Android liblog"
    sed -i '/LIBS .* -lutil/ s/$/ -llog/' "$makefile"
  fi
}

install_deps() {
  info "Updating Termux packages"
  DEBIAN_FRONTEND=noninteractive apt update -y

  info "Finishing any interrupted package configuration"
  DEBIAN_FRONTEND=noninteractive dpkg --configure -a \
    --force-confdef \
    --force-confold

  info "Upgrading installed Termux packages"
  DEBIAN_FRONTEND=noninteractive apt full-upgrade -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold"

  info "Installing core build tools"
  DEBIAN_FRONTEND=noninteractive apt install -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    build-essential \
    binutils \
    ca-certificates \
    clang \
    cmake \
    curl \
    fontconfig \
    git \
    make \
    ninja \
    patch \
    pkg-config \
    python \
    zlib

  info "Installing SDL2 build headers from the Termux X11 repository"
  DEBIAN_FRONTEND=noninteractive apt install -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    x11-repo
  DEBIAN_FRONTEND=noninteractive apt update -y
  DEBIAN_FRONTEND=noninteractive apt install -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    sdl2

  info "Installing optional helper libraries when available"
  for package in \
    libflac \
    libjpeg-turbo \
    libpng \
    libsqlite \
    lua54 \
    openssl \
    unzip \
    zip; do
    if ! DEBIAN_FRONTEND=noninteractive apt install -y \
      -o Dpkg::Options::="--force-confdef" \
      -o Dpkg::Options::="--force-confold" \
      "$package"; then
      info "Optional package not installed: $package"
    fi
  done
}

fetch_mame() {
  mkdir -p "$BUILD_DIR"
  info "Using official MAME source: $MAME_REPO"

  if [[ -d "$BUILD_DIR/mame/.git" ]]; then
    info "Updating MAME source in $BUILD_DIR/mame"
    git -C "$BUILD_DIR/mame" fetch --depth 1 origin "$MAME_REF"
    git -C "$BUILD_DIR/mame" checkout FETCH_HEAD
  else
    info "Downloading MAME source"
    rm -rf "$BUILD_DIR/mame"
    git clone --depth 1 --branch "$MAME_REF" "$MAME_REPO" "$BUILD_DIR/mame"
  fi
}

build_chdman() {
  cd "$BUILD_DIR/mame"
  local bits project_dir

  bits="$(getconf LONG_BIT 2>/dev/null || echo 64)"

  info "Generating MAME tool build files"
  if make \
    REGENIE=1 \
    IGNORE_GIT=1 \
    NOWERROR=1 \
    TOOLS=1 \
    EMULATOR=0 \
    SUBTARGET=tiny \
    NO_OPENGL=1 \
    NO_X11=1 \
    NO_USE_MIDI=1 \
    NO_USE_PORTAUDIO=1 \
    NO_USE_PULSEAUDIO=1 \
    NO_USE_PIPEWIRE=1 \
    NO_USE_XINPUT=1 \
    USE_QTDEBUG=0 \
    LDOPTS="$MAME_LDOPTS" \
    build/projects/sdl/mametiny/gmake-linux-clang/Makefile; then
    project_dir="build/projects/sdl/mametiny/gmake-linux-clang"
  else
    info "Clang project generation failed; trying the generic Linux makefile"
    make \
      REGENIE=1 \
      IGNORE_GIT=1 \
      NOWERROR=1 \
      TOOLS=1 \
      EMULATOR=0 \
      SUBTARGET=tiny \
      NO_OPENGL=1 \
      NO_X11=1 \
      NO_USE_MIDI=1 \
      NO_USE_PORTAUDIO=1 \
      NO_USE_PULSEAUDIO=1 \
      NO_USE_PIPEWIRE=1 \
      NO_USE_XINPUT=1 \
      USE_QTDEBUG=0 \
      LDOPTS="$MAME_LDOPTS" \
      build/projects/sdl/mametiny/gmake-linux/Makefile
    project_dir="build/projects/sdl/mametiny/gmake-linux"
  fi

  patch_android_log_link "$project_dir"

  info "Generating MAME version source"
  make \
    REGENIE=1 \
    IGNORE_GIT=1 \
    NOWERROR=1 \
    TOOLS=1 \
    EMULATOR=0 \
    SUBTARGET=tiny \
    NO_OPENGL=1 \
    NO_X11=1 \
    NO_USE_MIDI=1 \
    NO_USE_PORTAUDIO=1 \
    NO_USE_PULSEAUDIO=1 \
    NO_USE_PIPEWIRE=1 \
    NO_USE_XINPUT=1 \
    USE_QTDEBUG=0 \
    LDOPTS="$MAME_LDOPTS" \
    build/generated/version.cpp

  info "Building chdman with $JOBS job(s). This can take a while on a phone"
  make -j"$JOBS" -C "$project_dir" "config=release$bits" LDOPTS="$MAME_LDOPTS" chdman

  CHDMAN_BIN="$(find "$BUILD_DIR/mame" -type f -name chdman -perm -u+x | head -n 1 || true)"
  [[ -n "$CHDMAN_BIN" ]] || die "the build finished, but the chdman binary was not found."
}

install_files() {
  info "Creating $APP_DIR"
  mkdir -p "$APP_DIR"

  rm -f "$PREFIX/bin/chdman"
  cp "$CHDMAN_BIN" "$PREFIX/bin/chdman"
  chmod +x "$PREFIX/bin/chdman"

  info "Creating iso2chd.sh"
  cat > "$APP_DIR/iso2chd.sh" <<'ISO2CHD'
#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CHDMAN="${CHDMAN_BIN:-}"
OUT_DIR="${CHDMAN_OUT_DIR:-$SCRIPT_DIR/converted}"

if [[ -z "$CHDMAN" ]]; then
  if command -v chdman >/dev/null 2>&1; then
    CHDMAN="$(command -v chdman)"
  fi
fi

usage() {
  cat <<USAGE
Usage:
  bash iso2chd.sh
  bash iso2chd.sh file.iso [another-file.iso ...]
  bash iso2chd.sh /path/to/folder

Supported formats:
  .iso, .cue, .gdi

When no input is provided, this script converts supported files from:
  $SCRIPT_DIR

CHD files will be saved in:
  $OUT_DIR

You can change the chdman binary or output folder like this:
  CHDMAN_BIN=/data/data/com.termux/files/usr/bin/chdman bash iso2chd.sh game.iso
  CHDMAN_OUT_DIR=/sdcard/CHD bash iso2chd.sh game.iso
USAGE
}

[[ -x "$CHDMAN" ]] || {
  echo "Could not find chdman at: $CHDMAN" >&2
  echo "Set CHDMAN_BIN=/path/to/chdman or install chdman into the Termux PATH." >&2
  exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

mkdir -p "$OUT_DIR"

convert_one() {
  local input="$1"
  local base output

  case "${input,,}" in
    *.iso|*.cue|*.gdi) ;;
    *)
      echo "Skipping unsupported format: $input" >&2
      return 0
      ;;
  esac

  [[ -f "$input" ]] || {
    echo "Skipping, not a file: $input" >&2
    return 0
  }

  base="$(basename "$input")"
  output="$OUT_DIR/${base%.*}.chd"

  if [[ -e "$output" ]]; then
    echo "Already exists, skipping: $output"
    return 0
  fi

  echo "Converting: $input"
  "$CHDMAN" createcd -i "$input" -o "$output"
  echo "Saved to: $output"
}

if [[ "$#" -eq 0 ]]; then
  set -- "$SCRIPT_DIR"
fi

for item in "$@"; do
  if [[ -d "$item" ]]; then
    while IFS= read -r -d '' file; do
      convert_one "$file"
    done < <(find "$item" -type f \( -iname '*.iso' -o -iname '*.cue' -o -iname '*.gdi' \) -print0)
  else
    convert_one "$item"
  fi
done
ISO2CHD

  chmod +x "$APP_DIR/iso2chd.sh"

  if [[ -L "$PREFIX/bin/iso2chd" && "$(readlink "$PREFIX/bin/iso2chd")" == "$APP_DIR/iso2chd.sh" ]]; then
    rm -f "$PREFIX/bin/iso2chd"
  fi
}

cleanup_build_files() {
  if [[ "$CLEAN_BUILD" != "1" ]]; then
    info "Keeping build files in $BUILD_DIR"
    return 0
  fi

  info "Cleaning build files from $BUILD_DIR"
  rm -rf "$BUILD_DIR"
}

main() {
  require_termux
  set_install_dir
  set_build_dir
  setup_logging
  install_deps
  fetch_mame
  build_chdman
  install_files
  cleanup_build_files

  info "Done"
}

main "$@"
