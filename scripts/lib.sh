# Shared environment and helpers, sourced by every script.
set -euo pipefail

# Code/config root: the flake source when run via `nix run`, else the repo.
PN_ROOT="${PN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# Mutable state root: checkouts, build tree and output land here.
PN_STATE="${PN_STATE:-$PWD}"

WORK="$PN_STATE/work"
OUT="$PN_STATE/out"
SRC="$WORK/proton"
PROTONFIXES="$SRC/protonfixes"

BUILD_NAME="${PN_BUILD_NAME:-proton-nixlyos}"

# Build variant: v3 (x86-64-v3) or generic (baseline x86-64). Fetch/patch
# state is shared; build and stage trees are per-variant.
PN_VARIANT="${PN_VARIANT:-v3}"
case "$PN_VARIANT" in v3|generic) ;; *)
    echo "unknown PN_VARIANT '$PN_VARIANT' (v3|generic)" >&2; exit 1 ;;
esac
BUILD="$WORK/build-$PN_VARIANT"
STAGE="$WORK/stage-$PN_VARIANT"

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
