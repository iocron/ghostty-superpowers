#!/usr/bin/env zsh
# set -Eeo
# trap 'echo "Error in command: \"$funcstack\" (exit code $?)"; echo "Skipping init.sh..." >&2; return 0' ERR

## USAGE: source $HOME/.ghostty-superpowers/init.sh
# if [[ ( "$TERM_PROGRAM" == "ghostty" || -n "$GHOSTTY_SUPERPOWERS_FORCE" ) && $- == *i* ]]; then
# if [[ $- == *i* && -z $GHOSTTY_SUPERPOWERS ]]; then
if [[ $- == *i* && "$TERM_PROGRAM" == "ghostty" ]]; then

  setopt EXTENDED_HISTORY # Save timestamp of command and duration
  setopt HIST_EXPIRE_DUPS_FIRST # When trimming history, lose oldest duplicates first
  setopt HIST_IGNORE_ALL_DUPS # Ignore duplicate commands
  setopt HIST_IGNORE_SPACE # Ignore commands that start with a space
  setopt HIST_NO_FUNCTIONS # Don't save function definitions
  setopt HIST_SAVE_NO_DUPS # Don't save duplicate entries
  setopt HIST_VERIFY # Don't execute immediately upon history expansion
  setopt SHARE_HISTORY # Share history between sessions

  if command -v zsh >/dev/null 2>&1; then

    # export GHOSTTY_SUPERPOWERS="${0:A:h}"
    export GHOSTTY_SUPERPOWERS="${GHOSTTY_SUPERPOWERS:=${HOME}/.ghostty-superpowers}"
    export ZSH_THEME="${ZSH_THEME:-robbyrussell}"

    # SHELL FRAMEWORK
    # Native modules replace oh-my-zsh by default (no ~/.oh-my-zsh dependency).
    # Set GHOSTTY_SUPERPOWERS_USE_OMZ=1 to use a real oh-my-zsh install instead.
    if [[ "${GHOSTTY_SUPERPOWERS_USE_OMZ:-0}" == 1 ]]; then
      export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
      [[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"
    else
      source "$GHOSTTY_SUPERPOWERS/lib/colors.zsh"       # colours + prompt_subst, ls/grep
      source "$GHOSTTY_SUPERPOWERS/lib/completion.zsh"   # compinit + completion styles
      source "$GHOSTTY_SUPERPOWERS/lib/git-prompt.zsh"   # git_prompt_info et al.
      source "$GHOSTTY_SUPERPOWERS/lib/directories.zsh"  # auto_cd/pushd, ../.. shortcuts
      source "$GHOSTTY_SUPERPOWERS/lib/history.zsh"      # HISTFILE/HISTSIZE/SAVEHIST
      source "$GHOSTTY_SUPERPOWERS/lib/misc.zsh"         # interactivecomments (# gray), multios, sudo alias, pager
      source "$GHOSTTY_SUPERPOWERS/lib/functions-extra.zsh" # take family + zsh_stats
      source "$GHOSTTY_SUPERPOWERS/lib/keybindings-base.zsh" # emacs keymap, must precede plugins
      source "$GHOSTTY_SUPERPOWERS/lib/term.zsh"         # window title + OSC 7 cwd
      source "$GHOSTTY_SUPERPOWERS/lib/theme.zsh"        # robbyrussell prompt
    fi

    # 3TH-PARTY ZSH PLUGINS
    if [[ -f "$GHOSTTY_SUPERPOWERS/plugins_external/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
      source "$GHOSTTY_SUPERPOWERS/plugins_external/zsh-autosuggestions/zsh-autosuggestions.zsh"
    fi
    if [[ -f "$GHOSTTY_SUPERPOWERS/plugins_external/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
      source "$GHOSTTY_SUPERPOWERS/plugins_external/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    fi

    # GPOWERS - INIT LIB
    # (generic functions, aliases and more)
    source "$GHOSTTY_SUPERPOWERS/lib/aliases.zsh"
    source "$GHOSTTY_SUPERPOWERS/lib/functions.zsh"
    source "$GHOSTTY_SUPERPOWERS/lib/keybindings.zsh"

    # GPOWERS - FZF
    # (Fuzzy Finder / Reverse-Search / ..)
    source "$GHOSTTY_SUPERPOWERS/plugins/fzf.zsh"

    # GPOWERS - LLM COMPLETION
    # (AI-powered terminal autosuggestion)
    source "$GHOSTTY_SUPERPOWERS/plugins/zsh-ai-autocomplete.zsh"

    # GPOWERS - SNIPPETS & COMMANDS
    # (use your best snippets with autocomplete, sync & reverse search / fzf)
    source "$GHOSTTY_SUPERPOWERS/plugins/snippets.zsh"

    # GPOWERS - DIRECTORY JUMP
    # (frecency-style numeric shortcuts: 0 = list, 1 = cd -, 2.. = most-used dirs)
    source "$GHOSTTY_SUPERPOWERS/plugins/dirjump.zsh"

    # GPOWERS - UI EXTENSION
    # (make Ghostty UI even better)
    source "$GHOSTTY_SUPERPOWERS/plugins/ui.zsh"

    # GPOWERS - LIGHT SHELL OVER SSH
    # (gssh: ship zsh-autosuggestions + syntax-highlighting to remote hosts on
    #  connect, without installing anything into their config)
    source "$GHOSTTY_SUPERPOWERS/plugins/remote-ssh.zsh"

  else
    echo "[WARNING] zsh not found. Please install zsh shell to use ghostty-superpowers. You can also install all dependencies for ghostty-superpowers by running install.sh"
  fi
fi
