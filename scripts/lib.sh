# Shared environment and helpers, sourced by every script.
set -euo pipefail

# Code/config root: the flake source when run via `nix run`, else the repo.
PN_ROOT="${PN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# Mutable state root: checkouts, build tree and output land here.
PN_STATE="${PN_STATE:-$PWD}"

WORK="$PN_STATE/work"
OUT="$PN_STATE/out"
SRC="$WORK/proton"
BUILD="$WORK/build"
PROTONFIXES="$SRC/protonfixes"
STAGE="$WORK/stage"

BUILD_NAME="${PN_BUILD_NAME:-proton-nixlyos}"

export CCACHE_DIR="${CCACHE_DIR:-$WORK/ccache}"

log()  { printf '\033[1;32m[proton-nixlyos]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[proton-nixlyos] WARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[proton-nixlyos] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# Read one component line from sources.conf: prints "url branch".
source_for() {
    local line
    line="$(grep -E "^$1\|" "$PN_ROOT/config/sources.conf")" \
        || die "component '$1' missing from sources.conf"
    echo "${line#*|}" | tr '|' ' '
}

# Filesystem location of a component's source tree.
component_dir() {
    case "$1" in
        proton)      echo "$SRC" ;;
        protonfixes) echo "$PROTONFIXES" ;;
        *)           echo "$SRC/$1" ;;
    esac
}
