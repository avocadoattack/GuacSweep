#!/bin/bash
# guac-clean — a lean, transparent macOS maintenance script 🥑
# (placeholder name — will be renamed before publishing)

clear
echo "🥑  guac-clean — keeping your Mac ripe"
echo ""

PS3=$'\nSelection: '

options=(
  "Flush DNS Cache"
  "System Junk (User Caches + Logs)"
  "System Caches (sudo, /Library/Caches)"
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
