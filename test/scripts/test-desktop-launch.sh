#!/usr/bin/env bash
# Run inside Xvfb and a D-Bus session with a disposable installation home.
set -euo pipefail

: "${AIRGAP_GUI_TEST_HOME:?Set a disposable GUI test home}"
: "${AIRGAP_GUI_TEST_LOGS:?Set a directory for GUI test evidence}"
[[ "$HOME" == "$AIRGAP_GUI_TEST_HOME" ]] || { echo "Your home must be the disposable GUI test home" >&2; exit 1; }
archive=$(realpath "${1:?Pass the packaged Linux kit}")
logs_dir="$AIRGAP_GUI_TEST_LOGS"
mkdir -p "$logs_dir" "$HOME/.config" "$HOME/.runtime"
chmod 0700 "$HOME/.runtime"

report_failure() {
  local status=$?
  if [[ "$status" -ne 0 ]]; then
    tail -n 80 "$logs_dir"/*.log >&2 || true
  fi
}
trap report_failure EXIT

kit_dir=$(mktemp -d)
tar -xzf "$archive" -C "$kit_dir"
# Keep $HOME literal in the target's XDG directory configuration.
# shellcheck disable=SC2016
printf 'XDG_DESKTOP_DIR="$HOME/Your Desktop"\n' > "$HOME/.config/user-dirs.dirs"
cd "$kit_dir/airgap-dev-kit"
./airgap install --yes --nvim-mode=replace --configure-shell=false \
  --desktop-integration=menu-and-desktop > "$logs_dir/install.log" 2>&1

menu="$XDG_DATA_HOME/applications/airgap-wezterm.desktop"
shortcut="$HOME/Your Desktop/airgap-wezterm.desktop"
test -x "$shortcut"

launch_entry() {
  local entry="$1" label="$2" window=""
  desktop-file-validate "$entry"
  if [[ "$label" == menu ]]; then
    timeout 15s gtk-launch airgap-wezterm.desktop > "$logs_dir/$label.log" 2>&1
  else
    timeout 15s gio launch "$entry" > "$logs_dir/$label.log" 2>&1
  fi
  for _ in {1..20}; do
    xwininfo -root -tree > "$logs_dir/$label-tree.log"
    window=$(awk 'tolower($0) ~ /wezterm/ && $1 ~ /^0x/ {print $1; exit}' "$logs_dir/$label-tree.log")
    if [[ -n "$window" ]]; then
      break
    fi
    sleep 1
  done
  [[ -n "$window" ]] || { echo "No WezTerm window appeared from $label" >&2; return 1; }
  sleep 2
  xwininfo -id "$window" > "$logs_dir/$label-window.log"
  grep -q 'Map State: IsViewable' "$logs_dir/$label-window.log"
  timeout 15s "$HOME/.local/bin/wezterm" cli list --format json > "$logs_dir/$label-panes.log"
  "$HOME/.local/bin/jq" -e 'length > 0' "$logs_dir/$label-panes.log" >/dev/null
  import -window root "$logs_dir/$label.png"
  xkill -id "$window"
  for _ in {1..10}; do
    if ! xwininfo -root -tree | grep -qi wezterm; then
      echo "PASS: $label opened a visible WezTerm window through its desktop entry"
      return 0
    fi
    sleep 1
  done
  echo "The $label window did not close before the next independent launch" >&2
  return 1
}

# Each entry must create its own window; an earlier launch cannot satisfy both.
launch_entry "$menu" menu
launch_entry "$shortcut" desktop

# Confirm a broken Exec is rejected rather than counted as a successful launch.
sed 's|^Exec=.*|Exec=/airgap-test/nonexistent-command|' "$menu" > "$logs_dir/broken.desktop"
if timeout 15s gio launch "$logs_dir/broken.desktop" > "$logs_dir/broken.log" 2>&1; then
  echo "A broken desktop entry unexpectedly launched" >&2
  exit 1
fi

./airgap uninstall --yes > "$logs_dir/uninstall.log" 2>&1
test ! -f "$menu"
test ! -f "$shortcut"
echo "PASS: GUI entries validate, launch, reject a broken Exec, and uninstall"
