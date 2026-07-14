#!/usr/bin/env zsh
# GPOWERS - GIT PROMPT HELPERS
# Native replacement for the prompt-facing parts of oh-my-zsh's lib/git.zsh
# (synchronous variant, without the async/zstyle machinery). Provides
# git_prompt_info / parse_git_dirty used by the theme, plus git_current_branch.

# Run git read-only so the prompt never fights other git processes for locks.
function __git_prompt_git() {
  GIT_OPTIONAL_LOCKS=0 command git "$@"
}

# Theme defaults (a theme may override these before/after loading).
: "${ZSH_THEME_GIT_PROMPT_PREFIX=git:(}"
: "${ZSH_THEME_GIT_PROMPT_SUFFIX=)}"
: "${ZSH_THEME_GIT_PROMPT_DIRTY=*}"
: "${ZSH_THEME_GIT_PROMPT_CLEAN=}"

# Is the working tree dirty? Echoes the DIRTY or CLEAN marker.
function parse_git_dirty() {
  local STATUS
  local -a FLAGS
  FLAGS=('--porcelain')
  if [[ "$(__git_prompt_git config --get oh-my-zsh.hide-dirty)" != "1" ]]; then
    if [[ "${DISABLE_UNTRACKED_FILES_DIRTY:-}" == "true" ]]; then
      FLAGS+='--untracked-files=no'
    fi
    FLAGS+="--ignore-submodules=${GIT_STATUS_IGNORE_SUBMODULES:-dirty}"
    STATUS=$(__git_prompt_git status ${FLAGS} 2> /dev/null | tail -n 1)
  fi
  if [[ -n $STATUS ]]; then
    echo "$ZSH_THEME_GIT_PROMPT_DIRTY"
  else
    echo "$ZSH_THEME_GIT_PROMPT_CLEAN"
  fi
}

# Prompt segment: git:(branch)<dirty>. Empty outside a repo.
function git_prompt_info() {
  # Bail out if not in a repo, or info is hidden for this repo.
  if ! __git_prompt_git rev-parse --git-dir &> /dev/null \
    || [[ "$(__git_prompt_git config --get oh-my-zsh.hide-info 2>/dev/null)" == 1 ]]; then
    return 0
  fi

  # Prefer branch name, then tag, then short SHA.
  local ref
  ref=$(__git_prompt_git symbolic-ref --short HEAD 2> /dev/null) \
    || ref=$(__git_prompt_git describe --tags --exact-match HEAD 2> /dev/null) \
    || ref=$(__git_prompt_git rev-parse --short HEAD 2> /dev/null) \
    || return 0

  echo "${ZSH_THEME_GIT_PROMPT_PREFIX}${ref//\%/%%}$(parse_git_dirty)${ZSH_THEME_GIT_PROMPT_SUFFIX}"
}

# Name of the current branch (handy in scripts: git pull origin $(git_current_branch))
function git_current_branch() {
  local ref
  ref=$(__git_prompt_git symbolic-ref --quiet HEAD 2> /dev/null)
  local ret=$?
  if [[ $ret != 0 ]]; then
    [[ $ret == 128 ]] && return  # not a git repo
    ref=$(__git_prompt_git rev-parse --short HEAD 2> /dev/null) || return
  fi
  echo ${ref#refs/heads/}
}
