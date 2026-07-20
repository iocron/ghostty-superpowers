#!/usr/bin/env zsh
# GPOWERS - SHIFT-SELECT
# Select command-line text with Shift+arrows; binds the sequences Ghostty sends
# (^[[1;2D etc.) so Shift+Left no longer leaks its escape tail ("D"). Needs the
# emacs main keymap (keybindings-base.zsh) already loaded.
#
# Vendored verbatim from jirutka/zsh-shift-select v0.1.1:
#   Copyright 2022-present Jakub Jirutka <jakub@jirutka.cz>.
#   SPDX-License-Identifier: MIT  |  https://github.com/jirutka/zsh-shift-select

# Move cursor to buffer end/start (-w triggers syntax-highlight redraw).
function end-of-buffer() {
	CURSOR=${#BUFFER}
	zle end-of-line -w
}
zle -N end-of-buffer

function beginning-of-buffer() {
	CURSOR=0
	zle beginning-of-line -w
}
zle -N beginning-of-buffer

# Kill the selection, back to main keymap.
function shift-select::kill-region() {
	zle kill-region -w
	zle -K main
}
zle -N shift-select::kill-region

# Collapse selection, back to main keymap, reprocess the typed key there.
function shift-select::deselect-and-input() {
	zle deactivate-region -w
	zle -K main
	zle -U "$KEYS"
}
zle -N shift-select::deselect-and-input

# Start/extend selection, then run the movement widget ($WIDGET minus prefix).
function shift-select::select-and-invoke() {
	if (( !REGION_ACTIVE )); then
		zle set-mark-command -w
		zle -K shift-select
	fi
	zle ${WIDGET#shift-select::} -w
}

function {
	emulate -L zsh

	# Create a new keymap for the shift-selection mode.
	bindkey -N shift-select

	# Bind all possible key sequences to deselect-and-input, i.e. it will be used
	# as a fallback for "unbound" key sequences.
	bindkey -M shift-select -R '^@'-'^?' shift-select::deselect-and-input

	local kcap seq seq_mac widget

	# Bind Shift keys in the emacs and shift-select keymaps.
	for	kcap   seq          seq_mac    widget (             # key name
		kLFT   '^[[1;2D'    x          backward-char        # Shift + LeftArrow
		kRIT   '^[[1;2C'    x          forward-char         # Shift + RightArrow
		kri    '^[[1;2A'    x          up-line              # Shift + UpArrow
		kind   '^[[1;2B'    x          down-line            # Shift + DownArrow
		kHOM   '^[[1;2H'    x          beginning-of-line    # Shift + Home
		x      '^[[97;6u'   x          beginning-of-line    # Shift + Ctrl + A
		x      '^[[1;10D'   x          beginning-of-line    # Cmd + Shift + LeftArrow (macOS)
		kEND   '^[[1;2F'    x          end-of-line          # Shift + End
		x      '^[[101;6u'  x          end-of-line          # Shift + Ctrl + E
		x      '^[[1;10C'   x          end-of-line          # Cmd + Shift + RightArrow (macOS)
		x      '^[[1;6D'    '^[[1;4D'  backward-word        # Shift + Ctrl/Option + LeftArrow
		x      '^[[1;6C'    '^[[1;4C'  forward-word         # Shift + Ctrl/Option + RightArrow
		x      '^[[1;6H'    '^[[1;4H'  beginning-of-buffer  # Shift + Ctrl/Option + Home
		x      '^[[1;6F'    '^[[1;4F'  end-of-buffer        # Shift + Ctrl/Option + End
	); do
		# Use alternative sequence (Option instead of Ctrl) on macOS, if defined.
		[[ "$OSTYPE" = darwin* && "$seq_mac" != x ]] && seq=$seq_mac

		zle -N shift-select::$widget shift-select::select-and-invoke
		bindkey -M emacs ${terminfo[$kcap]:-$seq} shift-select::$widget
		bindkey -M shift-select ${terminfo[$kcap]:-$seq} shift-select::$widget
	done

	# Bind keys in the shift-select keymap.
	for	kcap   seq        widget (                          # key name
		kdch1  '^[[3~'    shift-select::kill-region         # Delete
		bs     '^?'       shift-select::kill-region         # Backspace
	); do
		bindkey -M shift-select ${terminfo[$kcap]:-$seq} $widget
	done
}
