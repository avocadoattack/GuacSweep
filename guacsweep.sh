#!/bin/bash
# GuacSweep: a lean, transparent macOS maintenance script 🥑

if [ -t 1 ]; then
  BOLD=$(tput bold 2>/dev/null)
  ITALIC=$(tput sitm 2>/dev/null)
  RESET=$(tput sgr0 2>/dev/null)
else
  BOLD=""
  ITALIC=""
  RESET=""
fi

# Best-effort, cosmetic-only guess at a human-readable name from a bundle ID.
# Not authoritative: always shown alongside the raw bundle ID, never used for matching logic.
friendly_name() {
  local id="$1"
  IFS='.' read -ra parts <<< "$id"
  local n=${#parts[@]}
  local name
  if [ "$n" -ge 3 ]; then
    name="${parts[2]}"
  elif [ "$n" -ge 2 ]; then
    name="${parts[1]}"
  else
    name="$id"
  fi
  name="${name//-/ }"
  name="${name//_/ }"
  if [ -n "$name" ]; then
    local first="${name:0:1}"
    local rest="${name:1}"
    first="$(echo "$first" | tr '[:lower:]' '[:upper:]')"
    name="${first}${rest}"
  fi
  echo "$name"
}

options=(
  "Delete User Junk Files (Cache + Logs)"
  "Delete System Junk Files (sudo)"
  "Delete Recent Items Lists"
  "Delete Terminal History"
  "Delete Download History"
  "Flush DNS Cache"
  "Time Machine Snapshot Thinning"
  "Leftover Sweep Scan (orphaned app data)"
  "Run Full Sweep (all safe options)"
  "🔥 Empty Trash (Permanent Delete)"
)

print_menu() {
  echo ""
  local i=1
  for o in "${options[@]}"; do
    printf '%s%2d) %s%s\n' "$BOLD" "$i" "$o" "$RESET"
    i=$((i + 1))
  done
  echo ""
  echo "Type E or EXIT to quit."
}

sudo_notice() {
  echo "🔑  macOS will now ask for your password. Press Ctrl+C anytime to cancel."
}

# --- Safe, reusable actions (no confirm prompt inside; callers handle that) ---

do_user_junk() {
  local batch="$HOME/.Trash/guacsweep-user-junk-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$batch/Caches" "$batch/Logs" "$batch/Xcode"
  shopt -s nullglob dotglob
  local cache_items=("$HOME"/Library/Caches/*)
  local log_items=("$HOME"/Library/Logs/*)
  local xcode_items=("$HOME/Library/Developer/Xcode/DerivedData"/*)
  shopt -u nullglob dotglob
  if [ ${#cache_items[@]} -gt 0 ]; then
    mv "${cache_items[@]}" "$batch/Caches/" 2>/dev/null
  fi
  if [ ${#log_items[@]} -gt 0 ]; then
    mv "${log_items[@]}" "$batch/Logs/" 2>/dev/null
  fi
  if [ ${#xcode_items[@]} -gt 0 ]; then
    mv "${xcode_items[@]}" "$batch/Xcode/" 2>/dev/null
  fi
  echo "✅  Moved ${#cache_items[@]} cache item(s), ${#log_items[@]} log item(s), and ${#xcode_items[@]} Xcode DerivedData item(s) to Trash."
  echo "    $batch"
}

do_system_caches() {
  local batch="$HOME/.Trash/guacsweep-system-junk-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$batch"
  shopt -s nullglob dotglob
  local sys_cache_items=(/Library/Caches/*)
  shopt -u nullglob dotglob
  if [ ${#sys_cache_items[@]} -gt 0 ]; then
    sudo mv "${sys_cache_items[@]}" "$batch/" 2>/dev/null
    sudo chown -R "$(whoami)" "$batch"
  fi
  echo "✅  Moved ${#sys_cache_items[@]} item(s) to Trash."
  echo "    $batch"
  echo "    A few items may be skipped if actively in use. That's normal."
}

do_recent_items() {
  local batch="$HOME/.Trash/guacsweep-recent-items-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$batch"
  shopt -s nullglob dotglob
  local recent_items=("$HOME/Library/Application Support/com.apple.sharedfilelist"/*)
  shopt -u nullglob dotglob
  if [ ${#recent_items[@]} -gt 0 ]; then
    mv "${recent_items[@]}" "$batch/" 2>/dev/null
  fi
  echo "✅  Moved ${#recent_items[@]} item(s) to Trash."
  echo "    $batch"
}

do_terminal_history() {
  local batch="$HOME/.Trash/guacsweep-terminal-history-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$batch"
  local moved=0
  for f in "$HOME/.zsh_history" "$HOME/.bash_history"; do
    if [ -f "$f" ]; then
      mv "$f" "$batch/" 2>/dev/null && moved=$((moved + 1))
    fi
  done
  if [ "$moved" -eq 0 ]; then
    echo "ℹ️  No shell history files found. Nothing to clear."
  else
    echo "✅  Moved $moved history file(s) to Trash."
    echo "    $batch"
  fi
}

do_download_history() {
  local qfile="$HOME/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2"
  if [ -e "$qfile" ]; then
    local batch="$HOME/.Trash/guacsweep-download-history-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$batch"
    mv "$qfile" "$batch/" 2>/dev/null
    echo "✅  Moved download history to Trash."
    echo "    $batch"
  else
    echo "ℹ️  No download history file found. Nothing to clear."
  fi
}

do_flush_dns() {
  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder
  echo "✅  DNS cache flushed."
}

do_snapshot_thinning() {
  local snapshots
  snapshots=$(tmutil listlocalsnapshots / 2>/dev/null | grep '^com\.apple\.TimeMachine\.' | sed -E 's/^com\.apple\.TimeMachine\.//; s/\.local.*$//')
  if [ -z "$snapshots" ]; then
    echo "ℹ️  No local snapshots found. Nothing to thin."
  else
    local success=0
    local failed=0
    while IFS= read -r snap; do
      [ -z "$snap" ] && continue
      if sudo tmutil deletelocalsnapshots "$snap" >/dev/null 2>&1; then
        success=$((success + 1))
      else
        failed=$((failed + 1))
      fi
    done <<< "$snapshots"
    echo "✅  Removed $success local snapshot(s)."
    if [ "$failed" -gt 0 ]; then
      echo "⚠️  $failed snapshot(s) could not be removed. This can happen with in-use or protected snapshots."
    fi
  fi
}

# --- Startup banner ---

clear
if command -v figlet >/dev/null 2>&1; then
  figlet_output=$(figlet GuacSweep)
  if command -v lolcat >/dev/null 2>&1; then
    echo "$figlet_output" | lolcat
  else
    echo "$figlet_output"
  fi
  echo ""
  fig_width=$(echo "$figlet_output" | awk '{ print length }' | sort -rn | head -1)
  tagline="Keeping your Mac ripe 🥑"
  tagline_len=${#tagline}
  pad=$(( (fig_width - tagline_len) / 2 ))
  [ "$pad" -lt 0 ] && pad=0
  printf "%${pad}s%s\n" "" "$tagline"
  credit="Mashed by: Mr. Avocado aka avocadoattack (v1.0.0)"
  credit_len=${#credit}
  credit_pad=$(( (fig_width - credit_len) / 2 ))
  [ "$credit_pad" -lt 0 ] && credit_pad=0
  printf "%${credit_pad}s${ITALIC}%s${RESET}\n" "" "$credit"
  echo ""
  echo "+--------------------------------------------------------------+"
  printf '| %-60s |\n' "Nothing here is destructive by default."
  printf '| %-60s |\n' "Every option below moves files to the Trash first, not"
  printf '| %-60s |\n' "permanent deletion, except the one clearly marked below."
  printf '| %-60s |\n' "You'll always get a chance to confirm before anything runs."
  echo "+--------------------------------------------------------------+"
else
  echo "${BOLD}🥑  GuacSweep: Keeping your Mac ripe${RESET}"
  echo "${ITALIC}Mashed by: Mr. Avocado aka avocadoattack (v1.0.0)${RESET}"
  echo ""
  printf '%-22s%s\n' '      ___' ""
  printf '%-22s%s\n' '    /     \' "+--------------------------------------------------------------+"
  printf '%-22s%s\n' '   /  ___  \' "| Nothing here is destructive by default.                      |"
  printf '%-22s%s\n' '  |  /   \  |' "| Every option below moves files to the Trash first, not       |"
  printf '%-22s%s\n' '  |  \___/  |' "| permanent deletion, except the one clearly marked below.     |"
  printf '%-22s%s\n' '   \       /' "| You'll always get a chance to confirm before anything runs.  |"
  printf '%-22s%s\n' '    \_____/' "+--------------------------------------------------------------+"
fi

trap 'echo ""; echo "❎  Cancelled with Ctrl+C. Back to the menu."; continue' SIGINT

while true; do
  print_menu
  read -rp "Selection: " REPLY

  if [ -z "$REPLY" ]; then
    continue
  fi

  reply_lower="$(echo "$REPLY" | tr '[:upper:]' '[:lower:]')"
  if [[ "$reply_lower" == "e" || "$reply_lower" == "exit" ]]; then
    echo ""
    echo "👋  See you next time!"
    break
  fi

  if [[ "$REPLY" =~ ^[0-9]+$ ]] && [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "${#options[@]}" ]; then
    opt="${options[$((REPLY - 1))]}"
  else
    echo "❎  Not a valid option. Type a number 1 through 10, or E to exit."
    continue
  fi

  case "$opt" in
    "Delete User Junk Files (Cache + Logs)")
      echo "🧹  This clears your account's app caches (~/Library/Caches), logs (~/Library/Logs),"
      echo "    and Xcode's DerivedData build cache (~/Library/Developer/Xcode/DerivedData), if present."
      echo "    These are all temporary files that get regenerated automatically, not your personal"
      echo "    files or settings."
      echo "    Same Trash-first policy applies: Trashed items are sent to the Trash, and nothing is deleted directly."
      read -p "Continue? [y/N] " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        do_user_junk
      else
        echo "❎  Skipped, nothing touched."
      fi
      ;;
    "Delete System Junk Files (sudo)")
      echo "🧹  This clears /Library/Caches, the shared cache folder used by system-level processes"
      echo "    and potentially other accounts on this Mac, not just yours."
      echo "    Requires sudo, since these files are owned by root."
      echo "    Same Trash-first policy applies: Trashed items are sent to the Trash, and nothing is deleted directly."
      read -p "Continue? [y/N] " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        sudo_notice
        do_system_caches
      else
        echo "❎  Skipped, nothing touched."
      fi
      ;;
    "Delete Recent Items Lists")
      echo "🧹  This clears your Recent Items lists: Apple menu Recent Documents, Recent Applications,"
      echo "    Recent Servers, plus each app's own File > Open Recent menu."
      echo "    These are just shortcuts to files you've opened, not the files themselves."
      echo "    Apps already open may not reflect this until you quit and reopen them."
      echo "    Same Trash-first policy applies: Trashed items are sent to the Trash, and nothing is deleted directly."
      read -p "Continue? [y/N] " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        do_recent_items
      else
        echo "❎  Skipped, nothing touched."
      fi
      ;;
    "Delete Terminal History")
      echo "🧹  This clears your shell command history (~/.zsh_history and ~/.bash_history)."
      echo "    This is a running log of nearly every command you've typed, and it can be privacy-sensitive"
      echo "    (file paths, hostnames, occasionally a pasted secret)."
      echo "    Your CURRENT open terminal session keeps its own history in memory, separate from the file"
      echo "    on disk. For a fully clean sweep, do this from a window you're about to close, or open a"
      echo "    fresh one afterward."
      echo "    Same Trash-first policy applies: Trashed items are sent to the Trash, and nothing is deleted directly."
      read -p "Continue? [y/N] " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        do_terminal_history
      else
        echo "❎  Skipped, nothing touched."
      fi
      ;;
    "Delete Download History")
      echo "🧹  This clears macOS's download quarantine metadata: the record of what you downloaded,"
      echo "    from where, and when."
      echo "    It does not delete any downloaded files themselves, only that tracking record."
      echo "    Same Trash-first policy applies: Trashed items are sent to the Trash, and nothing is deleted directly."
      read -p "Continue? [y/N] " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        do_download_history
      else
        echo "❎  Skipped, nothing touched."
      fi
      ;;
    "Flush DNS Cache")
      echo "🧹  This flushes your Mac's DNS cache, the temporary record of recently looked-up websites,"
      echo "    so future lookups are fetched fresh."
      echo "    This does not touch any files. It only clears an in-memory cache that rebuilds itself"
      echo "    automatically as you browse."
      echo "    Requires sudo."
      read -p "Continue? [y/N] " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        sudo_notice
        do_flush_dns
      else
        echo "❎  Skipped, nothing touched."
      fi
      ;;
    "Time Machine Snapshot Thinning")
      echo "🧹  This removes local Time Machine snapshots, on-disk checkpoints macOS keeps for offline"
      echo "    'Browse in Time' access. These are not your actual backups."
      echo "    Your real backup destination (external or network drive) is untouched."
      echo "    Local snapshots regenerate automatically, so this just reclaims space now."
      echo "    Requires sudo."
      read -p "Continue? [y/N] " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        sudo_notice
        do_snapshot_thinning
      else
        echo "❎  Skipped, nothing touched."
      fi
      ;;
    "Leftover Sweep Scan (orphaned app data)")
      echo "🔍  This scans ~/Library for data left behind by apps that no longer appear to be installed,"
      echo "    matched by bundle identifier (including sub-components/extensions of installed apps,"
      echo "    case-insensitively) against everything currently in /Applications, /Applications/Setapp,"
      echo "    and ~/Applications."
      echo "    If you choose to move anything, the same Trash-first policy applies: Trashed items are"
      echo "    sent to the Trash, and nothing is deleted directly."
      echo "    Known limitation: app-group containers, shared third-party SDKs (Sparkle, Firebase,"
      echo "    Bugsnag, Keystone), and helpers with non-standard naming can still show up as false"
      echo "    positives. Review the summary carefully before selecting anything to move."
      read -p "Scan now? [y/N] " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "🔍  Indexing installed apps..."
        installed_ids=()
        app_list=$(find /Applications "$HOME/Applications" -maxdepth 2 -iname "*.app" -type d 2>/dev/null)
        while IFS= read -r app; do
          [ -z "$app" ] && continue
          bid=$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null)
          [ -n "$bid" ] && installed_ids+=("$bid")
        done <<< "$app_list"

        installed_ids_lower=()
        for bid in "${installed_ids[@]}"; do
          installed_ids_lower+=("$(echo "$bid" | tr '[:upper:]' '[:lower:]')")
        done
        echo "    Found ${#installed_ids[@]} installed app bundle IDs."

        echo "🔍  Scanning for orphaned data..."
        labels=("Application Support" "Preferences" "Containers" "Saved Application State" "WebKit")
        dirs=(
          "$HOME/Library/Application Support"
          "$HOME/Library/Preferences"
          "$HOME/Library/Containers"
          "$HOME/Library/Saved Application State"
          "$HOME/Library/WebKit"
        )

        orphan_paths=()
        orphan_labels=()
        orphan_ids=()

        for i in "${!dirs[@]}"; do
          dir="${dirs[$i]}"
          label="${labels[$i]}"
          [ -d "$dir" ] || continue
          shopt -s nullglob dotglob
          items=("$dir"/*)
          shopt -u nullglob dotglob
          for item in "${items[@]}"; do
            name=$(basename "$item")
            candidate="${name%.plist}"
            candidate="${candidate%.savedState}"
            [[ "$candidate" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*(\.[A-Za-z0-9_-]+){2,}$ ]] || continue
            [[ "$candidate" == com.apple.* ]] && continue
            [[ "$candidate" == systemgroup.* ]] && continue
            [[ "$candidate" == group.* ]] && continue

            candidate_lower="$(echo "$candidate" | tr '[:upper:]' '[:lower:]')"
            found=0
            for bid_lower in "${installed_ids_lower[@]}"; do
              if [[ "$candidate_lower" == "$bid_lower" || "$candidate_lower" == "$bid_lower".* ]]; then
                found=1
                break
              fi
            done
            if [ "$found" -eq 0 ]; then
              orphan_paths+=("$item")
              orphan_labels+=("$label")
              orphan_ids+=("$candidate")
            fi
          done
        done

        if [ ${#orphan_paths[@]} -eq 0 ]; then
          echo "✅  No orphaned data found."
        else
          echo ""
          echo "-- Full raw list (for reference) --------------------------"
          for i in "${!orphan_paths[@]}"; do
            echo "   [${orphan_labels[$i]}] ${orphan_paths[$i]}"
          done

          # Group by unique bundle ID, no associative arrays (macOS ships bash 3.2 by default)
          unique_ids=()
          unique_counts=()
          for id in "${orphan_ids[@]}"; do
            existing=-1
            for j in "${!unique_ids[@]}"; do
              if [ "${unique_ids[$j]}" == "$id" ]; then
                existing=$j
                break
              fi
            done
            if [ "$existing" -eq -1 ]; then
              unique_ids+=("$id")
              unique_counts+=(1)
            else
              unique_counts[$existing]=$((unique_counts[existing] + 1))
            fi
          done

          echo ""
          echo "-- Found data for ${#unique_ids[@]} app(s) ---------------------------"
          for i in "${!unique_ids[@]}"; do
            fname=$(friendly_name "${unique_ids[$i]}")
            n="${unique_counts[$i]}"
            plural="item"
            [ "$n" -gt 1 ] && plural="items"
            printf "  %2d) %-24s (%d %s)  [%s]\n" "$((i + 1))" "$fname" "$n" "$plural" "${unique_ids[$i]}"
          done

          echo ""
          echo "⚠️  Shared SDKs (Sparkle, Firebase, Bugsnag, Keystone) and helpers with unusual naming"
          echo "    can appear here even though the parent app is installed. When in doubt, leave it out."
          echo ""
          echo "Enter numbers to move to Trash, like 1,3,5-8, or 'all', or 'none' to cancel:"
          read -p "> " selection

          selected_indices=()
          if [[ "$selection" == "all" ]]; then
            for ((k = 1; k <= ${#unique_ids[@]}; k++)); do
              selected_indices+=("$k")
            done
          elif [[ -z "$selection" || "$selection" == "none" ]]; then
            selected_indices=()
          else
            IFS=',' read -ra tokens <<< "$selection"
            for tok in "${tokens[@]}"; do
              tok="$(echo "$tok" | tr -d '[:space:]')"
              [ -z "$tok" ] && continue
              if [[ "$tok" == *-* ]]; then
                start="${tok%-*}"
                end="${tok#*-}"
                if [[ "$start" =~ ^[0-9]+$ && "$end" =~ ^[0-9]+$ ]]; then
                  for ((k = start; k <= end; k++)); do
                    selected_indices+=("$k")
                  done
                fi
              else
                if [[ "$tok" =~ ^[0-9]+$ ]]; then
                  selected_indices+=("$tok")
                fi
              fi
            done
          fi

          if [ ${#selected_indices[@]} -eq 0 ]; then
            echo "❎  Nothing selected, no changes made."
          else
            batch="$HOME/.Trash/guacsweep-leftover-sweep-$(date +%Y%m%d-%H%M%S)"
            moved_total=0
            for sel in "${selected_indices[@]}"; do
              if [ "$sel" -lt 1 ] || [ "$sel" -gt "${#unique_ids[@]}" ]; then
                continue
              fi
              target_id="${unique_ids[$((sel - 1))]}"
              for i in "${!orphan_ids[@]}"; do
                if [ "${orphan_ids[$i]}" == "$target_id" ]; then
                  dest="$batch/${orphan_labels[$i]}"
                  mkdir -p "$dest"
                  mv "${orphan_paths[$i]}" "$dest/" 2>/dev/null && moved_total=$((moved_total + 1))
                fi
              done
            done
            echo "✅  Moved $moved_total item(s) to Trash."
            echo "    $batch"
          fi
        fi
      else
        echo "❎  Skipped, no scan performed."
      fi
      ;;
    "Run Full Sweep (all safe options)")
      echo "🥑  This runs all 7 safe cleanup options in sequence: User Junk, System Junk (sudo),"
      echo "    Recent Items, Terminal History, Download History, Flush DNS, and Time Machine"
      echo "    Snapshot Thinning."
      echo "    Leftover Sweep and Empty Trash are excluded since they need your manual review."
      echo "    Same Trash-first policy applies: Trashed items are sent to the Trash, and nothing is deleted directly."
      echo "    System Junk, Flush DNS, and Snapshot Thinning need sudo, so macOS may prompt for your"
      echo "    password a few times along the way."
      read -p "Run all of these now? [y/N] " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo ""
        echo "▶  1/7  User Junk Files..."
        do_user_junk
        echo ""
        echo "▶  2/7  System Junk Files (sudo)..."
        sudo_notice
        do_system_caches
        echo ""
        echo "▶  3/7  Recent Items..."
        do_recent_items
        echo ""
        echo "▶  4/7  Terminal History..."
        do_terminal_history
        echo ""
        echo "▶  5/7  Download History..."
        do_download_history
        echo ""
        echo "▶  6/7  Flush DNS Cache..."
        sudo_notice
        do_flush_dns
        echo ""
        echo "▶  7/7  Time Machine Snapshot Thinning..."
        sudo_notice
        do_snapshot_thinning
        echo ""
        echo "✅  Full Sweep complete."
      else
        echo "❎  Skipped, nothing touched."
      fi
      ;;
    "🔥 Empty Trash (Permanent Delete)")
      echo "🔥  This is different from everything else in this script."
      echo "    Every other cleanup action moves files to Trash first, so you can recover them."
      echo "    This action permanently empties Trash, including any external drives' Trash."
      echo "    ${BOLD}Nothing removed here can be undone.${RESET}"
      read -p "${BOLD}Type EMPTY to confirm: ${RESET}" confirm
      if [[ "$confirm" == "EMPTY" ]]; then
        echo "🔥  Emptying Trash..."
        rm -rf ~/.Trash/*
        for vol_trash in /Volumes/*/.Trashes; do
          if [ -d "$vol_trash" ]; then
            sudo_notice
            sudo rm -rf "$vol_trash"/*
          fi
        done
        echo "✅  Trash emptied."
      else
        echo "❎  Cancelled, Trash left untouched."
      fi
      ;;
    *)
      echo "❎  Not a valid option. Type a number 1 through 10, or E to exit."
      ;;
  esac
done
