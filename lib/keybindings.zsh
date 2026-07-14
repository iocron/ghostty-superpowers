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
