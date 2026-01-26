from pymongo import MongoClient
import json
from datetime import datetime

# Connect to local MongoDB
client = MongoClient("mongodb://localhost:27017/")
db = client["GPSTracker"] 

def json_serial(obj):
    """JSON serializer for objects not serializable by default json code"""
    if isinstance(obj, datetime):
        return obj.isoformat()
    return str(obj)

print(f"Database: {db.name}")
print("=" * 30)

collections = db.list_collection_names()
if not collections:
    print("No collections found.")
else:
    for col_name in sorted(collections):
        print(f"\nCollection: {col_name}")
        print("-" * 30)
        col = db[col_name]
        docs = list(col.find())
        if not docs:
            print("  (Empty)")
        else:
            for doc in docs:
                # Remove _id for cleaner output if desired, or keep it
                doc['_id'] = str(doc['_id']) 
                print(json.dumps(doc, default=json_serial, indent=2))
        print("-" * 30)
