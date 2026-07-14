#!/usr/bin/env zsh
# GPOWERS - COLORS & APPEARANCE
# Native replacement for oh-my-zsh's lib/theme-and-appearance.zsh (+ grep.zsh).
# Provides the $fg/$bg/$reset_color arrays the prompt relies on, enables
# prompt expansion, and sets up coloured `ls`/`grep`. Load this first.

# Sets colour variables such as $fg, $bg, $color and $reset_color
autoload -U colors && colors

# Expand variables and commands inside PROMPT strings
setopt prompt_subst

# Colourise `diff` output when this diff supports --color (from oh-my-zsh
# lib/theme-and-appearance.zsh). Placed before the DISABLE_LS_COLORS return so
# it applies independently of ls colouring, matching OMZ.
if command diff --color /dev/null{,} &>/dev/null; then
  function diff { command diff --color "$@"; }
fi

# --- ls colours -------------------------------------------------------------
[[ "$DISABLE_LS_COLORS" == true ]] && return 0

# Default colouring for BSD-based ls
export LSCOLORS="Gxfxcxdxbxegedabagacad"

# Default colouring for GNU-based ls
if [[ -z "$LS_COLORS" ]]; then
  if (( $+commands[dircolors] )); then
    [[ -f "$HOME/.dircolors" ]] \
      && source <(dircolors -b "$HOME/.dircolors") \
      || source <(dircolors -b)
  else
    export LS_COLORS="di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43"
  fi
fi

# Pick the right coloured-ls invocation for this platform
_gtty_test_ls_args() { command "$@" /dev/null &>/dev/null; }
case "$OSTYPE" in
  (darwin|freebsd)*)
    _gtty_test_ls_args ls -G && alias ls='ls -G'
    ;;
  *)
    if _gtty_test_ls_args ls --color; then
      alias ls='ls --color=tty'
    elif _gtty_test_ls_args ls -G; then
      alias ls='ls -G'
    fi
    ;;
esac
unfunction _gtty_test_ls_args

# --- grep colours -----------------------------------------------------------
# (from oh-my-zsh lib/grep.zsh) colour matches and skip VCS/build dirs.
_gtty_grep_available() { command grep "$@" "" &>/dev/null <<< ""; }
_GTTY_GREP_EXC="{.bzr,CVS,.git,.hg,.svn,.idea,.tox,.venv,venv}"
if _gtty_grep_available --color=auto --exclude-dir=.cvs; then
  alias grep="grep --color=auto --exclude-dir=$_GTTY_GREP_EXC"
  alias egrep="grep -E"
  alias fgrep="grep -F"
elif _gtty_grep_available --color=auto --exclude=.cvs; then
  alias grep="grep --color=auto --exclude=$_GTTY_GREP_EXC"
  alias egrep="grep -E"
  alias fgrep="grep -F"
fi
unset _GTTY_GREP_EXC
unfunction _gtty_grep_available
