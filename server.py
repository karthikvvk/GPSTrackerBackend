from flask import Flask, request, jsonify
from datetime import datetime, timezone
from flask_cors import CORS
from flask_socketio import SocketIO, emit, join_room, leave_room
import os
import json
import sqlite3
import bcrypt
import uuid
import threading
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------
# SETTINGS_PATH = os.path.join(os.path.dirname(__file__), 'settings.json')
# with open(SETTINGS_PATH, 'r') as f:
#     settings = json.load(f)

# DEBUG_MODE = settings.get("debug_mode", False)

# ---------------------------------------------------------------------------
# Server-side SQLite  (users only — GPS data lives on device SQLite)
# ---------------------------------------------------------------------------
DB_PATH = os.path.join(os.path.dirname(__file__), 'users.db')
_db_lock = threading.Lock()


def get_db():
    """Return a thread-local SQLite connection."""
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    """Create the users table if it doesn't already exist."""
    with _db_lock:
        conn = get_db()
        conn.execute('''
            CREATE TABLE IF NOT EXISTS users (
                user_id      TEXT PRIMARY KEY,
                email        TEXT UNIQUE NOT NULL,
                password_hash BLOB NOT NULL,
                display_name TEXT NOT NULL,
                role         TEXT,
                created_at   TEXT NOT NULL
            )
        ''')
        conn.commit()
        conn.close()


init_db()

# ---------------------------------------------------------------------------
# Email (Supabase SMTP relay)
# ---------------------------------------------------------------------------
_SMTP_HOST = os.environ.get('SUPABASE_SMTP_HOST')
_SMTP_PORT = int(os.environ.get('SUPABASE_SMTP_PORT', '465'))
_SMTP_USER = os.environ.get('SUPABASE_SMTP_USER')
_SMTP_PASS = os.environ.get('SUPABASE_SMTP_PASS')
_FROM_EMAIL = os.environ.get('SUPABASE_FROM_EMAIL')


def _send_email_sync(to: str, subject: str, html_body: str):
    """Send a transactional email via Supabase SMTP relay (blocking)."""
    if not all([_SMTP_HOST, _SMTP_USER, _SMTP_PASS, _FROM_EMAIL]):
        print('[Email] SMTP not configured — skipping email.')
        return
    try:
        msg = MIMEMultipart('alternative')
        msg['Subject'] = subject
        msg['From'] = _FROM_EMAIL
        msg['To'] = to
        msg.attach(MIMEText(html_body, 'html'))
        with smtplib.SMTP_SSL(_SMTP_HOST, _SMTP_PORT) as server:
            server.login(_SMTP_USER, _SMTP_PASS)
            server.send_message(msg)
        print(f'[Email] Sent "{subject}" → {to}')
    except Exception as e:
        print(f'[Email] Failed to send email: {e}')


def send_email(to: str, subject: str, html_body: str):
    """Fire-and-forget email sending — runs in a background thread."""
    threading.Thread(target=_send_email_sync, args=(to, subject, html_body), daemon=True).start()


# ---------------------------------------------------------------------------
# Flask + SocketIO
# ---------------------------------------------------------------------------
app = Flask(__name__)
CORS(app)
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='eventlet')

# =============================================================================
# Connected clients tracking
# =============================================================================

# Maps userId -> sid (session ID) for online children
connected_children = {}
# Maps sid -> userId for reverse lookup
sid_to_child = {}
# Maps parentSid -> childId for active subscriptions
parent_subscriptions = {}

# =============================================================================
# Auth Endpoints (REST)
# =============================================================================

@app.route('/auth/register', methods=['POST'])
def register():
    """Register a new user with email and password."""
    data = request.get_json()

    if not data or "email" not in data or "password" not in data:
        return jsonify({"status": "error", "message": "Email and password required"}), 400

    email = data["email"].strip().lower()
    password = data["password"]
    display_name = data.get("display_name", email.split("@")[0])
    print(email, password, display_name)

    if "@" not in email or "." not in email:
        return jsonify({"status": "error", "message": "Invalid email format"}), 400

    if len(password) < 6:
        return jsonify({"status": "error", "message": "Password must be at least 6 characters"}), 400

    password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
    user_id = str(uuid.uuid4())
    created_at = datetime.now(timezone.utc).isoformat()

    try:
        with _db_lock:
            conn = get_db()
            conn.execute(
                'INSERT INTO users (user_id, email, password_hash, display_name, role, created_at) '
                'VALUES (?, ?, ?, ?, ?, ?)',
                (user_id, email, password_hash, display_name, None, created_at)
            )
            conn.commit()
            conn.close()
    except sqlite3.IntegrityError:
        return jsonify({"status": "error", "message": "Email already registered"}), 409

    # Send welcome email (non-blocking)
    welcome_html = f'''<html><body style="font-family:sans-serif;background:#f4f4f4;padding:32px">
    <div style="max-width:480px;margin:auto;background:#fff;border-radius:12px;padding:32px">
      <h2 style="color:#6366f1">Welcome to GPS Tracker!</h2>
      <p>Hi <strong>{display_name}</strong>,</p>
      <p>Your account has been created successfully.</p>
      <p style="color:#666;font-size:14px">Email: {email}</p>
      <hr style="border:none;border-top:1px solid #eee;margin:24px 0">
      <p style="color:#999;font-size:12px">If you didn't create this account, please ignore this email.</p>
    </div>
    </body></html>'''
    send_email(email, 'Welcome to GPS Tracker!', welcome_html)

    return jsonify({
        "status": "success",
        "user": {
            "user_id": user_id,
            "email": email,
            "display_name": display_name,
            "role": None
        }
    }), 201


@app.route('/auth/login', methods=['POST'])
def login():
    """Login with email and password."""
    data = request.get_json()

    if not data or "email" not in data or "password" not in data:
        return jsonify({"status": "error", "message": "Email and password required"}), 400

    email = data["email"].strip().lower()
    password = data["password"]

    with _db_lock:
        conn = get_db()
        row = conn.execute('SELECT * FROM users WHERE email = ?', (email,)).fetchone()
        conn.close()

    if not row:
        return jsonify({"status": "error", "message": "Invalid email or password"}), 401

    if not bcrypt.checkpw(password.encode('utf-8'), row["password_hash"]):
        return jsonify({"status": "error", "message": "Invalid email or password"}), 401

    return jsonify({
        "status": "success",
        "user": {
            "user_id": row["user_id"],
            "email": row["email"],
            "display_name": row["display_name"],
            "role": row["role"]
        }
    })


@app.route('/auth/lookup', methods=['GET'])
def lookup_user():
    """Look up a user's public info by email address.
    Used by parents to link a child account via email.
    """
    email = request.args.get('email', '').strip().lower()
    if not email:
        return jsonify({"status": "error", "message": "Missing email"}), 400

    with _db_lock:
        conn = get_db()
        row = conn.execute(
            'SELECT user_id, display_name, email FROM users WHERE email = ?', (email,)
        ).fetchone()
        conn.close()

    if not row:
        return jsonify({"status": "error", "message": "No user found with that email"}), 404

    return jsonify({
        "status": "success",
        "user": {
            "user_id": row["user_id"],
            "display_name": row["display_name"],
            "email": row["email"]
        }
    })


@app.route('/auth/profile', methods=['GET'])
def get_profile():
    """Get user profile by user_id."""
    user_id = request.args.get("user_id")
    if not user_id:
        return jsonify({"status": "error", "message": "Missing user_id"}), 400

    with _db_lock:
        conn = get_db()
        row = conn.execute('SELECT * FROM users WHERE user_id = ?', (user_id,)).fetchone()
        conn.close()

    if not row:
        return jsonify({"status": "error", "message": "User not found"}), 404

    return jsonify({
        "status": "success",
        "user": {
            "user_id": row["user_id"],
            "email": row["email"],
            "display_name": row["display_name"],
            "role": row["role"]
        }
    })


@app.route('/auth/profile', methods=['PUT'])
def update_profile():
    """Update user profile (display_name and/or role)."""
    data = request.get_json()

    if not data or "user_id" not in data:
        return jsonify({"status": "error", "message": "Missing user_id"}), 400

    user_id = data["user_id"]
    fields, values = [], []

    if "display_name" in data:
        fields.append("display_name = ?")
        values.append(data["display_name"])
    if "role" in data:
        fields.append("role = ?")
        values.append(data["role"])

    if not fields:
        return jsonify({"status": "error", "message": "No fields to update"}), 400

    values.append(user_id)
    with _db_lock:
        conn = get_db()
        result = conn.execute(
            f'UPDATE users SET {", ".join(fields)} WHERE user_id = ?', values
        )
        conn.commit()
        row = conn.execute('SELECT * FROM users WHERE user_id = ?', (user_id,)).fetchone()
        conn.close()

    if result.rowcount == 0:
        return jsonify({"status": "error", "message": "User not found"}), 404

    return jsonify({
        "status": "success",
        "user": {
            "user_id": row["user_id"],
            "email": row["email"],
            "display_name": row["display_name"],
            "role": row["role"]
        }
    })


# =============================================================================
# REST - Server & Relay Status
# =============================================================================

@app.route('/serverstatus', methods=['GET'])
def get_server_status():
    return jsonify({"server": True})


@app.route('/relay/status', methods=['GET'])
def relay_status():
    """Check if a child device is online."""
    child_id = request.args.get("childId")
    if not child_id:
        return jsonify({"status": "error", "message": "Missing childId"}), 400

    online = child_id in connected_children
    return jsonify({"status": "success", "childId": child_id, "online": online})


# =============================================================================
# WebSocket Events — Relay/Broker
# =============================================================================

@socketio.on('connect')
def handle_connect():
    print(f'[WS] Client connected: {request.sid}')


@socketio.on('disconnect')
def handle_disconnect():
    sid = request.sid
    print(f'[WS] Client disconnected: {sid}')

    if sid in sid_to_child:
        child_id = sid_to_child.pop(sid)
        connected_children.pop(child_id, None)
        leave_room(f'child_{child_id}')
        print(f'[WS] Child {child_id} went offline')
        socketio.emit('child_offline', {'childId': child_id}, room=f'watch_{child_id}')

    if sid in parent_subscriptions:
        child_id = parent_subscriptions.pop(sid)
        leave_room(f'watch_{child_id}')
        print(f'[WS] Parent {sid} unsubscribed from child {child_id}')


# --- Child Events ---

@socketio.on('child_register')
def handle_child_register(data):
    """Child device registers itself as online.
    data: { "userId": "..." }
    """
    user_id = data.get('userId')
    if not user_id:
        emit('error', {'message': 'Missing userId'})
        return

    sid = request.sid
    connected_children[user_id] = sid
    sid_to_child[sid] = user_id
    join_room(f'child_{user_id}')

    print(f'[WS] Child registered: {user_id} (sid={sid})')
    print(f'[WS] Online children now: {list(connected_children.keys())}')
    emit('registered', {'status': 'ok', 'userId': user_id})
    socketio.emit('child_online', {'childId': user_id}, room=f'watch_{user_id}')


@socketio.on('child_location_update')
def handle_child_location_update(data):
    """Child pushes its latest location. Server relays to subscribed parents."""
    user_id = data.get('userId')
    if not user_id:
        return

    socketio.emit('live_location', {
        'childId': user_id,
        'x_cord': data.get('x_cord'),
        'y_cord': data.get('y_cord'),
        'logged_time': data.get('logged_time'),
    }, room=f'watch_{user_id}', include_self=False)


@socketio.on('child_history_response')
def handle_child_history_response(data):
    """Child responds to a history request from a parent."""
    parent_sid = data.get('parentSid')
    if not parent_sid:
        return
    socketio.emit('history_data', {
        'requestId': data.get('requestId'),
        'date': data.get('date'),
        'coords': data.get('coords', []),
    }, room=parent_sid)


@socketio.on('child_dates_response')
def handle_child_dates_response(data):
    """Child responds with available dates for history."""
    parent_sid = data.get('parentSid')
    if not parent_sid:
        return
    socketio.emit('history_dates', {
        'requestId': data.get('requestId'),
        'dates': data.get('dates', []),
    }, room=parent_sid)


# --- Parent Events ---

@socketio.on('parent_subscribe')
def handle_parent_subscribe(data):
    """Parent subscribes to a child's live location stream.
    data: { "childId": "..." }
    """
    child_id = data.get('childId')
    if not child_id:
        emit('error', {'message': 'Missing childId'})
        return

    sid = request.sid
    if sid in parent_subscriptions:
        old_child = parent_subscriptions[sid]
        leave_room(f'watch_{old_child}')

    parent_subscriptions[sid] = child_id
    join_room(f'watch_{child_id}')

    online = child_id in connected_children
    print(f'[WS] Parent {sid} subscribed to child {child_id} (online={online})')
    print(f'[WS] Online children: {list(connected_children.keys())}')
    if not online:
        print(f'[WS] WARNING: child {child_id!r} is NOT in connected_children')

    emit('subscribed', {'childId': child_id, 'online': online})


@socketio.on('parent_request_history')
def handle_parent_request_history(data):
    """Parent requests historical data for a specific date from a child."""
    child_id = data.get('childId')
    date = data.get('date')
    request_id = data.get('requestId', str(uuid.uuid4()))

    if not child_id or not date:
        emit('error', {'message': 'Missing childId or date'})
        return

    if child_id not in connected_children:
        emit('history_data', {'requestId': request_id, 'date': date, 'coords': [], 'error': 'child_offline'})
        return

    child_sid = connected_children[child_id]
    socketio.emit('history_request', {
        'requestId': request_id,
        'date': date,
        'parentSid': request.sid,
    }, room=child_sid)


@socketio.on('parent_request_dates')
def handle_parent_request_dates(data):
    """Parent requests available history dates from a child."""
    child_id = data.get('childId')
    request_id = data.get('requestId', str(uuid.uuid4()))

    if not child_id:
        emit('error', {'message': 'Missing childId'})
        return

    if child_id not in connected_children:
        emit('history_dates', {'requestId': request_id, 'dates': [], 'error': 'child_offline'})
        return

    child_sid = connected_children[child_id]
    socketio.emit('dates_request', {
        'requestId': request_id,
        'parentSid': request.sid,
    }, room=child_sid)


@socketio.on('parent_request_sync')
def handle_parent_request_sync(data):
    """Parent requests a historical DB sync from the child.
    data: { "childId": "...", "fromTimestamp": "..." | null }
    """
    child_id = data.get('childId')
    from_timestamp = data.get('fromTimestamp')

    if not child_id:
        emit('error', {'message': 'Missing childId'})
        return

    if child_id not in connected_children:
        emit('sync_batch', {'coords': [], 'done': True, 'error': 'child_offline'})
        return

    child_sid = connected_children[child_id]
    print(f'[WS] Parent {request.sid} requested sync from child {child_id} (from={from_timestamp})')
    socketio.emit('sync_request', {
        'parentSid': request.sid,
        'fromTimestamp': from_timestamp,
    }, room=child_sid)


@socketio.on('child_sync_batch')
def handle_child_sync_batch(data):
    """Child sends a batch of historical coordinate records to a specific parent.
    data: { "parentSid": "...", "coords": [...], "done": bool }
    """
    parent_sid = data.get('parentSid')
    if not parent_sid:
        return

    coords = data.get('coords', [])
    done = data.get('done', False)
    print(f'[WS] Sync batch → parent {parent_sid}: {len(coords)} records, done={done}')
    socketio.emit('sync_batch', {'coords': coords, 'done': done}, room=parent_sid)


@socketio.on('parent_unsubscribe')
def handle_parent_unsubscribe(data):
    """Parent unsubscribes from a child's live feed."""
    sid = request.sid
    if sid in parent_subscriptions:
        child_id = parent_subscriptions.pop(sid)
        leave_room(f'watch_{child_id}')
        emit('unsubscribed', {'childId': child_id})


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    print(port)
    socketio.run(app, host='0.0.0.0', port=port)