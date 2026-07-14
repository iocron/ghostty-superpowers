#!/usr/bin/env zsh
# set -e

GHOSTTY_SUPERPOWERS="${GHOSTTY_SUPERPOWERS:-${HOME}/.ghostty-superpowers}"

# FZF Reverse-Search (Ctrl+R)
if command -v fzf >/dev/null 2>&1; then
  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh # Load fzf if installed

  fzf_history_widget() {
    # Get current input as initial query
    local initial_query="$LBUFFER"

    # Use fzf to select a command from history, prefilled with current input
    local selected
    selected=$(fc -l 1 | awk '{$1=""; print substr($0,2)}' | fzf \
      --height 40% --reverse --border \
      --query="$initial_query" \
      --delimiter='##' \
      --with-nth=1,2 \
      --multi \
      --preview 'echo -e "Name: {2}\n\nCommand: {1}\n\nDescription: {3}"' \
      --preview-window=45%,wrap \
      --bind 'tab:down,shift-tab:up')
      # --preview 'echo -e "\033[1mCommand:\033[0m {1}\n\n\033[1mDescription:\033[0m {2}"' \

    # Only replace LBUFFER if the user selected something
    # Extract only the command part before ## delimiter
    if [[ -n "$selected" ]]; then
      LBUFFER="${selected%%##*}"
    fi

    zle reset-prompt
  }

  # Register as Zsh widget
  zle -N fzf_history_widget

  # Bind Ctrl+R to it
  bindkey '^R' fzf_history_widget
else
  echo "⚠ fzf not found. Ctrl+R will use default Zsh history search."
fi
