#!/usr/bin/env zsh
# GPOWERS - DIRECTORIES
# Native replacement for oh-my-zsh's lib/directories.zsh. Enables cd niceties
# and the ../.. shorthands. NOTE: the numeric 1-9 dir-stack aliases OMZ defines
# are intentionally omitted here -- plugins/dirjump.zsh owns those digits.
# Load after completion.zsh (the `d` helper uses compdef).

# Changing/making/removing directory
setopt auto_cd            # `foo` alone cd's into ./foo
setopt auto_pushd         # every cd pushes onto the dir stack
setopt pushd_ignore_dups  # don't push duplicates
setopt pushdminus         # `cd -N` counts from the top of the stack

# Parent-directory shorthands
alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
alias -g ......='../../../../..'

alias -- -='cd -'

alias md='mkdir -p'
alias rd='rmdir'

# `d`  -> show the directory stack (top 10); `d N` -> operate on entry N
function d () {
  if [[ -n $1 ]]; then
    dirs "$@"
  else
    dirs -v | head -n 10
  fi
}
compdef _dirs d
