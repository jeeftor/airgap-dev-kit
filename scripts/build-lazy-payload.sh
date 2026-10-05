#!/usr/bin/env bash
# Build the offline LazyVim payload from the pinned Neovim configuration.
set -euo pipefail

: "${NVIM:?Set NVIM to the bundled Linux Neovim binary}"
: "${LAZY_CONFIG:?Set LAZY_CONFIG to config/nvim/.config/nvim}"
: "${LAZY_OUTPUT:?Set LAZY_OUTPUT to the output tarball path}"
: "${PARSER_MANIFEST:?Set PARSER_MANIFEST to config/plugin-manifest.lua}"
: "${TREE_SITTER_VERSION:?Set the pinned Tree-sitter CLI release}"
: "${TREE_SITTER_SOURCE_SHA256:?Set the Tree-sitter source archive checksum}"

for tool in cargo musl-gcc readelf; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Connected Linux builder requires $tool for the portable Tree-sitter CLI" >&2; exit 1; }
done

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/airgap-lazy.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

config_home="$work_dir/config"
data_home="$work_dir/data"
state_home="$work_dir/state"
cache_home="$work_dir/cache"
config_dir="$config_home/nvim"

mkdir -p "$config_dir"
cp -R "$LAZY_CONFIG/." "$config_dir/"

# Lazy reads its lockfile from the data directory, so seed that path before sync.
mkdir -p "$data_home/nvim"
if [ -f "$config_dir/lazy-lock.json" ]; then
  cp "$config_dir/lazy-lock.json" "$data_home/nvim/lazy-lock.json"
fi

# The checked-in configuration is intentionally offline-first. Permit this
# one connected build to fetch exactly the lockfile-pinned plugin set.
lazy_config_file="$config_dir/lua/config/lazy.lua"
sed 's/missing = false/missing = true/' "$lazy_config_file" > "$lazy_config_file.tmp"
mv "$lazy_config_file.tmp" "$lazy_config_file"

# Synchronize plugin sources first; compile parsers separately below so failed
# downloads or builds cannot silently produce an incomplete offline archive.
cat > "$config_dir/lua/plugins/zz-airgap-payload-build.lua" <<'EOF'
return {
  { "mason-org/mason.nvim", config = false },
  { "mason-org/mason-lspconfig.nvim", config = false },
  { "nvim-treesitter/nvim-treesitter", config = false },
}
EOF

XDG_CONFIG_HOME="$config_home" \
XDG_DATA_HOME="$data_home" \
XDG_STATE_HOME="$state_home" \
XDG_CACHE_HOME="$cache_home" \
  "$NVIM" --headless '+Lazy! install' +qa

# Lazy rewrites its lock while bootstrapping missing plugins. Restore the
# immutable input after bootstrap, then check out those revisions explicitly.
cp "$LAZY_CONFIG/lazy-lock.json" "$data_home/nvim/lazy-lock.json"
XDG_CONFIG_HOME="$config_home" \
XDG_DATA_HOME="$data_home" \
XDG_STATE_HOME="$state_home" \
XDG_CACHE_HOME="$cache_home" \
  "$NVIM" --headless '+Lazy! restore' +qa

lazy_dir="$data_home/nvim/lazy"
test -d "$lazy_dir"
test -f "$data_home/nvim/lazy-lock.json"

site_dir="$data_home/nvim/site"
mkdir -p "$site_dir/bin"
curl -fsSL "https://codeload.github.com/tree-sitter/tree-sitter/tar.gz/refs/tags/${TREE_SITTER_VERSION}" -o "$work_dir/tree-sitter-source.tar.gz"
printf '%s  %s\n' "$TREE_SITTER_SOURCE_SHA256" "$work_dir/tree-sitter-source.tar.gz" | sha256sum -c -
mkdir -p "$work_dir/tree-sitter-source"
tar -xzf "$work_dir/tree-sitter-source.tar.gz" --strip-components=1 -C "$work_dir/tree-sitter-source"
(
  cd "$work_dir/tree-sitter-source"
  CC_x86_64_unknown_linux_musl=musl-gcc \
  CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=musl-gcc \
  CARGO_TARGET_DIR="$work_dir/tree-sitter-target" \
    cargo build --locked --release --package tree-sitter-cli --target x86_64-unknown-linux-musl
)
cp "$work_dir/tree-sitter-target/x86_64-unknown-linux-musl/release/tree-sitter" "$site_dir/bin/tree-sitter"
chmod 0755 "$site_dir/bin/tree-sitter"
# Upstream's GNU release binary requires newer glibc than supported targets.
# Reject dynamic dependencies so an accidental target/linker change cannot ship.
readelf -l -d "$site_dir/bin/tree-sitter" > "$work_dir/tree-sitter-elf.txt"
if awk '/INTERP|NEEDED/ { dynamic = 1 } END { exit !dynamic }' "$work_dir/tree-sitter-elf.txt"; then
  cat "$work_dir/tree-sitter-elf.txt" >&2
  echo 'Tree-sitter CLI must be statically linked' >&2
  exit 1
fi
"$site_dir/bin/tree-sitter" --version
mkdir -p "$work_dir/tree-sitter-probe"
printf '%s\n' '{"name":"airgap_probe","rules":{"source_file":{"type":"STRING","value":"hello"}}}' > "$work_dir/tree-sitter-probe/grammar.json"
(
  cd "$work_dir/tree-sitter-probe"
  "$site_dir/bin/tree-sitter" generate grammar.json
  test -s src/parser.c
)

cat > "$work_dir/build-parsers.lua" <<'LUA'
local expected = vim.json.decode(table.concat(vim.fn.readfile(vim.env.AIRGAP_LOCKFILE), "\n"))
for name, entry in pairs(expected) do
  local result = vim.system({ "git", "-C", vim.env.AIRGAP_LAZY_DIR .. "/" .. name, "rev-parse", "HEAD" }, { text = true }):wait()
  assert(result.code == 0 and vim.trim(result.stdout) == entry.commit, "Plugin not at locked revision: " .. name .. " expected=" .. entry.commit .. " actual=" .. tostring(result.stdout) .. " stderr=" .. tostring(result.stderr))
end
vim.opt.rtp:prepend(vim.env.AIRGAP_TS_PLUGIN)
local ts = require("nvim-treesitter")
ts.setup({ install_dir = vim.env.AIRGAP_TS_SITE })
local languages = dofile(vim.env.PARSER_MANIFEST).treesitter
ts.install(languages):wait(300000)
for _, language in ipairs(languages) do
  local parser = vim.env.AIRGAP_TS_SITE .. "/parser/" .. language .. ".so"
  assert(vim.fn.filereadable(parser) == 1, "Missing compiled parser: " .. language)
  assert(vim.treesitter.language.add(language, { path = parser }), "Cannot load parser: " .. language)
  assert(vim.treesitter.query.get(language, "highlights"), "Missing highlight queries: " .. language)
end
LUA
PATH="$site_dir/bin:$PATH" \
AIRGAP_LOCKFILE="$LAZY_CONFIG/lazy-lock.json" AIRGAP_LAZY_DIR="$lazy_dir" \
AIRGAP_TS_PLUGIN="$lazy_dir/nvim-treesitter" AIRGAP_TS_SITE="$site_dir" \
  "$NVIM" --headless -u NONE -i NONE -l "$work_dir/build-parsers.lua"

# Tree-sitter links query directories to absolute builder paths. Materialize
# only links within this disposable build so extraction is safe and portable.
while IFS= read -r -d '' link; do
  target=$(readlink -f -- "$link")
  case "$target" in
    "$work_dir"/*) ;;
    *) echo "Parser payload link escapes the build: $link -> $target" >&2; exit 1 ;;
  esac
done < <(find "$site_dir" -type l -print0)
cp -RL "$site_dir" "$work_dir/portable-site"
rm -rf "$site_dir"
mv "$work_dir/portable-site" "$site_dir"

mkdir -p "$(dirname "$LAZY_OUTPUT")"
tar -C "$data_home/nvim" -czf "$LAZY_OUTPUT" lazy lazy-lock.json site
