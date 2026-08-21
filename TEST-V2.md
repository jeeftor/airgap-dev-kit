# Linux AMD64 v2 test guide

This guide tests the `v2.0.0-test.3` full kit on a Linux x86_64 machine. It is
a test artifact, not a signed production release. The Go command provides the
colored help and install confirmation UI; the underlying installation work is
still performed by the established shell installer.

## 1. Confirm the target

Run these commands on Linux before transferring the archive:

```sh
uname -s
uname -m
```

Expected values are `Linux` and either `x86_64` or `amd64`. Do not use this
AMD64 archive on ARM hardware.

## 2. Transfer and verify

Copy both files to the Linux machine:

- `airgap-dev-kit-linux-x86_64.tar.gz`
- `checksums.txt`

Verify before extracting:

```sh
sha256sum -c checksums.txt
```

The expected digest for this test artifact is:

```text
df572752da0ba39accbd00b0fffa3a68d0c618087fff25bdefe8265752c7c66f
```

## 3. Extract into a new directory

Do not extract over a prior test directory.

```sh
mkdir -p ~/airgap-v2-test
tar -xzf airgap-dev-kit-linux-x86_64.tar.gz -C ~/airgap-v2-test
cd ~/airgap-v2-test/airgap-dev-kit
```

## 4. Exercise the Go command first

These commands are offline and do not change your installation:

```sh
./offline-packages/linux/amd64/airgap --help
./offline-packages/linux/amd64/airgap version
./offline-packages/linux/amd64/airgap status --output json
./offline-packages/linux/amd64/airgap doctor --strict
```

When run from a terminal, help and normal text output use color. Set
`NO_COLOR=1` to force plain output.

## 5. Preview installation safely

This is the recommended first installer run. It uses the existing Neovim
profile instead of replacing it and must not make changes:

```sh
./offline-packages/linux/amd64/airgap install --dry-run --nvim-mode=preserve
```

## 6. Run the interactive test install

This starts the colored Go confirmation UI. Press `Enter` or `y` to continue;
press `q` or `Esc` to cancel. The shell installer may ask follow-up questions
about optional payloads.

```sh
./offline-packages/linux/amd64/airgap install --nvim-mode=preserve
```

Use `--no-tui` for deterministic text, such as redirected output. The TUI is
also disabled automatically by `--yes`, `NO_COLOR`, `TERM=dumb`, or non-TTY
input/output.

## 7. Confirm the installed commands

Open a new shell if the installer changed your shell configuration, then run:

```sh
airgap version
airgap-dev-kit version
airgap doctor --strict
```

The two command names are aliases for the same Go binary.

## 8. Report results

Capture the output of the Go-command checks, dry-run, and any installer error.
Do not use `airgap update` in this test: release signing is intentionally
fail-closed until the protected Ed25519 release key and tag publication flow
are provisioned.
