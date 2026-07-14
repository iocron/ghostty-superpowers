#!/usr/bin/env zsh
# GPOWERS - HISTORY (file + sizing)
# Native replacement for the file/size parts of oh-my-zsh's lib/history.zsh.
# The behavioural history `setopt`s (share/ignore-dups/verify/...) already live
# at the top of init.zsh and apply in every mode, so they are not repeated here.

[ -z "$HISTFILE" ] && HISTFILE="$HOME/.zsh_history"
[ "${HISTSIZE:-0}" -lt 50000 ] && HISTSIZE=50000
[ "${SAVEHIST:-0}" -lt 10000 ] && SAVEHIST=10000
