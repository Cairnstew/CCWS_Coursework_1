# MMI226816 | Cloud Computing and Web Services | Coursework 1

**S2555839 | Sean Cairns**

---

**Glasgow Caledonian University**  
**Department of Computer Science | School of Science and Engineering**

## Cloud Computing and Web Services  
**MMI226816**  
**Coursework 1 — Diet 1**

| Field          | Details                  |
|----------------|--------------------------|
| Student Name   | Sean Cairns              |
| Student ID     | S2555839                 |
| Module Leader  | Dr Imene Mitiche         |
| Trimester      | Trimester B, 2025–26     |
| Issue Date     | 26th February 2026       |
| Submission Date| 18th March 2026          |

---

## Table of Contents

- **Task 1 — Compute Engine and App Engine** ................................................ 3
  - 1a — Linux Compute Engine Instance ...................................................... 3
  - 1b — Web Server Installation .................................................................. 5
  - 1c — Serving an Image File .................................................................... 6
  - 1d — App Engine Application .................................................................. 7
- **Task 2 — Cloud Storage and Image Serving** ............................................. 10
  - 2a — Cloud Storage Bucket .................................................................... 10
  - 2b — Uploading Public Images ............................................................... 11
  - 2c — HTML Image Gallery on Compute Engine .......................................... 12
  - 2d — App Engine Image Viewer .............................................................. 13
- **Task 3 — REST API and Identity-Aware Proxy** .......................................... 17
  - 3a — APIs Explorer ............................................................................... 17
  - 3b — App Engine Metadata Application ................................................... 19
  - 3c — Identity-Aware Proxy (IAP) ............................................................ 21

**References** ......................................................................................... 24

---

## Task 1 — Compute Engine and App Engine

Task 1 demonstrates the creation of cloud infrastructure on the Google Cloud Platform, specifically a Debian virtual machine using Compute Engine. Furthermore, the installation and configuration of a nginx web server, serving simple static content, and the deployment of a serverless application using Google’s App Engine. Terraform served as the infrastructure as code tool ensuring repeatability and consistency.

### 1a — Linux Compute Engine Instance

#### Overview
A Debian/Linux Compute Engine virtual machine was provisioned in the `europe-west2` (London) region using an `e2-micro` machine type. The `e2-micro` instance type was selected for its low operating cost — it falls within the Google Cloud free tier allowance — while remaining suitable for lightweight web serving workloads. The instance was configured to permit both HTTP (port 80) and HTTPS (port 443) inbound network traffic via dedicated firewall rules. Infrastructure provisioning was managed declaratively using Terraform, ensuring that all configuration decisions are version-controlled and reproducible.

#### Terraform Configuration
```terraform
resource "google_compute_instance" "web_server" {
  name         = "ccws-web-server"
  machine_type = "e2-micro"   # Low cost; eligible for free tier
  zone         = "europe-west2-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 10  # GB
    }
  }

  network_interface {
    network = "default"
    access_config {}  # Assigns a public IP
  }

  tags = ["http-server", "https-server", "ssh-server"]

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx
    mkdir -p /var/www/html/images
  EOT
}
```

Separate firewall rules were defined for HTTP, HTTPS, and SSH traffic, each targeting instances with the corresponding network tag. This approach follows the principle of least privilege by scoping firewall rules to tagged instances rather than the entire network.

**Figure 1.1** — Compute Engine instance details in Google Cloud Console  
**Figure 1.2** — Terraform apply output confirming successful provisioning

### 1b — Web Server Installation

#### Overview
Nginx was selected as the web server on the basis of its lightweight memory footprint, high performance for static content delivery, and wide industry adoption. Unlike Apache, Nginx uses an asynchronous, event-driven architecture which makes it more efficient under concurrent connections — well-suited to a low-resource `e2-micro` instance. Installation was automated via the Terraform startup script, ensuring the server is ready immediately upon instance creation without requiring manual intervention.

#### Startup Script
```bash
#!/bin/bash
apt-get update -y
apt-get install -y nginx
systemctl enable nginx          # Start automatically on reboot
systemctl start nginx
mkdir -p /var/www/html/images
chmod 755 /var/www/html/images

# Default landing page
echo '<html><body><h1>CCWS Coursework 1</h1>
<p>Web server is running.</p></body></html>' > /var/www/html/index.html
```

#### Verification
The web server was verified by navigating to the instance’s external IP address in a web browser over HTTP. The Nginx default page was replaced with a custom landing page confirming that the server was operational. Additionally, the service status was confirmed via SSH using `systemctl status nginx`, which reported the service as active (running).

**Figure 1.3** — `systemctl status nginx` confirming Nginx is active and running  
**Figure 1.4** — Browser confirming Nginx is serving HTTP responses on the VM’s public IP

### 1c — Serving an Image File

#### Overview
A photographic image was copied from the local machine to the Compute Engine instance and served by Nginx using a custom URL path. The `gcloud compute scp` command was used to transfer the file securely over SSH to the `/var/www/html/images/` directory, which falls within Nginx’s document root. No additional Nginx configuration was required, as the default server block serves all files within the document root hierarchy.

#### Upload Command
```bash
gcloud compute scp images/dog.jpg ccws-web-server:/var/www/html/images/dog.jpg \
  --zone=europe-west2-b --project=ccws-coursework-1
```

#### Resulting URL
`http://<VM_PUBLIC_IP>/images/dog.jpg`

**Figure 1.5** — Successful file transfer to the VM via `gcloud compute scp`  
**Figure 1.6** — Image served successfully by Nginx via the custom URL path

### 1d — App Engine Application

#### Overview
A Python Flask web application was developed and deployed to Google App Engine (Standard Environment). The application presents the student’s name, student ID, and the precise date and time of the browser request, generated fresh on each HTTP request using Python’s `datetime` module. Python 3.11 was selected as the runtime as it is a current long-term support version supported by App Engine Standard. Gunicorn was used as the production WSGI server in place of Flask’s built-in development server, which is not suitable for production deployment. The application was tested both locally (using Flask’s development server on port 8080) and remotely (via the App Engine URL).

#### Application Code (`app1/main.py`)
```python
from flask import Flask
from datetime import datetime

app = Flask(__name__)

@app.route('/')
def index():
    # Timestamp generated fresh on every request
    now = datetime.now().strftime('%A %d %B %Y, %H:%M:%S')
    html = f'''<!DOCTYPE html>
<html>
<head><title>CCWS Coursework 1 - Task 1d</title></head>
<body>
    <h1>Cloud Computing and Web Services - Coursework 1</h1>
    <table>
        <tr><th>Field</th><th>Value</th></tr>
        <tr><td>Name</td><td>Sean Cairns</td></tr>
        <tr><td>Student ID</td><td>S2555839</td></tr>
        <tr><td>Access Time</td><td>{now}</td></tr>
    </table>
</body>
</html>'''
    return html

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)
```

#### App Engine Configuration (`app1/app.yaml`)
```yaml
runtime: python3.11
entrypoint: gunicorn -b :$PORT main:app
```

#### Deployment
```bash
cd app1
gcloud app deploy --quiet --project=ccws-coursework-1
```

**Figure 1.7** — App 1 running locally on port 8080 (local test prior to deployment)  
**Figure 1.8** — App Engine deployment output confirming successful deployment  
**Figure 1.9** — App 1 accessed remotely via the App Engine URL, showing live timestamp

---

## Task 2 — Cloud Storage and Image Serving

This task demonstrates the use of Google Cloud Storage as a scalable, highly available object store for image assets, configured for public access and multi-region replication. A static HTML image gallery was served from the Compute Engine instance, and a second App Engine application was developed to serve individual images from the bucket via parameterised URL paths.

### 2a — Cloud Storage Bucket

#### Overview
A Cloud Storage bucket was provisioned using Terraform with the EU multi-region location. The EU location replicates data redundantly across multiple data centres within the European Union, satisfying the requirement for content replication across at least two regions. The STANDARD storage class was selected as it is optimised for data that is accessed frequently (multiple times per month), making it the appropriate choice for serving images to web clients. Uniform bucket-level access control was enabled to simplify IAM management. A CORS policy was also configured to permit cross-origin GET requests, ensuring images can be embedded in web pages served from different origins.

#### Terraform Configuration
```terraform
resource "google_storage_bucket" "images_bucket" {
  name                      = "ccws-coursework-1-ccws-images"
  location                  = "EU"          # Multi-region: replicates across EU
  storage_class             = "STANDARD"    # Appropriate for frequent access
  force_destroy             = true
  uniform_bucket_level_access = true

  cors {
    origin          = ["*"]
    method          = ["GET"]
    response_header = ["Content-Type"]
    max_age_seconds = 3600
  }
}

# Grant public read access to all objects
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.images_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}
```

**Figure 2.1** — Cloud Storage bucket configuration confirming EU multi-region and Standard class

### 2b — Uploading Public Images

#### Overview
Three photographic images were uploaded to the Cloud Storage bucket using the `gsutil cp` command. Public read access was granted to all objects via the IAM policy applied through Terraform (`roles/storage.objectViewer` for `allUsers`), making each image accessible via a predictable public HTTPS URL without requiring authentication.

#### Upload Commands
```bash
gsutil cp images/dog.jpg      gs://ccws-coursework-1-ccws-images/
gsutil cp images/mountain.jpg gs://ccws-coursework-1-ccws-images/
gsutil cp images/city.jpg     gs://ccws-coursework-1-ccws-images/
```

#### Public URLs
- `https://storage.googleapis.com/ccws-coursework-1-ccws-images/dog.jpg`
- `https://storage.googleapis.com/ccws-coursework-1-ccws-images/mountain.jpg`
- `https://storage.googleapis.com/ccws-coursework-1-ccws-images/city.jpg`

**Figure 2.2** — Three images uploaded to the Cloud Storage bucket  
**Figure 2.3** — Confirming `mountain.jpg` is publicly accessible via its HTTPS URL

### 2c — HTML Image Gallery on Compute Engine

#### Overview
A static HTML file was created to display all three Cloud Storage images in a gallery layout, with an appropriate descriptive caption beneath each image. Each image is referenced via its public Cloud Storage HTTPS URL, meaning the browser fetches images directly from Cloud Storage without proxying through the VM. The HTML file was transferred to the Compute Engine instance using `gcloud compute scp` and placed within Nginx’s document root. It is served by Nginx at the `/index/` path.

#### HTML File (`app2/index.html`)
```html
<!DOCTYPE html>
<html>
<head>
    <title>Cloud Images</title>
    <style>
        body { font-family: Arial; text-align: center; margin: 40px; }
        img { max-width: 600px; display: block; margin: 20px auto; }
        p { font-size: 1.2em; }
    </style>
</head>
<body>
    <h1>My Image Gallery</h1>
    <img src='https://storage.googleapis.com/ccws-coursework-1-ccws-images/dog.jpg'>
    <p>A friendly dog enjoying the outdoors</p>
    <img src='https://storage.googleapis.com/ccws-coursework-1-ccws-images/mountain.jpg'>
    <p>A stunning mountain landscape</p>
    <img src='https://storage.googleapis.com/ccws-coursework-1-ccws-images/city.jpg'>
    <p>A vibrant city skyline at dusk</p>
</body>
</html>
```

#### Copy to VM
```bash
gcloud compute ssh ccws-web-server --zone=europe-west2-b \
  --command='mkdir -p /var/www/html/index'
gcloud compute scp app2/index.html \
  ccws-web-server:/var/www/html/index/index.html \
  --zone=europe-west2-b --project=ccws-coursework-1
```

**Figure 2.4** — Successful transfer of the HTML gallery file to the VM  
**Figure 2.5** — HTML image gallery served by Nginx, images loaded from Cloud Storage

### 2d — App Engine Image Viewer

#### Overview
A second Python Flask application was developed and deployed to App Engine. The application serves individual images from the Cloud Storage bucket using parameterised URL paths in the format `/images/<n>`, where `n` is 1, 2, or 3. Each route returns a complete HTML page containing the corresponding image and its caption. A navigation bar allows the user to move between images without returning to a separate index page. Invalid image IDs return an HTTP 404 response, demonstrating appropriate error handling. The application was tested both locally on port 8080 and remotely via the deployed App Engine URL.

#### URL Routing

| URL Path     | Image Displayed                              |
|--------------|----------------------------------------------|
| `/images/1`  | dog.jpg — A friendly dog enjoying the outdoors |
| `/images/2`  | mountain.jpg — A stunning mountain landscape |
| `/images/3`  | city.jpg — A vibrant city skyline at dusk    |

#### Application Code (`app2/main.py`)
```python
from flask import Flask, abort

app = Flask(__name__)

BUCKET_NAME     = 'ccws-coursework-1-ccws-images'
BUCKET_BASE_URL = f'https://storage.googleapis.com/{BUCKET_NAME}'

# Maps URL index to filename and caption
IMAGES = {
    '1': {'filename': 'dog.jpg',      'caption': 'A friendly dog enjoying the outdoors'},
    '2': {'filename': 'mountain.jpg', 'caption': 'A stunning mountain landscape'},
    '3': {'filename': 'city.jpg',     'caption': 'A vibrant city skyline at dusk'},
}

@app.route('/images/<image_id>')
def serve_image(image_id):
    if image_id not in IMAGES:
        abort(404)  # Defensive: reject unknown IDs

    image     = IMAGES[image_id]
    image_url = f'{BUCKET_BASE_URL}/{image["filename"]}'

    return f'''
    <!DOCTYPE html><html>
    <head><title>CCWS Image Viewer - Image {image_id}</title></head>
    <body style='text-align:center;font-family:Arial;margin:40px;'>
      <h1>Cloud Storage Image Viewer</h1>
      <nav>
        <a href='/images/1'>Image 1</a> |
        <a href='/images/2'>Image 2</a> |
        <a href='/images/3'>Image 3</a>
      </nav>
      <img src='{image_url}' style='max-width:800px;width:100%;'>
      <p>{image['caption']}</p>
    </body></html>
    '''

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)
```

**Figure 2.6** — App 2 running locally at `/images/1`  
**Figure 2.7** — App 2 deployed on App Engine, `/images/1`  
**Figure 2.8** — App 2 deployed on App Engine, `/images/2`  
**Figure 2.9** — App 2 deployed on App Engine, `/images/3`

---

## Task 3 — REST API and Identity-Aware Proxy

This task demonstrates the consumption of a Google Cloud REST API to retrieve object metadata from Cloud Storage, the development of an App Engine application that exposes that metadata as a structured JSON response, and the securing of the application using Google Identity-Aware Proxy (IAP) to enforce authenticated, authorised access.

### 3a — APIs Explorer

#### Overview
The Google APIs Explorer was used to identify the appropriate REST API method for retrieving object metadata from a Cloud Storage bucket. The `storage.objects.get` method of the Cloud Storage JSON API v1 was identified as suitable for this purpose. This method accepts the bucket name and object name as path parameters and returns a JSON object containing all metadata fields associated with the stored object, including its file name, content type, size in bytes, and creation timestamp.

#### REST API Method

| Property   | Value                                      |
|------------|--------------------------------------------|
| API        | Cloud Storage JSON API v1                  |
| Method     | storage.objects.get                        |
| HTTP Verb  | GET                                        |
| Endpoint   | `https://storage.googleapis.com/storage/v1/b/{bucket}/o/{object}` |

#### Example Request URL
```http
GET https://storage.googleapis.com/storage/v1/b/ccws-coursework-1-ccws-images/o/dog.jpg
```

#### Example Response (subset)
```json
{
  "kind":        "storage#object",
  "name":        "dog.jpg",
  "bucket":      "ccws-coursework-1-ccws-images",
  "contentType": "image/jpeg",
  "size":        "4586",
  "timeCreated": "2026-03-17T19:03:23.481Z"
}
```

**Figure 3.1** — Google APIs Explorer showing the `storage.objects.get` method  
**Figure 3.2** — APIs Explorer showing a live 200 response with metadata for `dog.jpg`

### 3b — App Engine Metadata Application

#### Overview
A third Python Flask application was developed and deployed to App Engine. The application calls the GCS REST API (`storage.objects.get`) on every incoming HTTP request to retrieve current metadata for the specified image. It does not cache the API response between requests, satisfying the requirement that the REST API is called each time. The application returns a JSON response containing a required subset of the metadata alongside the student ID and a server-side timestamp indicating when the request was processed. As the bucket is publicly readable, no authentication token is required to call the metadata endpoint; the request is made using the Python `requests` library with no credentials.

#### URL Routing

| URL Path       | Response                          |
|----------------|-----------------------------------|
| `/metadata/1`  | JSON metadata for dog.jpg         |
| `/metadata/2`  | JSON metadata for mountain.jpg    |
| `/metadata/3`  | JSON metadata for city.jpg        |

#### JSON Response Fields

| Field            | Source                          |
|------------------|---------------------------------|
| image_filename   | GCS API — name field            |
| content_type     | GCS API — contentType field     |
| file_size_bytes  | GCS API — size field            |
| time_created     | GCS API — timeCreated field     |
| student_id       | Hardcoded constant (S2555839)   |
| request_time     | `datetime.now()` at time of request |

#### Application Code (`app3/main.py`)
```python
from flask import Flask, abort, jsonify
from datetime import datetime
import requests

app = Flask(__name__)

BUCKET_NAME = 'ccws-coursework-1-ccws-images'
STUDENT_ID  = 'S2555839'
GCS_API_BASE = 'https://storage.googleapis.com/storage/v1/b/{bucket}/o/{object}'

IMAGES = {
    '1': 'dog.jpg',
    '2': 'mountain.jpg',
    '3': 'city.jpg',
}

@app.route('/metadata/<image_id>')
def serve_metadata(image_id):
    if image_id not in IMAGES:
        abort(404)

    filename = IMAGES[image_id]

    # Construct GCS REST API URL and call it fresh on every request
    api_url  = GCS_API_BASE.format(bucket=BUCKET_NAME, object=filename)
    response = requests.get(api_url)

    if response.status_code != 200:
        return jsonify({'error': f'GCS API error: {response.status_code}'}), 500

    gcs = response.json()

    # Return required subset plus student ID and request timestamp
    return jsonify({
        'student_id':      STUDENT_ID,
        'request_time':    datetime.now().strftime('%A %d %B %Y, %H:%M:%S'),
        'image_filename':  gcs.get('name'),
        'content_type':    gcs.get('contentType'),
        'file_size_bytes': gcs.get('size'),
        'time_created':    gcs.get('timeCreated')
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)
```

**Figure 3.3** — App 3 running locally, `/metadata/1` returning JSON for dog.jpg  
**Figure 3.4** — App 3 deployed on App Engine, `/metadata/1`  
**Figure 3.5** — App 3 deployed on App Engine, `/metadata/2`  
**Figure 3.6** — App 3 deployed on App Engine, `/metadata/3`

### 3c — Identity-Aware Proxy (IAP)

#### Overview
Google Identity-Aware Proxy (IAP) was configured to secure the App Engine application, ensuring that only an explicitly authorised user (`seanstrcairns@gmail.com`) can access it. IAP enforces authentication and authorisation at the Google network level, intercepting requests before they reach the application and redirecting unauthenticated users to a Google sign-in page. Authenticated users are checked against the IAP IAM policy; those without the `roles/iap.httpsResourceAccessor` role receive a “You don’t have access” denial page. This approach requires no changes to the application code itself.

#### Step 1 — Enable IAP API
```bash
gcloud services enable iap.googleapis.com --project=ccws-coursework-1
```

#### Step 2 — Enable IAP on App Engine
```bash
gcloud iap web enable \
  --resource-type=app-engine \
  --project=ccws-coursework-1
```

#### Step 3 — Verify OAuth Brand
```bash
gcloud iap oauth-brands list --project=ccws-coursework-1
# Result: brand already existed with supportEmail: seanstrcairns@gmail.com
```

#### Step 4 — Grant IAP Accessor Role
```bash
gcloud iap web add-iam-policy-binding \
  --resource-type=app-engine \
  --project=ccws-coursework-1 \
  --member='user:seanstrcairns@gmail.com' \
  --role='roles/iap.httpsResourceAccessor'
```

#### Step 5 — Create OAuth Client ID (Console)
An OAuth 2.0 Client ID was created manually in the Google Cloud Console via **APIs & Services → Credentials → Create Credentials → OAuth Client ID**. The application type was set to **Web application** and the client was named **IAP-App-Engine-Client**. An authorised redirect URI was added:
```
https://iap.googleapis.com/v1/oauth/clientIds/502055903328-ovhl5sneef0cfi3jq9dg12rhjj7aso2o.apps.googleusercontent.com:handleRedirect
```

#### Step 6 — Add Test User to OAuth Consent Screen
The account `seanstrcairns@gmail.com` was added via **APIs & Services → OAuth consent screen → Test users**.

#### Step 7 — Re-enable IAP with OAuth Credentials
```bash
gcloud iap web enable \
  --resource-type=app-engine \
  --project=ccws-coursework-1 \
  --oauth2-client-id=502055903328-ovhl5sneef0cfi3jq9dg12rhjj7aso2o.apps.googleusercontent.com \
  --oauth2-client-secret=GOCSPX-SPOFnPnkxdXoxv96qoXJz…
```

#### Step 8 — Verify OAuth Client ID
```bash
gcloud iap oauth-clients list projects/502055903328/brands/502055903328
```

**Figure 3.7** — IAP redirecting unauthenticated user to Google sign-in  
**Figure 3.8** — Authorized access granted after authenticating as `seanstrcairns@gmail.com`  
**Figure 3.9** — IAP denying access to an unauthorised Google account

---

## References

1. Google Cloud. (n.d.). *Compute Engine documentation*. Retrieved 12 March 2026, from https://cloud.google.com/compute/docs  
2. Google Cloud. (n.d.). *Cloud Storage JSON API v1: Objects: get*. Retrieved 15 March 2026, from https://cloud.google.com/storage/docs/json_api/v1/objects/get  
3. HashiCorp. (n.d.). *Terraform Google Cloud provider documentation*. Retrieved 01 March 2026, from https://registry.terraform.io/providers/hashicorp/google/latest/docs

---

**S2555839 | Sean Cairns**  
**Page 24** (End of document)
