from flask import Flask, request, jsonify
from flask_pymongo import PyMongo
from datetime import datetime, timezone
from pymongo import MongoClient
from flask_cors import CORS
import queue
from dotenv import load_dotenv
import os
from urllib.parse import quote_plus
from pymongo.server_api import ServerApi
import dns.resolver



dns.resolver.default_resolver = dns.resolver.Resolver(configure=False)
dns.resolver.default_resolver.nameservers = ['8.8.8.8']  # Use Google DNS

load_dotenv()
MONGO_URI = os.getenv("MONGO_URI")
client = MongoClient(MONGO_URI, server_api=ServerApi('1'))
mongo_db = client["trackerDB"]


app = Flask(__name__)
CORS(app)



# Shared state
track_active = False  # global flag
sync_queue = queue.Queue()

def get_today_collection():
    return datetime.now(timezone.utc).strftime("%Y_%m_%d")

# --- Endpoints ---

@app.route('/send', methods=['POST'])
def send_data():
    data = request.get_json()
    if not data or "firebaseid" not in data or "coords" not in data or not isinstance(data["coords"], list):
        return jsonify({"status": "error", "message": "Invalid payload"}), 400
    firebaseid = data["firebaseid"]
    coords = data["coords"]

    collection_name = datetime.now(timezone.utc).strftime("%Y_%m_%d")
    collection = mongo_db[collection_name]

    valid_coords = []
    for coord in coords:  # Now iterating through data["coords"]
        if 'x_cord' in coord and 'y_cord' in coord:
            coord_doc = {
                "firebaseid": firebaseid,  # Added this line
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
        firebaseid = data["firebaseid"]  # <-- Added this line

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
                "firebaseid": "firebaseid",
            })

        if not found:
            # Search for the timestamp
            match = collection.find_one({"firebaseid": firebaseid,"logged_time": {"$gte": last_ts}}, sort=[("logged_time", 1)])
            if match:
                found = True
                # Now get all data from this timestamp onwards
                cursor = collection.find({"firebaseid": firebaseid,"logged_time": {"$gte": last_ts}}, {"_id": 0})
                sync_data.extend(list(cursor))
        else:
            # Already found; get all data from the next collections
            cursor = collection.find({"firebaseid": firebaseid}, {"_id": 0})
            sync_data.extend(list(cursor))

        collection.delete_many({"dummy": True})


    return jsonify({"status": "success", "synced_data": sync_data})

@app.route('/viewtoday', methods=['GET'])
def view_today():
    firebaseid = request.args.get("firebaseid")
    if not firebaseid:
        return jsonify({"status": "error", "message": "Missing firebaseid"}), 400
    collection_name = get_today_collection()
    collection = mongo_db[collection_name]
    coords = list(collection.find({"firebaseid": firebaseid}, {'_id': 0}))
    return jsonify(coords)

@app.route('/sync_all', methods=['GET'])
def sync_all():
    firebaseid = request.args.get("firebaseid")
    if not firebaseid:
        return jsonify({"status": "error", "message": "Missing firebaseid"}), 400

    try:
        date_docs = list(mongo_db.list_collection_names())
        date_docs.sort()


        # Also include today's collection if not in history
        today_str = get_today_collection()
        if today_str not in date_docs:
            date_docs.append(today_str)

        full_sync_data = []

        for date_str in date_docs:
            collection = mongo_db[date_str]
            cursor = collection.find({}, {"_id": 0})
            full_sync_data.extend(list(cursor))

        return jsonify({"status": "success", "synced_data": full_sync_data})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/history', methods=['GET'])
def history_dates():
    firebaseid = request.args.get("firebaseid")
    if not firebaseid:
        return jsonify({"status": "error", "message": "Missing firebaseid"}), 400

    user_dates = [
        date_str for date_str in mongo_db.list_collection_names()
        if mongo_db[date_str].count_documents({"firebaseid": firebaseid}) > 0  # <-- Added filter
    ]
    return jsonify({"available_dates": sorted(user_dates)})

@app.route('/serverstatus', methods=['GET'])
def get_server_status():
    return jsonify({"server": True})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
