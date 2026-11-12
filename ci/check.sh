#!/bin/sh
# SPDX-License-Identifier: 0BSD
# Builds the package with makepkg as a non-root user in the ci/Containerfile image, installs its
# depends and runs namcap, failing on any namcap error such as a linked library missing from
# depends, and fails when .SRCINFO is out of date (--write-srcinfo rewrites it instead).
# Usage: ci/check.sh [--write-srcinfo]   (CONTAINER_ENGINE overrides podman)
set -eu

engine=${CONTAINER_ENGINE:-podman}
root=$(cd "$(dirname "$0")/.." && pwd)
work=$root/build
write=
case ${1:-} in
    --write-srcinfo) write=1 ;;
    '') ;;
    *) echo "usage: $0 [--write-srcinfo]" >&2; exit 2 ;;
esac

# Files the build user leaves behind are owned by a subordinate uid under rootless podman.
cleanup() { "$engine" unshare rm -rf "$work" 2>/dev/null || rm -rf "$work"; }
cleanup
trap cleanup EXIT
mkdir -p "$work"
cp "$root/PKGBUILD" "$root/LICENSE" "$work/"
chmod a+rwx "$work"
chmod a+r "$work/PKGBUILD" "$work/LICENSE"

"$engine" build -q -t openidea-bin-ci -f "$root/ci/Containerfile" "$root/ci" >/dev/null
"$engine" run --rm -v "$work:/pkg:Z" openidea-bin-ci sh -eu -c '
    su builder -c "cd /pkg && makepkg -f --nodeps --nocolor && makepkg --printsrcinfo >.SRCINFO"
    cd /pkg
    # namcap maps linked libraries to packages through the local database.
    pacman -Syu --needed --noconfirm --asdeps $(sed -n "s/^\tdepends = //p" .SRCINFO) >/dev/null
    echo "== namcap PKGBUILD"
    namcap PKGBUILD
    echo "== namcap package"
    namcap ./*.pkg.tar.zst | tee /tmp/namcap
    if grep -q " E: " /tmp/namcap; then
        echo "namcap reported errors" >&2
        exit 1
    fi
    echo "== libraries missing with only depends installed"
    mkdir /tmp/root
    bsdtar -xf ./*.pkg.tar.zst -C /tmp/root
    missing=$(find /tmp/root/usr/bin -type f -exec ldd {} + 2>/dev/null | grep "not found" | sort -u || true)
    if [ -n "$missing" ]; then
        echo "$missing" >&2
        exit 1
    fi
    echo none
'

if [ -n "$write" ]; then
    cp "$work/.SRCINFO" "$root/.SRCINFO"
elif ! diff -u "$root/.SRCINFO" "$work/.SRCINFO"; then
    echo ".SRCINFO is out of date: run ci/check.sh --write-srcinfo" >&2
    exit 1
fi
