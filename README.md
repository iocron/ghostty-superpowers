<p align="center"><img width="25%" src="./img/logo.png" alt="Ghostty Superpowers"></p>

# Ghostty Terminal with Superpowers! (BETA)

Ghostty Terminal with Zsh, a simple and awesome UI, advanced autocomplete, fzf, command snippets/history, and much more.

## Requirements
- macOS, Ubuntu, or Arch / Arch-based OS with one of these package managers: [brew](https://brew.sh/), pacman, or snap+apt

## Install
1. Clone the repository
    ```bash
    git clone git@github.com:iocron/ghostty-superpowers.git ~/.ghostty-superpowers
    ```
2. Set up the installer
    ```bash
    cd ~/.ghostty-superpowers && chmod +x install.sh
    ```
3. Start the Installer and pick a profile when prompted:
    ```bash
    ./install.sh
    ```
    - **Minimal** - Ghostty + config, zsh, the zsh plugins, fzf, and the Hack Nerd Font.
    - **Full** - everything in Minimal plus extra tools (btop, fd, helix, lazygit, ripgrep, tldr, …) and the AI stack (Ollama + a default model, pulled for you).
4. (Re)start Ghostty (on macOS located in /Applications/Ghostty.app)

Enjoy your new Ghostty Experience :)

## Features
- Ghostty Terminal with Blockview Gadgets
- Advanced Snippet-/Historysearch and Autocomplete
- AI-Powered LLM Completion (type `#` followed by text and press Tab or Enter)
- Directory Jump with numeric shortcuts (`0`-`9`) to hop between your most-used directories (type `0` to show the ranked list)
- Quick browser websearch (e.g. `s <query>`)
- `gssh` - take your autosuggestions + syntax highlighting to remote hosts over SSH, without installing anything on them
- Zsh with a built-in framework (prompt, completion, keybindings, git prompt)
- Other helper aliases and functions can be listed with `alias` / `functions`

## How to use the Snippet-/History Autocomplete Feature
Simply create/edit the file ~/.ghostty-superpowers/data/snippets.txt and add snippets in the form:
```text
COMMAND ## NAME/TITLE ## DESCRIPTION..
```

For example: `echo "123" ## Echo example ## Outputs text`\
(or use one of the example files data/snippets.examples-long.txt)

When you restart Ghostty, you should see your new commands in the history/reverse search and while typing (due to autocomplete). If this still doesn't work, delete the file /tmp/.ghostty_snippets_lastrun and restart Ghostty again.

## How to use the AI Auto-Completion Feature
The **Full** installation sets up ollama and the default model out of the box. With a **Minimal** install, install ollama yourself (https://ollama.com/) and pull a model: `ollama pull gemma4:e2b` (or `gemma4:e2b-mlx` on macOS).

To use a different model, pull it and set `GHOSTTY_SUPERPOWERS_OLLAMA_MODEL` in `~/.ghostty-superpowers/.env` (or your zsh profile), e.g. `GHOSTTY_SUPERPOWERS_OLLAMA_MODEL=gemma4:e2b`

Then, in a new pane or session, use it two ways - press Tab or Enter after typing:
- **Generate** a command: start the line with `#` and describe what you want, e.g. `# list files by size`.
- **Modify** a command: write the command, then `#` and an instruction, e.g. `echo 123 # change the string to hello world` → `echo "hello world"`.

## How to use gssh (Superpowers on Remote Hosts)

`gssh user@host` connects like `ssh` but brings autosuggestions + syntax
highlighting along, **without installing anything into the remote's config**. It
ships a small bundle on connect (zsh remotes get the zsh plugins, bash ≥ 4 get
[`ble.sh`](https://github.com/akinomyoga/ble.sh), others fall back to a plain
login) and never touches the host's rc files or history.

Options (in `~/.ghostty-superpowers/.env` or your zsh profile):
- `GSP_SSH_EPHEMERAL=1` — no residue; else the bundle is cached under
  `~/.cache/gsp-lite` (remove it with `rm -rf ~/.cache/gsp-lite`).
- `GSP_SSH_WRAP=1` — also enhance the plain `ssh` command, not just `gssh`.

## Preview of some Features

![Preview](img/preview.jpg)

## FAQ

**Prefer oh-my-zsh?**

Set `GHOSTTY_SUPERPOWERS_USE_OMZ=1` in your ~/.zshrc (before `init.zsh` is sourced) to load your existing oh-my-zsh in place of the built-in framework - the rest of ghostty-superpowers (plugins, fzf, snippets, AI completion) still loads either way.

**Don't have one of the supported package managers?**

Set up manually: install Ghostty, zsh, fzf, and a Hack Nerd Font; clone `zsh-autosuggestions` and `zsh-syntax-highlighting` into `plugins_external/`; add `config-file = ~/.ghostty-superpowers/data/ghostty-config` to `~/.config/ghostty/config`; source `~/.ghostty-superpowers/init.zsh` in `~/.zshrc`; then restart Ghostty.

