from flask import Flask, request, jsonify
from flask_pymongo import PyMongo
from datetime import datetime, timezone
from pymongo import MongoClient
from flask_cors import CORS
import queue
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



# Shared state
track_active = False  # global flag
sync_queue = queue.Queue()

def get_today_collection():
    return datetime.now(timezone.utc).strftime("%Y_%m_%d")

def is_date_collection(name):
    """Check if collection name is in YYYY_MM_DD format"""
    return bool(re.match(r'^\d{4}_\d{2}_\d{2}$', name))

# =============================================================================
# Auth Endpoints
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
# GPS Tracking Endpoints (updated to use userid instead of firebaseid)
# =============================================================================

@app.route('/send', methods=['POST'])
def send_data():
    data = request.get_json()
    if not data or "userid" not in data or "coords" not in data or not isinstance(data["coords"], list):
        return jsonify({"status": "error", "message": "Invalid payload"}), 400
    userid = data["userid"]
    coords = data["coords"]

    collection_name = datetime.now(timezone.utc).strftime("%Y_%m_%d")
    collection = mongo_db[collection_name]

    valid_coords = []
    for coord in coords:
        if 'x_cord' in coord and 'y_cord' in coord:
            coord_doc = {
                "userid": userid,
                "x_cord": coord["x_cord"],
                "y_cord": coord["y_cord"],
                "logged_time": datetime.now(timezone.utc)
            }
            valid_coords.append(coord_doc)

            # Still add to sync queue ONLY if tracking is on
            if track_active:
                sync_queue.put(coord_doc)

    if valid_coords:
        collection.insert_many(valid_coords)


    return jsonify({
        "status": "success",
        "inserted": len(valid_coords),
        "track_active": track_active
    })

@app.route('/sync', methods=['POST'])
def sync_resume():
    data = request.get_json()
    if not data or 'last_synced_timestamp' not in data:
        return jsonify({"status": "error", "message": "Missing 'last_synced_timestamp'"}), 400

    try:
        # Handle 'Z' (Zulu/UTC) and convert to aware datetime
        last_ts = datetime.fromisoformat(data['last_synced_timestamp'].replace("Z", "+00:00"))
        userid = data["userid"]

    except Exception as e:
        return jsonify({"status": "error", "message": "Invalid timestamp format"}), 400



    date_docs = list(mongo_db.list_collection_names())
    date_docs.sort()

    # Include today as well
    today_str = get_today_collection()
    if today_str not in date_docs:
        date_docs.append(today_str)

    sync_data = []
    found = False

    for date_str in date_docs:
        collection = mongo_db[date_str]

        # force collection create
        if collection.estimated_document_count() == 0:
            collection.insert_one({
                "x_cord": 0,
                "y_cord": 0,
                "logged_time": datetime.now(timezone.utc),
                "dummy": True,
                "userid": "userid",
            })

        if not found:
            # Search for the timestamp
            match = collection.find_one({"userid": userid,"logged_time": {"$gte": last_ts}}, sort=[("logged_time", 1)])
            if match:
                found = True
                # Now get all data from this timestamp onwards
                cursor = collection.find({"userid": userid,"logged_time": {"$gte": last_ts}}, {"_id": 0})
                sync_data.extend(list(cursor))
        else:
            # Already found; get all data from the next collections
            cursor = collection.find({"userid": userid}, {"_id": 0})
            sync_data.extend(list(cursor))

        collection.delete_many({"dummy": True})


    return jsonify({"status": "success", "synced_data": sync_data})

@app.route('/viewtoday', methods=['GET'])
def view_today():
    userid = request.args.get("userid")
    if not userid:
        return jsonify({"status": "error", "message": "Missing userid"}), 400
    collection_name = get_today_collection()
    collection = mongo_db[collection_name]
    coords = list(collection.find({"userid": userid}, {'_id': 0}))
    return jsonify(coords)

@app.route('/sync_all', methods=['GET'])
def sync_all():
    userid = request.args.get("userid")
    if not userid:
        return jsonify({"status": "error", "message": "Missing userid"}), 400

    try:
        # Get all collections that look like dates
        all_collections = mongo_db.list_collection_names()
        date_docs = [c for c in all_collections if is_date_collection(c)]
        date_docs.sort()

        # Also include today's collection if not in history (and matches format)
        today_str = get_today_collection()
        if today_str not in date_docs and is_date_collection(today_str):
            date_docs.append(today_str)

        full_sync_data = []

        for date_str in date_docs:
            collection = mongo_db[date_str]
            # CRITICAL FIX: Filter by userid to avoid leaking other users' data
            cursor = collection.find({"userid": userid}, {"_id": 0})
            full_sync_data.extend(list(cursor))

        return jsonify({"status": "success", "synced_data": full_sync_data})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/history', methods=['GET'])
def history_dates():
    userid = request.args.get("userid")
    if not userid:
        return jsonify({"status": "error", "message": "Missing userid"}), 400

    # Only look at collections that match YYYY_MM_DD
    all_collections = mongo_db.list_collection_names()
    date_collections = [c for c in all_collections if is_date_collection(c)]
    
    user_dates = [
        date_str for date_str in date_collections
        if mongo_db[date_str].count_documents({"userid": userid}) > 0
    ]
    return jsonify({"available_dates": sorted(user_dates)})

@app.route('/history/view', methods=['GET'])
def view_history():
    userid = request.args.get("userid")
    date_str = request.args.get("date")
    
    if not userid:
        return jsonify({"status": "error", "message": "Missing userid"}), 400
    if not date_str:
        return jsonify({"status": "error", "message": "Missing date"}), 400
        
    if not is_date_collection(date_str):
         return jsonify({"status": "error", "message": "Invalid date format. Use YYYY_MM_DD"}), 400

    collection = mongo_db[date_str]
    # Check if collection exists implicitly by checking if it has data? 
    # Or just query it. MongoDB is forgiving.
    
    coords = list(collection.find({"userid": userid}, {'_id': 0}))
    return jsonify(coords)

@app.route('/serverstatus', methods=['GET'])
def get_server_status():
    return jsonify({"server": True})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
