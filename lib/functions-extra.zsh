#!/usr/bin/env zsh
# GPOWERS - CONVENIENCE FUNCTIONS
# Small quality-of-life helpers people often carry over from other zsh setups.
# These are our own, behaviour-compatible implementations -- not copied source:
#   take / mkcd / takedir  make a directory (+ parents) and cd in, or fetch and
#                          enter a tarball / zip / git repo
#   zsh_stats              your most frequently run commands

# --- make (or fetch) a directory, then enter it -----------------------------

# mkdir -p the given path(s) and cd into the last one.
mkcd() {
  mkdir -p -- "$@" && cd -- "${@[-1]}"
}
takedir() { mkcd "$@"; }   # familiar alias

# Download $1 into a scratch file; echo its path, or fail with a message.
_gtty_fetch_tmp() {
  local tmp; tmp="$(mktemp)" || return 1
  if curl -fL# -o "$tmp" -- "$1"; then
    print -r -- "$tmp"
  else
    rm -f -- "$tmp"; print -u2 "take: download failed: $1"; return 1
  fi
}

# Fetch a tarball URL, unpack it, and cd into its top-level directory.
takeurl() {
  local tmp top; tmp="$(_gtty_fetch_tmp "$1")" || return 1
  tar xf "$tmp"
  top="$(tar tf "$tmp" | head -1)"; top="${top%%/*}"
  rm -f -- "$tmp"
  [[ -n "$top" && -d "$top" ]] && cd -- "$top"
}

# Fetch a zip URL, unpack it, and cd into its top-level directory.
takezip() {
  local tmp top; tmp="$(_gtty_fetch_tmp "$1")" || return 1
  unzip -q -- "$tmp"
  top="$(unzip -Z1 "$tmp" | head -1)"; top="${top%%/*}"
  rm -f -- "$tmp"
  [[ -n "$top" && -d "$top" ]] && cd -- "$top"
}

# Clone a git URL and cd into the resulting directory.
takegit() {
  local name="${${1##*/}%.git}"
  git clone -- "$1" && cd -- "$name"
}

# Dispatch on the argument: tarball URL, zip URL, git repo, or plain directory.
take() {
  local a="$1"
  if [[ "$a" == (http|https|ftp|ftps)://*.(tar.gz|tar.bz2|tar.xz|tgz) ]]; then
    takeurl "$a"
  elif [[ "$a" == (http|https|ftp|ftps)://*.zip ]]; then
    takezip "$a"
  elif [[ "$a" == *.git || "$a" == *.git/ || "$a" == *@*:*.git ]]; then
    takegit "$a"
  else
    mkcd "$@"
  fi
}

# --- history stats ----------------------------------------------------------

# Rank the commands you run most (default top 20), with count and share.
zsh_stats() {
  local n="${1:-20}"
  fc -ln 1 \
    | awk '{ seen[$1]++; total++ }
           END { for (c in seen) printf "%6d  %5.1f%%  %s\n", seen[c], 100*seen[c]/total, c }' \
    | sort -rn \
    | head -n "$n"
}
