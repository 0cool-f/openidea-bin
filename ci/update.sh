#!/bin/sh
# SPDX-License-Identifier: 0BSD
# Moves PKGBUILD and .SRCINFO to upstream release VERSION, with checksums of the release RPMs as
# downloaded from GitHub, then builds and checks the package with ci/check.sh.
# Usage: ci/update.sh VERSION   (needs gh; build output goes to stderr)
set -eu

[ $# -eq 1 ] || { echo "usage: $0 VERSION" >&2; exit 2; }
version=$1
root=$(cd "$(dirname "$0")/.." && pwd)
dl=$(mktemp -d)
trap 'rm -rf "$dl"' EXIT

gh release download "v$version" -R l0ng-ai/openidea -D "$dl" -p "OpenIDEA-$version-1.*.rpm"
sum() {
    [ -f "$dl/OpenIDEA-$version-1.$1.rpm" ] || { echo "release v$version lacks the $1 RPM" >&2; exit 1; }
    sha256sum "$dl/OpenIDEA-$version-1.$1.rpm" | cut -d' ' -f1
}
sha_x86_64=$(sum x86_64)
sha_aarch64=$(sum aarch64)

sed -i \
    -e "s/^pkgver=.*/pkgver=$version/" \
    -e "s/^pkgrel=.*/pkgrel=1/" \
    -e "s/^sha256sums_x86_64=.*/sha256sums_x86_64=('$sha_x86_64')/" \
    -e "s/^sha256sums_aarch64=.*/sha256sums_aarch64=('$sha_aarch64')/" \
    "$root/PKGBUILD"
"$root/ci/check.sh" --write-srcinfo >&2
