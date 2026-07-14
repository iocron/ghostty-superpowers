#!/usr/bin/env zsh
# GPOWERS - TERMINAL SUPPORT
# Native replacement for oh-my-zsh's lib/termsupport.zsh: sets the window/tab
# title from the cwd and running command, and emits OSC 7 so new Ghostty splits
# and windows inherit the current working directory. Self-contained (does not
# rely on oh-my-zsh's omz_urlencode).

autoload -Uz add-zsh-hook

# --- window / tab title -----------------------------------------------------
# usage: title short_tab_title [long_window_title]
function title {
  setopt localoptions nopromptsubst
  [[ -n "${INSIDE_EMACS:-}" && "$INSIDE_EMACS" != vterm ]] && return
  : ${2=$1}

  case "$TERM" in
    cygwin|xterm*|putty*|rxvt*|konsole*|ansi|mlterm*|alacritty*|st*|foot*|contour*|wezterm*)
      print -Pn "\e]2;${2:q}\a" # window name
      print -Pn "\e]1;${1:q}\a" # tab name
      ;;
    screen*|tmux*)
      print -Pn "\ek${1:q}\e\\" # screen hardstatus
      ;;
    *)
      if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
        print -Pn "\e]2;${2:q}\a"
        print -Pn "\e]1;${1:q}\a"
      elif (( ${+terminfo[fsl]} && ${+terminfo[tsl]} )); then
        print -Pn "${terminfo[tsl]}$1${terminfo[fsl]}"
      fi
      ;;
  esac
}

ZSH_THEME_TERM_TAB_TITLE_IDLE="%15<..<%~%<<" # 15-char left-truncated PWD
ZSH_THEME_TERM_TITLE_IDLE="%n@%m:%~"

# Before each prompt: reset title to the idle (cwd) form.
function _gtty_termsupport_precmd {
  [[ "${DISABLE_AUTO_TITLE:-}" != true ]] || return 0
  title "$ZSH_THEME_TERM_TAB_TITLE_IDLE" "$ZSH_THEME_TERM_TITLE_IDLE"
}

# Before running a command: show the command in the title.
function _gtty_termsupport_preexec {
  [[ "${DISABLE_AUTO_TITLE:-}" != true ]] || return 0
  emulate -L zsh
  setopt extended_glob
  # command name only (skip sudo/ssh wrappers and assignments)
  local CMD="${1[(wr)^(*=*|sudo|ssh|mosh|rake|-*)]:gs/%/%%}"
  local LINE="${2:gs/%/%%}"
  title "$CMD" "%100>...>${LINE}%<<"
}

if [[ -z "$INSIDE_EMACS" || "$INSIDE_EMACS" = vterm ]]; then
  add-zsh-hook precmd _gtty_termsupport_precmd
  add-zsh-hook preexec _gtty_termsupport_preexec
fi

# --- OSC 7 current-working-directory ---------------------------------------
# Skip inside Emacs or over SSH (the local terminal wouldn't be ours to drive).
if [[ -n "$INSIDE_EMACS" || -n "$SSH_CLIENT" || -n "$SSH_TTY" ]]; then
  return
fi

# Only emit on terminals that handle (or safely ignore) OSC 7.
case "$TERM" in
  xterm*|putty*|rxvt*|konsole*|mlterm*|alacritty*|screen*|tmux*|contour*|foot*) ;;
  *)
    case "$TERM_PROGRAM" in
      Apple_Terminal|iTerm.app|ghostty|Ghostty) ;;
      *) return ;;
    esac ;;
esac

# Minimal RFC-3986 percent-encoder for the path (keeps unreserved chars + '/').
function _gtty_url_encode {
  emulate -L zsh
  local str="$1" out="" i c
  for (( i = 1; i <= ${#str}; i++ )); do
    c="${str[i]}"
    case "$c" in
      [A-Za-z0-9/._~-]) out+="$c" ;;
      *) out+=$(printf '%%%02X' "'$c") ;;
    esac
  done
  print -r -- "$out"
}

# Emit OSC 7 (file://host/path) so the terminal tracks our cwd.
function _gtty_termsupport_cwd {
  setopt localoptions unset
  local url_host url_path
  url_host="$(_gtty_url_encode "$HOST")" || return 1
  url_path="$(_gtty_url_encode "$PWD")" || return 1
  printf "\e]7;file://%s%s\e\\" "${url_host}" "${url_path}"
}

# precmd (not chpwd) so directory changes made inside scripts are still tracked.
add-zsh-hook precmd _gtty_termsupport_cwd
