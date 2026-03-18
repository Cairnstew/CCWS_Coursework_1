# ============================================================
# Task 3b - App Engine App 3
# Calls the GCS JSON REST API to fetch image metadata
# Returns a JSON response including:
#   - image file name
#   - content type
#   - file size
#   - time of creation
#   - student ID
#   - request time and date
# URL paths: /metadata/1, /metadata/2, /metadata/3
# ============================================================

from flask import Flask, abort, jsonify, request
from datetime import datetime
import requests

app = Flask(__name__)

BUCKET_NAME = "ccws-coursework-1-ccws-images"
STUDENT_ID  = "S2555839"

# Map image number to filename
IMAGES = {
    "1": "dog.jpg",
    "2": "mountain.jpg",
    "3": "city.jpg"
}

# GCS JSON API endpoint 
GCS_API_BASE = "https://storage.googleapis.com/storage/v1/b/{bucket}/o/{object}"

@app.route('/')
def index():
    user_email = request.headers.get('X-Goog-Authenticated-User-Email', 'Not available')
    user_email = user_email.split(':')[-1]  # needed for strip

    return f"""
    <!DOCTYPE html>
    <html>
      <head><title>CCWS Metadata API</title></head>
      <body style="font-family:Arial;margin:40px;">
        <h1>Image Metadata API</h1>
        <p style="background:#d4edda;padding:10px;border-radius:5px;">
          ✅ Access granted to: <strong>{user_email}</strong>
        </p>
        <ul>
          <li><a href="/metadata/1">/metadata/1 - Dog metadata</a></li>
          <li><a href="/metadata/2">/metadata/2 - Mountain metadata</a></li>
          <li><a href="/metadata/3">/metadata/3 - City metadata</a></li>
        </ul>
      </body>
    </html>
    """

@app.route('/metadata/<image_id>')
def serve_metadata(image_id):
    if image_id not in IMAGES:
        abort(404)

    filename = IMAGES[image_id]

    # Build the URL
    api_url = GCS_API_BASE.format(
        bucket=BUCKET_NAME,
        object=filename
    )

    # Call the GCS REST API every request
    response = requests.get(api_url)

    if response.status_code != 200:
        return jsonify({
            "error": f"Failed to fetch metadata. Status: {response.status_code}"
        }), 500

    gcs_data = response.json()

    # Return metadata + project info
    metadata = {
        "student_id":      STUDENT_ID,
        "request_time":    datetime.now().strftime("%A %d %B %Y, %H:%M:%S"),
        "image_filename":  gcs_data.get("name"),
        "content_type":    gcs_data.get("contentType"),
        "file_size_bytes": gcs_data.get("size"),
        "time_created":    gcs_data.get("timeCreated")
    }

    return jsonify(metadata)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)