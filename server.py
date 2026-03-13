from flask import Flask, request, jsonify
from flask_pymongo import PyMongo
from datetime import datetime, timezone
from pymongo import MongoClient
from flask_cors import CORS
from flask_socketio import SocketIO, emit, join_room, leave_room
import os
import json
from pymongo.server_api import ServerApi
import dns.resolver
import bcrypt
import uuid
import re

# Load settings from settings.json
SETTINGS_PATH = os.path.join(os.path.dirname(__file__), 'settings.json')
with open(SETTINGS_PATH, 'r') as f:
    settings = json.load(f)

dns.resolver.default_resolver = dns.resolver.Resolver(configure=False)
dns.resolver.default_resolver.nameservers = ['8.8.8.8']  # Use Google DNS

MONGO_URI = settings.get("mongo_uri")
DB_NAME = settings.get("db_name", "GPSTracker")
DEBUG_MODE = settings.get("debug_mode", False)

client = MongoClient(MONGO_URI, server_api=ServerApi('1'))
mongo_db = client[DB_NAME]

# Users collection
users_collection = mongo_db["ourusers"]

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


def is_date_collection(name):
    """Check if collection name is in YYYY_MM_DD format"""
    return bool(re.match(r'^\d{4}_\d{2}_\d{2}$', name))


# =============================================================================
# Auth Endpoints (REST - unchanged)
# =============================================================================

@app.route('/auth/register', methods=['POST'])
def register():
    """Register a new user with email and password"""
    data = request.get_json()
    
    if not data or "email" not in data or "password" not in data:
        return jsonify({"status": "error", "message": "Email and password required"}), 400
    
    email = data["email"].strip().lower()
    password = data["password"]
    display_name = data.get("display_name", email.split("@")[0])
    
    # Validate email format (basic check)
    if "@" not in email or "." not in email:
        return jsonify({"status": "error", "message": "Invalid email format"}), 400
    
    # Check password length
    if len(password) < 6:
        return jsonify({"status": "error", "message": "Password must be at least 6 characters"}), 400
    
    # Check if email already exists
    existing_user = users_collection.find_one({"email": email})
    if existing_user:
        return jsonify({"status": "error", "message": "Email already registered"}), 409
    
    # Hash password
    password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
    
    # Generate user ID
    user_id = str(uuid.uuid4())
    
    # Create user document
    user_doc = {
        "user_id": user_id,
        "email": email,
        "password_hash": password_hash,
        "display_name": display_name,
        "role": None,  # To be set later
        "created_at": datetime.now(timezone.utc)
    }
    
    users_collection.insert_one(user_doc)
    
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
    """Login with email and password"""
    data = request.get_json()
    
    if not data or "email" not in data or "password" not in data:
        return jsonify({"status": "error", "message": "Email and password required"}), 400
    
    email = data["email"].strip().lower()
    password = data["password"]
    
    # Find user
    user = users_collection.find_one({"email": email})
    if not user:
        return jsonify({"status": "error", "message": "Invalid email or password"}), 401
    
    # Verify password
    if not bcrypt.checkpw(password.encode('utf-8'), user["password_hash"]):
        return jsonify({"status": "error", "message": "Invalid email or password"}), 401
    
    return jsonify({
        "status": "success",
        "user": {
            "user_id": user["user_id"],
            "email": user["email"],
            "display_name": user["display_name"],
            "role": user.get("role")
        }
    })


@app.route('/auth/profile', methods=['GET'])
def get_profile():
    """Get user profile by user_id"""
    user_id = request.args.get("user_id")
    if not user_id:
        return jsonify({"status": "error", "message": "Missing user_id"}), 400
    
    user = users_collection.find_one({"user_id": user_id})
    if not user:
        return jsonify({"status": "error", "message": "User not found"}), 404
    
    return jsonify({
        "status": "success",
        "user": {
            "user_id": user["user_id"],
            "email": user["email"],
            "display_name": user["display_name"],
            "role": user.get("role")
        }
    })


@app.route('/auth/profile', methods=['PUT'])
def update_profile():
    """Update user profile"""
    data = request.get_json()
    
    if not data or "user_id" not in data:
        return jsonify({"status": "error", "message": "Missing user_id"}), 400
    
    user_id = data["user_id"]
    
    # Build update document
    update_doc = {}
    if "display_name" in data:
        update_doc["display_name"] = data["display_name"]
    if "role" in data:
        update_doc["role"] = data["role"]
    
    if not update_doc:
        return jsonify({"status": "error", "message": "No fields to update"}), 400
    
    result = users_collection.update_one(
        {"user_id": user_id},
        {"$set": update_doc}
    )
    
    if result.matched_count == 0:
        return jsonify({"status": "error", "message": "User not found"}), 404
    
    # Return updated user
    user = users_collection.find_one({"user_id": user_id})
    return jsonify({
        "status": "success",
        "user": {
            "user_id": user["user_id"],
            "email": user["email"],
            "display_name": user["display_name"],
            "role": user.get("role")
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
    """Check if a child device is online"""
    child_id = request.args.get("childId")
    if not child_id:
        return jsonify({"status": "error", "message": "Missing childId"}), 400
    
    online = child_id in connected_children
    return jsonify({
        "status": "success",
        "childId": child_id,
        "online": online
    })


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
    
    # If this was a child, remove from connected list
    if sid in sid_to_child:
        child_id = sid_to_child.pop(sid)
        connected_children.pop(child_id, None)
        leave_room(f'child_{child_id}')
        print(f'[WS] Child {child_id} went offline')
        
        # Notify any subscribed parents that child went offline
        socketio.emit('child_offline', {'childId': child_id}, room=f'watch_{child_id}')
    
    # If this was a parent with an active subscription, clean up
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
    
    # Notify any parents already watching this child that it came online
    socketio.emit('child_online', {'childId': user_id}, room=f'watch_{user_id}')


@socketio.on('child_location_update')
def handle_child_location_update(data):
    """Child pushes its latest location. Server relays to subscribed parents.
    
    data: { "userId": "...", "x_cord": ..., "y_cord": ..., "logged_time": "..." }
    """
    user_id = data.get('userId')
    if not user_id:
        return
    
    # Relay to all parents watching this child (room: watch_{childId})
    socketio.emit('live_location', {
        'childId': user_id,
        'x_cord': data.get('x_cord'),
        'y_cord': data.get('y_cord'),
        'logged_time': data.get('logged_time'),
    }, room=f'watch_{user_id}', include_self=False)


@socketio.on('child_history_response')
def handle_child_history_response(data):
    """Child responds to a history request from a parent.
    
    data: { "requestId": "...", "parentSid": "...", "coords": [...], "date": "..." }
    """
    parent_sid = data.get('parentSid')
    if not parent_sid:
        return
    
    # Send the history data directly to the requesting parent
    socketio.emit('history_data', {
        'requestId': data.get('requestId'),
        'date': data.get('date'),
        'coords': data.get('coords', []),
    }, room=parent_sid)


@socketio.on('child_dates_response')
def handle_child_dates_response(data):
    """Child responds with available dates for history.
    
    data: { "requestId": "...", "parentSid": "...", "dates": [...] }
    """
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
    
    # Unsubscribe from previous child if any
    if sid in parent_subscriptions:
        old_child = parent_subscriptions[sid]
        leave_room(f'watch_{old_child}')
    
    parent_subscriptions[sid] = child_id
    join_room(f'watch_{child_id}')
    
    online = child_id in connected_children
    print(f'[WS] Parent {sid} subscribed to child {child_id} (online={online})')
    print(f'[WS] Online children: {list(connected_children.keys())}')
    if not online:
        print(f'[WS] WARNING: child {child_id!r} is NOT in connected_children — check that the child sent child_register with this exact ID')
    
    emit('subscribed', {
        'childId': child_id,
        'online': online,
    })


@socketio.on('parent_request_history')
def handle_parent_request_history(data):
    """Parent requests historical data for a specific date from a child.
    
    data: { "childId": "...", "date": "YYYY-MM-DD", "requestId": "..." }
    """
    child_id = data.get('childId')
    date = data.get('date')
    request_id = data.get('requestId', str(uuid.uuid4()))
    
    if not child_id or not date:
        emit('error', {'message': 'Missing childId or date'})
        return
    
    if child_id not in connected_children:
        emit('history_data', {
            'requestId': request_id,
            'date': date,
            'coords': [],
            'error': 'child_offline',
        })
        return
    
    # Forward request to the child
    child_sid = connected_children[child_id]
    socketio.emit('history_request', {
        'requestId': request_id,
        'date': date,
        'parentSid': request.sid,
    }, room=child_sid)


@socketio.on('parent_request_dates')
def handle_parent_request_dates(data):
    """Parent requests available history dates from a child.
    
    data: { "childId": "...", "requestId": "..." }
    """
    child_id = data.get('childId')
    request_id = data.get('requestId', str(uuid.uuid4()))
    
    if not child_id:
        emit('error', {'message': 'Missing childId'})
        return
    
    if child_id not in connected_children:
        emit('history_dates', {
            'requestId': request_id,
            'dates': [],
            'error': 'child_offline',
        })
        return
    
    # Forward request to the child
    child_sid = connected_children[child_id]
    socketio.emit('dates_request', {
        'requestId': request_id,
        'parentSid': request.sid,
    }, room=child_sid)


@socketio.on('parent_unsubscribe')
def handle_parent_unsubscribe(data):
    """Parent unsubscribes from a child's live feed."""
    sid = request.sid
    if sid in parent_subscriptions:
        child_id = parent_subscriptions.pop(sid)
        leave_room(f'watch_{child_id}')
        emit('unsubscribed', {'childId': child_id})


if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=5000)
