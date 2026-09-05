#!/usr/bin/env bash
# Resolve "auto" to the newest versioned branch of a repo.
# Considers cachyos_X.Y_DATE/main, experimental_X.Y and proton_X.Y;
# highest version wins, ties break cachyos > experimental > proton.
# Usage: resolve-branch.sh <git url>
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

url="$1"
branch="$(git ls-remote --heads "$url" \
    | awk '{print $2}' \
    | sed 's|refs/heads/||' \
    | grep -E '^(experimental_[0-9.]+|cachyos_[0-9.]+_[0-9]+/main|proton_[0-9.]+)$' \
    | sed -E 's/^cachyos_([0-9.]+).*/\1 3 &/; s/^experimental_([0-9.]+).*/\1 2 &/; s/^proton_([0-9.]+).*/\1 1 &/' \
    | sort -V \
    | tail -1 \
    | cut -d' ' -f3-)"

[ -n "$branch" ] || die "no versioned branch found at $url"
echo "$branch"
