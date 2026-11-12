#!/bin/sh
# SPDX-License-Identifier: 0BSD
# Exchanges the package files (PKGBUILD, .SRCINFO, LICENSE) with the AUR repository.
#   pull: copies the AUR files over the working tree.
#   push: pushes the files of HEAD to the AUR, with HEAD's subject as message; refuses when the
#         AUR holds neither HEAD's nor HEAD^'s files, so changes made only on the AUR are never lost.
# Usage: ci/aur.sh pull|push   (SSH access to aur@aur.archlinux.org must already be set up)
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
files="PKGBUILD .SRCINFO LICENSE"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
aur=$tmp/aur
git clone -q ssh://aur@aur.archlinux.org/openidea-bin.git "$aur"

matches() {
    for f in $files; do
        git -C "$root" show "$1:$f" | cmp -s - "$aur/$f" || return 1
    done
}

case ${1:-} in
    pull)
        for f in $files; do cp "$aur/$f" "$root/$f"; done
        ;;
    push)
        if matches HEAD; then
            echo "AUR repository already up to date"
            exit 0
        fi
        if ! matches HEAD^; then
            echo "the AUR has changes this repository lacks: run the update workflow to pull them" >&2
            exit 1
        fi
        for f in $files; do git -C "$root" show "HEAD:$f" >"$aur/$f"; done
        git -C "$aur" add $files
        git -C "$aur" \
            -c user.name="$(git -C "$root" log -1 --format=%an)" \
            -c user.email="$(git -C "$root" log -1 --format=%ae)" \
            commit -q -m "$(git -C "$root" log -1 --format=%s)"
        git -C "$aur" push -q origin HEAD:master
        echo "pushed $(git -C "$aur" rev-parse --short HEAD) to the AUR"
        ;;
    *)
        echo "usage: $0 pull|push" >&2
        exit 2
        ;;
esac
