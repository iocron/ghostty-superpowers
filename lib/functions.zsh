# Show only added/removed diff lines matching a string across Git history.
# Groups matches by file (header printed once) and colorizes the output.
# Colors auto-disable when the output is piped/redirected.
git_diff_string_history() {
    local search="$1"

    if [[ -z "$search" ]]; then
        echo "Usage: ${FUNCNAME[0]} <search-string>"
        return 1
    fi

    # Enable colors only on an interactive terminal.
    local c_commit='' c_file='' c_add='' c_del='' c_reset=''
    if [[ -t 1 ]]; then
        c_commit=$'\e[1;90m'   # bold gray
        c_file=$'\e[1;36m'     # bold cyan
        c_add=$'\e[32m'        # green
        c_del=$'\e[31m'        # red
        c_reset=$'\e[0m'
    fi

    git log --all --format='%H' -G "$search" |
    while read -r commit; do
        git diff-tree --no-commit-id --unified=0 -r "$commit" |
        awk -v search="$search" \
            -v header="$(git show -s --format='%h %s' "$commit")" \
            -v c_commit="$c_commit" -v c_file="$c_file" \
            -v c_add="$c_add" -v c_del="$c_del" -v c_reset="$c_reset" '
            function flush_file() {
                if (nlines > 0) {
                    if (!commit_shown) {
                        print ""
                        print c_commit "━━━━━ " header " ━━━━━" c_reset
                        commit_shown = 1
                    }
                    print ""
                    print c_file file c_reset
                    for (i = 1; i <= nlines; i++) print lines[i]
                }
                nlines = 0
            }
            /^diff --git/ {
                flush_file()
                # Use the b/ path (second path) as the display name.
                file = $NF
                sub(/^b\//, "", file)
                next
            }
            /^[+-]/ && !/^(---|\+\+\+)/ {
                if (index($0, search)) {
                    color = (substr($0, 1, 1) == "+") ? c_add : c_del
                    lines[++nlines] = "  " color $0 c_reset
                }
            }
            END { flush_file() }
        '
    done
}

# Open a URL/file in the OS default handler (macOS `open`, Linux `xdg-open`).
_gtty_open() {
  if command -v open >/dev/null 2>&1; then
    open "$@"
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$@"
  else
    echo "[WARNING] No URL opener found (need 'open' or 'xdg-open')." >&2
    return 1
  fi
}

# Github URL Browser Opener
github_search() {
  local query
  query=$(printf '%s' "$*" | sed 's/ /+/g')
  _gtty_open "https://github.com/search?q=${query}&type=repositories"
}

# w3m duckduckgo search query
duck() {
  if command -v w3m >/dev/null 2>&1; then
    w3m -dump "https://duckduckgo.com/?q=$*"
  else
    echo "[WARNING] Tool w3m does not exist. Install first please (on macos: \"brew install w3m\")."
  fi
}
alias dk="duck"

# DuckDuckGo Quicksearch
# Usage: s hello world
# Usage with Bangs: s '!gh ollama'
# (for more bangs see: https://duckduckgo.com/bangs)
s() {
  local query
  query=$(printf '%s' "$*" | sed 's/ /+/g')
  _gtty_open "https://duckduckgo.com/?q=$query"
  # open "https://lite.duckduckgo.com/lite/?q=$query"
}

# SSM Shortcut Function for AWS SSM (SessionManager)
# Requirements: Install session-manager-plugin (e.g. brew install session-manager-plugin)
# Example: ssm i-01a89a0c5c3599999
ssm() { aws ssm start-session --target "$1"; }

# List the last 10 updated/modified files/dirs sorted from top to bottom
# Usage: lt OR lt <path>
lt () {
  ls -lht "$@" | head -10
}
