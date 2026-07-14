#!/usr/bin/env zsh
# GPOWERS - DIRECTORY JUMP
# Frecency-style numeric shortcuts for hopping between your busiest dirs.
#
#   0   → show the ranked list of tracked directories
#   1   → cd -            (toggle to the previous directory)
#   2   → most-used directory
#   3   → 2nd most-used directory
#   4   → 3rd most-used directory
#   ... → up to 9
#
# Every real directory change is logged (one "epoch <TAB> path" line per visit)
# and ranking counts how often each dir appears within the most recent window of
# visits -- so a place you hammered long ago fades once it scrolls out of the
# window, while recently-busy dirs rise. Tweak behaviour via:
#   GTTY_DIRJUMP_DB    path to the visit log
#   GTTY_DIRJUMP_MAX   size of the recent-visit window used for ranking

: "${GTTY_DIRJUMP_DB:=${GHOSTTY_SUPERPOWERS:-$HOME/.ghostty-superpowers}/cache/.dir_frecency}"
: "${GTTY_DIRJUMP_MAX:=100}"

autoload -Uz add-zsh-hook
zmodload -F zsh/datetime +EPOCHSECONDS 2>/dev/null

# Log folder ships via cache/.gitkeep; warn instead of creating it.
if [[ ! -d "${GTTY_DIRJUMP_DB:h}" ]]; then
  print -u2 "dirjump: log folder missing: ${GTTY_DIRJUMP_DB:h} (frecency tracking disabled)"
else
  [[ -f "$GTTY_DIRJUMP_DB" ]] || : >> "$GTTY_DIRJUMP_DB" 2>/dev/null
fi

# Record a visit to $PWD; runs on every directory change. Appends the visit and
# trims to the most recent GTTY_DIRJUMP_MAX lines (the ranking window).
_gtty_dirjump_record() {
  local db="$GTTY_DIRJUMP_DB" dir="$PWD" now=${EPOCHSECONDS:-$(date +%s)}
  [[ -d "${db:h}" ]] || return
  local tmp
  tmp="$(mktemp "${db}.XXXXXX")" || return
  { [[ -f "$db" ]] && cat -- "$db"; printf '%s\t%s\n' "$now" "$dir"; } \
    | tail -n "$GTTY_DIRJUMP_MAX" > "$tmp" 2>/dev/null
  mv -f "$tmp" "$db" 2>/dev/null || rm -f "$tmp" 2>/dev/null
}

# Emit unique dirs ranked by visit frequency within the window (most-used first).
# Output: count <TAB> last_epoch <TAB> path
_gtty_dirjump_rank() {
  [[ -s "$GTTY_DIRJUMP_DB" ]] || return
  awk -F '\t' '
    NF >= 2 { p = $2; cnt[p]++; if ($1 + 0 > last[p]) last[p] = $1 }
    END     { for (p in cnt) printf "%d\t%d\t%s\n", cnt[p], last[p], p }
  ' "$GTTY_DIRJUMP_DB" 2>/dev/null \
    | sort -t $'\t' -k1,1nr -k2,2nr
}

# Print the path ranked at position $1 (1 = most used).
_gtty_dirjump_path() {
  _gtty_dirjump_rank | awk -F '\t' -v n="$1" 'NR == n { print $3; exit }'
}

# Show the ranked list with the command number to type for each entry.
_gtty_dirjump_list() {
  print -P "%F{244} cmd  recent  directory%f"
  print -P "%F{244}   1       -  cd - -> ${${OLDPWD:-none}/#$HOME/~}%f"
  local ranked; ranked="$(_gtty_dirjump_rank)"
  [[ -n "$ranked" ]] || { print -P "%F{244}   (no directories tracked yet)%f"; return; }
  # Only list dirs that have a working jump command. Digits run 1-9 and cmd 1 is
  # `cd -`, so the ranked list can fill commands 2-9 (8 dirs) at most; stop there
  # rather than printing rows whose cmd number (10, 11, ...) can never be typed.
  local i=1 count ts path marker
  while IFS=$'\t' read -r count ts path; do
    (( i + 1 > 9 )) && break
    marker=' '; [[ "$path" == "$PWD" ]] && marker='*'
    printf '%s%3d  %6d  %s\n' "$marker" $(( i + 1 )) "$count" "${path/#$HOME/~}"
    (( i++ ))
  done <<< "$ranked"
}

# Dispatch a numeric command to the right action.
_gtty_dirjump_go() {
  local n="$1" dir
  case "$n" in
    0) _gtty_dirjump_list ;;
    1) cd - ;;
    *) dir="$(_gtty_dirjump_path $(( n - 1 )))"
       if [[ -n "$dir" && -d "$dir" ]]; then
         cd -- "$dir"
       elif [[ -n "$dir" ]]; then
         print -u2 "dirjump: rank $(( n - 1 )) directory no longer exists: $dir"
         return 1
       else
         print -u2 "dirjump: nothing ranked at position $(( n - 1 )) yet (try 0)"
         return 1
       fi ;;
  esac
}

# Expose bare numeric commands 0-9 as functions. A digit alias (e.g. 2='cd -2')
# would be expanded before function lookup and shadow us, so drop any first.
for _n in 0 1 2 3 4 5 6 7 8 9; do
  (( ${+aliases[$_n]} )) && unalias "$_n" 2>/dev/null
  eval "${_n}() { _gtty_dirjump_go ${_n}; }"
done
unset _n

add-zsh-hook chpwd _gtty_dirjump_record
