#!/usr/bin/env bash
set -Eeo pipefail # set -Eeuo pipefail
trap 'echo "[ERROR] Error at line $LINENO: $BASH_COMMAND"' ERR

readonly GHOSTTY_SUPERPOWERS_DIRNAME=".ghostty-superpowers"
readonly GHOSTTY_SUPERPOWERS="${GHOSTTY_SUPERPOWERS:-${HOME}/$GHOSTTY_SUPERPOWERS_DIRNAME}"
readonly GHOSTTY_CONFIG_PATH_CUSTOM="$GHOSTTY_SUPERPOWERS/data/ghostty-config"
readonly GHOSTTY_CONFIG_PATH_TARGET_DIR="$HOME/.config/ghostty"
readonly GHOSTTY_CONFIG_PATH_TARGET="$GHOSTTY_CONFIG_PATH_TARGET_DIR/config"

# CHECK if USER is ROOT (use variable $SUDO instead of "sudo" everywhere)
if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

# SETUP GHOSTTY + DEPENDENCIES
# ---- flags -------------------------------------------------
[[ " $* " == *" --force "* || " $* " == *" -f "* ]] && FORCE=1

# ---- prompt ------------------------------------------------
if [[ -z $FORCE ]]; then
  read -n 1 -r -p \
"Choose install option:
1) Minimal Installation (ghostty+plugins, zsh, fzf, font-hack-nerd-font)
2) Full Installation with AI Features and many convenience tools (btop, cloc, ..)
q) Quit
" REPLY
  echo
else
  REPLY=1
fi

# ---- choice ------------------------------------------------
case "$REPLY" in
  1) PROFILE=base ;;
  2) PROFILE=full ;;
  [Qq]) exit 0 ;;
  *) echo "[ERROR] Invalid option"; exit 1 ;;
esac

# ---- package manager detection -----------------------------
HAS_BREW=0
HAS_PACMAN=0
HAS_SNAP=0
HAS_APT=0

command -v brew   >/dev/null 2>&1 && HAS_BREW=1
command -v pacman >/dev/null 2>&1 && HAS_PACMAN=1
command -v snap   >/dev/null 2>&1 && HAS_SNAP=1
command -v apt    >/dev/null 2>&1 && HAS_APT=1

# ---- sanity check ------------------------------------------
if (( !HAS_BREW )) && (( !HAS_PACMAN )) && (( !(HAS_SNAP && HAS_APT) )); then
  echo "[ERROR] No supported install method found."
  echo "Require either:"
  echo "  - Homebrew (preferred), or"
  echo "  - pacman, or"
  echo "  - snap + apt"
  exit 1
fi

# ---- helper functions ------------------------------------
is_ghostty_installed() {
  [[ -d "/Applications/Ghostty.app" ]] || command -v ghostty >/dev/null 2>&1
}

install_ghostty() {

  # SETUP CUSTOM GHOSTTY CONFIG (loaded via a `config-file` include so the
  # user's own config and overrides survive updates)
  [[ ! -d "$GHOSTTY_CONFIG_PATH_TARGET_DIR" ]] && mkdir -p "$GHOSTTY_CONFIG_PATH_TARGET_DIR"
  local include_line="config-file = $GHOSTTY_CONFIG_PATH_CUSTOM"

  if [[ ! -f "$GHOSTTY_CONFIG_PATH_TARGET" ]]; then
    # No config yet — create one that loads ghostty-superpowers
    printf '%s\n\n# Personal Ghostty overrides below\n' "$include_line" > "$GHOSTTY_CONFIG_PATH_TARGET"
  elif grep -qF "$include_line" "$GHOSTTY_CONFIG_PATH_TARGET"; then
    # Include already present (active or commented out) — skip
    [[ -n "$DEBUG" ]] && echo "[SKIP] Ghostty config already loads ghostty-superpowers"
  else
    # Existing config — prepend our include so the user's settings below win
    printf '%s\n' "$include_line" | cat - "$GHOSTTY_CONFIG_PATH_TARGET" > "$GHOSTTY_CONFIG_PATH_TARGET.tmp" \
      && mv "$GHOSTTY_CONFIG_PATH_TARGET.tmp" "$GHOSTTY_CONFIG_PATH_TARGET"
  fi

  # SKIP GHOSTTY INSTALL
  if is_ghostty_installed; then
    [[ -n "$DEBUG" ]] && echo "[SKIP] Ghostty already installed, skipping"
    return 0
  fi

  # INSTALL GHOSTTY
  if (( HAS_BREW )); then
    brew install --cask ghostty
  elif (( HAS_PACMAN )); then
    $SUDO pacman -S ghostty
  elif (( HAS_SNAP )); then
    $SUDO snap install ghostty --classic
  else
    echo "[ERROR] Cannot install Ghostty"
    exit 1
  fi

}

# Install Zsh if not present
install_zsh() {
  if ! command -v zsh >/dev/null 2>&1; then
    echo "[INFO] Zsh not found. Installing..."
    if (( HAS_BREW )); then
      brew install zsh
    elif (( HAS_PACMAN )); then
      $SUDO pacman -S zsh
    elif (( HAS_APT )); then
      $SUDO apt install -y zsh
    else
      echo "[WARN] Could not install zsh. Please install manually."
    fi
  fi
}

# Create default .env file
install_ghostty_superpowers_env() {
  local env_file="$GHOSTTY_SUPERPOWERS/.env"
  [[ -f "$env_file" ]] || touch "$env_file"

  # GHOSTTY OLLAMA MODEL DEFAULT
#   if [[ ! -f "$env_file" ]]; then
#     cat > "$env_file" << 'EOF'
# # Ollama Model Configuration
# GHOSTTY_SUPERPOWERS_OLLAMA_MODEL=gemma4:e2b
# EOF
#     echo "[INFO] Created default .env file with GHOSTTY_SUPERPOWERS_OLLAMA_MODEL configuration"
#   fi
}

install_ghostty_superpowers_zsh() {
    local zshrc="$HOME/.zshrc"

    [[ -f "$zshrc" ]] || touch "$zshrc"

    # Check if Ghostty Superpowers is already referenced
    if grep -q "ghostty-superpowers" "$zshrc" 2>/dev/null; then
        echo
        echo "[IMPORTANT] Ghostty Superpowers is already referenced in your ~/.zshrc."
        echo "Make sure its correctly set similar to:"
        echo "source ~/$GHOSTTY_SUPERPOWERS_DIRNAME/init.zsh"
        echo
    else
        # if [[ -f "$zshrc" ]]; then
        #   # Comments out oh-my-zsh.sh (ghostty-superpowers loads oh-my-zsh anyway)
        #   sed -i.bak '/^[[:space:]]*source \$ZSH\/oh-my-zsh.sh/ s/^[[:space:]]*/#/' "$zshrc"
        # fi

        # Append ghostty-superpowers to .zshrc
        cat << EOF >> "$zshrc"
source ~/$GHOSTTY_SUPERPOWERS_DIRNAME/init.zsh
EOF
        echo
        echo "[INFO] Ghostty Superpowers has been added to your ~/.zshrc."
        echo "(Re)Start your Ghostty Terminal."
        echo
    fi
}

# NOTE: oh-my-zsh is no longer required. ghostty-superpowers ships native
# equivalents (prompt, completion, keybindings, git prompt, ...) under lib/.
# To use a real oh-my-zsh install instead, install it yourself and set
# GHOSTTY_SUPERPOWERS_USE_OMZ=1 before sourcing init.zsh.

install_zsh_plugins_external() {
  # git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  # git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
  # OR:
  # git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
  # git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting
  TMP_ZSH_AUTOSUGGESTIONS="$HOME/.ghostty-superpowers/plugins_external/zsh-autosuggestions"
  if [[ -d "$TMP_ZSH_AUTOSUGGESTIONS" ]]; then
    (cd "$TMP_ZSH_AUTOSUGGESTIONS" && git pull)
  else
    git clone https://github.com/zsh-users/zsh-autosuggestions "$TMP_ZSH_AUTOSUGGESTIONS"
  fi

  TMP_ZSH_SYNTAX_HIGHLIGHTING="$HOME/.ghostty-superpowers/plugins_external/zsh-syntax-highlighting"
  if [[ -d "$TMP_ZSH_SYNTAX_HIGHLIGHTING" ]]; then
    (cd "$TMP_ZSH_SYNTAX_HIGHLIGHTING" && git pull)
  else
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$TMP_ZSH_SYNTAX_HIGHLIGHTING"
  fi
}

install_base() {
  install_ghostty
  install_zsh
  install_zsh_plugins_external
  install_ghostty_superpowers_zsh
  install_ghostty_superpowers_env

  if (( HAS_BREW )); then
    brew install fzf font-hack-nerd-font || true # jq is usually pre-installed
  elif (( HAS_PACMAN )); then
    $SUDO pacman -S fzf otf-font-hack-nerd ttf-font-hack-nerd jq || true
  elif (( HAS_APT )); then
    $SUDO apt install -y fzf fonts-hack-ttf jq || true
  fi
}

install_full() {
  install_base

  if (( HAS_BREW )); then
    brew install btop cloc fd helix go gopls lazygit ollama rg tldr || true
  elif (( HAS_PACMAN )); then
    $SUDO pacman -S btop cloc fd helix go gopls lazygit ripgrep tldr || true
  elif (( HAS_APT )); then
    $SUDO apt install -y btop cloc fd-find helix golang gopls lazygit ripgrep tldr || true
  fi

  if (( HAS_PACMAN || HAS_APT )); then
    ! command -v ollama >/dev/null 2>&1 && curl -fsSL https://ollama.com/install.sh | sh
  fi

  if [[ "$(uname -s)" == "Darwin" ]]; then
    ollama pull gemma4:e2b-mlx
  else
    ollama pull gemma4:e2b
  fi
}

# ---- run ---------------------------------------------------
install_$PROFILE

echo
echo "[FINISHED] Installation finished. Restart your Terminal."

