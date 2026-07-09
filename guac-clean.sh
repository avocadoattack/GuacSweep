#!/bin/bash
# guac-clean — a lean, transparent macOS maintenance script 🥑
# (placeholder name — will be renamed before publishing)

clear
echo "🥑  guac-clean — keeping your Mac ripe"
echo ""

PS3=$'\nSelection: '

options=(
  "Flush DNS Cache"
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
    "Exit")
      echo "👋  See you next time."
      break
      ;;
    *)
      echo "Invalid option, try again."
      ;;
  esac
done
