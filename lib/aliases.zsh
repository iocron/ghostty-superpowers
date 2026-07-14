# Define an alias only if one with that name isn't already set
# (so a user's own .zshrc aliases take precedence, provided this file
#  is sourced *before* those aliases or they simply already exist).
alias_default() {
    local name="${1%%=*}"
    alias "$name" >/dev/null 2>&1 || alias "$1"
}

# AI Stuff
if command -v ollama >/dev/null 2>&1; then
    alias_default ol="ollama"
fi

# CONTAINER Stuff
alias_default co="colima"
alias_default nerd="nerdctl" # for colima

# DuckDuckGo Search Aliases
alias_default dict="s '!dict.cc'"
! command -v gh >/dev/null 2>&1 && alias_default gh=github_search
alias_default ghub="github_search"
# alias gh='ghub' 2>/dev/null || true
# alias ghub="s '!gh'" # Github
alias_default wiki="s '!w'" # Wikipedia

# Git Helper Functions
alias_default git-remote-open-url='_gtty_open "$(git config --get remote.origin.url | sed '\''s/^git@\(.*\):/https:\/\/\1\//'\'' | sed '\''s/\.git$//'\'')"'

# OS Helper
alias_default ca="$(command -v mcat >/dev/null 2>&1 && echo mcat || echo cat)"
alias_default cl="clear"
alias_default g="grep"
alias_default gr="grep"
alias_default h="tldr"
alias_default he="head"
alias_default l="ls -lah"
alias_default la="ls -lAh"
alias_default ll="ls -lah"
alias_default lsa="ls -lah"
alias_default mc="mcat"
alias_default rg="rg --no-ignore"
alias_default t="tail"
alias_default w3m="w3m -o accept_encoding='identity;q=0'"
alias_default w3="w3m -dump -o accept_encoding='identity;q=0'"
alias_default web="w3m -dump -o accept_encoding='identity;q=0'"
alias_default wh="which"

unset -f alias_default
