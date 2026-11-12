# openidea-bin

Automation for the AUR package [`openidea-bin`](https://aur.archlinux.org/packages/openidea-bin),
which repackages the prebuilt [OpenIDEA](https://github.com/l0ng-ai/openidea) release RPMs for
`x86_64` and `aarch64`. The package is co-maintained, so the AUR repository is the source of truth
and `PKGBUILD`, `.SRCINFO` and `LICENSE` here mirror it.

## How it is maintained

- `update` runs every 3 hours: it pulls the package files from the AUR and commits them to `main`
  when they changed there; when upstream has a newer stable release it sets `pkgver`, resets
  `pkgrel`, takes the checksums of the release RPMs, builds the package and runs `namcap`, then
  pushes to the AUR and to `main`. Without a newer release it builds the current package and, when
  `.SRCINFO` does not match the `PKGBUILD`, regenerates it and pushes the fix to the AUR and to
  `main`.
- `ci` builds every push and PR in an Arch container with `makepkg`, installs the depends and fails
  on any `namcap` error, such as a linked library missing from `depends`, or on a stale
  `.SRCINFO`. On `main` it pushes the package files to the AUR, refusing when the AUR has changes
  this repository has not pulled yet.
- `automerge` merges Dependabot PRs once `ci` has passed on them.

## Local use

```sh
ci/check.sh                   # build, namcap, verify .SRCINFO (needs podman)
ci/check.sh --write-srcinfo   # regenerate .SRCINFO after editing PKGBUILD
ci/update.sh 0.1.43           # move to another upstream release (needs gh)
ci/aur.sh pull                # copy the AUR package files over the working tree
```

`LICENSE` is OpenIDEA's Apache-2.0 license, installed by the package. The automation in `ci/` and
`.github/` is released under the 0BSD license.
