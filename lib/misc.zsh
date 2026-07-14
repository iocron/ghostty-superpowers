#!/usr/bin/env zsh
# GPOWERS - MISC DEFAULTS
# Sensible interactive shell defaults. Most important is `interactivecomments`,
# which lets zsh recognise `#` as a comment on the command line so that
# zsh-syntax-highlighting colours it gray instead of flagging the line red as an
# unknown command. Sourced inside the native block, before the external zsh
# plugins, so the paste-magic widgets below are wrapped correctly by them.

autoload -Uz is-at-least

# URL/paste magic: auto-quote special characters when pasting URLs and enable
# bracketed-paste handling. Opt out with DISABLE_MAGIC_FUNCTIONS=true.
if [[ "$DISABLE_MAGIC_FUNCTIONS" != true ]]; then
  for d in $fpath; do
    if [[ -e "$d/url-quote-magic" ]]; then
      if is-at-least 5.1; then
        autoload -Uz bracketed-paste-magic
        zle -N bracketed-paste bracketed-paste-magic
      fi
      autoload -Uz url-quote-magic
      zle -N self-insert url-quote-magic
      break
    fi
  done
fi

setopt multios              # allow redirect to multiple streams: echo >f1 >f2
setopt long_list_jobs       # show long-format job notifications
setopt interactivecomments  # recognise `#` comments on the command line

# Default pager (only set when the user hasn't already chosen one).
if (( ${+commands[less]} )); then
  : "${PAGER:=less}"
  : "${LESS:=-R}"
  export PAGER LESS
elif (( ${+commands[more]} )); then
  : "${PAGER:=more}"
  export PAGER
fi

# Super-user shorthand, plus a smarter ack alias when it's installed.
alias _='sudo '
if (( $+commands[ack-grep] )); then
  alias afind='ack-grep -il'
elif (( $+commands[ack] )); then
  alias afind='ack -il'
fi
