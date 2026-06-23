# Air-Gap Dev Kit - tmux window naming for SSH sessions
#
# Sourced by ~/.bashrc / ~/.zshrc via the airgap-dev-kit installer.
# Renames the current tmux window to the SSH hostname while a session is
# active, then restores the previous window name and automatic-rename state
# on disconnect. No-op outside tmux so it never interferes with normal ssh.

# Extract the hostname from ssh arguments.
# Walks the arg list as ssh would: short flags may be clustered (-vv, -p2222,
# -vL 8080), value-taking options consume either the rest of the cluster or
# the next arg, and "--" ends option processing. Strips a leading "user@"
# prefix so the tab shows just the host.
_airgap_ssh_host() {
  local arg host rest c consumed_next
  local value_opts="BbcDeEFIiJLlmOopQRSWw"
  while [[ $# -gt 0 ]]; do
    arg="$1"; shift
    case "$arg" in
      --)
        host="${1:-}"; break ;;                       # end of options
      --*=*)
        ;;                                            # --opt=value
      --*)
        shift ;;                                      # --opt VALUE (best-effort)
      -*)
        rest="${arg#-}"
        consumed_next=0
        while [[ -n "$rest" ]]; do
          c="${rest:0:1}"; rest="${rest:1}"
          if [[ "$value_opts" == *"$c"* ]]; then
            # Value is attached (-XVALUE) or the next arg (-X VALUE).
            [[ -z "$rest" ]] && consumed_next=1
            break
          fi
        done
        [[ $consumed_next -eq 1 ]] && shift
        ;;
      *)
        host="$arg"; break ;;                         # first positional = host
    esac
  done
  [[ -n "$host" ]] || return 1
  printf '%s' "${host##*@}"                           # drop user@ if present
}

# Wrap ssh so the tmux tab reflects the connected host.
ssh() {
  if [[ -z "${TMUX:-}" ]]; then
    command ssh "$@"
    return $?
  fi
  local host label prev_name prev_auto rc
  host="$(_airgap_ssh_host "$@" 2>/dev/null)" && label="$host" || label="ssh"
  prev_name="$(tmux display-message -p '#W' 2>/dev/null || true)"
  [[ -n "$prev_name" ]] || prev_name="shell"
  prev_auto="$(tmux show-options -wv automatic-rename 2>/dev/null || true)"
  [[ -n "$prev_auto" ]] || prev_auto="on"

  tmux rename-window "$label"
  tmux set-option -w automatic-rename off 2>/dev/null

  command ssh "$@"
  rc=$?

  tmux set-option -w automatic-rename "$prev_auto" 2>/dev/null
  tmux rename-window "$prev_name" 2>/dev/null
  return "$rc"
}
