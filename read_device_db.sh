#!/bin/bash
# Pulls the gpstracker SQLite DB from an Android device and dumps its contents.
# Usage: ./read_device_db.sh [device_serial]
#   e.g. ./read_device_db.sh RZ8T71HKV7K   (child)
#        ./read_device_db.sh b07f9b42       (parent)
#        ./read_device_db.sh                (first connected device)

SERIAL=${1:-""}
ADB_ARGS=""
if [ -n "$SERIAL" ]; then
  ADB_ARGS="-s $SERIAL"
fi

PKG="com.example.gpstracking"
DB_PATH="/data/data/$PKG/databases/gpstracker.db"
LOCAL_COPY="/tmp/gpstracker_${SERIAL:-device}.db"

echo "=== Pulling DB from device ${SERIAL:-'(default)'} ==="
adb $ADB_ARGS shell "run-as $PKG cat $DB_PATH" > "$LOCAL_COPY" 2>/dev/null

if [ $? -ne 0 ]; then
  echo "ERROR: Could not pull DB. Make sure:"
  echo "  1. Device is connected and developer options enabled"
  echo "  2. App is a debug build (run-as requires debuggable=true)"
  echo "  3. Package name is: $PKG"
  exit 1
fi

echo "DB saved to: $LOCAL_COPY"
echo ""

# Check sqlite3 is available
if ! command -v sqlite3 &>/dev/null; then
  echo "sqlite3 not found — install with: sudo pacman -S sqlite (or apt install sqlite3)"
  exit 1
fi

echo "=== TABLE: coordinate_logs ==="
sqlite3 "$LOCAL_COPY" "SELECT COUNT(*) || ' total records' FROM coordinate_logs;"
sqlite3 "$LOCAL_COPY" "SELECT MIN(logged_time), MAX(logged_time) FROM coordinate_logs;"
echo ""
echo "--- Last 10 records ---"
sqlite3 -column -header "$LOCAL_COPY" \
  "SELECT id, user_id, x_cord, y_cord, logged_time, sim_date, synced FROM coordinate_logs ORDER BY logged_time DESC LIMIT 10;"

echo ""
echo "=== TABLE: backup_logs ==="
sqlite3 "$LOCAL_COPY" "SELECT COUNT(*) || ' total backup records' FROM backup_logs;"
echo ""
echo "--- Last 5 backup records ---"
sqlite3 -column -header "$LOCAL_COPY" \
  "SELECT id, user_id, x_cord, y_cord, logged_time, sim_date FROM backup_logs ORDER BY logged_time DESC LIMIT 5;"

echo ""
echo "=== DISTINCT dates with data ==="
sqlite3 "$LOCAL_COPY" "SELECT sim_date, COUNT(*) as count FROM coordinate_logs GROUP BY sim_date ORDER BY sim_date;"
