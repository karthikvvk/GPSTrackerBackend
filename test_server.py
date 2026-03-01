import requests
import json
import datetime

URL = "http://127.0.0.1:5000/send"

# Test data simulating the app
payload = {
    "userid": "test_user_123",
    "coords": [
        {
            "x_cord": 12.9716,
            "y_cord": 80.2746
        }
    ]
}

try:
    print(f"Sending to {URL}...")
    response = requests.post(URL, json=payload)
    print(f"Status: {response.status_code}")
    print(f"Response: {response.text}")
    print("\nIf successful, check the MongoDB database for a new collection with today's date.")
except Exception as e:
    print(f"Failed: {e}")
