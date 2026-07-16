#!/usr/bin/env zsh
# gssh — bring autosuggestions + syntax highlighting to a remote over SSH without
# installing anything into its config. On connect it probes the remote (zsh ->
# zsh plugins via ZDOTDIR; bash >=4 -> ble.sh via --rcfile; else plain login) and
# loads a bundle whose rc chain-sources the host's own startup files first.
#
# No `rm -rf` ever targets a config path: cached mode extracts in place under
# ~/.cache/gsp-lite (tar overwrite, re-pushed only when the content sig changes);
# GSP_SSH_EPHEMERAL=1 stages into a remote `mktemp -d` and deletes exactly that.
#
# `gssh` completes hosts like `ssh` (compdef); GSP_SSH_WRAP=1 also shadows `ssh`.
# Non-interactive uses (remote command, no tty, scp/rsync/git) pass through.

GHOSTTY_SUPERPOWERS="${GHOSTTY_SUPERPOWERS:-${HOME}/.ghostty-superpowers}"

: "${GSP_SSH_CACHE:=${GHOSTTY_SUPERPOWERS}/cache}"
: "${GSP_SSH_REMOTE_DIR:=.cache/gsp-lite}"   # cached mode: relative to remote $HOME
: "${GSP_SSH_EPHEMERAL:=0}"                  # 1 = stage in a mktemp dir, wipe on logout
: "${GSP_SSH_WRAP:=0}"                       # 1 = also shadow the `ssh` command

# Reuse one connection for the probe + upload + interactive launch.
_gsp_ssh_mux=(
  -o ControlMaster=auto
  -o 'ControlPath=~/.ssh/gsp-%C'
  -o ControlPersist=15
)

# sha256 of a file argument, or of stdin when called with none.
_gsp_ssh_sum() {
  local h; if command -v sha256sum >/dev/null 2>&1; then h=sha256sum; else h="shasum -a 256"; fi
  if (( $# )); then ${=h} "$1" | cut -d' ' -f1; else ${=h} | cut -d' ' -f1; fi
}

_gsp_ssh_bundle_path() { print "${GSP_SSH_CACHE}/gsp-lite-$1.tgz"; }

# Top-level source paths composing a flavor's bundle (one per line).
_gsp_ssh_inputs() {
  local ext="$GHOSTTY_SUPERPOWERS/plugins_external"
  case "$1" in
    zsh)
      print -r -- "$ext/zsh-autosuggestions/zsh-autosuggestions.zsh"
      print -r -- "$ext/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
      print -r -- "$ext/zsh-syntax-highlighting/highlighters" ;;
    bash)
      print -r -- "$ext/blesh/ble.sh" ;;
    *) return 1 ;;
  esac
}

# Content signature of a flavor's inputs + this script (mtime-independent, so a
# vendored-archive swap is caught). Also the remote bundle marker.
_gsp_ssh_sig() {
  local -a paths; paths=( ${(f)"$(_gsp_ssh_inputs "$1")"} "${(%):-%x}" )
  (( ${#paths} )) || return 1
  { print -rl -- "$paths[@]"
    find "$paths[@]" -type f 2>/dev/null | LC_ALL=C sort | tr '\n' '\0' | xargs -0 cat 2>/dev/null
  } | _gsp_ssh_sum
}

# Validate GSP_SSH_REMOTE_DIR: must be a non-empty relative subdir (it becomes
# the extract target $HOME/$rd, so an unsafe value could clobber $HOME's rc files).
_gsp_ssh_remote_dir() {
  local rd="$GSP_SSH_REMOTE_DIR"
  case "$rd" in
    ""|.|..|/*|*/|*..*)
      print -u2 "gssh: refusing unsafe GSP_SSH_REMOTE_DIR='$rd' (must be a relative subdir)"; return 1 ;;
  esac
  print -r -- "$rd"
}

# Build (or rebuild) the local bundle tarball for a flavor.
#   $1 = zsh | bash
_gsp_ssh_build_bundle() {
  local flavor="$1"
  local ext="$GHOSTTY_SUPERPOWERS/plugins_external"
  local out; out="$(_gsp_ssh_bundle_path "$flavor")"
  local staging

  local -a inputs; inputs=( ${(f)"$(_gsp_ssh_inputs "$flavor")"} )
  (( ${#inputs} )) || return 1
  local f; for f in "$inputs[@]"; do
    [[ -e "$f" ]] || { print -u2 "gssh: missing $f"; return 1; }
  done

  staging=$(mktemp -d "${TMPDIR:-/tmp}/gsp-lite.XXXXXX") || return 1

  if [[ "$flavor" == zsh ]]; then
    # ZDOTDIR rc files. Quoted heredocs keep $HOME etc. literal (expand remotely).
    cat > "$staging/.zshenv" <<'EOF'
# gsp-lite: ZDOTDIR shadows ~/.zshenv, so pull the host's real one back in.
[[ -f "$HOME/.zshenv" ]] && source "$HOME/.zshenv"
EOF
    cat > "$staging/.zshrc" <<'EOF'
# gsp-lite: load the host's real interactive config first, unchanged...
[[ -f "$HOME/.zprofile" ]] && source "$HOME/.zprofile"
[[ -f "$HOME/.zshrc" ]] && source "$HOME/.zshrc"
# ...then layer our two plugins on top (highlighting sourced last, per its docs).
_gsp_dir="${${(%):-%x}:h}"
source "$_gsp_dir/zsh-autosuggestions/zsh-autosuggestions.zsh" 2>/dev/null
source "$_gsp_dir/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" 2>/dev/null
unset _gsp_dir
EOF
    mkdir -p "$staging/zsh-autosuggestions" "$staging/zsh-syntax-highlighting"
    cp "$ext/zsh-autosuggestions/zsh-autosuggestions.zsh" "$staging/zsh-autosuggestions/"
    cp "$ext/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" "$staging/zsh-syntax-highlighting/"
    cp -R "$ext/zsh-syntax-highlighting/highlighters" "$staging/zsh-syntax-highlighting/highlighters"
    # Drop the highlighters' test fixtures (~1 MB, unused at runtime).
    find "$staging/zsh-syntax-highlighting/highlighters" -name test-data -type d -prune -exec rm -rf {} + 2>/dev/null
  else
    # bash: an rcfile that chain-loads the host's startup files, wrapped in ble.sh.
    cat > "$staging/bashrc" <<'EOF'
# gsp-lite (bash): load the host's own startup files, then ble.sh on top.
_gsp_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# login-shell env, mirroring bash's own "first existing" order
for _gsp_f in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
  [ -r "$_gsp_f" ] && { . "$_gsp_f"; break; }
done
# ble.sh recommended wrap: load detached, run interactive rc, then attach.
[ -r "$_gsp_dir/blesh/ble.sh" ] && source "$_gsp_dir/blesh/ble.sh" --noattach
[ -r "$HOME/.bashrc" ] && . "$HOME/.bashrc"
[ -n "${BLE_VERSION-}" ] && ble-attach
unset _gsp_dir _gsp_f
EOF
    mkdir -p "$staging/blesh"
    cp -R "$ext/blesh/." "$staging/blesh/"
  fi

  mkdir -p "${out:h}"
  # --no-xattrs/COPYFILE_DISABLE: no macOS provenance xattrs (GNU tar warns on them).
  # $staging is a mktemp dir, so the rm is safe by construction.
  ( cd "$staging" && COPYFILE_DISABLE=1 tar --no-xattrs -czf "$out" . ) || { rm -rf "$staging"; return 1; }
  rm -rf "$staging"
}

# Probe the remote for the best supported flavor: prints "zsh", "bash", or "none".
_gsp_ssh_probe() {
  command ssh "${_gsp_ssh_mux[@]}" "$1" '
    if command -v zsh >/dev/null 2>&1; then echo zsh
    elif command -v bash >/dev/null 2>&1 && [ "$(bash -c "echo \${BASH_VERSINFO[0]:-0}")" -ge 4 ]; then echo bash
    else echo none
    fi' 2>/dev/null
}

# Stage the flavor bundle on the remote and echo the dir to launch from.
#   cached (default): extract in place under $HOME/$rd (no delete); echo "$HOME/<rd>".
#   ephemeral: mktemp -d, extract into it, echo its absolute path.
_gsp_ssh_stage() {
  local dest="$1" flavor="$2"
  local sig; sig=$(_gsp_ssh_sig "$flavor") || return 1
  local bundle; bundle="$(_gsp_ssh_bundle_path "$flavor")"

  if [[ "$GSP_SSH_EPHEMERAL" == 1 ]]; then
    _gsp_ssh_build_bundle "$flavor" || return 1
    command ssh "${_gsp_ssh_mux[@]}" "$dest" \
      'd=$(mktemp -d "${TMPDIR:-/tmp}/gsp-lite.XXXXXX") || exit 1; tar xzf - -C "$d" && printf %s "$d"' \
      < "$bundle"
    return
  fi

  local rd; rd=$(_gsp_ssh_remote_dir) || return 1
  # Guard (both connections): $HOME absolute and $d strictly below it.
  local guard="case \"\$HOME\" in /?*) : ;; *) echo 'gssh: \$HOME is not an absolute path' >&2; exit 1 ;; esac; d=\"\$HOME/$rd\"; case \"\$d\" in \"\$HOME\"/?*) : ;; *) echo 'gssh: unsafe remote dir' >&2; exit 1 ;; esac"

  # `|| true`: a missing marker on first connect must not abort via cat's exit 1.
  local have
  have=$(command ssh "${_gsp_ssh_mux[@]}" "$dest" "$guard; cat \"\$d/.sum\" 2>/dev/null || true") || return 1
  if [[ "$have" != "$sig" ]]; then
    _gsp_ssh_build_bundle "$flavor" || return 1
    command ssh "${_gsp_ssh_mux[@]}" "$dest" \
      "$guard; mkdir -p \"\$d\" && tar xzf - -C \"\$d\" && printf %s '$sig' > \"\$d/.sum\"" \
      < "$bundle" || return 1
  fi
  print -r -- "\$HOME/$rd"
}

_gsp_ssh() {
  emulate -L zsh
  setopt localoptions no_nomatch

  # Only enhance a plain interactive login. Bail to `command ssh` otherwise.
  if [[ ! -t 0 || ! -t 1 ]]; then command ssh "$@"; return; fi

  # Parse ssh's argv the way getopt(3) does: options (some take a value) come
  # first, the first bare token is the destination, anything after it is a
  # remote command. A remote command / no destination => don't enhance.
  local -a argv_in=("$@")
  local argopts="bcDEeFIiJLlmOopQRSWw"   # ssh short options that take a value
  local noshell="NfGMTOWQ"               # options that never open an interactive shell
  local i=1 n=${#argv_in} tok dest="" have_cmd=0
  while (( i <= n )); do
    tok="${argv_in[i]}"
    if [[ "$tok" == "--" ]]; then
      (( i++ )); (( i <= n )) && dest="${argv_in[i]}"; (( i++ )); (( i <= n )) && have_cmd=1; break
    elif [[ "$tok" == -* && "$tok" != "-" ]]; then
      # Forwarding/control-only invocation: no shell to enhance, pass through.
      [[ "$noshell" == *"${tok[2]}"* ]] && { command ssh "$@"; return; }
      if (( ${#tok} == 2 )) && [[ "$argopts" == *"${tok[2]}"* ]]; then
        (( i += 2 ))          # e.g. -p 22 : skip option and its value
      else
        (( i++ ))             # flag, or glued form like -p22 / -oX=Y
      fi
    else
      dest="$tok"; (( i++ )); (( i <= n )) && have_cmd=1; break
    fi
  done

  if [[ -z "$dest" || "$have_cmd" == 1 ]]; then command ssh "$@"; return; fi

  # Probe the remote and pick a payload. No supported shell => plain login.
  local flavor; flavor=$(_gsp_ssh_probe "$dest")
  if [[ "$flavor" != zsh && "$flavor" != bash ]]; then command ssh "$@"; return; fi

  # Stage the bundle; on failure fall back to a normal login.
  local rdir; rdir=$(_gsp_ssh_stage "$dest" "$flavor")
  if [[ $? -ne 0 || -z "$rdir" ]]; then
    print -u2 "gssh: falling back to plain ssh (staging failed)"
    command ssh "$@"; return
  fi

  # Cached mode uses `exec` (no cleanup); ephemeral rm's the mktemp $rdir on exit.
  local launch
  if [[ "$GSP_SSH_EPHEMERAL" == 1 ]]; then
    if [[ "$flavor" == zsh ]]; then
      launch="ZDOTDIR=\"$rdir\" zsh -i; rm -rf \"$rdir\""
    else
      launch="bash --rcfile \"$rdir/bashrc\" -i; rm -rf \"$rdir\""
    fi
  else
    if [[ "$flavor" == zsh ]]; then
      launch="ZDOTDIR=\"$rdir\" exec zsh -i"
    else
      launch="exec bash --rcfile \"$rdir/bashrc\" -i"
    fi
  fi

  command ssh "${_gsp_ssh_mux[@]}" -t "$@" "$launch"
}

gssh() { _gsp_ssh "$@"; }

# Complete hosts (from ~/.ssh/config, known_hosts, ...) for `gssh` just like ssh.
(( $+functions[compdef] )) && compdef gssh=ssh

# Opt-in: transparently enhance the real `ssh` command too.
if [[ "$GSP_SSH_WRAP" == 1 ]]; then
  ssh() { _gsp_ssh "$@"; }
fi
