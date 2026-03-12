# ============================================================
# CCWS Coursework 1 - Terraform Configuration
# Region: europe-west2 (London)
# Web Server: Nginx
# ============================================================

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# ============================================================
# Variables - fill these in with your own values
# ============================================================

variable "project_id" {
  description = "Your GCP Project ID"
  type        = string
}

variable "student_id" {
  description = "Your Student ID e.g. S1234567"
  type        = string
}

# ============================================================
# Provider
# ============================================================

provider "google" {
  project = var.project_id
  region  = "europe-west2"
  zone    = "europe-west2-b"
}

# ============================================================
# TASK 1a - Compute Engine Instance (e2-micro = low cost)
# ============================================================

resource "google_compute_instance" "web_server" {
  name         = "ccws-web-server"
  machine_type = "e2-micro"   # Low cost, suitable for web serving
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

  # Allow HTTP and HTTPS traffic (Task 1a requirement)
  tags = ["http-server", "https-server"]

  # Task 1b - Install and start Nginx on boot
  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx

    # Task 1c - Create a directory for serving images
    mkdir -p /var/www/html/images

    # Create a simple default index page
    cat > /var/www/html/index.html <<EOF
    <html>
      <body>
        <h1>CCWS Coursework 1</h1>
        <p>Web server is running.</p>
      </body>
    </html>
    EOF
  EOT
}

# Firewall rule - allow HTTP
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}

# Firewall rule - allow HTTPS
resource "google_compute_firewall" "allow_https" {
  name    = "allow-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["https-server"]
}

# ============================================================
# TASK 2a - Cloud Storage Bucket
# Multi-region (replicates to 2 regions), STANDARD = frequent access
# ============================================================

resource "google_storage_bucket" "images_bucket" {
  name          = "${var.project_id}-ccws-images"  # Must be globally unique
  location      = "EU"           # Multi-region covering europe-west2
  storage_class = "STANDARD"     # Appropriate for frequent access

  uniform_bucket_level_access = true  # Required for public access via IAM

  cors {
    origin          = ["*"]
    method          = ["GET"]
    response_header = ["Content-Type"]
    max_age_seconds = 3600
  }
}

# Task 2b - Make bucket publicly readable
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.images_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# ============================================================
# App Engine - enable the application (required before deploying apps)
# ============================================================

resource "google_app_engine_application" "app" {
  location_id = "europe-west2"  # London region for App Engine
}

# ============================================================
# Outputs - useful values to copy after terraform apply
# ============================================================

output "compute_instance_ip" {
  description = "Public IP of your Compute Engine instance"
  value       = google_compute_instance.web_server.network_interface[0].access_config[0].nat_ip
}

output "storage_bucket_name" {
  description = "Name of your Cloud Storage bucket"
  value       = google_storage_bucket.images_bucket.name
}

output "storage_bucket_url" {
  description = "Public URL of your Cloud Storage bucket"
  value       = "https://storage.googleapis.com/${google_storage_bucket.images_bucket.name}"
}
