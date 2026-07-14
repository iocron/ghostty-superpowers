#!/usr/bin/env zsh
# GPOWERS - BASE KEYMAP
# Native replacement for oh-my-zsh's lib/key-bindings.zsh. Must be sourced
# BEFORE the external plugins: it defines zle-line-init/zle-line-finish, and
# zsh-syntax-highlighting's add-zle-hook-widget only preserves those widgets if
# they already exist when it loads. Ctrl+R is intentionally left unbound -
# plugins/fzf.zsh (sourced later) owns it.

# Keep the terminal in application mode while zle is active so the $terminfo
# key values used below are valid.
if (( ${+terminfo[smkx]} )) && (( ${+terminfo[rmkx]} )); then
  function zle-line-init() { echoti smkx; }
  function zle-line-finish() { echoti rmkx; }
  zle -N zle-line-init
  zle -N zle-line-finish
fi

# Emacs key bindings
bindkey -e

# [PageUp] / [PageDown] - move a line through history
[[ -n "${terminfo[kpp]}" ]] && bindkey "${terminfo[kpp]}" up-line-or-history
[[ -n "${terminfo[knp]}" ]] && bindkey "${terminfo[knp]}" down-line-or-history

# Start typing + [Up]/[Down] - prefix search through history
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search
[[ -n "${terminfo[kcuu1]}" ]] && bindkey "${terminfo[kcuu1]}" up-line-or-beginning-search
[[ -n "${terminfo[kcud1]}" ]] && bindkey "${terminfo[kcud1]}" down-line-or-beginning-search

# [Home] / [End]
[[ -n "${terminfo[khome]}" ]] && bindkey "${terminfo[khome]}" beginning-of-line
[[ -n "${terminfo[kend]}" ]]  && bindkey "${terminfo[kend]}"  end-of-line

# [Shift-Tab] - reverse through the completion menu
[[ -n "${terminfo[kcbt]}" ]] && bindkey "${terminfo[kcbt]}" reverse-menu-complete

# [Backspace] / [Delete]
bindkey '^?' backward-delete-char
if [[ -n "${terminfo[kdch1]}" ]]; then
  bindkey "${terminfo[kdch1]}" delete-char
else
  bindkey "^[[3~" delete-char
fi

# [Ctrl-Delete] delete word forward, [Ctrl-Left/Right] move by word
bindkey '^[[3;5~' kill-word
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

bindkey ' ' magic-space  # [Space] - expand history inline

# [Ctrl-x Ctrl-e] - edit the current command line in $EDITOR
autoload -U edit-command-line
zle -N edit-command-line
bindkey '^x^e' edit-command-line
