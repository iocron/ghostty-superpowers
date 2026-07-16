#!/usr/bin/env zsh
# GPOWERS - COMPLETION
# Native replacement for oh-my-zsh's compinit bootstrap (oh-my-zsh.sh) plus
# lib/completion.zsh. Initialises the completion system with a cached dump in
# ghostty-superpowers' own cache/ dir (no ~/.oh-my-zsh dependency) and applies
# sensible completion styles. Must run before plugins that call `compdef`.

zmodload -i zsh/complist

# Cache dir for the compdump and completion caching (reuse the repo's cache/).
GTTY_CACHE_DIR="${GHOSTTY_SUPERPOWERS:-$HOME/.ghostty-superpowers}/cache"
if [[ ! -w "$GTTY_CACHE_DIR" ]]; then
  GTTY_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ghostty-superpowers"
fi
mkdir -p "$GTTY_CACHE_DIR/completions"
(( ${fpath[(Ie)$GTTY_CACHE_DIR/completions]} )) || fpath=("$GTTY_CACHE_DIR/completions" $fpath)

# Initialise completion. `-i` skips insecure-directory prompts (matches OMZ's
# default), dump kept per zsh version so it is rebuilt after upgrades.
autoload -Uz compinit
compinit -i -d "$GTTY_CACHE_DIR/.zcompdump-${ZSH_VERSION}"

# Allow bash-style completion scripts (used by some tools).
autoload -U +X bashcompinit && bashcompinit

# --- completion styles (from oh-my-zsh lib/completion.zsh) ------------------
WORDCHARS=''

unsetopt menu_complete    # do not autoselect the first completion entry
unsetopt flowcontrol
setopt auto_menu          # show completion menu on successive tab press
setopt complete_in_word
setopt always_to_end

bindkey -M menuselect '^o' accept-and-infer-next-history
zstyle ':completion:*:*:*:*:*' menu select

# Case-insensitive, partial-word and substring completion
if [[ "$CASE_SENSITIVE" == true ]]; then
  zstyle ':completion:*' matcher-list 'r:|=*' 'l:|=* r:|=*'
elif [[ "$HYPHEN_INSENSITIVE" == true ]]; then
  zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]-_}={[:upper:][:lower:]_-}' 'r:|=*' 'l:|=* r:|=*'
else
  zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'r:|=*' 'l:|=* r:|=*'
fi
unset CASE_SENSITIVE HYPHEN_INSENSITIVE

zstyle ':completion:*' special-dirs true
zstyle ':completion:*' list-colors ''
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'
zstyle ':completion:*:*:*:*:processes' command "ps -u $USERNAME -o pid,user,comm -w -w"

# Don't offer directory-stack / named-dir entries for `cd`
zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories

# Cache slow completions (apt, dpkg, ...)
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path "$GTTY_CACHE_DIR"

zstyle '*' single-ignored show

# Match completion colours to $LS_COLORS
[[ -z "$LS_COLORS" ]] || zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Add ~/.ssh/config Host aliases (+ known_hosts) to host completion, so `ssh <TAB>` lists them.
zstyle -e ':completion:*:*:*:hosts' hosts '
  reply=(
    ${(f)"$(awk '\''tolower($1)=="host"{for (i=2;i<=NF;i++) if ($i !~ /[*?]/) print $i}'\'' ~/.ssh/config 2>/dev/null)"}
    ${${${(f)"$(cat ~/.ssh/known_hosts /etc/ssh/ssh_known_hosts 2>/dev/null)"}:#[|]*}%%[ ,]*}
  )'

# Hide macOS/system service accounts ('_'-prefixed) from user completion, so `ssh <TAB>` isn't flooded.
zstyle ':completion:*:*:*:users' ignored-patterns '_*'

unset GTTY_CACHE_DIR
