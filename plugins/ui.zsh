#!/usr/bin/env zsh
# set -e

# CUSTOM GHOSTTY UI/BLOCK VIEW
draw_separator() {
  local cols=$(tput cols)
  echo
  printf "\e[38;2;25;25;25m%*s\e[0m\n" "$cols" "" | tr ' ' '─'
  echo
}

preexec() {
  GTTY_LAST_CMD="$1"
  GTTY_CMD_START=$SECONDS

  if (( ! ${+_ghostty_state} || _ghostty_state == 2 )); then # optional wait for ghostty
    draw_separator

    # PATH OUTPUT INFO:
    print -P "%F{242}%~%f %F{244}$(git rev-parse --abbrev-ref HEAD 2>/dev/null | sed 's/^/git:(/;s/$/)/')%f"

    # LAST USED COMMAND:
    print -P "%F{green}${GTTY_LAST_CMD}%f"
    echo
  fi
}

precmd() {
  if [[ -n "$GTTY_CMD_START" ]]; then
    local duration=$((SECONDS - GTTY_CMD_START))
    if (( duration > 0 )); then
      local prefix="duration: "
      local prefix_safety=5
      local dur_text="%F{244}(${prefix}${duration}s)%f"
      local visible_len=$(( ${#prefix} + ${#duration} + $prefix_safety ))
      local pad=$(( COLUMNS - visible_len ))
      (( pad < 0 )) && pad=0

      # Print spaces + colored duration
      printf "%*s" "$pad" ""
      print -P "$dur_text"
    fi

    if [[ "$GTTY_LAST_CMD" != "clear" ]]; then
      echo
      draw_separator
      echo
    fi

    unset GTTY_CMD_START
  fi
}

