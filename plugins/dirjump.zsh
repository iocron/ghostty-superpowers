#!/usr/bin/env zsh
# GPOWERS - DIRECTORY JUMP
# Frecency-style numeric shortcuts for hopping between your busiest dirs.
#
#   0   → show the ranked list of tracked directories
#   1   → top-ranked dir  (busiest by recency-weighted score; the slot is sticky)
#   2   → 2nd-ranked dir
#   3   → 3rd-ranked dir
#   ... → up to 9
#   -   → cd -            (toggle to the previous directory; see lib/directories.zsh)
#
# Each dir change is logged (epoch <TAB> path). Score = EMA of visits.
# Slot numbers are sticky: only a clearly-busier dir steals a slot. Tune via:
#   GTTY_DIRJUMP_DB        path to the visit log
#   GTTY_DIRJUMP_MAX       size of the recent-visit window kept in the log
#   GTTY_DIRJUMP_HALFLIFE  EMA half-life in seconds (default 86400 = 24h)
#   GTTY_DIRJUMP_MARGIN    how much busier a dir must be to steal a slot (default 2.0x)
#   GTTY_DIRJUMP_STICKY    top slots pinned to sticky order; the rest (up to 9) show most-recent (default 5)
#   GTTY_DIRJUMP_ORDER     path to the persisted sticky-order sidecar file

: "${GTTY_DIRJUMP_DB:=${GHOSTTY_SUPERPOWERS:-$HOME/.ghostty-superpowers}/cache/.dir_frecency}"
: "${GTTY_DIRJUMP_MAX:=200}"
: "${GTTY_DIRJUMP_HALFLIFE:=86400}"
: "${GTTY_DIRJUMP_MARGIN:=2.0}"
: "${GTTY_DIRJUMP_STICKY:=5}"
: "${GTTY_DIRJUMP_ORDER:=${GTTY_DIRJUMP_DB}.order}"

autoload -Uz add-zsh-hook
zmodload -F zsh/datetime +EPOCHSECONDS 2>/dev/null

# Log folder ships via cache/.gitkeep; warn instead of creating it.
if [[ ! -d "${GTTY_DIRJUMP_DB:h}" ]]; then
  print -u2 "dirjump: log folder missing: ${GTTY_DIRJUMP_DB:h} (frecency tracking disabled)"
else
  [[ -f "$GTTY_DIRJUMP_DB" ]] || : >> "$GTTY_DIRJUMP_DB" 2>/dev/null
fi

# Recompute + persist the sticky order; overtake needs MARGIN x the score above.
_gtty_dirjump_reorder() {
  local db="$GTTY_DIRJUMP_DB" order="$GTTY_DIRJUMP_ORDER"
  local now=${EPOCHSECONDS:-$(date +%s)}
  [[ -d "${order:h}" && -s "$db" ]] || return
  local prev="$order"; [[ -s "$prev" ]] || prev=/dev/null
  local tmp
  tmp="$(mktemp "${order}.XXXXXX")" || return
  awk -F '\t' -v now="$now" -v hl="$GTTY_DIRJUMP_HALFLIFE" \
      -v margin="$GTTY_DIRJUMP_MARGIN" -v dbfile="$db" '
    # The visit log -- accumulate each dir'"'"'s EMA score and last-seen epoch.
    FILENAME == dbfile {
      if (NF >= 2) { p = $2; score[p] += exp(-0.6931472 * (now - $1) / hl)
                     if ($1 + 0 > last[p]) last[p] = $1 }
      next
    }
    # Previous order (one path/line); match by FILENAME, not NR==FNR (empty-safe).
    length($0) { prev[++np] = $0 }
    END {
      no = 0
      # Keep prior order for dirs still inside the window (score > 0).
      for (i = 1; i <= np; i++) {
        p = prev[i]
        if ((p in score) && !(p in seen)) { ord[++no] = p; seen[p] = 1 }
      }
      # Append dirs not seen before, busiest-first.
      nn = 0
      for (p in score) if (!(p in seen)) newp[++nn] = p
      for (i = 2; i <= nn; i++) {
        x = newp[i]; j = i - 1
        while (j >= 1 && busier(x, newp[j])) { newp[j + 1] = newp[j]; j-- }
        newp[j + 1] = x
      }
      for (i = 1; i <= nn; i++) ord[++no] = newp[i]
      # Hysteresis: bubble a dir up only when its score >= margin x the one above.
      swapped = 1
      while (swapped) {
        swapped = 0
        for (i = 1; i < no; i++) {
          a = ord[i]; b = ord[i + 1]
          if (score[b] >= score[a] * margin) { ord[i] = b; ord[i + 1] = a; swapped = 1 }
        }
      }
      for (i = 1; i <= no; i++) print ord[i]
    }
    # True when x is busier than y (higher score, ties broken by recency).
    function busier(x, y) {
      return (score[x] > score[y]) || (score[x] == score[y] && last[x] > last[y])
    }
  ' "$db" "$prev" > "$tmp" 2>/dev/null \
    && mv -f "$tmp" "$order" 2>/dev/null || rm -f "$tmp" 2>/dev/null
}

# Record a $PWD visit (chpwd): append, trim to last MAX lines, refresh order.
_gtty_dirjump_record() {
  local db="$GTTY_DIRJUMP_DB" dir="$PWD" now=${EPOCHSECONDS:-$(date +%s)}
  [[ -d "${db:h}" ]] || return
  local tmp
  tmp="$(mktemp "${db}.XXXXXX")" || return
  { [[ -f "$db" ]] && cat -- "$db"; printf '%s\t%s\n' "$now" "$dir"; } \
    | tail -n "$GTTY_DIRJUMP_MAX" > "$tmp" 2>/dev/null
  mv -f "$tmp" "$db" 2>/dev/null || { rm -f "$tmp" 2>/dev/null; return; }
  _gtty_dirjump_reorder
}

# Drop every trace of dirs that no longer exist on disk from the log + order.
# Runs on any access (list or jump) so the history stays self-cleaning.
_gtty_dirjump_sweep() {
  local db="$GTTY_DIRJUMP_DB" order="$GTTY_DIRJUMP_ORDER" tmp deadfile p
  [[ -s "$db" ]] || return
  local -aU paths; local -a dead
  paths=(${(f)"$(awk -F '\t' 'NF>=2 && length($2) {print $2}' "$db" 2>/dev/null)"})
  for p in $paths; do [[ -d "$p" ]] || dead+=("$p"); done
  (( ${#dead} )) || return
  deadfile="$(mktemp "${db}.dead.XXXXXX")" || return
  print -rl -- "$dead[@]" > "$deadfile"
  # Strip matching field-2 paths from the visit log.
  tmp="$(mktemp "${db}.XXXXXX")" \
    && awk -F '\t' -v df="$deadfile" '
         BEGIN { while ((getline d < df) > 0) dead[d] = 1 }
         !($2 in dead)' "$db" > "$tmp" 2>/dev/null \
    && mv -f "$tmp" "$db" 2>/dev/null || rm -f "$tmp" 2>/dev/null
  # Strip matching whole-line paths from the sticky order.
  if [[ -s "$order" ]]; then
    tmp="$(mktemp "${order}.XXXXXX")" \
      && awk -v df="$deadfile" '
           BEGIN { while ((getline d < df) > 0) dead[d] = 1 }
           !($0 in dead)' "$order" > "$tmp" 2>/dev/null \
      && mv -f "$tmp" "$order" 2>/dev/null || rm -f "$tmp" 2>/dev/null
  fi
  rm -f "$deadfile" 2>/dev/null
  _gtty_dirjump_reorder
}

# Emit dirs in sticky-slot order. Output: score <TAB> last_epoch <TAB> path
_gtty_dirjump_rank() {
  _gtty_dirjump_sweep
  [[ -s "$GTTY_DIRJUMP_DB" ]] || return
  local now=${EPOCHSECONDS:-$(date +%s)}
  # Preferred path: emit in the persisted sticky order so numbers stay memorable.
  if [[ -s "$GTTY_DIRJUMP_ORDER" ]]; then
    awk -F '\t' -v now="$now" -v hl="$GTTY_DIRJUMP_HALFLIFE" -v dbfile="$GTTY_DIRJUMP_DB" '
      FILENAME == dbfile {
        if (NF >= 2) { p = $2; score[p] += exp(-0.6931472 * (now - $1) / hl)
                       if ($1 + 0 > last[p]) last[p] = $1 }
        next
      }
      length($0) { ord[++no] = $0 }
      END {
        for (i = 1; i <= no; i++) {
          p = ord[i]
          if (p in score) printf "%.6f\t%d\t%s\n", score[p], last[p], p
        }
      }
    ' "$GTTY_DIRJUMP_DB" "$GTTY_DIRJUMP_ORDER" 2>/dev/null | _gtty_dirjump_blend
    return
  fi
  # Cold-cache fallback (no order file yet): rank by EMA score, ties by recency.
  awk -F '\t' -v now="$now" -v hl="$GTTY_DIRJUMP_HALFLIFE" '
    NF >= 2 { p = $2; score[p] += exp(-0.6931472 * (now - $1) / hl)
              if ($1 + 0 > last[p]) last[p] = $1 }
    END     { for (p in score) printf "%.6f\t%d\t%s\n", score[p], last[p], p }
  ' "$GTTY_DIRJUMP_DB" 2>/dev/null \
    | sort -t $'\t' -k1,1nr -k2,2nr | _gtty_dirjump_blend
}

# View transform: keep top-STICKY rows in base order, then fill the remaining
# visible slots (up to 9) with the most-recently-visited of the rest.
_gtty_dirjump_blend() {
  awk -F '\t' -v sticky="$GTTY_DIRJUMP_STICKY" '
    { n++; sc[n]=$1; lt[n]=$2; pa[n]=$3 }
    END {
      vis = 0
      for (i = 1; i <= n && vis < sticky && vis < 9; i++) { out[++vis]=i; shown[i]=1 }
      nc = 0
      for (i = 1; i <= n; i++) if (!(i in shown)) cand[++nc] = i
      for (a = 2; a <= nc; a++) {          # insertion sort by last_epoch desc, ties by score desc
        x = cand[a]; j = a - 1
        while (j >= 1 && (lt[cand[j]] < lt[x] || (lt[cand[j]] == lt[x] && sc[cand[j]] < sc[x]))) {
          cand[j+1] = cand[j]; j--
        }
        cand[j+1] = x
      }
      for (a = 1; a <= nc && vis < 9; a++) out[++vis] = cand[a]
      for (a = 1; a <= vis; a++) { i = out[a]; printf "%s\t%s\t%s\n", sc[i], lt[i], pa[i] }
    }
  '
}

# Print the path ranked at position $1 (1 = most used).
_gtty_dirjump_path() {
  _gtty_dirjump_rank | awk -F '\t' -v n="$1" 'NR == n { print $3; exit }'
}

# Render the 0 list: ranked dirs (last-visit time + EMA freq bar)
_gtty_dirjump_list() {
  print -P "%F{244}   last   freq  cmd  directory%f"
  local ranked; ranked="$(_gtty_dirjump_rank)"
  local now=${EPOCHSECONDS:-$(date +%s)}
  # Digits 1-9 map to ranked dirs 1-9, so list at most 9 rows.
  if [[ -n "$ranked" ]]; then
    awk -F '\t' -v now="$now" -v pwd="$PWD" -v home="$HOME" '
      { n++; sc[n] = $1; lt[n] = $2; pa[n] = $3; if ($1 + 0 > mx) mx = $1 + 0 }
      END {
        for (i = 1; i <= n && i <= 9; i++) {
          ago = now - lt[i]
          if      (ago < 60)    agostr = ago "s"
          else if (ago < 3600)  agostr = int(ago / 60) "m"
          else if (ago < 86400) agostr = sprintf("%.1fh", ago / 3600)
          else                  agostr = sprintf("%.1fd", ago / 86400)
          cells = (mx > 0) ? int(sc[i] / mx * 5 + 0.999) : 0
          if (cells > 5) cells = 5
          if (cells < 1 && sc[i] + 0 > 0) cells = 1
          bar = ""
          for (k = 1; k <= 5; k++) bar = bar (k <= cells ? "\342\226\210" : "\342\226\221")
          marker = (pa[i] == pwd) ? "*" : " "
          path = pa[i]
          if (substr(path, 1, length(home)) == home) path = "~" substr(path, length(home) + 1)
          printf "%s%6s  %s  %3d  %s\n", marker, agostr, bar, i, path
        }
      }
    ' <<< "$ranked"
  else
    print -P "%F{244}   (no directories tracked yet)%f"
  fi
  # echo
  printf '%s%6s  %s  %3s  %s\n' ' ' '-' '     ' '-' "${${OLDPWD:-none}/#$HOME/~}"
}

# Dispatch a digit: 1-9 jump to ranked dirs 1-9 (cd - is the separate `-` alias).
_gtty_dirjump_go() {
  local n="$1" dir
  case "$n" in
    0) _gtty_dirjump_list ;;
    *) dir="$(_gtty_dirjump_path "$n")"
       if [[ -n "$dir" && -d "$dir" ]]; then
         cd -- "$dir"
       elif [[ -n "$dir" ]]; then
         print -u2 "dirjump: rank $n directory no longer exists: $dir"
         return 1
       else
         print -u2 "dirjump: nothing ranked at position $n yet (try 0)"
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
