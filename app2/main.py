# ============================================================
# Task 2d - App Engine App 2
# Serves images from Cloud Storage bucket with captions
# URL paths: /images/1, /images/2, /images/3
# ============================================================

from flask import Flask, abort

app = Flask(__name__)

# ============================================================
# Replace YOUR_BUCKET_NAME with your actual bucket name
# e.g. "my-project-123456-ccws-images"
# ============================================================
BUCKET_NAME = "ccws-coursework-1-ccws-images"
BUCKET_BASE_URL = f"https://storage.googleapis.com/{BUCKET_NAME}"

# Map image number to filename and caption
IMAGES = {
    "1": {
        "filename": "dog.jpg",
        "caption": "A friendly dog enjoying the outdoors"
    },
    "2": {
        "filename": "mountain.jpg",
        "caption": "A stunning mountain landscape"
    },
    "3": {
        "filename": "city.jpg",
        "caption": "A vibrant city skyline at dusk"
    }
}

@app.route('/')
def index():
    return """
    <!DOCTYPE html>
    <html>
      <head><title>CCWS Image Viewer</title></head>
      <body style="font-family:Arial;margin:40px;">
        <h1>Image Viewer</h1>
        <ul>
          <li><a href="/images/1">Image 1 - Dog</a></li>
          <li><a href="/images/2">Image 2 - Mountain</a></li>
          <li><a href="/images/3">Image 3 - City</a></li>
        </ul>
      </body>
    </html>
    """

@app.route('/images/<image_id>')
def serve_image(image_id):
    # Check the requested image number is valid
    if image_id not in IMAGES:
        abort(404)

    image = IMAGES[image_id]
    image_url = f"{BUCKET_BASE_URL}/{image['filename']}"

    html = f"""
    <!DOCTYPE html>
    <html>
      <head>
        <title>CCWS Image Viewer - Image {image_id}</title>
        <style>
          body {{ font-family: Arial, sans-serif; margin: 40px; text-align: center; }}
          h1 {{ color: #333; }}
          img {{ max-width: 800px; width: 100%; border: 2px solid #ccc; border-radius: 8px; }}
          p.caption {{ font-size: 1.2em; color: #555; margin-top: 15px; }}
          nav {{ margin-bottom: 30px; }}
          nav a {{ margin: 0 10px; text-decoration: none; color: #0066cc; font-size: 1.1em; }}
        </style>
      </head>
      <body>
        <h1>Cloud Storage Image Viewer</h1>
        <nav>
          <a href="/images/1">Image 1</a>
          <a href="/images/2">Image 2</a>
          <a href="/images/3">Image 3</a>
        </nav>
        <img src="{image_url}" alt="{image['caption']}">
        <p class="caption">{image['caption']}</p>
      </body>
    </html>
    """
    return html

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)