#!/usr/bin/env zsh
# set -e

GHOSTTY_SUPERPOWERS="${GHOSTTY_SUPERPOWERS:-${HOME}/.ghostty-superpowers}"

# BUG: script is causing file creation of files like: ) > 0) { split(name, a, -
# its all related to the snippet: Name: 'network - v2 list processes/apps network com in detail'


# VARS
readonly SNIPPETS_FILE="$GHOSTTY_SUPERPOWERS/data/snippets.txt"
readonly SNIPPETS_BACKUP_FILE="$GHOSTTY_SUPERPOWERS/data/.snippets.txt.backup"
readonly HISTORY_FILE="${HOME}/.zsh_history"
SNIPPETS_LAST_RUN_FILE="/tmp/.ghostty_snippets_lastrun"

touch "$HISTORY_FILE"

# Get current mtime of snippets file and this script
SCRIPT_PATH="${(%):-%x}"
if [[ "$OSTYPE" == "darwin"* ]]; then
  CURRENT_MTIME=$(stat -f%m "$SNIPPETS_FILE" 2>/dev/null)
  SCRIPT_MTIME=$(stat -f%m "$SCRIPT_PATH" 2>/dev/null)
else
  CURRENT_MTIME=$(stat -c%Y "$SNIPPETS_FILE" 2>/dev/null)
  SCRIPT_MTIME=$(stat -c%Y "$SCRIPT_PATH" 2>/dev/null)
fi

# Combine mtimes for change detection
COMBINED_MTIME="${CURRENT_MTIME}:${SCRIPT_MTIME}"

if [[ -z "$CURRENT_MTIME" ]]; then
  [[ -n "$DEBUG" ]] && echo "Snippets file not found or inaccessible: $SNIPPETS_FILE"
  return 0
fi

if [[ -f "$SNIPPETS_LAST_RUN_FILE" ]]; then
  LAST_RUN=$(cat "$SNIPPETS_LAST_RUN_FILE" 2>/dev/null)
  if [[ "$COMBINED_MTIME" == "$LAST_RUN" ]]; then
    [[ -n "$DEBUG" ]] && echo "Skipping snippets.zsh (no changes detected)"
    return 0
  fi
fi

# Update last run timestamp
echo "$COMBINED_MTIME" > "$SNIPPETS_LAST_RUN_FILE"


# Check if the snippets file exists
if [[ ! -f "$SNIPPETS_FILE" ]]; then
    echo "Snippets file not found: $SNIPPETS_FILE"
    echo "Created file $SNIPPETS_FILE"
    touch $SNIPPETS_FILE
    return 0 # exit 0
fi


# Function to create backup of snippets file
create_snippets_backup() {
    if [[ -f "$SNIPPETS_FILE" ]]; then
        cp "$SNIPPETS_FILE" "$SNIPPETS_BACKUP_FILE"
    fi
}


# Function to remove entries from history that are no longer in snippets
remove_old_entries_from_history() {
    # If backup doesn't exist, nothing to compare
    if [[ ! -f "$SNIPPETS_BACKUP_FILE" ]]; then
        return 0
    fi
    
    # Create temporary files
    local current_snippets_tmp="$(mktemp)"
    local backup_snippets_tmp="$(mktemp)"
    # tmp_hist is mv'd onto $HISTORY_FILE, so keep it on the same filesystem
    # to guarantee an atomic rename (avoids truncating history if interrupted).
    local tmp_hist="$(mktemp "${HISTORY_FILE}.XXXXXX")" || return 0
    
    # Get just the snippet lines (without timestamps) from current history
    LC_ALL=C grep -E "^: [0-9]+:0;" "$HISTORY_FILE" | LC_ALL=C sed 's/^: [0-9]\+:0;//' > "$current_snippets_tmp"
    
    # Get lines from backup file
    cat "$SNIPPETS_BACKUP_FILE" > "$backup_snippets_tmp"
    
    # Find lines in backup that are not in current snippets file
    local removed_lines_tmp="$(mktemp)"
    LC_ALL=C grep -Fvf "$SNIPPETS_FILE" "$backup_snippets_tmp" > "$removed_lines_tmp"
    
    # Remove each removed line from history
    if [[ -s "$removed_lines_tmp" ]]; then
        while IFS= read -r removed_line; do
            if [[ -n "$removed_line" ]]; then
                # Remove the line from history (both with and without timestamps)
                LC_ALL=C grep -v -F "$removed_line" "$HISTORY_FILE" > "$tmp_hist" && mv "$tmp_hist" "$HISTORY_FILE"
            fi
        done < "$removed_lines_tmp"
    fi
    
    # Clean up temp files
    rm -f "$current_snippets_tmp" "$backup_snippets_tmp" "$removed_lines_tmp" "$tmp_hist"
}


# Handle backup and old entry removal
remove_old_entries_from_history
create_snippets_backup

# Function to extract just the command part (before ##)
extract_command() {
    local line="$1"
    # Split at the first occurrence of " ##" to separate command from comment
    echo "$line" | sed 's/ ##.*//'
}

# Function to extract the comment part (between first ## and second ##)
extract_comment() {
    local line="$1"
    # Extract everything between the first ## and second ##
    echo "$line" | sed -n 's/.*## \(.*\) ##.*/\1/p'
}

# Function to extract the description part (after second ##)
extract_description() {
    local line="$1"
    # Extract everything after the second ##
    echo "$line" | sed -n 's/.*## ## \(.*\)/\1/p'
}

# Function to remove old history entry for a command
remove_command_from_history() {
    LC_ALL=C grep -vF -e "$1" "$HISTORY_FILE" > "$HISTORY_FILE.$$" && mv "$HISTORY_FILE.$$" "$HISTORY_FILE"
}

# Function to remove old history entry for a comment
remove_comment_from_history() {
    LC_ALL=C grep -vF -e "$1" "$HISTORY_FILE" > "$HISTORY_FILE.$$" && mv "$HISTORY_FILE.$$" "$HISTORY_FILE"
}

# Function to check if command exists in history file
command_exists_in_history() {
    LC_ALL=C grep -F -e "$1" "$HISTORY_FILE" > /dev/null 2>&1
}

# Function to check if comment exists in history file
comment_exists_in_history() {
    LC_ALL=C grep -F -e "$1" "$HISTORY_FILE" > /dev/null 2>&1
}

# Function to check if exact line exists in history file
exact_line_exists_in_history() {
    LC_ALL=C grep -F -e "$1" "$HISTORY_FILE" > /dev/null 2>&1
}

flatten_command() {
    local cmd="$1"
    # Remove literal newlines and replace with spaces
    echo "$cmd" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g'
}

# Function to add command to history file
add_to_history_file() {
    local cmd="$1"
    local timestamp=$(date +%s)

    cmd=$(flatten_command "$cmd")
    # Add command to history file in zsh format
    # Use flock to prevent race conditions with concurrent sessions if available
    echo ": $timestamp:0;$cmd" >> "$HISTORY_FILE"
    # if command -v flock >/dev/null 2>&1; then
    #     flock -e "$HISTORY_FILE" sh -c "echo ': $timestamp:0;$cmd' >> '$HISTORY_FILE'"
    # else
    #     echo ": $timestamp:0;$cmd" >> "$HISTORY_FILE"
    # fi
}

# Function to add command to current shell session
add_to_current_session() {
    local cmd="$1"
    cmd=$(flatten_command "$cmd")

    if [[ -n "$ZSH_VERSION" ]]; then
        # Zsh
        print -s "$cmd"
    else
        # Bash
        history -s "$cmd"
    fi
}

# Function to add/update command in history
add_to_history() {
    local line="$1"

    # Extract command, comment, description
    local cmd=$(extract_command "$line")
    local comment=$(extract_comment "$line")
    local desc=$(extract_description "$line")

    # Skip empty command lines
    [[ -z "$cmd" ]] && return 0

    # Remove duplicates based on exact line match
    if [[ -n "$line" ]]; then
        # Create the temp next to $HISTORY_FILE so the mv below is an atomic
        # same-filesystem rename (no risk of truncating history mid-copy).
        local tmp_hist="$(mktemp "${HISTORY_FILE}.XXXXXX")" || return 0
        
        # Remove exact line matches (both with and without timestamps)
        # This uses grep -v with extended regex to match lines with or without timestamps
        LC_ALL=C grep -v -E "(: [0-9]+:0;)?$(echo "$line" | LC_ALL=C sed 's/[[\.*^$()+?{|]/\\&/g')" "$HISTORY_FILE" > "$tmp_hist" && mv "$tmp_hist" "$HISTORY_FILE"
    fi

    # Debug output
    [[ -n "$DEBUG" ]] && echo "Adding snippet: ${cmd:0:50}..."

    # Append the snippet line to history in zsh format
    add_to_history_file "$line"

    # Update the current shell session
    add_to_current_session "$line"
}

# Read and process each line from the snippets file
while IFS= read -r line; do
    add_to_history "$line"
done < "$SNIPPETS_FILE"

if [[ -n "$DEBUG" ]]; then
    echo "Finished processing snippets from $SNIPPETS_FILE"
    echo "Please run 'exec zsh' or start a new shell session to use the snippets"
fi
