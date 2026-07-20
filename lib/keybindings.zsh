#!/usr/bin/env zsh

# Sourced after the external zsh plugins (see init.zsh). Keep only bindings that
# are safe to define late here; the base keymap that must precede the plugins
# lives in lib/keybindings-base.zsh.

# Shift+Enter → insert a literal newline into the command buffer.
#
# With Ghostty's enhanced keyboard protocol (Kitty / modifyOtherKeys) active,
# Shift+Enter is sent as a distinct escape sequence with no default ZLE binding,
# leaking its raw tail (e.g. "2;13~") into the line. Binding both encodings
# keeps Shift+Enter consistent whichever protocol mode the terminal is in.
_gtty_insert_newline() { LBUFFER+=$'\n'; }
zle -N _gtty_insert_newline

bindkey '^[[27;2;13~' _gtty_insert_newline  # legacy CSI-27 / modifyOtherKeys form
bindkey '^[[13;2u'    _gtty_insert_newline  # Kitty keyboard protocol form

# Reset the terminal to legacy keyboard mode each prompt: a crashed TUI or dropped
# gssh/ble.sh session can leave the enhanced protocol on, leaking Shift+letters as
# escape-tail garbage (e.g. "6~3~"). zle never uses it, so this is safe.
autoload -Uz add-zsh-hook
_gtty_reset_kbd_protocol() { print -n '\e[>4;0m\e[<u'; }  # disable modifyOtherKeys, pop Kitty stack
add-zsh-hook precmd _gtty_reset_kbd_protocol
