#!/usr/bin/env zsh
# GPOWERS - PROMPT THEME
# Native replacement for oh-my-zsh's robbyrussell theme. Byte-for-byte identical
# prompt, so nothing changes visually. Load last (needs colours + git_prompt_info).
# Set ZSH_THEME to anything other than "robbyrussell" (or define your own PROMPT
# afterwards) to opt out and keep a custom prompt.

[[ "${ZSH_THEME:-robbyrussell}" == "robbyrussell" ]] || return 0

PROMPT="%(?:%{$fg_bold[green]%}%1{➜%} :%{$fg_bold[red]%}%1{➜%} ) %{$fg[cyan]%}%c%{$reset_color%}"
PROMPT+=' $(git_prompt_info)'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}git:(%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}%1{✗%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"
