#!/usr/bin/env python3
"""Exercise the kit's mouse and clipboard paths in a Linux virtual display."""

import argparse
import base64
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import tty
from collections.abc import Callable


def run(*args: str, env: dict[str, str] | None = None) -> str:
    """Run a bounded command and report useful diagnostics on failure."""
    try:
        result = subprocess.run(args, env=env, text=True, capture_output=True, check=True, timeout=20)
    except subprocess.CalledProcessError as error:
        print(error.stderr, file=sys.stderr, end="")
        raise
    return result.stdout


def wait_for(check: Callable[[], bool], description: str) -> None:
    """Allow asynchronous GUI and clipboard operations to settle."""
    for _ in range(100):
        if check():
            return
        time.sleep(0.1)
    raise AssertionError(description)


def fixture(output: Path) -> None:
    """Serve deterministic terminal text, application clipboard writes, and paste capture."""
    tty.setraw(sys.stdin.fileno())
    sys.stdout.write("\033[2J\033[H\033[?2004h\033[2;2Hpane-selection-marker\033[4;2Hclipboard fixture")
    sys.stdout.flush()
    while data := os.read(sys.stdin.fileno(), 4096):
        with output.open("ab") as stream:
            stream.write(data)
        for key, text in [(b"r", b"raw-application-marker"), (b"w", b"wrapped-application-marker")]:
            if data == key:
                sequence = b"\033]52;c;" + base64.b64encode(text) + b"\a"
                if key == b"w":
                    sequence = b"\033Ptmux;\033" + sequence + b"\033\\"
                os.write(sys.stdout.fileno(), sequence)


def main() -> None:
    """Verify pane selection, application OSC 52, and real middle-click paste."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wezterm", default="wezterm")
    parser.add_argument("--kitty", help="Test the portable Kitty executable instead of WezTerm")
    parser.add_argument("--tmux", default="tmux")
    parser.add_argument("--config-root", type=Path, required=True)
    parser.add_argument("--logs", type=Path, required=True)
    parser.add_argument("--opencode", required=True)
    args = parser.parse_args()
    logs: Path = args.logs.resolve()
    logs.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="airgap-clipboard-") as directory:
        home = Path(directory)
        runtime = home / "runtime"
        runtime.mkdir(mode=0o700)
        env = os.environ | {"HOME": str(home), "XDG_RUNTIME_DIR": str(runtime),
                           "XDG_CONFIG_HOME": str(home / ".config"),
                           "XDG_DATA_HOME": str(home / ".local/share"),
                           "XDG_STATE_HOME": str(home / ".local/state"),
                           "XDG_CACHE_HOME": str(home / ".cache"),
                           "LIBGL_ALWAYS_SOFTWARE": "true"}
        env.pop("WAYLAND_DISPLAY", None)
        env.pop("TMUX", None)
        env.pop("WEZTERM_UNIX_SOCKET", None)
        # The installed font lives in the caller's user data directory. Keep it
        # visible to the GUI while isolating tmux and OpenCode configuration/state.
        gui_env = env | {"HOME": str(Path.home()),
                         "XDG_DATA_HOME": os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))}
        isolated_home = [f"{key}={env[key]}" for key in
                         ("HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME")]
        socket = str(home / "tmux.sock")
        output = logs / "fixture-input.bin"
        output.write_bytes(b"")

        def tmux(*command: str) -> str:
            """Address only the disposable tmux server."""
            return run(args.tmux, "-S", socket, *command, env=env)

        def clipboard() -> str:
            """Read the external clipboard only from the test harness."""
            try:
                return run("xclip", "-selection", "clipboard", "-o", env=env)
            except subprocess.CalledProcessError:
                return ""

        terminal = "Kitty" if args.kitty else "WezTerm"
        if args.kitty:
            terminal_command = [
                args.kitty, "--config", str(args.config_root / "kitty/.config/kitty/kitty.conf"),
                "--title", "airgap-clipboard-test", "--override", "window_padding_width=0",
                "--override", "window_margin_width=0", "--override", "hide_window_decorations=yes",
                "--override", "initial_window_width=100c", "--override", "initial_window_height=30c",
            ]
        else:
            terminal_command = [args.wezterm, "--config-file",
                                str(args.config_root / "wezterm/.config/wezterm/wezterm.lua"),
                                "start", "--always-new-process", "--cwd", str(logs), "--"]
        with (logs / (terminal.lower() + ".log")).open("w") as log:
            process = subprocess.Popen([
                *terminal_command, "/usr/bin/env", *isolated_home,
                args.tmux, "-S", socket,
                "-f", str(args.config_root / "tmux/.tmux.conf"), "new-session", "-s", "clipboard",
                sys.executable, str(Path(__file__).resolve()), "--fixture", str(output),
            ], env=gui_env, stdout=log, stderr=log, cwd=logs)
            try:
                if args.kitty:
                    def find_window() -> str:
                        """Find the isolated Kitty test window without a window manager."""
                        result = subprocess.run(["xdotool", "search", "--name", "^airgap-clipboard-test$"],
                                                env=env, text=True, capture_output=True, timeout=20)
                        return result.stdout.strip()
                    wait_for(find_window, "Kitty did not start")
                    window = find_window().splitlines()[0]
                    wait_for(lambda: Path(socket).exists(), "tmux socket did not appear")
                    wait_for(lambda: "pane-selection-marker" in tmux("capture-pane", "-p"), "fixture did not render")
                    geometry = dict(line.split("=") for line in
                                    run("xdotool", "getwindowgeometry", "--shell", window).splitlines())
                    cols, rows = tmux("display-message", "-p", "#{client_width} #{client_height}").split()
                    pane = {"size": {"cols": int(cols), "rows": int(rows),
                                     "pixel_width": int(geometry["WIDTH"]), "pixel_height": int(geometry["HEIGHT"])}}
                else:
                    wait_for(lambda: bool(list(runtime.glob("wezterm/gui-sock-*"))), "WezTerm did not start")
                    env["WEZTERM_UNIX_SOCKET"] = str(next(runtime.glob("wezterm/gui-sock-*")))

                    def wez(*command: str) -> str:
                        """Send input to the real terminal instance."""
                        return run(args.wezterm, "cli", "--no-auto-start", *command, env=env)

                    pane = json.loads(wez("list", "--format", "json"))[0]
                    (logs / "terminal-size.json").write_text(json.dumps(pane, indent=2))
                    # AppImage extraction can leave a launcher parent above the GUI process.
                    gui_pid = Path(env["WEZTERM_UNIX_SOCKET"]).name.removeprefix("gui-sock-")
                    window = run("xdotool", "search", "--pid", gui_pid, "--class", "org.wezfurlong.wezterm").splitlines()[0]
                run("xdotool", "windowfocus", "--sync", window)
                wait_for(lambda: "pane-selection-marker" in tmux("capture-pane", "-p"), "fixture did not render")
                target = tmux("display-message", "-p", "#{pane_id}").strip()
                tmux("split-window", "-h", "-d", "printf '\033[2;2HNEIGHBOR-MUST-NOT-BE-COPIED'; sleep 300")
                time.sleep(0.5)

                def drag(column: int, row: int, end_column: int) -> None:
                    """Generate actual mouse events with time for each terminal redraw."""
                    size = pane["size"]
                    width = size["pixel_width"] / size["cols"]
                    height = size["pixel_height"] / size["rows"]
                    left, top = (0, 0) if args.kitty else (8, 6)
                    y = str(round(top + (row - 0.5) * height))
                    commands = ["xdotool", "mousemove", "--window", window,
                                str(round(left + (column - 0.5) * width)), y,
                                "mousedown", "1", "sleep", "0.2"]
                    # A jump directly into a neighboring pane omits every motion in the source pane.
                    for cell in range(column + 1, end_column + 1):
                        commands += ["mousemove", "--window", window,
                                     str(round(left + (cell - 0.5) * width)), y, "sleep", "0.01"]
                    run(*commands, "sleep", "0.2", "mouseup", "1")

                def middle_paste(expected: str) -> None:
                    """Ensure a real middle-click pastes CLIPBOARD rather than stale PRIMARY."""
                    subprocess.run(["xclip", "-selection", "primary"], input=b"stale-primary-marker", env=env, check=True)
                    before = output.stat().st_size
                    time.sleep(0.6)  # Separate single clicks from the terminal's multi-click interval.
                    run("xdotool", "mousemove", "--window", window, "150", "100", "click", "2")
                    wait_for(lambda: expected.encode() in output.read_bytes()[before:], "middle-click did not paste " + expected)

                # Verify the actual terminal before exercising tmux forwarding.
                terminal_tty = tmux("display-message", "-p", "#{client_tty}").strip()
                with open(terminal_tty, "wb", buffering=0) as stream:
                    stream.write(b"\033]52;c;" + base64.b64encode(b"direct-terminal-marker") + b"\a")
                wait_for(lambda: clipboard() == "direct-terminal-marker", "direct OSC 52 did not update " + terminal + " CLIPBOARD")
                print("PASS: direct " + terminal + " OSC 52 clipboard write", flush=True)
                tmux("set-buffer", "-w", "manual-tmux-marker")
                wait_for(lambda: clipboard() == "manual-tmux-marker", "tmux set-buffer -w did not update CLIPBOARD")
                print("PASS: tmux set-buffer -w clipboard write", flush=True)

                if args.kitty:
                    # Native terminal selection must use the same clipboard as applications.
                    tmux("set-option", "-g", "mouse", "off")
                    time.sleep(0.3)
                    drag(2, 2, 23)
                    wait_for(lambda: clipboard() == "pane-selection-marker", "native terminal drag did not reach CLIPBOARD")
                    middle_paste("pane-selection-marker")
                    tmux("set-option", "-g", "mouse", "on")
                    time.sleep(0.3)
                    print("PASS: native terminal selection and middle-click")

                # Drag enters tmux copy mode, including across a pane boundary.
                drag(2, 2, 22)
                wait_for(lambda: clipboard() == "pane-selection-marker", "tmux drag did not reach CLIPBOARD")
                middle_paste("pane-selection-marker")
                subprocess.run(["xclip", "-selection", "clipboard"], input=b"before-cross-pane-drag", env=env, check=True)
                drag(2, 2, 75)
                # Releasing over another pane may leave copy mode active; commit with vi y.
                if tmux("display-message", "-p", "-t", target, "#{pane_in_mode}").strip() == "1":
                    tmux("send-keys", "-t", target, "y")
                wait_for(lambda: "pane-selection-marker" in clipboard(), "cross-pane drag did not copy")
                assert "NEIGHBOR" not in clipboard(), "selection crossed into the neighboring pane"
                print("PASS: tmux mouse selection and middle-click, with pane boundaries")

                for key, expected in [("r", "raw-application-marker"), ("w", "wrapped-application-marker")]:
                    tmux("send-keys", "-t", target, "-l", key)
                    wait_for(lambda: clipboard() == expected, expected + " did not reach " + terminal)
                    middle_paste(expected)
                    print("PASS: " + expected + " and middle-click")

                print("OpenCode version: " + run(args.opencode, "--version").strip())
                # No prompt is submitted and no model/provider is required.
                no_tools = home / "no-clipboard-tools"
                no_tools.mkdir()
                tmux("respawn-pane", "-k", "-t", target, "/usr/bin/env", "PATH=" + str(no_tools),
                     "OPENCODE_DISABLE_MODELS_FETCH=true", "OPENCODE_DISABLE_AUTOUPDATE=true", args.opencode)
                wait_for(lambda: "Ask anything" in tmux("capture-pane", "-p", "-t", target), "OpenCode input did not render")
                marker = "opencode-selection-marker"
                tmux("send-keys", "-t", target, "-l", marker)
                wait_for(lambda: marker in tmux("capture-pane", "-p", "-t", target), "OpenCode input not visible")
                lines = tmux("capture-pane", "-p", "-t", target).splitlines()
                row = next(i for i, line in enumerate(lines) if marker in line)
                column = lines[row].index(marker)
                drag(column + 1, row + 1, column + len(marker) + 1)
                wait_for(lambda: clipboard() == marker, "OpenCode mouse selection did not reach " + terminal)
                # Clear input, then paste with the actual mouse; never submit it.
                tmux("send-keys", "-t", target, "C-u")
                wait_for(lambda: marker not in tmux("capture-pane", "-p", "-t", target), "OpenCode input did not clear before paste")
                subprocess.run(["xclip", "-selection", "primary"], input=b"stale-primary-marker", env=env, check=True)
                time.sleep(0.6)
                run("xdotool", "mousemove", "--window", window, "150", "100", "click", "2")
                wait_for(lambda: marker in tmux("capture-pane", "-p", "-t", target), "middle-click did not paste into OpenCode")
                (logs / "opencode-screen.txt").write_text(tmux("capture-pane", "-p", "-t", target))
                print("PASS: real OpenCode mouse selection and middle-click inside tmux")
                run("import", "-window", window, str(logs / "clipboard.png"))
            except Exception:
                for name, command in [("tmux-screen.txt", ("capture-pane", "-p")), ("tmux-buffer.txt", ("show-buffer",)), ("tmux-info.txt", ("info",)), ("tmux-options.txt", ("show-options", "-s")), ("tmux-client.txt", ("display-message", "-p", "#{client_termname} #{client_termfeatures}"))]:
                    try:
                        (logs / name).write_text(tmux(*command))
                    except subprocess.CalledProcessError:
                        pass
                (logs / "clipboard.txt").write_text(clipboard())
                raise
            finally:
                subprocess.run([args.tmux, "-S", socket, "kill-server"], env=env, capture_output=True)
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--fixture":
        fixture(Path(sys.argv[2]))
    else:
        main()
