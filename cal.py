import json

def sz(obj) -> int:
    """Byte size of a JSON-serialised dict or a raw string."""
    if isinstance(obj, dict):
        return len(json.dumps(obj, separators=(',', ':')).encode('utf-8'))
    return len(str(obj).encode('utf-8'))

sample_uuid    = "6d258f79-183a-47e1-82b0-f0d6bc1cd2d1"  # 36 chars
sample_lat     = 12.9744
sample_lon     = 80.1867
sample_iso     = "2026-06-13T11:15:23.123456Z"            # 27 chars
sample_epoch   = 1749813323123                             # 13 digits

# --- child → server (child_location_update) ---
old_up = {'userId': sample_uuid, 'x_cord': sample_lat, 'y_cord': sample_lon,
          'logged_time': sample_iso}
new_up = {'userId': sample_uuid, 'x_cord': sample_lat, 'y_cord': sample_lon,
          'ts': sample_epoch}

# --- server → parent (live_location) ---
old_dn = {'childId': sample_uuid, 'x_cord': sample_lat, 'y_cord': sample_lon,
          'logged_time': sample_iso}
new_dn = {'childId': sample_uuid, 'x_cord': sample_lat, 'y_cord': sample_lon,
          'ts': sample_epoch}

print("=" * 60)
print("LIVE-LOCATION WEBSOCKET PAYLOAD SIZE")
print("=" * 60)

print(f"\nchild_location_update  (child → server)")
print(f"  BEFORE : {json.dumps(old_up, separators=(',',':'))}")
print(f"           {sz(old_up)} bytes")
print(f"  AFTER  : {json.dumps(new_up, separators=(',',':'))}")
print(f"           {sz(new_up)} bytes")
print(f"  Saving : {sz(old_up)-sz(new_up)} bytes  ({(sz(old_up)-sz(new_up))/sz(old_up)*100:.1f}% reduction)")

print(f"\nlive_location           (server → parent)")
print(f"  BEFORE : {json.dumps(old_dn, separators=(',',':'))}")
print(f"           {sz(old_dn)} bytes")
print(f"  AFTER  : {json.dumps(new_dn, separators=(',',':'))}")
print(f"           {sz(new_dn)} bytes")
print(f"  Saving : {sz(old_dn)-sz(new_dn)} bytes  ({(sz(old_dn)-sz(new_dn))/sz(old_dn)*100:.1f}% reduction)")

print()
msgs_per_day = 12 * 60 * 24          # 1 msg / 5 s
mb_before    = sz(old_up) * msgs_per_day / 1_048_576
mb_after     = sz(new_up) * msgs_per_day / 1_048_576
print(f"Daily data (child → server @1/5s):")
print(f"  Before : {mb_before:.2f} MB/day")
print(f"  After  : {mb_after:.2f} MB/day")
print(f"  Saving : {mb_before-mb_after:.2f} MB/day  "
      f"≈ {(mb_before-mb_after)*30:.1f} MB/month")
print()
print("Note: DB still stores ISO strings — epoch ms is wire-format only.")
print("=" * 60)
