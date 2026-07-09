#!/bin/bash
# guac-clean — a lean, transparent macOS maintenance script 🥑
# (placeholder name — will be renamed before publishing)

clear
echo "🥑  guac-clean — keeping your Mac ripe"
echo ""

# Best-effort, cosmetic-only guess at a human-readable name from a bundle ID.
# Not authoritative — always shown alongside the raw bundle ID, never used for matching logic.
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

PS3=$'\nSelection: '

options=(
  "Flush DNS Cache"
  "System Junk (User Caches + Logs)"
  "System Caches (sudo, /Library/Caches)"
  "Recent Items"
  "Snapshot Thinning (Time Machine)"
  "Leftover Sweep (orphaned app data)"
  "──────── ⚠️  destructive below ────────"
  "🔥 Empty Trash (Permanent Delete)"
  "Exit"
)

select opt in "${options[@]}"
do
  case $opt in
    "Flush DNS Cache")
      echo "🧹  Flushing DNS cache..."
      sudo dscacheutil -flushcache
      sudo killall -HUP mDNSResponder
      echo "✅  DNS cache flushed."
      ;;
    "System Junk (User Caches + Logs)")
      echo "🧹  This clears your account's app caches (~/Library/Caches) and logs (~/Library/Logs)."
      echo "    These are temp files apps create over time — not your files or settings."
      echo "    Nothing is deleted directly — everything moves to a dated folder inside Trash first."
      read -p "Continue? [y/N] " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        batch="$HOME/.Trash/guac-clean-system-junk-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$batch/Caches" "$batch/Logs"
        shopt -s nullglob dotglob
        cache_items=("$HOME"/Library/Caches/*)
        log_items=("$HOME"/Library/Logs/*)
        shopt -u nullglob dotglob
        if [ ${#cache_items[@]} -gt 0 ]; then
          mv "${cache_items[@]}" "$batch/Caches/" 2>/dev/null
        fi
        if [ ${#log_items[@]} -gt 0 ]; then
          mv "${log_items[@]}" "$batch/Logs/" 2>/dev/null
        fi
        echo "✅  Moved ${#cache_items[@]} cache item(s) and ${#log_items[@]} log item(s) to Trash:"
        echo "    $batch"
        echo "    Review or restore anytime before running Empty Trash."
      else
        echo "❎  Skipped — nothing touched."
      fi
      ;;
    "System Caches (sudo, /Library/Caches)")
      echo "🧹  This clears /Library/Caches — the shared cache folder used by system-level"
      echo "    processes and potentially other accounts on this Mac, not just yours."
      echo "    Requires sudo, since these files are owned by root."
      echo "    Same Trash-first policy applies — nothing is deleted directly."
      read -p "Continue? [y/N] " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        batch="$HOME/.Trash/guac-clean-system-caches-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$batch"
        shopt -s nullglob dotglob
        sys_cache_items=(/Library/Caches/*)
        shopt -u nullglob dotglob
        if [ ${#sys_cache_items[@]} -gt 0 ]; then
          sudo mv "${sys_cache_items[@]}" "$batch/" 2>/dev/null
          sudo chown -R "$(whoami)" "$batch"
        fi
        echo "✅  Moved ${#sys_cache_items[@]} item(s) to Trash:"
        echo "    $batch"
        echo "    Review or restore anytime before running Empty Trash."
        echo "    Note: a few items may be skipped if actively in use — that's normal."
      else
        echo "❎  Skipped — nothing touched."
      fi
      ;;
    "Recent Items")
      echo "🧹  This clears your Recent Items lists — Apple menu Recent Documents/Applications/Servers,"
      echo "    and each app's own File > Open Recent menu."
      echo "    These are just shortcuts to files you've opened — not the files themselves."
      echo "    Note: apps already open may not reflect this until you quit and reopen them."
      echo "    Nothing is deleted directly — everything moves to a dated folder inside Trash first."
      read -p "Continue? [y/N] " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        batch="$HOME/.Trash/guac-clean-recent-items-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$batch"
        shopt -s nullglob dotglob
        recent_items=("$HOME/Library/Application Support/com.apple.sharedfilelist"/*)
        shopt -u nullglob dotglob
        if [ ${#recent_items[@]} -gt 0 ]; then
          mv "${recent_items[@]}" "$batch/" 2>/dev/null
        fi
        echo "✅  Moved ${#recent_items[@]} item(s) to Trash:"
        echo "    $batch"
        echo "    Review or restore anytime before running Empty Trash."
      else
        echo "❎  Skipped — nothing touched."
      fi
      ;;
    "Snapshot Thinning (Time Machine)")
      echo "🧹  This removes local Time Machine snapshots — on-disk checkpoints macOS keeps"
      echo "    for offline 'Browse in Time' access, not your actual backups."
      echo "    Your real backup destination (external/network drive) is untouched."
      echo "    Local snapshots regenerate automatically — this just reclaims space now."
      echo "    Requires sudo."
      read -p "Continue? [y/N] " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        snapshots=$(tmutil listlocalsnapshots / 2>/dev/null | grep '^com\.apple\.TimeMachine\.' | sed -E 's/^com\.apple\.TimeMachine\.//; s/\.local.*$//')
        if [ -z "$snapshots" ]; then
          echo "ℹ️  No local snapshots found — nothing to thin."
        else
          success=0
          failed=0
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
            echo "⚠️  $failed snapshot(s) could not be removed — this can happen with in-use or protected snapshots."
          fi
        fi
      else
        echo "❎  Skipped — nothing touched."
      fi
      ;;
    "Leftover Sweep (orphaned app data)")
      echo "🔍  This scans ~/Library for data left behind by apps that no longer appear to be installed —"
      echo "    matched by bundle identifier (including sub-components/extensions of installed apps,"
      echo "    case-insensitively) against everything currently in /Applications, /Applications/Setapp,"
      echo "    and ~/Applications."
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
          echo "── Full raw list (for reference) ──────────────────────────"
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
          echo "── Found data for ${#unique_ids[@]} app(s) ─────────────────────────"
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
          echo "Enter numbers to move to Trash — e.g. 1,3,5-8 — or 'all', or 'none' to cancel:"
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
            echo "❎  Nothing selected — no changes made."
          else
            batch="$HOME/.Trash/guac-clean-leftover-sweep-$(date +%Y%m%d-%H%M%S)"
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
            echo "✅  Moved $moved_total item(s) to Trash:"
            echo "    $batch"
            echo "    Review or restore anytime before running Empty Trash."
          fi
        fi
      else
        echo "❎  Skipped — no scan performed."
      fi
      ;;
    "──────── ⚠️  destructive below ────────")
      echo "(that's just a divider — pick a real option)"
      ;;
    "🔥 Empty Trash (Permanent Delete)")
      echo "🔥  This is different from everything else in this script."
      echo "    Every other cleanup action moves files to Trash first, so you can recover them."
      echo "    This action permanently empties Trash — including any external drives' Trash."
      echo "    Nothing removed here can be undone."
      read -p "Type EMPTY to confirm: " confirm
      if [[ "$confirm" == "EMPTY" ]]; then
        echo "🔥  Emptying Trash..."
        rm -rf ~/.Trash/*
        for vol_trash in /Volumes/*/.Trashes; do
          if [ -d "$vol_trash" ]; then
            sudo rm -rf "$vol_trash"/*
          fi
        done
        echo "✅  Trash emptied."
      else
        echo "❎  Cancelled — Trash left untouched."
      fi
      ;;
    "Exit")
      echo "👋  See you next time."
      break
      ;;
    *)
      echo "Invalid option, try again."
      ;;
  esac
done
