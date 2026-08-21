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

Before publishing v2, replace the fail-closed placeholder public key in
`internal/cli/update.go` with the protected release signing public key and add
the corresponding private key only to protected GitHub Actions secrets. Never
enable unsigned checksum-only updates.
