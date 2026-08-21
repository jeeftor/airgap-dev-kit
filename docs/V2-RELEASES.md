# v2 release architecture

v2.0.0 ships the lifecycle binary and complete kit for `linux/amd64` only.
The kit payload is selected through `kit-manifest.json`, whose payload directory
is `offline-packages/linux/amd64`; future ARM support therefore adds a distinct
target directory rather than repurposing the AMD64 payload.

`airgap` is the canonical command. `airgap-dev-kit` remains a symlink alias.
Normal install, status, and doctor commands are offline. Only `airgap update`
contacts GitHub Releases, verifies the raw `release-manifest.json` with an
embedded Ed25519 public key, and verifies the selected archive before it is
extracted.

Signed updates use the public key embedded in `internal/cli/update.go`. The
matching private key is stored only as the protected GitHub Actions secret
`AIRGAP_RELEASE_SIGNING_PRIVATE_KEY`. Never enable unsigned checksum-only
updates or commit the private key.

## Build and publish path

There is one release path:

```text
pull request or master push -> validation only
vX.Y.Z tag -> Release Air-Gap Kit -> archive, checksums, attestations, GitHub Release
```

Create the tag from the verified `master` commit:

```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```

The release workflow builds the `airgap` Linux binary, packages the complete
kit, verifies the archive includes the root `./airgap` launcher plus LazyVim
and Mason payloads, then publishes `airgap-dev-kit-linux-x86_64.tar.gz` and
`checksums.txt`. A non-SemVer `build-*` release is not part of this path.
