#!/bin/bash
set -euo pipefail

DEST="azblob:tower-backups"
STAGE=/mnt/user/backups/azure-staging
LOG=/mnt/user/backups/azure-backup.log
NOTIFY=/usr/local/emhttp/webGui/scripts/notify
OPTS=(--azureblob-no-check-container --azureblob-access-tier cool --log-file="$LOG" --log-level INFO)

on_fail() { "$NOTIFY" -e "Azure backup" -s "Azure backup FAILED" -d "See $LOG" -i alert; }
trap on_fail ERR

mkdir -p "$STAGE"
echo "$(date) start" >> "$LOG"

# 1. Audiobooks: incremental, no deletions propagated
rclone copy "/mnt/user/unraiddata/Media/Audio Books" "$DEST/audiobooks" "${OPTS[@]}"

# 2. Appdata backups: only new files upload
rclone copy "/mnt/user/unraiddata/Backup" "$DEST/appdata" --include "/ab_*/**" "${OPTS[@]}"

# 3. Calibre: monthly tar snapshot (runs only on the first Sunday of the month)
if [ "$(date +%d)" -le 7 ]; then
  out="$STAGE/calibre-$(date +%F).tar"
  tar -C /mnt/user/unraiddata/Media -cf "$out" calibreLibrary
  rclone copy "$out" "$DEST/calibre" "${OPTS[@]}"
  rm -f "$out"
fi

echo "$(date) done" >> "$LOG"
"$NOTIFY" -e "Azure backup" -s "Azure backup OK" -d "Completed $(date +%F)" -i normal